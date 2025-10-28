export default {
  mounted() {
    // Allow global shortcuts to focus the search input
    // - Ctrl/Cmd+K for traditional search
    // - Forward slash (/) for quick search
    this.onKey = (e) => {
      const isMac = navigator.platform.toUpperCase().indexOf("MAC") >= 0;
      const mod = isMac ? e.metaKey : e.ctrlKey;

      // Check if the user is typing in an input, textarea, or contenteditable
      const activeElement = document.activeElement;
      const isTyping =
        activeElement.tagName === "INPUT" ||
        activeElement.tagName === "TEXTAREA" ||
        activeElement.isContentEditable;

      // Ctrl/Cmd + K shortcut
      if (mod && e.key.toLowerCase() === "k") {
        e.preventDefault();
        const el = this.el.querySelector('input[type="text"][name="q"]');
        if (el) {
          el.focus();
          el.select();
        }
      }

      // Forward slash (/) shortcut - only if not already typing
      if (e.key === "/" && !isTyping) {
        e.preventDefault();
        const el = this.el.querySelector('input[type="text"][name="q"]');
        if (el) {
          el.focus();
        }
      }
    };

    window.addEventListener("keydown", this.onKey);
  },
  destroyed() {
    window.removeEventListener("keydown", this.onKey);
  },
};
