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
    ~H"""
    <div class="bg-violet-200 px-3 py-1 text-sm font-semibold">
      <p>If you need information about [Redacted]</p>
    </div>

    <header
      class="px-4 sm:px-6 lg:px-8 bg-white/90 backdrop-blur-sm z-10 w-full"
      id="navigationHeader"
    >
      <div class="flex items-center justify-between border-b border-zinc-100 py-3 text-sm">
        <div class="flex items-center gap-2">
          <a href="/" class="flex items-center gap-2">
            <img src={~p"/images/v.png"} width="36" />
            <h5>Voile</h5>
          </a>
        </div>
        
        <div class="hidden lg:flex items-center gap-10 font-semibold leading-6 text-zinc-900">
          <div><.link href="/">Beranda</.link></div>
          
          <div><.link href="/about">Tentang</.link></div>
          
          <div>
            <p>Koleksi</p>
          </div>
          
          <div>
            <p>Kontak</p>
          </div>
        </div>
        
        <div>
          <div class="flex lg:hidden"><.button><.icon name="hero-bars-3" /></.button></div>
          
          <div class="hidden lg:block">
            <div class="flex items-center justify-center gap-2">
              <Layouts.theme_toggle />
              <%= if @current_scope do %>
                <.link navigate="/manage">
                  <.button class="default-btn">{@current_scope.username}</.button>
                </.link>
              <% else %>
                <.link navigate="/login"><.button class="ml-2 default-btn">Masuk</.button></.link>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </header>

    <main class="min-h-screen w-full h-full">{render_slot(@inner_block)}</main>

    <footer>
      <div class="bg-zinc-700 py-3 text-center text-violet-200">&copy; Voile {get_year()}</div>
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
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />
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
end
