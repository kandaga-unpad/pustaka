defmodule VoileWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use VoileWeb, :controller` and
  `use VoileWeb, :live_view`.
  """
  use VoileWeb, :html
  alias Phoenix.LiveView.JS
  alias Voile.Schema.System

  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    # Make current_path available automatically:
    # - For controller-rendered templates, derive it from @conn.assigns
    # - For LiveViews, it can be passed explicitly or assigned via LV hook
    assigns =
      assign_new(assigns, :current_path, fn ->
        case assigns do
          %{conn: %Plug.Conn{assigns: %{current_path: path}}} -> path
          _ -> nil
        end
      end)

    assigns = assign_nav_items(assigns)

    # Load app profile settings for branding
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo = System.get_setting_value("app_logo_url", nil)
    app_main_color = System.get_setting_value("app_main_color", nil)
    app_secondary_color = System.get_setting_value("app_secondary_color", nil)
    app_contact_email = System.get_setting_value("app_contact_email", "curatorian_id@gmail.com")

    assigns = assign(assigns, :app_name, app_name)
    assigns = assign(assigns, :app_logo, app_logo)
    assigns = assign(assigns, :app_main_color, app_main_color)
    assigns = assign(assigns, :app_secondary_color, app_secondary_color)
    assigns = assign(assigns, :app_contact_email, app_contact_email)

    ~H"""
    <div class="bg-voile-primary text-white px-3 py-1 text-sm font-semibold">
      <p>
        {gettext("If you need information about %{app_name}, please contact %{link}.",
          app_name: @app_name,
          link:
            "<a href='mailto:#{@app_contact_email}' target='_blank' class='text-white underline'>#{@app_name}</a>"
        )
        |> Phoenix.HTML.raw()}
      </p>
    </div>
    <!-- Inject CSS variables for brand colors so Tailwind/daisyUI tokens can be overridden -->
    <%= if @app_main_color || @app_secondary_color do %>
      <style>
        :root {
        <%= if @app_main_color do %>--color-voile-primary: <%= @app_main_color %>;<% end %>
        <%= if @app_secondary_color do %>--color-voile-secondary: <%= @app_secondary_color %>;<% end %>
        }
      </style>
    <% end %>

    <header
      class="px-4 sm:px-6 lg:px-8 bg-white/60 dark:bg-gray-700/60 backdrop-blur-sm z-[20] w-full sticky top-0"
      id="navigationHeader"
    >
      <div class="flex items-center justify-between py-3 text-sm">
        <div class="flex items-center gap-10">
          <a href="/" class="flex items-center gap-2">
            <%= if @app_logo do %>
              <img src={@app_logo} width="36" />
            <% else %>
              <img src={~p"/images/v.png"} width="36" />
            <% end %>

            <h5 style={if @app_main_color, do: "color: #{@app_main_color}", else: nil}>
              {@app_name}
            </h5>
          </a>
          <nav class="hidden lg:flex items-center gap-10 font-semibold leading-6">
            <%= for nav_item <- @nav_items do %>
              <div>
                <%= if nav_item.href do %>
                  <.link href={nav_item.href}>{nav_item.label}</.link>
                <% else %>
                  <p>{nav_item.label}</p>
                <% end %>
              </div>
            <% end %>
          </nav>
        </div>

        <div>
          <div class="flex lg:hidden">
            <.button
              phx-click={
                JS.toggle(
                  to: "#mobileNav [data-mobile-backdrop]",
                  in: "opacity-100 pointer-events-auto",
                  out: "opacity-0 pointer-events-none",
                  display: "block"
                )
                |> JS.toggle(
                  to: "#mobileNav [data-mobile-panel]",
                  in: "translate-x-0",
                  out: "-translate-x-full",
                  display: "block"
                )
              }
              id="mobile-nav-toggle"
            >
              <.icon name="hero-bars-3" />
            </.button>
          </div>

          <div class="hidden lg:block">
            <div class="flex items-center justify-center gap-2">
              <.button
                phx-click={
                  JS.toggle(
                    to: "#searchPanel",
                    in: "block",
                    out: "hidden",
                    display: "block"
                  )
                }
                aria-label={gettext("Open search")}
                class="p-2 bg-transparent border-0"
              >
                <.icon name="hero-magnifying-glass" class="w-5 h-5" />
              </.button>
              <.locale_switcher current_path={@current_path} />
              <Layouts.theme_toggle />
              <%= if @current_scope do %>
                <div phx-hook="position_panel" id="user-info-panel" class="relative inline-block">
                  <div class="flex items-center justify-center gap-3">
                    <%= if has_dashboard_access?(@current_scope.user) do %>
                      <.link navigate="/manage">
                        <.button class="default-btn">{gettext("Dashboard")}</.button>
                      </.link>
                    <% else %>
                      <.link navigate="/atrium">
                        <.button class="default-btn">{gettext("Atrium")}</.button>
                      </.link>
                    <% end %>

                    <button
                      data-panel-anchor
                      aria-expanded="false"
                      class="p-0 bg-transparent border-0"
                    >
                      <%= if @current_scope.user.user_image == nil do %>
                        <img
                          src="/images/default_avatar.jpg"
                          class="w-8 h-8 rounded-full border-2"
                          style={
                            if @app_main_color, do: "border-color: #{@app_main_color}", else: nil
                          }
                          alt="User avatar"
                        />
                      <% else %>
                        <img
                          src={"#{@current_scope.user.user_image}"}
                          class="w-8 h-8 rounded-full border-2"
                          style={
                            if @app_main_color, do: "border-color: #{@app_main_color}", else: nil
                          }
                          alt="User avatar"
                          referrerpolicy="no-referrer"
                        />
                      <% end %>
                    </button>
                  </div>

                  <div
                    data-position-panel
                    class="sticky hidden bg-voile-light dark:bg-voile-dark max-w-sm right-8 p-4 mt-1 rounded-md shadow-xl text-right"
                  >
                    <p class="text-sm">
                      {gettext("Hello, %{name}!", name: @current_scope.user.fullname)}
                    </p>

                    <div class="mt-2 flex w-full gap-2 text-xs">
                      <%= if has_dashboard_access?(@current_scope.user) do %>
                        <.link navigate="/manage" class="primary-btn flex flex-col w-full text-center">
                          <span>
                            <.icon name="hero-chart-bar-square" class="size-5 inline-block mr-1" />
                          </span>
                          <span>{gettext("Dashboard")}</span>
                        </.link>
                        <.link navigate="/atrium" class="primary-btn flex flex-col w-full text-center">
                          <span><.icon name="hero-home" class="size-5 inline-block mr-1" /></span>
                          <span>{gettext("Atrium")}</span>
                        </.link>
                        <.link
                          href="/users/log_out"
                          method="delete"
                          class="cancel-btn flex flex-col w-full text-center"
                        >
                          <span>
                            <.icon
                              name="hero-arrow-right-on-rectangle"
                              class="size-5 inline-block mr-1"
                            />
                          </span>
                          <span>{gettext("Log out")}</span>
                        </.link>
                      <% else %>
                        <.link navigate="/atrium" class="success-btn w-full text-center">
                          <span><.icon name="hero-home" class="size-5 inline-block mr-1" /></span>
                          <span>{gettext("Atrium")}</span>
                        </.link>
                        <.link
                          href="/users/log_out"
                          method="delete"
                          class="cancel-btn w-full text-center"
                        >
                          <span>
                            <.icon
                              name="hero-arrow-right-on-rectangle"
                              class="size-5 inline-block mr-1"
                            />
                          </span>
                          <span>{gettext("Log out")}</span>
                        </.link>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% else %>
                <.link href="/login">
                  <.button class="ml-2 default-btn">{gettext("Sign in")}</.button>
                </.link>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </header>
    <!-- Search panel (hidden by default) -->
    <.search_panel id="searchPanel" />
    <!-- Mobile navigation component -->
    <.mobile_nav id="mobileNav" current_scope={@current_scope} />
    <main class="min-h-screen w-full h-full">{render_slot(@inner_block)}</main>

    <footer class="bg-gray-900 dark:bg-gray-950 text-gray-300">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8 mb-8">
          <!-- About Section -->
          <div>
            <div class="flex items-center gap-2 mb-4">
              <%= if @app_logo do %>
                <img src={@app_logo} width="32" alt="Logo" />
              <% else %>
                <img src={~p"/images/v.png"} width="32" alt="Voile Logo" />
              <% end %>

              <h3
                class="text-lg font-bold"
                style={if @app_main_color, do: "color: #{@app_main_color}", else: "color: #9333ea"}
              >
                {@app_name}
              </h3>
            </div>

            <p class="text-sm text-gray-400 leading-relaxed">
              Virtual Organized of Information & Library Ecosystem - A next-generation digital library management system.
            </p>
          </div>
          <!-- Quick Links -->
          <div>
            <h4 class="text-white font-semibold mb-4">{gettext("Quick Links")}</h4>

            <ul class="space-y-2 text-sm">
              <li>
                <.link
                  href="/"
                  class="hover:text-white transition-colors"
                  style={
                    "hover:color: #{if @app_main_color, do: @app_main_color, else: "#9333ea"}"
                  }
                >
                  {gettext("Home")}
                </.link>
              </li>

              <li>
                <.link href="/about" class="hover:text-white transition-colors">
                  {gettext("About")}
                </.link>
              </li>

              <li>
                <.link href="/collections" class="hover:text-white transition-colors">
                  {gettext("Collections")}
                </.link>
              </li>

              <li>
                <.link href="/items" class="hover:text-white transition-colors">
                  {gettext("Items")}
                </.link>
              </li>

              <li>
                <.link href="/search" class="hover:text-white transition-colors">
                  {gettext("Search")}
                </.link>
              </li>
            </ul>
          </div>
          <!-- User Section -->
          <div>
            <h4 class="text-white font-semibold mb-4">{gettext("For Users")}</h4>

            <ul class="space-y-2 text-sm">
              <%= if @current_scope do %>
                <%= if has_dashboard_access?(@current_scope.user) do %>
                  <li>
                    <.link navigate="/manage" class="hover:text-white transition-colors">
                      {gettext("Dashboard")}
                    </.link>
                  </li>
                <% else %>
                  <li>
                    <.link navigate="/atrium" class="hover:text-white transition-colors">
                      {gettext("My Atrium")}
                    </.link>
                  </li>
                <% end %>

                <li>
                  <.link
                    href="/users/log_out"
                    method="delete"
                    class="hover:text-white transition-colors"
                  >
                    {gettext("Log Out")}
                  </.link>
                </li>
              <% else %>
                <li>
                  <.link navigate="/login" class="hover:text-white transition-colors">
                    {gettext("Sign In")}
                  </.link>
                </li>

                <li>
                  <.link navigate="/register" class="hover:text-white transition-colors">
                    {gettext("Register")}
                  </.link>
                </li>
              <% end %>
            </ul>
          </div>
          <!-- Contact & Info -->
          <div>
            <h4 class="text-white font-semibold mb-4">{gettext("Contact")}</h4>

            <ul class="space-y-3 text-sm">
              <li class="flex items-start gap-2">
                <.icon name="hero-envelope" class="w-5 h-5 flex-shrink-0 mt-0.5" />
                <span class="text-gray-400 break-all">
                  {System.get_setting_value("app_contact_email", "chrisna.adhi@unpad.ac.id")}
                </span>
              </li>

              <li class="flex items-start gap-2">
                <.icon name="hero-map-pin" class="w-5 h-5 flex-shrink-0 mt-0.5" />
                <span class="text-gray-400">
                  {System.get_setting_value("app_address", "Kandaga Universitas Padjadjaran")}
                </span>
              </li>

              <%= if System.get_setting_value("app_website", nil) do %>
                <li class="flex items-start gap-2">
                  <.icon name="hero-globe-alt" class="w-5 h-5 flex-shrink-0 mt-0.5" />
                  <a
                    href={System.get_setting_value("app_website", "https://curatorian.id")}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-gray-400 hover:text-white transition-colors break-all"
                  >
                    {System.get_setting_value("app_website", "https://curatorian.id")}
                  </a>
                </li>
              <% end %>
            </ul>
          </div>
        </div>
        <!-- Bottom Bar -->
        <div class="border-t border-gray-800 pt-8">
          <div class="flex flex-col md:flex-row justify-between items-center gap-4">
            <div class="text-sm text-gray-400">
              <p>&copy; {get_year()} {@app_name}. {gettext("All rights reserved.")}</p>

              <p class="mt-1 text-xs">
                {gettext("Powered by")}
                <a
                  href="https://github.com/curatorian"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="hover:text-white transition-colors"
                  style={
                    "hover:color: #{if @app_main_color, do: @app_main_color, else: "#9333ea"}"
                  }
                >
                  Curatorian Developer
                </a>
              </p>
            </div>

            <div class="flex items-center gap-6">
              <div class="text-xs text-gray-500">
                <span>Built with</span>
                <span
                  class="mx-1"
                  style={"color: #{if @app_main_color, do: @app_main_color, else: "#9333ea"}"}
                >
                  ♥
                </span>
                <span>
                  using
                  <a
                    href="https://github.com/curatorian/voile"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="hover:text-white transition-colors"
                  >
                    Voile
                  </a>
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </footer>
    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0
        [[data-theme-pref=light]_&]:left-1/3
        [[data-theme-pref=dark]_&]:left-2/3
        transition-[left]" />
      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  def get_year() do
    DateTime.utc_now().year
  end

  defp assign_nav_items(assigns) do
    nav_items = [
      %{label: gettext("Home"), href: "/"},
      %{label: gettext("About"), href: "/about"},
      %{label: gettext("Collections"), href: "/collections"}
    ]

    assign(assigns, :nav_items, nav_items)
  end

  # Mobile nav function component inlined per request
  attr :id, :string, required: true
  attr :current_scope, :map, default: nil

  def mobile_nav(assigns) do
    assigns = assign_new(assigns, :nav_items, fn -> mobile_nav_items() end)

    ~H"""
    <div id={@id} phx-hook="MobileNav" class="lg:hidden">
      <!-- backdrop -->
      <div
        phx-click={
          JS.toggle(
            to: "#mobileNav [data-mobile-backdrop]",
            in: "block opacity-100 pointer-events-auto",
            out: "hidden opacity-0 pointer-events-none",
            display: "block"
          )
          |> JS.toggle(
            to: "#mobileNav [data-mobile-panel]",
            in: "block translate-x-0",
            out: "hidden -translate-x-full",
            display: "block"
          )
          |> JS.dispatch("voile:mobile-nav-toggled")
        }
        data-mobile-backdrop
        class="hidden fixed inset-0 bg-black/40 opacity-0 pointer-events-none transition-opacity duration-200 z-50"
        aria-hidden="true"
      />
      <!-- slide-in panel -->
      <aside
        data-mobile-panel
        class="hidden fixed inset-y-0 left-0 w-72 max-w-full transform -translate-x-full transition-transform duration-200 bg-white dark:bg-gray-800 shadow-lg z-50"
        role="dialog"
        aria-modal="true"
      >
        <div class="p-4 border-b border-base-200 dark:border-gray-700 flex items-center justify-between">
          <a href="/" class="flex items-center gap-2">
            <img src={~p"/images/v.png"} width="28" /> <span class="font-semibold">Voile</span>
          </a>
          <%!-- <div class="flex items-center gap-2">
            <.button
              phx-click={
                JS.toggle(
                  to: "#searchPanel",
                  in: "block",
                  out: "hidden",
                  display: "block"
                )
                |> JS.toggle(
                  to: "#mobileNav [data-mobile-backdrop]",
                  in: "hidden",
                  out: "block",
                  display: "block"
                )
              }
              aria-label="Open search"
              class="p-2"
            >
              <.icon name="hero-magnifying-glass" />
            </.button>
            <button
              phx-click={
                JS.toggle(
                  to: "#mobileNav [data-mobile-backdrop]",
                  in: "block opacity-100 pointer-events-auto",
                  out: "hidden opacity-0 pointer-events-none",
                  display: "block"
                )
                |> JS.toggle(
                  to: "#mobileNav [data-mobile-panel]",
                  in: "block translate-x-0",
                  out: "hidden -translate-x-full",
                  display: "block"
                )
                |> JS.dispatch("voile:mobile-nav-toggled")
              }
              aria-label="Close"
              class="p-2"
            >
              <.icon name="hero-x-mark" />
            </button>
          </div> --%>
          <.link navigate="/search" class="p-2"><.icon name="hero-magnifying-glass" /></.link>
          <button
            phx-click={
              JS.toggle(
                to: "#mobileNav [data-mobile-backdrop]",
                in: "block opacity-100 pointer-events-auto",
                out: "hidden opacity-0 pointer-events-none",
                display: "block"
              )
              |> JS.toggle(
                to: "#mobileNav [data-mobile-panel]",
                in: "block translate-x-0",
                out: "hidden -translate-x-full",
                display: "block"
              )
              |> JS.dispatch("voile:mobile-nav-toggled")
            }
            aria-label="Close"
            class="p-2"
          >
            <.icon name="hero-x-mark" />
          </button>
        </div>

        <nav class="p-4">
          <ul class="flex flex-col gap-3">
            <%= for item <- @nav_items do %>
              <li>
                <%= if item.href do %>
                  <.link href={item.href} class="block py-2 px-3 rounded hover:bg-base-200">
                    {item.label}
                  </.link>
                <% else %>
                  <span class="block py-2 px-3">{item.label}</span>
                <% end %>
              </li>
            <% end %>
          </ul>

          <div class="mt-6">
            <%= if @current_scope do %>
              <p class="text-sm mb-2">
                {gettext("Signed in as %{name}", name: @current_scope.user.fullname)}
              </p>

              <div class="flex flex-col gap-2">
                <%= if has_dashboard_access?(@current_scope.user) do %>
                  <.link navigate="/manage" class="primary-btn w-full text-center">
                    {gettext("Dashboard")}
                  </.link>
                <% else %>
                  <.link navigate="/atrium" class="primary-btn w-full text-center">
                    {gettext("Atrium")}
                  </.link>
                <% end %>

                <.link href="/users/log_out" method="delete" class="cancel-btn w-full text-center">
                  {gettext("Log out")}
                </.link>
              </div>
            <% else %>
              <.link navigate="/login" class="default-btn w-full">{gettext("Sign in")}</.link>
            <% end %>
          </div>
        </nav>
      </aside>
    </div>
    """
  end

  defp mobile_nav_items do
    [
      %{label: gettext("Home"), href: "/"},
      %{label: gettext("About"), href: "/about"},
      %{label: gettext("Collections"), href: "/collections"}
    ]
  end

  attr :id, :string, required: true

  def search_panel(assigns) do
    ~H"""
    <div>
      <div
        id={@id}
        class="hidden fixed inset-x-0 top-[64px] z-40"
        aria-hidden={true}
      >
        <div class="max-w-4xl mx-auto p-4 bg-white dark:bg-gray-800 rounded-b shadow-md">
          <div
            phx-hook="SearchPanel"
            id={"panel-" <> @id}
            class="transition-all duration-200 ease-out"
          >
            <div class="flex items-center gap-3">
              <div class="flex-1">
                <form action="/search" method="get" class="relative">
                  <input
                    type="text"
                    name="q"
                    placeholder={gettext("Search collections...")}
                    class="block w-full pl-3 pr-3 py-3 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-800 placeholder-gray-500 dark:placeholder-gray-400 text-gray-900 dark:text-white focus:outline-none focus:ring-1 focus:ring-blue-500"
                    autocomplete="off"
                  />
                </form>
              </div>

              <button
                phx-click={
                  JS.toggle(
                    to: "#" <> @id,
                    in: "block",
                    out: "hidden",
                    display: "block"
                  )
                }
                aria-label={gettext("Close search")}
                class="p-2"
              >
                <.icon name="hero-x-mark" />
              </button>
            </div>
          </div>
        </div>
      </div>
      <!-- backdrop: clicking it closes the search panel -->
      <div
        phx-click={
          JS.toggle(
            to: "#" <> @id,
            in: "block",
            out: "hidden",
            display: "block"
          )
        }
        class="hidden fixed inset-0 bg-black/40 z-30"
        data-search-backdrop
      />
    </div>
    """
  end

  # Helper function to check if user has dashboard access
  # Users with administrative roles (super_admin, admin, editor) or system permissions can access dashboard
  defp has_dashboard_access?(user) do
    alias VoileWeb.Auth.Authorization
    alias Voile.Repo

    # Preload roles if not already loaded
    user = Repo.preload(user, [:roles, :permissions])

    # Check if user has admin/editor roles
    has_admin_role? =
      Enum.any?(user.roles, fn role ->
        role.name in [
          "super_admin",
          "admin",
          "editor",
          "librarian",
          "gallery_curator",
          "archivist",
          "museum_curator"
        ]
      end)

    # Check if user has any administrative permissions
    has_admin_permission? =
      Authorization.can?(user, "system.settings") ||
        Authorization.can?(user, "users.manage_roles") ||
        Authorization.can?(user, "collections.delete") ||
        Authorization.can?(user, "roles.create")

    has_admin_role? || has_admin_permission?
  end
end
