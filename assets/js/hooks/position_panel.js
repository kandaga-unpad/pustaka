export default {
  mounted() {
    this.isOpen = false;
    // We'll render the panel into a portal at document.body to avoid layout shifts.
    this.originalParent = null;
    this.panel = null;
    this.portal = null;

    this.calculate = () => {
      const anchor = this.el.querySelector("[data-panel-anchor]");
      const panel = this.panel;
      if (!anchor || !panel || !this.portal) return;

      const rect = anchor.getBoundingClientRect();

      // Determine whether any ancestor of the anchor is fixed/sticky
      let el = anchor;
      let isAncestorFixed = false;
      while (el && el !== document.body) {
        const pos = window.getComputedStyle(el).position;
        if (pos === "fixed" || pos === "sticky") {
          isAncestorFixed = true;
          break;
        }
        el = el.parentElement;
      }

      // Ensure panel is visible to measure
      const wasHidden = panel.classList.contains("hidden");
      if (wasHidden) panel.classList.remove("hidden");

      // Use plain offsetWidth (no computed/getBoundingClientRect) per preference.
      const panelWidth = panel.offsetWidth || 200;
      const margin = 8;

      // Align panel's right edge to anchor's right edge by default
      let left = rect.right - panelWidth;
      // Convert to document coords (account for scroll) when using absolute positioning.
      // If the anchor is inside a fixed/sticky container (like a sticky header),
      // position the portal as fixed and use viewport coordinates so it follows the
      // visible header while scrolling.
      if (!isAncestorFixed) {
        left = left + window.scrollX;
      }

      // Clamp into viewport
      const maxLeft = Math.max(
        margin,
        window.scrollX + window.innerWidth - panelWidth - margin
      );
      if (left > maxLeft) left = maxLeft;
      if (left < window.scrollX + margin) left = window.scrollX + margin;

      const top = rect.bottom + 8;

      if (isAncestorFixed) {
        // Use fixed positioning relative to the viewport.
        this.portal.style.position = "fixed";
        this.portal.style.left = `${left}px`;
        this.portal.style.top = `${top}px`;
      } else {
        // Use absolute positioning in document coordinates.
        this.portal.style.position = "absolute";
        this.portal.style.left = `${left}px`;
        this.portal.style.top = `${top + window.scrollY}px`;
      }
      this.portal.style.zIndex = "9999";
      // Set the portal width to the measured plain width.
      this.portal.style.width = `${panelWidth}px`;

      if (wasHidden) panel.classList.add("hidden");
    };

    this.resizeObserver = new ResizeObserver(() => this.calculate());
    this.resizeObserver.observe(this.el);
    window.addEventListener("resize", this.calculate);
    // Recalculate during scroll so the portaled panel follows sticky header
    this._scrollFrame = null;
    this._onScroll = () => {
      if (this._scrollFrame) return;
      this._scrollFrame = window.requestAnimationFrame(() => {
        this._scrollFrame = null;
        this.calculate();
      });
    };
    window.addEventListener("scroll", this._onScroll, { passive: true });

    // Prepare portal and move panel into it
    const panelEl = this.el.querySelector("[data-position-panel]");
    if (panelEl) {
      this.panel = panelEl;
      this.originalParent = panelEl.parentNode;
      this.nextSibling = panelEl.nextSibling;
      // save inline style to restore later
      this.originalPanelStyle = panelEl.getAttribute("style") || "";
      // create portal wrapper
      this.portal = document.createElement("div");
      this.portal.className = "voile-position-portal";
      document.body.appendChild(this.portal);
      // move panel into portal
      this.portal.appendChild(this.panel);

      // Override inline positioning so Tailwind's `absolute` and `right-8`
      // don't constrain the panel when it's portaled. Make the panel flow
      // inside the portal and take the portal's minWidth.
      this.panel.style.position = "relative";
      this.panel.style.right = "auto";
      this.panel.style.left = "auto";
      this.panel.style.width = "100%";
      this.panel.style.boxSizing = "border-box";
    }

    // Toggle handler on anchor
    this.toggle = (e) => {
      e.preventDefault();
      this.isOpen = !this.isOpen;
      const panel = this.panel;
      const anchor = this.el.querySelector("[data-panel-anchor]");
      if (!panel || !anchor) return;
      panel.classList.toggle("hidden", !this.isOpen);
      anchor.setAttribute("aria-expanded", this.isOpen ? "true" : "false");
      if (this.isOpen) {
        this.calculate();
        // focus first focusable inside panel
        const focusable = panel.querySelector(
          'a, button, input, [tabindex]:not([tabindex="-1"])'
        );
        if (focusable) focusable.focus();
      }
    };

    // click outside to close
    this.outsideClick = (e) => {
      const panel = this.panel;
      const anchor = this.el.querySelector("[data-panel-anchor]");
      if (!panel || !anchor) return;
      const clickedInside =
        panel.contains(e.target) || anchor.contains(e.target);
      if (!clickedInside && this.isOpen) {
        this.isOpen = false;
        panel.classList.add("hidden");
        anchor.setAttribute("aria-expanded", "false");
      }
    };

    this.escapeHandler = (e) => {
      if (e.key === "Escape" && this.isOpen) {
        const panel = this.el.querySelector("[data-position-panel]");
        const anchor = this.el.querySelector("[data-panel-anchor]");
        this.isOpen = false;
        if (panel) panel.classList.add("hidden");
        if (anchor) anchor.setAttribute("aria-expanded", "false");
      }
    };

    const anchorEl = this.el.querySelector("[data-panel-anchor]");
    if (anchorEl) anchorEl.addEventListener("click", this.toggle);
    document.addEventListener("click", this.outsideClick);
    document.addEventListener("keydown", this.escapeHandler);

    // run after connect
    setTimeout(this.calculate, 0);
  },
  updated() {
    // recalc on updates
    setTimeout(() => this.calculate(), 0);
  },
  destroyed() {
    if (this.resizeObserver) this.resizeObserver.disconnect();
    window.removeEventListener("resize", this.calculate);
  window.removeEventListener("scroll", this._onScroll, { passive: true });
    const anchorEl = this.el.querySelector("[data-panel-anchor]");
    if (anchorEl) anchorEl.removeEventListener("click", this.toggle);
    document.removeEventListener("click", this.outsideClick);
    document.removeEventListener("keydown", this.escapeHandler);
    // move panel back if it was portaled
    if (this.panel && this.originalParent) {
      try {
        // restore original inline styles (if any)
        if (this.originalPanelStyle !== undefined) {
          if (this.originalPanelStyle)
            this.panel.setAttribute("style", this.originalPanelStyle);
          else this.panel.removeAttribute("style");
        }
        if (this.nextSibling)
          this.originalParent.insertBefore(this.panel, this.nextSibling);
        else this.originalParent.appendChild(this.panel);
      } catch (e) {
        // ignore
      }
    }
    if (this.portal && this.portal.parentNode)
      this.portal.parentNode.removeChild(this.portal);
  },
};
