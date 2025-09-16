export default {
  mounted() {
    const container = this.el;
    const panel = container.querySelector("[data-mobile-panel]");
    const backdrop = container.querySelector("[data-mobile-backdrop]");

    if (!panel) return;

    this.handleKey = (e) => {
      if (e.key === "Escape") {
        // close directly
        this.close();
      }
    };

    this.trapFocus = (e) => {
      const focusable = panel.querySelectorAll(
        'a[href], button:not([disabled]), textarea, input, select, [tabindex]:not([tabindex="-1"])'
      );
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];

      if (e.key === "Tab") {
        if (e.shiftKey && document.activeElement === first) {
          e.preventDefault();
          last.focus();
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault();
          first.focus();
        }
      }
    };

    document.addEventListener("keydown", this.handleKey);
    panel.addEventListener("keydown", this.trapFocus);

    // when menu is toggled, focus the first focusable element in the panel (if opening)
    this.onToggled = (e) => {
      const detail = e.detail || {};
      if (detail && detail.close) {
        // closing event: do nothing here (JS.toggle already runs)
        return;
      }

      // menu opened: focus first focusable
      const focusable = panel.querySelectorAll(
        'a[href], button:not([disabled]), textarea, input, select, [tabindex]:not([tabindex="-1"])'
      );
      if (focusable.length > 0) focusable[0].focus();
    };

    document.addEventListener("voile:mobile-nav-toggled", this.onToggled);

    this.close = () => {
      if (backdrop.classList.contains("hidden")) return;

      // Try LiveView JS toggle (non-blocking) then ensure DOM classes are updated
      try {
        const phx = window.LiveView && window.LiveView.JS;
        if (phx) {
          phx.toggle({
            to: "#mobileNav [data-mobile-backdrop]",
            in: "block opacity-100 pointer-events-auto",
            out: "hidden opacity-0 pointer-events-none",
            display: "block",
          });
          phx.toggle({
            to: "#mobileNav [data-mobile-panel]",
            in: "block translate-x-0",
            out: "hidden -translate-x-full",
            display: "block",
          });
        }
      } catch (err) {
        // ignore
      }

      // Always update DOM classes as a reliable fallback so ESC always closes the menu
      backdrop.classList.add("hidden");
      backdrop.classList.remove("opacity-100");
      backdrop.classList.add("opacity-0");
      backdrop.classList.remove("pointer-events-auto");
      backdrop.classList.add("pointer-events-none");

      panel.classList.add("hidden");
      panel.classList.remove("translate-x-0");
      panel.classList.add("-translate-x-full");

      // return focus to the mobile toggle button if present
      const toggle = document.getElementById("mobile-nav-toggle");
      if (toggle) toggle.focus();
    };

    // listen for programmatic close event on the element
    this.el.addEventListener("close-mobile-nav", this.close);
  },
  destroyed() {
    document.removeEventListener("keydown", this.handleKey);
    const panel = this.el.querySelector("[data-mobile-panel]");
    if (panel) panel.removeEventListener("keydown", this.trapFocus);
    this.el.removeEventListener("close-mobile-nav", this.close);
  },
};
