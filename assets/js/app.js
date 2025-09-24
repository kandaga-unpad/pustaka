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
import topbar from "../vendor/topbar";
import DragDrop from "./hooks/sortable";
import DragUpload from "./hooks/draggable_area";
import position_panel from "./hooks/position_panel";
import MobileNav from "./hooks/mobile_nav";
import { ItemSearch } from "./hooks/item_search_hook";
import { SearchDropdown } from "./hooks/search_dropdown_hook";
import { SearchPanel } from "./hooks/search_panel_hook";

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

let header = document.getElementById("navigationHeader");
let sticky = header?.offsetTop;

const date = new Date();

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

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
        true
      );

      window.liveReloader = reloader;
    }
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
    isDark ? "dark" : "light"
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

// Role form resource management
window.addEventListener("phx:page-loading-stop", () => {
  // Add resource functionality
  const addResourceBtn = document.querySelector('[phx-click="add_resource"]');
  const newResourceInput = document.getElementById("new-resource");

  if (addResourceBtn && newResourceInput) {
    addResourceBtn.addEventListener("click", (e) => {
      e.preventDefault();
      const resourceName = newResourceInput.value.trim();

      if (resourceName) {
        // Send the resource name to the LiveView component
        const targetElement = e.target.closest("[phx-target]");
        if (targetElement) {
          const targetValue = targetElement.getAttribute("phx-target");
          window.liveSocket.execJS(
            targetElement,
            `[[\"push\", {\"event\":\"add_resource_with_name\", \"value\":{\"resource\":\"${resourceName}\"}}]]`
          );
        }
        newResourceInput.value = "";
      }
    });

    // Allow Enter key to add resource
    newResourceInput.addEventListener("keypress", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        addResourceBtn.click();
      }
    });
  }
});
