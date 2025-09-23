export const ItemSearch = {
  mounted() {
    const input = this.el.querySelector('input[name="item_search"]') || this.el;
    const list = this.el.querySelector("ul");
    let index = -1;

    const items = () =>
      list ? Array.from(list.querySelectorAll("li[phx-value-item_id]")) : [];

    const reset = () => {
      index = -1;
      items().forEach((i) => i.classList.remove("bg-gray-100"));
    };

    input &&
      input.addEventListener("keydown", (e) => {
        const listItems = items();
        if (!listItems.length) return;

        if (e.key === "ArrowDown") {
          e.preventDefault();
          index = Math.min(index + 1, listItems.length - 1);
          reset();
          listItems[index] && listItems[index].classList.add("bg-gray-100");
        } else if (e.key === "ArrowUp") {
          e.preventDefault();
          index = Math.max(index - 1, 0);
          reset();
          listItems[index] && listItems[index].classList.add("bg-gray-100");
        } else if (e.key === "Enter") {
          if (index >= 0 && listItems[index]) {
            e.preventDefault();
            const id = listItems[index].getAttribute("phx-value-item_id");
            // trigger phx-click by dispatching a click
            listItems[index].click();
          }
        } else if (e.key === "Escape") {
          input.value = "";
          input.dispatchEvent(new Event("input", { bubbles: true }));
        }
      });

    // Close suggestions when clicking outside
    document.addEventListener("click", (ev) => {
      if (!this.el.contains(ev.target)) {
        // clear list by sending empty search
        const evt = new CustomEvent("phx:send", {
          detail: { type: "item_search", value: "" },
        });
        // Not a standard phx event; instead just blur input to trigger server-side clear via phx-change
        input && input.dispatchEvent(new Event("change", { bubbles: true }));
      }
    });
  },
};
