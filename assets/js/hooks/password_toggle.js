// PasswordToggle hook
// Mount on a wrapper div that contains a <.input type="password"> component.
// It injects a show/hide toggle button over the password input.
const PasswordToggle = {
  mounted() {
    this._visible = false;
    this._injectToggle();
  },

  // Re-inject after LiveView patches the DOM (e.g. phx-change validate re-renders)
  updated() {
    this._injectToggle();
  },

  _injectToggle() {
    const input = this.el.querySelector(
      "input[type='password'], input[type='text'][data-pt='1']",
    );
    if (!input) return;

    // Mark as managed by this hook
    input.dataset.pt = "1";

    // Restore the current visibility state after re-render (LiveView resets type to "password")
    if (this._visible) {
      input.type = "text";
    }

    // Remove any previously injected button to avoid duplicates
    const existing = this.el.querySelector("[data-pt-btn]");
    if (existing) existing.remove();

    // Add padding-right to the input so text doesn't hide under the button
    input.style.paddingRight = "2.5rem";

    const eyeIcon = `<span class="hero-eye size-5 pointer-events-none"></span>`;
    const eyeSlashIcon = `<span class="hero-eye-slash size-5 pointer-events-none"></span>`;

    // Create the toggle button (absolutely positioned inside the label)
    const btn = document.createElement("button");
    btn.type = "button";
    btn.setAttribute("tabindex", "-1");
    btn.setAttribute("aria-label", "Toggle password visibility");
    btn.setAttribute("data-pt-btn", "1");
    btn.className =
      "absolute inset-y-0 right-0 flex items-center pr-3 pt-6 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 focus:outline-none";
    btn.innerHTML = this._visible ? eyeSlashIcon : eyeIcon;

    const label = input.closest("label");
    if (label) {
      label.style.position = "relative";
      label.style.display = "block";
      label.appendChild(btn);
    } else {
      this.el.style.position = "relative";
      this.el.appendChild(btn);
    }

    btn.addEventListener("click", () => {
      this._visible = !this._visible;
      input.type = this._visible ? "text" : "password";
      btn.innerHTML = this._visible ? eyeSlashIcon : eyeIcon;
    });
  },
};

export default PasswordToggle;
