/// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { hooks as colocatedHooks } from "phoenix-colocated/voile";
import { ItemSearch } from "./hooks/item_search_hook";
import { SearchDropdown } from "./hooks/search_dropdown_hook";
import { SearchPanel } from "./hooks/search_panel_hook";
import { TurnstileHook } from "phoenix_turnstile";
import { EbookReader } from "./hooks/ebook_reader_hook";
import { BarcodeScanner } from "./hooks/barcode_scanner";
import topbar from "../vendor/topbar";
import DragDrop from "./hooks/sortable";
import DragUpload from "./hooks/draggable_area";
import position_panel from "./hooks/position_panel";
import MobileNav from "./hooks/mobile_nav";
import SearchFocus from "./hooks/search_focus";
import SearchResultsLoading from "./hooks/search_results_loading";
import PasswordToggle from "./hooks/password_toggle";

// LocaleSwitcher Hook for current path and locale link rewriting
const LocaleSwitcher = {
  mounted() {
    this.syncLocaleLinks();
  },
  updated() {
    this.syncLocaleLinks();
  },
  syncLocaleLinks() {
    const injectedPath = this.el.dataset.currentPath || "/";
    const windowPath = window.location.pathname || "/";
    const resolvedPath =
      windowPath && !windowPath.startsWith("/live")
        ? windowPath
        : injectedPath || "/";

    const normalizePath = (path) => {
      const p = (path || "/").split("?")[0] || "/";
      if (p.startsWith("/live")) {
        return "/";
      }
      return p === "" ? "/" : p;
    };

    const base = normalizePath(resolvedPath);

    const links = [...this.el.querySelectorAll("a[data-locale], a[href*='locale="]")];

    links.forEach((link) => {
      const locale = link.dataset.locale || new URL(link.href, window.location.origin).searchParams.get("locale");
      if (!locale) return;

      link.setAttribute("href", `${base}?locale=${encodeURIComponent(locale)}`);
      link.dataset.locale = locale;
    });
  },
};

// Notification Sound Hook for reservation notifications
const NotificationSound = {
  mounted() {
    this.handleEvent("play_notification_sound", () => {
      // Play custom reservation notification sound
      const audio = new Audio("/sfx/reservation.mp3");
      audio.play().catch((e) => console.log("Audio play failed:", e));

      console.log("🔔 New reservation notification");
    });
  },
};

// Check-in Storage Hook for persisting node and location selection
// Helper: set a cookie with a max-age (seconds). SameSite=Lax keeps it
// compatible with standard same-origin navigation while still surviving
// browser restarts (unlike sessionStorage) and "clear on close" settings
// that only target sessionStorage / some localStorage implementations.
const ONE_YEAR_SECONDS = 365 * 24 * 60 * 60;
function setCookie(name, value, maxAge = ONE_YEAR_SECONDS) {
  document.cookie = `${name}=${encodeURIComponent(value)}; max-age=${maxAge}; path=/; SameSite=Lax`;
}
function getCookie(name) {
  const match = document.cookie
    .split("; ")
    .find((c) => c.startsWith(name + "="));
  return match ? decodeURIComponent(match.split("=")[1]) : null;
}
function deleteCookie(name) {
  document.cookie = `${name}=; max-age=0; path=/; SameSite=Lax`;
}

const CheckInStorage = {
  mounted() {
    // Try to restore from cookie on mount (falls back to localStorage for
    // clients that already had the old value stored there)
    const nodeId =
      getCookie("visitor_check_in_node_id") ||
      localStorage.getItem("visitor_check_in_node_id");
    const locationId =
      getCookie("visitor_check_in_location_id") ||
      localStorage.getItem("visitor_check_in_location_id");

    if (nodeId && locationId) {
      this.pushEvent("restore_from_storage", {
        node_id: nodeId,
        location_id: locationId,
      });
    }

    // Handle clear storage events
    this.handleEvent("clear_location_storage", () => {
      deleteCookie("visitor_check_in_location_id");
      localStorage.removeItem("visitor_check_in_location_id");
    });

    this.handleEvent("clear_check_in_storage", () => {
      deleteCookie("visitor_check_in_node_id");
      deleteCookie("visitor_check_in_location_id");
      localStorage.removeItem("visitor_check_in_node_id");
      localStorage.removeItem("visitor_check_in_location_id");
    });
  },
  updated() {
    // Save to cookie when node or location changes
    const nodeId = this.el.dataset.nodeId;
    const locationId = this.el.dataset.locationId;

    if (nodeId && nodeId !== "undefined" && nodeId !== "null") {
      setCookie("visitor_check_in_node_id", nodeId);
      localStorage.setItem("visitor_check_in_node_id", nodeId);
    }

    if (locationId && locationId !== "undefined" && locationId !== "null") {
      setCookie("visitor_check_in_location_id", locationId);
      localStorage.setItem("visitor_check_in_location_id", locationId);
    }
  },
};

// Virtual Keyboard Tab Hook for handling tab switching
const VirtualKeyboardTab = {
  mounted() {
    // Initialize active tab state (default to "number")
    this.activeTab = "number";
    this.setupTabs();
  },
  updated() {
    // Restore active tab after LiveView updates
    this.setupTabs();
  },
  setupTabs() {
    const tabs = this.el.querySelectorAll(".keyboard-tab");
    const contents = this.el.querySelectorAll(".keyboard-content");

    // Set up click listeners (idempotent - won't duplicate)
    tabs.forEach((tab) => {
      // Remove old listener if exists
      const newTab = tab.cloneNode(true);
      tab.parentNode.replaceChild(newTab, tab);

      newTab.addEventListener("click", (e) => {
        const targetTab = newTab.dataset.tab;
        this.activeTab = targetTab;
        this.activateTab(targetTab);
      });
    });

    // Activate the current active tab
    this.activateTab(this.activeTab);
  },
  activateTab(targetTab) {
    const tabs = this.el.querySelectorAll(".keyboard-tab");
    const contents = this.el.querySelectorAll(".keyboard-content");

    // Remove active class from all tabs
    tabs.forEach((t) => {
      t.classList.remove(
        "active",
        "text-blue-600",
        "dark:text-blue-400",
        "border-b-2",
        "border-blue-600",
        "dark:border-blue-400",
      );
      t.classList.add(
        "text-gray-600",
        "dark:text-gray-400",
        "hover:text-blue-600",
        "dark:hover:text-blue-400",
      );
    });

    // Add active class to target tab
    const targetTabEl = this.el.querySelector(`[data-tab="${targetTab}"]`);
    if (targetTabEl) {
      targetTabEl.classList.add(
        "active",
        "text-blue-600",
        "dark:text-blue-400",
        "border-b-2",
        "border-blue-600",
        "dark:border-blue-400",
      );
      targetTabEl.classList.remove(
        "text-gray-600",
        "dark:text-gray-400",
        "hover:text-blue-600",
        "dark:hover:text-blue-400",
      );
    }

    // Hide all content panels
    contents.forEach((content) => {
      content.classList.add("hidden");
      content.classList.remove("active");
    });

    // Show target content panel
    const targetContent = this.el.querySelector(
      `[data-content="${targetTab}"]`,
    );
    if (targetContent) {
      targetContent.classList.remove("hidden");
      targetContent.classList.add("active");
    }
  },
};

// Identifier Input Hook for auto-focus and barcode scanning
const IdentifierInput = {
  mounted() {
    // Auto-focus on mount for barcode scanning
    this.el.focus();
    this.moveCursorToEnd();

    // Listen for focus event from server
    this.handleEvent("focus_identifier", () => {
      this.el.focus();
      this.moveCursorToEnd();
    });

    // Clear input on Enter key (for barcode scanners)
    this.el.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        const form = this.el.closest("form");
        if (form) {
          // Submit the form
          form.dispatchEvent(
            new Event("submit", { bubbles: true, cancelable: true }),
          );
          // Clear the input immediately
          setTimeout(() => {
            this.el.value = "";
            this.el.focus();
          }, 100);
        }
      }
    });
  },
  updated() {
    // Ensure focus after updates and move cursor to end
    this.el.focus();
    this.moveCursorToEnd();
  },
  moveCursorToEnd() {
    // Move cursor to the end of the input
    const length = this.el.value.length;
    this.el.setSelectionRange(length, length);
  },
};

// Realtime Clock Hook for client-side time display
const RealtimeClock = {
  mounted() {
    this.updateClock();
    this.interval = setInterval(() => this.updateClock(), 1000);
  },
  destroyed() {
    if (this.interval) clearInterval(this.interval);
  },
  updateClock() {
    const now = new Date();

    // Format time (HH:MM:SS)
    const hours = String(now.getHours()).padStart(2, "0");
    const minutes = String(now.getMinutes()).padStart(2, "0");
    const seconds = String(now.getSeconds()).padStart(2, "0");
    const timeString = `${hours}:${minutes}:${seconds}`;

    // Format date (Sunday, 08 Feb 2026)
    const days = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
    ];
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    const dayName = days[now.getDay()];
    const day = String(now.getDate()).padStart(2, "0");
    const month = months[now.getMonth()];
    const year = now.getFullYear();
    const dateString = `${dayName}, ${day} ${month} ${year}`;

    // Update DOM
    const timeEl = this.el.querySelector("[data-clock-time]");
    const dateEl = this.el.querySelector("[data-clock-date]");
    if (timeEl) timeEl.textContent = timeString;
    if (dateEl) dateEl.textContent = dateString;
  },
};

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: {
    DragDrop,
    DragUpload,
    position_panel,
    MobileNav,
    ItemSearch,
    SearchDropdown,
    SearchPanel,
    SearchFocus,
    SearchResultsLoading,
    NotificationSound,
    LocaleSwitcher,
    BarcodeScanner,
    CheckInStorage,
    IdentifierInput,
    VirtualKeyboardTab,
    RealtimeClock,
    Turnstile: TurnstileHook,
    EbookReader,
    PasswordToggle,
    ...colocatedHooks,
  },
});

// Listen for Voile-specific dispatched events from HEEx components
document.addEventListener("voile:set-active-tab", (e) => {
  try {
    const { selector, content } = e.detail || {};
    if (selector) {
      // set active tab styles
      document
        .querySelectorAll(".search-tab-item")
        .forEach((el) => el.classList.remove("active-tab-item"));
      const tab = document.querySelector(selector);
      if (tab) tab.classList.add("active-tab-item");
    }

    if (content) {
      // show the corresponding content pane if present
      document
        .querySelectorAll(".tab-pane")
        .forEach((p) => p.classList.remove("active"));
      const pane = document.querySelector(content);
      if (pane) pane.classList.add("active");
    }
  } catch (err) {
    console.error("Error handling voile:set-active-tab", err);
  }
});

// Handle copy to clipboard
document.addEventListener("voile:copy-to-clipboard", async (e) => {
  try {
    // For token copy functionality, we hardcode the selector
    const targetSelector = "#new-token-value";
    const successMessage = e.detail?.success_message || "Copied!";

    if (targetSelector) {
      const input = document.querySelector(targetSelector);
      if (input) {
        const textToCopy = input.value || input.textContent;

        // Try modern Clipboard API first (requires HTTPS)
        if (navigator.clipboard && navigator.clipboard.writeText) {
          try {
            await navigator.clipboard.writeText(textToCopy);
            showSuccessFeedback(e.target, successMessage);
            return;
          } catch (clipboardErr) {
            // Fall back to legacy method
          }
        }

        // Fallback to legacy method
        try {
          input.select();
          input.setSelectionRange(0, 99999); // For mobile devices
          const successful = document.execCommand("copy");
          if (successful) {
            showSuccessFeedback(e.target, successMessage);
            return;
          }
        } catch (legacyErr) {
          // Continue to next fallback
        }

        // Last resort: try to copy using a temporary textarea
        try {
          const textArea = document.createElement("textarea");
          textArea.value = textToCopy;
          textArea.style.position = "fixed";
          textArea.style.left = "-999999px";
          textArea.style.top = "-999999px";
          document.body.appendChild(textArea);
          textArea.focus();
          textArea.select();
          const successful = document.execCommand("copy");
          document.body.removeChild(textArea);

          if (successful) {
            showSuccessFeedback(e.target, successMessage);
            return;
          }
        } catch (fallbackErr) {
          // All methods failed
        }

        // If all methods fail, show error feedback
        showErrorFeedback(e.target, "Copy failed");
      } else {
        console.error("Target element not found:", targetSelector);
      }
    }
  } catch (err) {
    console.error("Error handling voile:copy-to-clipboard", err);
  }
});

function showSuccessFeedback(element, message) {
  if (element) {
    const originalText = element.textContent;
    element.textContent = message;
    setTimeout(() => {
      if (originalText) element.textContent = originalText;
    }, 2000);
  }
}

function showErrorFeedback(element, message) {
  if (element) {
    const originalText = element.textContent;
    element.textContent = message;
    element.style.color = "red";
    setTimeout(() => {
      if (originalText) element.textContent = originalText;
      element.style.color = "";
    }, 2000);
  }
}

let header = document.getElementById("navigationHeader");
let sticky = header?.offsetTop;

const date = new Date();

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// Handle CSV download events
window.addEventListener("phx:download", (e) => {
  const { filename, content, mime_type } = e.detail;
  const blob = new Blob([content], { type: mime_type || "text/csv" });
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  window.URL.revokeObjectURL(url);
  document.body.removeChild(a);
});

// Label print isolation: clone #print-labels to a direct body child so
// the dashboard layout (min-h-screen) doesn't produce blank print pages.
let _printLabelsClone = null;

window.addEventListener("beforeprint", () => {
  const el = document.getElementById("print-labels");
  if (el) {
    _printLabelsClone = document.createElement("div");
    _printLabelsClone.id = "print-labels-clone";
    _printLabelsClone.style.display = "block";
    _printLabelsClone.innerHTML = el.innerHTML;
    document.body.appendChild(_printLabelsClone);
    document.body.classList.add("is-printing");
  }
});

window.addEventListener("afterprint", () => {
  if (_printLabelsClone) {
    _printLabelsClone.remove();
    _printLabelsClone = null;
  }
  document.body.classList.remove("is-printing");
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true,
      );

      window.liveReloader = reloader;
    },
  );
}

function handleScroll() {
  if (window.scrollY > sticky) {
    header?.classList?.add("sticky-header");
  } else {
    header?.classList?.remove("sticky-header");
  }
}

window.onscroll = function () {
  handleScroll();
};

document.addEventListener("DOMContentLoaded", function () {
  document.addEventListener("click", function (e) {
    if (
      e.target.classList.contains("search-tab-item") &&
      e.target.classList.contains("active-tab-item")
    ) {
      e.preventDefault();
      e.stopPropagation();
    }
  });
});

function applySystemTheme() {
  const isDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  document.documentElement.setAttribute(
    "data-theme",
    isDark ? "dark" : "light",
  );
  document.documentElement.classList.toggle("dark", isDark);
}

window
  .matchMedia("(prefers-color-scheme: dark)")
  .addEventListener("change", () => {
    if (localStorage.getItem("theme") === "system") {
      applySystemTheme();
    }
  });

window.addEventListener("phx:set-theme", (e) => {
  let pref = e.target.dataset.phxTheme;
  localStorage.setItem("theme", pref);
  document.documentElement.setAttribute("data-theme-pref", pref);

  if (pref === "system") {
    applySystemTheme();
  } else {
    document.documentElement.setAttribute("data-theme", pref);
    document.documentElement.classList.toggle("dark", pref === "dark");
  }
});

(function initTheme() {
  let pref = localStorage.getItem("theme") || "system";
  document.documentElement.setAttribute("data-theme-pref", pref);

  if (pref === "system") {
    applySystemTheme();
  } else {
    document.documentElement.setAttribute("data-theme", pref);
    document.documentElement.classList.toggle("dark", pref === "dark");
  }
})();

// Role form resource management is handled server-side via phx-submit on the add-resource form.
