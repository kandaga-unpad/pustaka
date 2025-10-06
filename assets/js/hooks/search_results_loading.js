export default {
  mounted() {
    // Listen to LiveView page-loading events to toggle a spinner for the results area
    this.show = () => {
      const spinner = this.el.querySelector(".search-results-spinner");
      if (spinner) spinner.classList.remove("hidden");
    };
    this.hide = () => {
      const spinner = this.el.querySelector(".search-results-spinner");
      if (spinner) spinner.classList.add("hidden");
    };

    window.addEventListener("phx:page-loading-start", this.show);
    window.addEventListener("phx:page-loading-stop", this.hide);
  },
  destroyed() {
    window.removeEventListener("phx:page-loading-start", this.show);
    window.removeEventListener("phx:page-loading-stop", this.hide);
  },
};
