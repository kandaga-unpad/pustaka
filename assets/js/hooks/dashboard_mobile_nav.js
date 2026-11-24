// DashboardMobileNav — left slide-in navigation drawer for the Voile
// dashboard shell (mobile / tablet, below lg). The hook owns the open/close
// state: open requests arrive from the bottom-nav "More" button via
// `JS.dispatch("voile:open-dashboard-nav")`, and the drawer closes on
// backdrop click, Escape, the close button, and any navigation link click
// (the dashboard layout persists across live navigation, so the drawer must
// dismiss itself when a link is followed).

const DashboardMobileNav = {
  mounted() {
    this.isOpen = false;

    this.backdrop = this.el.querySelector("[data-voile-drawer-backdrop]");
    this.panel = this.el.querySelector("[data-voile-drawer-panel]");

    this.onOpenRequest = () => this.open();

    this.onKeyDown = (e) => {
      if (this.isOpen && e.key === "Escape") {
        e.preventDefault();
        this.close();
      }
    };

    this.onBackdropClick = (e) => {
      if (e.target === this.backdrop) this.close();
    };

    this.onCloseClick = (e) => {
      const target = e.target.closest("[data-voile-drawer-close]");
      if (target) this.close();
    };

    this.onLinkClick = (e) => {
      const link = e.target.closest("a[href]");
      if (link) this.close();
    };

    document.addEventListener("keydown", this.onKeyDown);
    document.addEventListener("voile:open-dashboard-nav", this.onOpenRequest);

    if (this.backdrop) {
      this.backdrop.addEventListener("click", this.onBackdropClick);
    }

    if (this.panel) {
      this.panel.addEventListener("click", this.onCloseClick);
      this.panel.addEventListener("click", this.onLinkClick);
    }
  },

  destroyed() {
    document.removeEventListener("keydown", this.onKeyDown);
    document.removeEventListener(
      "voile:open-dashboard-nav",
      this.onOpenRequest
    );

    if (this.backdrop) {
      this.backdrop.removeEventListener("click", this.onBackdropClick);
    }

    if (this.panel) {
      this.panel.removeEventListener("click", this.onCloseClick);
      this.panel.removeEventListener("click", this.onLinkClick);
    }
  },

  open() {
    if (this.isOpen) return;
    this.isOpen = true;

    if (this.backdrop) {
      this.backdrop.classList.remove("hidden", "opacity-0", "pointer-events-none");
      this.backdrop.classList.add("opacity-100", "pointer-events-auto");
    }

    if (this.panel) {
      this.panel.classList.remove("hidden", "-translate-x-full");
      this.panel.classList.add("translate-x-0");
      this.panel.focus({ preventScroll: true });
    }
  },

  close() {
    if (!this.isOpen) return;
    this.isOpen = false;

    if (this.backdrop) {
      this.backdrop.classList.add("hidden", "opacity-0", "pointer-events-none");
      this.backdrop.classList.remove("opacity-100", "pointer-events-auto");
    }

    if (this.panel) {
      this.panel.classList.add("hidden", "-translate-x-full");
      this.panel.classList.remove("translate-x-0");
    }

    const toggle = document.querySelector("[data-voile-bottom-nav-more]");
    if (toggle) toggle.focus({ preventScroll: true });
  },
};

export default DashboardMobileNav;
