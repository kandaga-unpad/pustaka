// Sidebar — desktop collapse toggle for the Voile redesign shell.
// Collapses the sidebar to an 80px icon rail and remembers the choice
// per-device in localStorage["voile:sidebar"]. Purely client-side: no
// server round-trip, no LiveView event needed.

const Sidebar = {
  mounted() {
    const el = this.el;
    const STORAGE_KEY = "voile:sidebar";
    const COLLAPSED_CLASS = "voile-sidebar-collapsed";
    const toggle = el.querySelector("[data-voile-sidebar-toggle]");

    // Apply persisted state on first paint (before user interaction).
    try {
      if (localStorage.getItem(STORAGE_KEY) === "collapsed") {
        el.classList.add(COLLAPSED_CLASS);
        syncToggleLabel(toggle, true);
      }
    } catch (_e) {
      // localStorage may be unavailable (private mode, etc.) — skip persistence.
    }

    if (toggle) {
      toggle.addEventListener("click", () => {
        const collapsed = el.classList.toggle(COLLAPSED_CLASS);
        try {
          localStorage.setItem(STORAGE_KEY, collapsed ? "collapsed" : "expanded");
        } catch (_e) {
          // ignore write failure
        }
        syncToggleLabel(toggle, collapsed);
      });
    }
  },
};

function syncToggleLabel(toggle, collapsed) {
  if (!toggle) return;
  toggle.setAttribute(
    "aria-label",
    collapsed ? "Expand sidebar" : "Collapse sidebar"
  );
  toggle.setAttribute("aria-expanded", collapsed ? "false" : "true");
}

export default Sidebar;
