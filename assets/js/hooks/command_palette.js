// CommandPalette — global ⌘K / Ctrl+K hook for the Voile redesign.
// Listens for the keyboard shortcut anywhere on the page, opens/closes
// the #voile-command-palette element, and handles arrow-key navigation.

const CommandPalette = {
  mounted() {
    this.isOpen = false;
    this.activeIndex = 0;

    this.onKeyDown = (e) => {
      const isToggle =
        (e.metaKey || e.ctrlKey) && (e.key === "k" || e.key === "K");

      if (isToggle) {
        e.preventDefault();
        this.toggle();
        return;
      }

      if (!this.isOpen) return;

      if (e.key === "Escape") {
        e.preventDefault();
        this.close();
      } else if (e.key === "ArrowDown") {
        e.preventDefault();
        this.moveSelection(1);
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        this.moveSelection(-1);
      } else if (e.key === "Enter") {
        e.preventDefault();
        const selected = this.getResult(this.activeIndex);
        if (selected) {
          selected.click();
          this.close();
        }
      }
    };

    this.onInput = (e) => {
      const q = (e.target.value || "").toLowerCase().trim();
      this.filterResults(q);
      this.activeIndex = 0;
      this.renderSelection();
    };

    this.onResultClick = (e) => {
      const target = e.target.closest("[data-voile-cmd-result]");
      if (!target) return;
      this.close();
    };

    this.onBackdropClick = (e) => {
      if (e.target.dataset.rdCmdBackdrop !== undefined) this.close();
    };

    // Open requests come from the topbar search pill / mobile overflow slot
    // via `JS.dispatch("voile:open-command-palette")`. The hook owns the
    // open/close state, so these must route through open() — otherwise the
    // palette shows but this.isOpen stays false and close() (backdrop click,
    // Escape) becomes a no-op.
    this.onOpenRequest = () => this.open();

    document.addEventListener("keydown", this.onKeyDown);
    document.addEventListener("voile:open-command-palette", this.onOpenRequest);

    this.input = this.el.querySelector("[data-voile-cmd-input]");
    this.panel = this.el.querySelector("[data-voile-cmd-panel]");
    this.backdrop = this.el.querySelector("[data-voile-cmd-backdrop]");

    if (this.input) {
      this.input.addEventListener("input", this.onInput);
    }

    if (this.panel) {
      this.panel.addEventListener("click", this.onResultClick);
    }

    if (this.backdrop) {
      this.backdrop.addEventListener("click", this.onBackdropClick);
    }
  },

  destroyed() {
    document.removeEventListener("keydown", this.onKeyDown);
    document.removeEventListener("voile:open-command-palette", this.onOpenRequest);
  },

  toggle() {
    if (this.isOpen) this.close();
    else this.open();
  },

  open() {
    if (this.isOpen) return;
    this.isOpen = true;
    this.el.classList.remove("hidden");
    if (this.input) {
      this.input.value = "";
      setTimeout(() => this.input.focus(), 30);
    }
    this.filterResults("");
    this.activeIndex = 0;
    this.renderSelection();
  },

  close() {
    if (!this.isOpen) return;
    this.isOpen = false;
    this.el.classList.add("hidden");
  },

  filterResults(query) {
    const groups = this.el.querySelectorAll("[data-voile-cmd-group]");
    let visibleCount = 0;

    groups.forEach((group) => {
      const items = group.querySelectorAll("[data-voile-cmd-result]");
      let groupVisible = 0;

      items.forEach((item) => {
        const text = (item.dataset.rdCmdSearch || item.textContent || "")
          .toLowerCase()
          .trim();
        const match = !query || text.includes(query);
        item.classList.toggle("hidden", !match);
        if (match) groupVisible++;
      });

      group.classList.toggle("hidden", groupVisible === 0);
      visibleCount += groupVisible;
    });

    const empty = this.el.querySelector("[data-voile-cmd-empty]");
    if (empty) empty.classList.toggle("hidden", visibleCount !== 0);
  },

  moveSelection(delta) {
    const results = this.visibleResults();
    if (results.length === 0) return;
    this.activeIndex =
      (this.activeIndex + delta + results.length) % results.length;
    this.renderSelection();
  },

  visibleResults() {
    return Array.from(
      this.el.querySelectorAll(
        "[data-voile-cmd-result]:not(.hidden)"
      )
    ).filter((el) => !el.closest("[data-voile-cmd-group].hidden"));
  },

  getResult(index) {
    const results = this.visibleResults();
    return results[index] || null;
  },

  renderSelection() {
    const results = this.visibleResults();
    results.forEach((el, i) => {
      const selected = i === this.activeIndex;
      el.classList.toggle("voile-cmd-selected", selected);
      el.setAttribute("aria-selected", selected ? "true" : "false");
      if (selected) {
        el.scrollIntoView({ block: "nearest" });
      }
    });
  },
};

export default CommandPalette;
