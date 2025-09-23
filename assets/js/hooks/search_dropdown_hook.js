export const SearchDropdown = {
  mounted() {
    // container is the element with phx-hook="SearchDropdown"
    const container = this.el;
    const input = container.querySelector('input[type="text"][name]');
    const list = container.querySelector('[role="listbox"]');
    if (input) {
      // Keep behavior simple: only handle Escape to clear and blur the input on outside click.
      input.addEventListener("keydown", (e) => {
        if (e.key === "Escape") {
          input.value = "";
          input.dispatchEvent(new Event("input", { bubbles: true }));
          input.blur();
        }
      });
    }

    // click outside to close dropdown - simply blur the input to trigger server-side clear
    document.addEventListener("click", (ev) => {
      if (!container.contains(ev.target)) {
        input && input.blur();
      }
    });
  },
};
