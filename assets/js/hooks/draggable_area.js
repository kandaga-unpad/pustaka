let DragUpload = {
  mounted() {
    let el = this.el;

    el.addEventListener("dragenter", (e) => {
      e.preventDefault();
      el.classList.add("dragging");
    });

    el.addEventListener("dragover", (e) => {
      e.preventDefault();
      el.classList.add("dragging");
    });

    el.addEventListener("dragleave", (e) => {
      el.classList.remove("dragging");
    });

    el.addEventListener("drop", (e) => {
      el.classList.remove("dragging");
    });
  },
};

export default DragUpload;
