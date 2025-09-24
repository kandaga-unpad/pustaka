export const SearchPanel = {
  mounted() {
    const panel = this.el.querySelector(`#${this.el.id}`) || this.el;
    const backdrop = document.querySelector("[data-search-backdrop]");
    const focusable = panel.querySelector(
      "input, button, textarea, [tabindex]"
    );

    const open = () => {
      panel.classList.remove("opacity-0", "translate-y-[-6px]", "hidden");
      panel.classList.add("opacity-100", "translate-y-0");
      backdrop && backdrop.classList.remove("hidden");
    };

    const close = () => {
      panel.classList.remove("opacity-100", "translate-y-0");
      panel.classList.add("opacity-0");
      backdrop && backdrop.classList.add("hidden");
    };

    // close on Esc
    const onKey = (e) => {
      if (e.key === "Escape") close();
      if (e.key === "Enter") {
        // let native form handle enter
      }
    };

    document.addEventListener("keydown", onKey);

    // click on backdrop closes
    if (backdrop) {
      backdrop.addEventListener("click", (e) => {
        close();
      });
    }

    // cleanup
    this.destroy = () => {
      document.removeEventListener("keydown", onKey);
    };
  },
};
