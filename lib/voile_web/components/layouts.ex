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
    assigns = assign_nav_items(assigns)

    ~H"""
    <div class="bg-violet-200 dark:bg-violet-400 px-3 py-1 text-sm font-semibold">
      <p>If you need information about [Redacted]</p>
    </div>

    <header
      class="px-4 sm:px-6 lg:px-8 bg-voile-surface/60 dark:bg-gray-700/60 backdrop-blur-sm z-10 w-full"
      id="navigationHeader"
    >
      <div class="flex items-center justify-between py-3 text-sm">
        <div class="flex items-center gap-10">
          <a href="/" class="flex items-center gap-2">
            <img src={~p"/images/v.png"} width="36" />
            <h5>Voile</h5>
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
                aria-label="Open search"
                class="p-2 bg-transparent border-0"
              >
                <.icon name="hero-magnifying-glass" class="w-5 h-5" />
              </.button> <Layouts.theme_toggle />
              <%= if @current_scope do %>
                <div phx-hook="position_panel" id="user-info-panel" class="relative inline-block">
                  <div class="flex items-center justify-center gap-3">
                    <%= unless (Ecto.assoc_loaded?(@current_scope.user.user_role) && @current_scope.user.user_role.name in ["Member", "Admin"]) do %>
                      <.link navigate="/manage">
                        <.button class="default-btn">Dashboard</.button>
                      </.link>
                    <% else %>
                      <.link navigate="/atrium"><.button class="default-btn">Atrium</.button></.link>
                    <% end %>
                    
                    <button
                      data-panel-anchor
                      aria-expanded="false"
                      class="p-0 bg-transparent border-0"
                    >
                      <%= if @current_scope.user.user_image == nil do %>
                        <img
                          src="/images/default_avatar.jpg"
                          class="w-8 h-8 rounded-full border-2 border-voile-primary"
                          alt="User avatar"
                        />
                      <% else %>
                        <img
                          src={@current_scope.user.user_image}
                          class="w-8 h-8 rounded-full border-2 border-voile-primary"
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
                      Signed in as <strong>{@current_scope.user.fullname}</strong>
                    </p>
                    
                    <div class="mt-2 flex w-full gap-2 text-xs">
                      <%= unless (Ecto.assoc_loaded?(@current_scope.user.user_role) && @current_scope.user.user_role.name in ["Member", "Admin"]) do %>
                        <.link navigate="/manage" class="primary-btn w-full text-center">
                          <span>
                            <.icon name="hero-chart-bar-square" class="size-5 inline-block mr-1" />
                          </span> <span>Dashboard</span>
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
                          </span> <span>Logout</span>
                        </.link>
                      <% else %>
                        <.link navigate="/atrium" class="primary-btn w-full text-center">
                          <span>
                            <.icon name="hero-cog-6-tooth" class="size-5 inline-block mr-1" />
                          </span> <span>Settings</span>
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
                          </span> <span>Logout</span>
                        </.link>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% else %>
                <.link navigate="/login"><.button class="ml-2 default-btn">Masuk</.button></.link>
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

    <footer>
      <div class="bg-zinc-700 dark:bg-surface-dark py-3 text-center text-white">
        &copy; Voile - Curatorian Developer | 2024 - {get_year()}
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
      %{label: "Beranda", href: "/"},
      %{label: "Tentang", href: "/about"},
      %{label: "Koleksi", href: "/collections"}
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
              <p class="text-sm mb-2">Signed in as <strong>{@current_scope.user.fullname}</strong></p>
              
              <div class="flex flex-col gap-2">
                <%= unless (Ecto.assoc_loaded?(@current_scope.user.user_role) && @current_scope.user.user_role.name in ["Member", "Admin"]) do %>
                  <.link navigate="/manage" class="primary-btn w-full text-center">Dashboard</.link>
                <% else %>
                  <.link navigate="/atrium" class="primary-btn w-full text-center">Atrium</.link>
                <% end %>
                
                <.link href="/users/log_out" method="delete" class="cancel-btn w-full text-center">
                  Logout
                </.link>
              </div>
            <% else %>
              <.link navigate="/login" class="default-btn w-full">Masuk</.link>
            <% end %>
          </div>
        </nav>
      </aside>
    </div>
    """
  end

  defp mobile_nav_items do
    [
      %{label: "Beranda", href: "/"},
      %{label: "Tentang", href: "/about"},
      %{label: "Koleksi", href: "/collections"}
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
                    placeholder="Search collections..."
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
                aria-label="Close search"
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
end
