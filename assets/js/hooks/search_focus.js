export default {
  mounted() {
    // Allow global shortcut to focus the search input: Ctrl/Cmd+K
    this.onKey = (e) => {
      const isMac = navigator.platform.toUpperCase().indexOf("MAC") >= 0;
      const mod = isMac ? e.metaKey : e.ctrlKey;
      if (mod && e.key.toLowerCase() === "k") {
        e.preventDefault();
        const el = this.el.querySelector('input[type="text"][name="q"]');
        if (el) {
          el.focus();
          el.select();
        }
      }
    };

    window.addEventListener("keydown", this.onKey);
  },
  destroyed() {
    window.removeEventListener("keydown", this.onKey);
  },
};
