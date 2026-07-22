defmodule VoileWeb.RedesignComponents do
  @moduledoc """
  Components for the Voile dashboard redesign (v2).

  These components are the implementation of the design system documented in
  `plans/dashboard-redesign.md`. They are isolated from the legacy
  `VoileDashboardComponents` so the redesign can ship behind a dedicated layout
  and route without touching any existing surface.

  All new dashboard LiveViews should `use VoileWeb, :live_view_redesign` and
  import nothing from `VoileDashboardComponents`. This module is imported
  automatically by the `live_view_redesign` macro in `VoileWeb`.
  """

  use Phoenix.Component
  use Gettext, backend: VoileWeb.Gettext

  import VoileWeb.CoreComponents,
    only: [icon: 1, theme_toggle: 1, modal: 1, input: 1, flash_group: 1, locale_switcher: 1]

  alias Phoenix.LiveView.JS

  # ----------------------------------------------------------------------------
  # Tone helpers — single source of truth for tone -> CSS class mapping
  # ----------------------------------------------------------------------------

  @doc """
  Returns the CSS color class for a semantic tone atom.
  """
  def tone_text(:brand), do: "text-voile-primary"
  def tone_text(:info), do: "text-voile-info"
  def tone_text(:success), do: "text-voile-success"
  def tone_text(:warning), do: "text-voile-warning"
  def tone_text(:error), do: "text-voile-error"
  def tone_text(:glam_gallery), do: "text-glam-gallery"
  def tone_text(:glam_library), do: "text-glam-library"
  def tone_text(:glam_archive), do: "text-glam-archive"
  def tone_text(:glam_museum), do: "text-glam-museum"
  def tone_text(_), do: "text-voile-primary"

  @doc """
  Returns the soft background CSS class for a semantic tone atom.
  """
  def tone_soft_bg(:brand), do: "bg-tone-brand-soft"
  def tone_soft_bg(:info), do: "bg-tone-info-soft"
  def tone_soft_bg(:success), do: "bg-tone-success-soft"
  def tone_soft_bg(:warning), do: "bg-tone-warning-soft"
  def tone_soft_bg(:error), do: "bg-tone-error-soft"
  def tone_soft_bg(:glam_gallery), do: "bg-glam-gallery-soft"
  def tone_soft_bg(:glam_library), do: "bg-glam-library-soft"
  def tone_soft_bg(:glam_archive), do: "bg-glam-archive-soft"
  def tone_soft_bg(:glam_museum), do: "bg-glam-museum-soft"
  def tone_soft_bg(_), do: "bg-tone-brand-soft"

  def tone_solid_bg(:glam_gallery), do: "bg-glam-gallery"
  def tone_solid_bg(:glam_library), do: "bg-glam-library"
  def tone_solid_bg(:glam_archive), do: "bg-glam-archive"
  def tone_solid_bg(:glam_museum), do: "bg-glam-museum"
  def tone_solid_bg(:brand), do: "bg-voile-primary"
  def tone_solid_bg(:info), do: "bg-voile-info"
  def tone_solid_bg(:success), do: "bg-voile-success"
  def tone_solid_bg(:warning), do: "bg-voile-warning"
  def tone_solid_bg(:error), do: "bg-voile-error"
  def tone_solid_bg(_), do: "bg-voile-primary"

  # ----------------------------------------------------------------------------
  # Shell primitives — sidebar, topbar, bottom nav, footer
  # ----------------------------------------------------------------------------

  @doc """
  Renders the persistent desktop sidebar (lg+).

  Inside the redesign layout, this is always paired with
  `<.rd_bottom_nav>` for mobile.
  """
  attr :current_path, :string, default: "/manage"
  attr :user, :map, default: nil

  def rd_sidebar(assigns) do
    ~H"""
    <aside
      id="rd-sidebar"
      class="rd-sidebar hidden lg:flex flex-col"
      phx-hook="Sidebar"
    >
      <div class="rd-sidebar-header">
        <.link navigate="/manage/redesign-test" class="rd-sidebar-brand">
          <img src="/images/v.png" alt="Voile" class="rd-sidebar-logo" />
          <span class="rd-sidebar-brand-text t-h4 text-primary">
            {Voile.Schema.System.get_setting_value("app_name", "Voile")}
          </span>
        </.link>
        <button
          type="button"
          data-rd-sidebar-toggle
          class="rd-sidebar-toggle"
          aria-label={gettext("Collapse sidebar")}
          aria-expanded="true"
        >
          <.icon name="hero-chevron-left" class="rd-sidebar-toggle-icon-collapse w-5 h-5" />
          <.icon name="hero-chevron-right" class="rd-sidebar-toggle-icon-expand w-5 h-5" />
        </button>
      </div>

      <nav class="rd-sidebar-nav flex-1 min-h-0 overflow-y-auto px-3 py-4 space-y-6">
        <.rd_sidebar_section title={gettext("Workspace")}>
          <%= for item <- workspace_items(@current_path) do %>
            <.rd_sidebar_link item={item} current_path={@current_path} />
          <% end %>
        </.rd_sidebar_section>

        <.rd_sidebar_section title={gettext("Collections")}>
          <%= for item <- collection_items(@current_path) do %>
            <.rd_sidebar_link item={item} current_path={@current_path} />
          <% end %>
        </.rd_sidebar_section>

        <.rd_sidebar_section title={gettext("People")}>
          <%= for item <- people_items(@current_path) do %>
            <.rd_sidebar_link item={item} current_path={@current_path} />
          <% end %>
        </.rd_sidebar_section>

        <.rd_sidebar_section title={gettext("System")}>
          <%= for item <- system_items(@current_path) do %>
            <.rd_sidebar_link item={item} current_path={@current_path} />
          <% end %>
        </.rd_sidebar_section>
      </nav>

      <.rd_sidebar_user_card user={@user} />
    </aside>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp rd_sidebar_section(assigns) do
    ~H"""
    <div class="rd-sidebar-section">
      <p class="rd-sidebar-section-title t-label text-tertiary px-3 mb-2">{@title}</p>
      <div class="space-y-0.5">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :current_path, :string, required: true

  defp rd_sidebar_link(assigns) do
    ~H"""
    <.link
      navigate={@item.path}
      title={@item.label}
      class={[
        "rd-nav-link",
        String.starts_with?(@current_path, @item.path) &&
          @current_path != "/manage/redesign-test" &&
          "rd-nav-link-active",
        @current_path == @item.path && @item.path == "/manage/redesign-test" &&
          "rd-nav-link-active"
      ]}
    >
      <.icon name={@item.icon} class="w-5 h-5 shrink-0" />
      <span class="rd-sidebar-label">{@item.label}</span>
      <%= if @item.shortcut do %>
        <kbd class="rd-sidebar-shortcut ml-auto t-mono text-tertiary hidden xl:inline">
          {@item.shortcut}
        </kbd>
      <% end %>
    </.link>
    """
  end

  attr :user, :map, default: nil

  defp rd_sidebar_user_card(assigns) do
    ~H"""
    <div class="rd-sidebar-user-card border-t border-subtle p-3">
      <div class="rd-sidebar-user-row flex items-center gap-3 px-2 py-2">
        <img
          src={user_avatar(@user)}
          alt={gettext("Avatar")}
          class="rd-sidebar-avatar w-9 h-9 rounded-full object-cover ring-2 ring-subtle"
        />
        <div class="rd-sidebar-user-info min-w-0 flex-1">
          <p class="text-sm font-semibold text-primary truncate">{user_name(@user)}</p>
          <p class="text-xs text-tertiary truncate">{user_role(@user)}</p>
        </div>
        <.link
          href="/users/log_out"
          method="delete"
          class="rd-sidebar-logout p-2 rounded-lg text-tertiary hover:text-voile-error hover:bg-tone-error-soft transition-colors"
          aria-label={gettext("Log out")}
          title={gettext("Log out")}
        >
          <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5" />
        </.link>
      </div>
    </div>
    """
  end

  defp user_name(%{fullname: name}) when is_binary(name), do: name
  defp user_name(%{username: name}) when is_binary(name), do: name
  defp user_name(_), do: gettext("Guest")

  defp user_avatar(%{user_image: url}) when is_binary(url), do: url
  defp user_avatar(_), do: "/images/default_avatar.jpg"

  defp user_role(%{user_type: %{name: name}}), do: name
  defp user_role(_), do: gettext("Staff")

  defp workspace_items(_current_path) do
    [
      %{label: gettext("Home"), path: "/manage", icon: "hero-home", shortcut: "G H"},
      %{
        label: gettext("Redesign Sample"),
        path: "/manage/redesign-test",
        icon: "hero-sparkles",
        shortcut: nil
      }
    ]
  end

  defp collection_items(_current_path) do
    [
      %{
        label: gettext("Catalog"),
        path: "/manage/catalog",
        icon: "hero-rectangle-stack",
        shortcut: nil
      },
      %{
        label: gettext("GLAM"),
        path: "/manage/glam",
        icon: "hero-building-library",
        shortcut: nil
      },
      %{
        label: gettext("Library"),
        path: "/manage/glam/library",
        icon: "hero-book-open",
        shortcut: nil
      },
      %{
        label: gettext("Archive"),
        path: "/manage/glam/archive",
        icon: "hero-archive-box",
        shortcut: nil
      },
      %{
        label: gettext("Gallery"),
        path: "/manage/glam/gallery",
        icon: "hero-photo",
        shortcut: nil
      },
      %{label: gettext("Museum"), path: "/manage/glam/museum", icon: "hero-cube", shortcut: nil}
    ]
  end

  defp people_items(_current_path) do
    [
      %{
        label: gettext("Members"),
        path: "/manage/members",
        icon: "hero-user-group",
        shortcut: nil
      },
      %{
        label: gettext("Visitors"),
        path: "/manage/visitor/statistics",
        icon: "hero-chart-bar",
        shortcut: nil
      }
    ]
  end

  defp system_items(_current_path) do
    [
      %{
        label: gettext("Plugins"),
        path: "/manage/plugins",
        icon: "hero-puzzle-piece",
        shortcut: nil
      },
      %{
        label: gettext("Settings"),
        path: "/manage/settings",
        icon: "hero-cog-6-tooth",
        shortcut: nil
      },
      %{
        label: gettext("Master Data"),
        path: "/manage/master",
        icon: "hero-circle-stack",
        shortcut: nil
      },
      %{label: gettext("Metadata"), path: "/manage/metaresource", icon: "hero-tag", shortcut: nil}
    ]
  end

  @doc """
  Renders the mobile bottom navigation (visible only below lg).
  Five slots: Home, Catalog, primary-GLAM, Members, More.
  """
  attr :current_path, :string, default: "/manage"

  def rd_bottom_nav(assigns) do
    ~H"""
    <nav class="rd-bottom-nav fixed bottom-0 inset-x-0 lg:hidden grid grid-cols-5 z-40">
      <.rd_bottom_nav_item
        label={gettext("Home")}
        icon="hero-home"
        path="/manage"
        current_path={@current_path}
      />
      <.rd_bottom_nav_item
        label={gettext("Catalog")}
        icon="hero-rectangle-stack"
        path="/manage/catalog"
        current_path={@current_path}
      />
      <.rd_bottom_nav_item
        label={gettext("GLAM")}
        icon="hero-building-library"
        path="/manage/glam"
        current_path={@current_path}
      />
      <.rd_bottom_nav_item
        label={gettext("Members")}
        icon="hero-user-group"
        path="/manage/members"
        current_path={@current_path}
      />
      <button
        type="button"
        phx-click={JS.dispatch("voile:open-command-palette")}
        class="flex flex-col items-center justify-center gap-1 py-2 text-secondary hover:text-voile-primary transition-colors"
        aria-label={gettext("Open command palette")}
      >
        <.icon name="hero-squares-2x2" class="w-6 h-6" />
        <span class="text-[11px] font-medium">{gettext("More")}</span>
      </button>
    </nav>
    """
  end

  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :path, :string, required: true
  attr :current_path, :string, required: true

  defp rd_bottom_nav_item(assigns) do
    ~H"""
    <.link
      navigate={@path}
      class={[
        "flex flex-col items-center justify-center gap-1 py-2 transition-colors relative",
        String.starts_with?(@current_path, @path) &&
          "text-voile-primary",
        !String.starts_with?(@current_path, @path) &&
          "text-secondary hover:text-voile-primary"
      ]}
    >
      <%= if String.starts_with?(@current_path, @path) do %>
        <span class="absolute top-0 inset-x-4 h-0.5 rounded-b bg-voile-primary"></span>
      <% end %>
      <.icon name={@icon} class="w-6 h-6" />
      <span class="text-[11px] font-medium">{@label}</span>
    </.link>
    """
  end

  @doc """
  Renders the sticky topbar with breadcrumb, command palette trigger,
  notifications, theme toggle, and user avatar.
  """
  attr :current_path, :string, default: "/manage"
  attr :user, :map, default: nil
  attr :breadcrumb, :list, default: []
  attr :notification_count, :integer, default: 0

  def rd_topbar(assigns) do
    ~H"""
    <header class="rd-topbar px-4 lg:px-8 flex items-center gap-4">
      <div class="flex items-center gap-3 min-w-0 flex-1">
        <.link navigate="/manage/redesign-test" class="lg:hidden shrink-0">
          <img src="/images/v.png" alt="Voile" class="w-8 h-8" />
        </.link>
        <.rd_breadcrumb items={@breadcrumb} current_path={@current_path} />
      </div>

      <div class="flex items-center gap-2">
        <button
          type="button"
          phx-click={JS.dispatch("voile:open-command-palette")}
          class="rd-chip hidden md:inline-flex"
          aria-label={gettext("Open command palette")}
        >
          <.icon name="hero-magnifying-glass" class="w-4 h-4" />
          <span class="text-secondary">{gettext("Search")}</span>
          <kbd class="ml-2 t-mono text-tertiary hidden lg:inline">⌘K</kbd>
        </button>

        <button
          type="button"
          phx-click={JS.dispatch("voile:open-command-palette")}
          class="md:hidden p-2 rounded-lg text-secondary hover:text-voile-primary hover:bg-tone-brand-soft transition-colors"
          aria-label={gettext("Search")}
        >
          <.icon name="hero-magnifying-glass" class="w-5 h-5" />
        </button>

        <button
          type="button"
          class="relative p-2 rounded-lg text-secondary hover:text-voile-primary hover:bg-tone-brand-soft transition-colors"
          aria-label={gettext("Notifications")}
        >
          <.icon name="hero-bell" class="w-5 h-5" />
          <%= if @notification_count > 0 do %>
            <span class="absolute top-1 right-1 min-w-4 h-4 px-1 rounded-full bg-voile-error text-white text-[10px] font-bold flex items-center justify-center">
              {@notification_count}
            </span>
          <% end %>
        </button>

        <div class="hidden sm:block">
          <.theme_toggle />
        </div>

        <img
          src={user_avatar(@user)}
          alt={gettext("Avatar")}
          class="w-8 h-8 rounded-full object-cover ring-2 ring-subtle"
        />
      </div>
    </header>
    """
  end

  attr :items, :list, required: true
  attr :current_path, :string, required: true

  defp rd_breadcrumb(assigns) do
    assigns = assign(assigns, :indexed_items, Enum.with_index(assigns.items))

    ~H"""
    <nav aria-label={gettext("Breadcrumb")} class="flex items-center gap-1.5 min-w-0 text-sm">
      <%= for {item, idx} <- @indexed_items do %>
        <%= if item.path do %>
          <.link
            navigate={item.path}
            class="text-secondary hover:text-voile-primary transition-colors truncate"
          >
            {item.label}
          </.link>
        <% else %>
          <span class="text-primary font-semibold truncate">{item.label}</span>
        <% end %>
        <%= if idx < length(@indexed_items) - 1 do %>
          <.icon name="hero-chevron-right" class="w-3.5 h-3.5 text-tertiary shrink-0" />
        <% end %>
      <% end %>
    </nav>
    """
  end

  @doc """
  Renders the lite footer shown at the bottom of the scrolling content area.
  Single-line attribution, brand-tinted.
  """
  attr :app_name, :string, default: "Voile"

  def rd_footer(assigns) do
    assigns = assign(assigns, :year, DateTime.utc_now().year)

    ~H"""
    <footer class="border-t border-subtle px-4 lg:px-8 py-4">
      <div class="max-w-[var(--layout-content-max)] mx-auto flex flex-wrap items-center justify-between gap-2 text-xs text-tertiary">
        <p>
          Manage · {@app_name} · © {@year} Curatorian Developer
        </p>
        <div class="flex items-center gap-4">
          <a
            href="https://github.com/curatorian"
            target="_blank"
            rel="noopener noreferrer"
            class="hover:text-voile-primary transition-colors"
          >
            Docs ↗
          </a>
          <a
            href="https://github.com/curatorian/voile"
            target="_blank"
            rel="noopener noreferrer"
            class="hover:text-voile-primary transition-colors"
          >
            GitHub ↗
          </a>
        </div>
      </div>
    </footer>
    """
  end

  # ----------------------------------------------------------------------------
  # Content primitives
  # ----------------------------------------------------------------------------

  @doc """
  Renders the canonical page header: eyebrow + title + description + actions.
  One per page.
  """
  attr :eyebrow, :string, default: nil
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :icon, :string, default: nil
  attr :tone, :atom, default: :brand
  slot :actions

  def rd_page_header(assigns) do
    ~H"""
    <div class="mb-8">
      <%= if @eyebrow do %>
        <p class={"t-label mb-2 #{tone_text(@tone)}"}>{@eyebrow}</p>
      <% end %>
      <div class="flex items-start justify-between gap-4 flex-wrap">
        <div class="flex items-start gap-3 min-w-0">
          <%= if @icon do %>
            <div class={"shrink-0 w-11 h-11 rounded-xl flex items-center justify-center #{tone_soft_bg(@tone)}"}>
              <.icon name={@icon} class={"w-6 h-6 #{tone_text(@tone)}"} />
            </div>
          <% end %>
          <div class="min-w-0">
            <h1 class="t-h1 text-primary text-2xl md:text-3xl">{@title}</h1>
            <%= if @description do %>
              <p class="text-secondary mt-1.5 text-sm md:text-base max-w-2xl">{@description}</p>
            <% end %>
          </div>
        </div>
        <%= if @actions do %>
          <div class="flex items-center gap-2 shrink-0">{render_slot(@actions)}</div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a brand-aware stat card with optional trend and sparkline.

  ## Examples

      <.rd_stat_card
        label="Total Members"
        value="1,204"
        icon="hero-users"
        tone={:success}
        trend=%{direction: :up, value: "+12%", period: "vs last week"}
      />
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :unit, :string, default: nil
  attr :icon, :string, default: nil
  attr :tone, :atom, default: :brand
  attr :trend, :map, default: nil
  attr :sparkline, :list, default: nil
  attr :href, :string, default: nil
  attr :loading, :boolean, default: false
  attr :class, :string, default: nil

  def rd_stat_card(assigns) do
    ~H"""
    <div class={[
      "rd-card rd-card-hover p-5 flex flex-col gap-3",
      @href && "cursor-pointer",
      @class
    ]}>
      <div class="flex items-center justify-between gap-2">
        <p class="t-label text-secondary">{@label}</p>
        <%= if @icon do %>
          <div class={"w-8 h-8 rounded-lg flex items-center justify-center #{tone_soft_bg(@tone)}"}>
            <.icon name={@icon} class={"w-4 h-4 #{tone_text(@tone)}"} />
          </div>
        <% end %>
      </div>

      <%= if @loading do %>
        <div class="skeleton h-9 w-24"></div>
      <% else %>
        <p class="t-stat text-primary text-3xl">
          {@value}
          <%= if @unit do %>
            <span class="text-base text-tertiary font-medium ml-1">{@unit}</span>
          <% end %>
        </p>
      <% end %>

      <%= if @sparkline && !@loading do %>
        <.rd_sparkline points={@sparkline} tone={@tone} />
      <% end %>

      <%= if @trend && !@loading do %>
        <div class="flex items-center gap-1.5 text-xs">
          <%= case @trend[:direction] do %>
            <% :up -> %>
              <.icon name="hero-arrow-trending-up" class={"w-4 h-4 #{tone_text(:success)}"} />
              <span class={tone_text(:success)}>{@trend[:value]}</span>
            <% :down -> %>
              <.icon name="hero-arrow-trending-down" class={"w-4 h-4 #{tone_text(:error)}"} />
              <span class={tone_text(:error)}>{@trend[:value]}</span>
            <% _ -> %>
              <.icon name="hero-minus" class="w-4 h-4 text-tertiary" />
              <span class="text-tertiary">{@trend[:value]}</span>
          <% end %>
          <%= if @trend[:period] do %>
            <span class="text-tertiary">{@trend[:period]}</span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :points, :list, required: true
  attr :tone, :atom, default: :brand

  defp rd_sparkline(assigns) do
    %{points: points} = assigns

    assigns =
      assign(assigns, :path_string, build_sparkline_path(points))

    ~H"""
    <svg
      viewBox="0 0 100 24"
      preserveAspectRatio="none"
      class="w-full h-6"
      aria-hidden="true"
    >
      <path
        d={@path_string}
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class={tone_text(@tone)}
      />
    </svg>
    """
  end

  defp build_sparkline_path([]), do: "M 0 12"

  defp build_sparkline_path(points) do
    max = Enum.max(points)
    min = Enum.min(points)
    range = max - min

    points
    |> Enum.with_index()
    |> Enum.map(fn {v, i} ->
      x = if length(points) <= 1, do: 0, else: i * 100 / (length(points) - 1)
      normalized = if range == 0, do: 0.5, else: (v - min) / range
      y = 22 - normalized * 20
      "#{format_coord(x)} #{format_coord(y)}"
    end)
    |> Enum.join(" L ")
    |> then(&"M #{&1}")
  end

  defp format_coord(n) do
    Float.round(n * 1.0, 2)
  end

  @doc """
  Renders the GLAM strip: four large tiles for the four GLAM types.
  """
  attr :stats, :map, required: true

  def rd_glam_strip(assigns) do
    ~H"""
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 md:gap-4 mb-8">
      <.rd_glam_tile
        type={:gallery}
        count={@stats[:gallery_count] || 0}
        delta={@stats[:gallery_delta] || 0}
        href="/manage/glam/gallery"
      />
      <.rd_glam_tile
        type={:library}
        count={@stats[:library_count] || 0}
        delta={@stats[:library_delta] || 0}
        href="/manage/glam/library"
      />
      <.rd_glam_tile
        type={:archive}
        count={@stats[:archive_count] || 0}
        delta={@stats[:archive_delta] || 0}
        href="/manage/glam/archive"
      />
      <.rd_glam_tile
        type={:museum}
        count={@stats[:museum_count] || 0}
        delta={@stats[:museum_delta] || 0}
        href="/manage/glam/museum"
      />
    </div>
    """
  end

  attr :type, :atom, required: true
  attr :count, :integer, required: true
  attr :delta, :integer, default: 0
  attr :href, :string, required: true

  @doc """
  Renders a single GLAM type tile (the public version used by `rd_glam_strip`).
  Drop-in replacement for the legacy `glam_type_card/1`. DRAFT API — stable.
  """
  def rd_glam_tile(assigns) do
    %{type: type} = assigns

    assigns =
      assigns
      |> assign(:name, glam_type_name(type))
      |> assign(:icon, glam_type_icon(type))
      |> assign(:tone, type)

    ~H"""
    <.link navigate={@href} class="rd-card rd-card-hover p-5 group relative overflow-hidden block">
      <div class={[
        "absolute -right-6 -top-6 w-24 h-24 rounded-full blur-2xl opacity-30 group-hover:opacity-50 transition-opacity",
        tone_soft_bg(@tone)
      ]}>
      </div>

      <div class="relative flex items-center gap-2 mb-3">
        <div class={"w-9 h-9 rounded-lg flex items-center justify-center #{tone_soft_bg(@tone)}"}>
          <.icon name={@icon} class={"w-5 h-5 #{tone_text(@tone)}"} />
        </div>
        <p class="t-label text-secondary">{@name}</p>
      </div>

      <p class="t-stat text-primary text-3xl">{@count}</p>

      <div class="flex items-center gap-1.5 text-xs mt-2">
        <%= cond do %>
          <% @delta > 0 -> %>
            <.icon name="hero-arrow-trending-up" class="w-3.5 h-3.5 text-voile-success" />
            <span class="text-voile-success">+{@delta} {gettext("this week")}</span>
          <% @delta < 0 -> %>
            <.icon name="hero-arrow-trending-down" class="w-3.5 h-3.5 text-voile-error" />
            <span class="text-voile-error">{@delta} {gettext("this week")}</span>
          <% true -> %>
            <.icon name="hero-minus" class="w-3.5 h-3.5 text-tertiary" />
            <span class="text-tertiary">{gettext("no change")}</span>
        <% end %>
      </div>
    </.link>
    """
  end

  defp glam_type_name(:gallery), do: gettext("Gallery")
  defp glam_type_name(:library), do: gettext("Library")
  defp glam_type_name(:archive), do: gettext("Archive")
  defp glam_type_name(:museum), do: gettext("Museum")

  defp glam_type_icon(:gallery), do: "hero-photo"
  defp glam_type_icon(:library), do: "hero-book-open"
  defp glam_type_icon(:archive), do: "hero-archive-box"
  defp glam_type_icon(:museum), do: "hero-cube"

  @doc """
  Renders a titled card that wraps content. The primary composition primitive.
  """
  attr :title, :string, default: nil
  attr :icon, :string, default: nil
  attr :tone, :atom, default: :brand
  attr :action_label, :string, default: nil
  attr :action_path, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def rd_section_card(assigns) do
    ~H"""
    <section class={["rd-card p-5 md:p-6", @class]}>
      <%= if @title do %>
        <div class="flex items-center justify-between gap-2 mb-4">
          <div class="flex items-center gap-2 min-w-0">
            <%= if @icon do %>
              <.icon name={@icon} class={"w-5 h-5 #{tone_text(@tone)}"} />
            <% end %>
            <h2 class="t-h3 text-primary text-lg">{@title}</h2>
          </div>
          <%= if @action_label && @action_path do %>
            <.link
              navigate={@action_path}
              class="text-sm text-voile-primary hover:underline shrink-0"
            >
              {@action_label} →
            </.link>
          <% end %>
        </div>
      <% end %>
      {render_slot(@inner_block)}
    </section>
    """
  end

  @doc """
  Renders a metric row: label on the left, value on the right, and an
  optional proportional bar when a `:total` is supplied.
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :total, :any, default: nil
  attr :tone, :atom, default: :brand

  def rd_metric_row(assigns) do
    assigns =
      with %{total: total, value: value} when is_number(total) and is_number(value) and total > 0 <-
             assigns do
        percent = Float.round(value / total * 100, 1)
        assign(assigns, :percent, percent)
      else
        _ -> assign(assigns, :percent, nil)
      end

    ~H"""
    <div class="py-2">
      <div class="flex items-center justify-between text-sm mb-1.5">
        <span class="text-secondary">{@label}</span>
        <span class="text-primary font-semibold t-tabular">{@value}</span>
      </div>
      <%= if @percent do %>
        <div class="track-subtle h-1.5 rounded-full overflow-hidden">
          <div
            class={"h-full rounded-full #{tone_solid_bg(@tone)}"}
            style={"width: #{@percent}%; transition: width 600ms var(--ease-smooth)"}
          >
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a uniform activity feed from a list of items.

  Each item is a map with keys:
    - `:icon`     — hero-* icon name
    - `:tone`     — semantic tone atom
    - `:title`    — bold first line
    - `:subtitle` — secondary text (optional)
    - `:meta`     — right-aligned meta text (e.g. timestamp) (optional)
    - `:href`     — link target (optional)
  """
  attr :items, :list, required: true
  attr :empty_text, :string, default: nil

  def rd_activity_feed(assigns) do
    ~H"""
    <div class="space-y-1">
      <%= if @items == [] && @empty_text do %>
        <p class="text-sm text-tertiary text-center py-6">{@empty_text}</p>
      <% else %>
        <%= for item <- @items do %>
          <.rd_activity_item item={item} />
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :item, :map, required: true

  defp rd_activity_item(assigns) do
    ~H"""
    <div class="flex items-start gap-3 p-2 rounded-lg hover-surface transition-colors">
      <div class={"shrink-0 w-8 h-8 rounded-lg flex items-center justify-center #{tone_soft_bg(@item.tone)}"}>
        <.icon name={@item.icon} class={"w-4 h-4 #{tone_text(@item.tone)}"} />
      </div>
      <div class="min-w-0 flex-1">
        <div class="flex items-start justify-between gap-2">
          <p class="text-sm text-primary font-medium truncate">
            {@item.title}
          </p>
          <%= if @item.meta do %>
            <span class="text-xs text-tertiary t-mono shrink-0">{@item.meta}</span>
          <% end %>
        </div>
        <%= if @item.subtitle do %>
          <p class="text-xs text-secondary truncate mt-0.5">{@item.subtitle}</p>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders the command palette overlay (modal).

  Listens for ⌘K via the `CommandPalette` hook. Items are static for the demo;
  in production these will be live-driven via a pushEvent to query collections.
  """
  attr :current_path, :string, default: "/manage"

  def rd_command_palette(assigns) do
    ~H"""
    <div id="rd-command-palette" phx-hook="CommandPalette" class="hidden">
      <div data-rd-cmd-backdrop class="rd-cmd-backdrop"></div>
      <div data-rd-cmd-panel class="rd-cmd-panel">
        <div class="flex items-center gap-3 px-4 py-3 border-b border-subtle">
          <.icon name="hero-magnifying-glass" class="w-5 h-5 text-tertiary" />
          <input
            type="text"
            data-rd-cmd-input
            placeholder={gettext("Search or jump to…")}
            autocomplete="off"
            class="flex-1 bg-transparent outline-none text-base text-primary placeholder:text-tertiary"
          />
          <kbd class="t-mono text-xs text-tertiary rd-chip">Esc</kbd>
        </div>

        <div class="overflow-y-auto flex-1 p-2">
          <.rd_cmd_group title={gettext("Quick actions")}>
            <.rd_cmd_item
              icon="hero-plus"
              tone={:brand}
              label={gettext("Start a circulation transaction")}
              href="/manage/glam/library/ledger"
            />
            <.rd_cmd_item
              icon="hero-user-plus"
              tone={:brand}
              label={gettext("Add a new member")}
              href="/manage/members/management/new"
            />
            <.rd_cmd_item
              icon="hero-document-plus"
              tone={:brand}
              label={gettext("Create a new collection")}
              href="/manage/catalog/collections/new"
            />
          </.rd_cmd_group>

          <.rd_cmd_group title={gettext("Navigation")}>
            <.rd_cmd_item
              icon="hero-home"
              tone={:brand}
              label={gettext("Dashboard Home")}
              meta="G H"
              href="/manage"
            />
            <.rd_cmd_item
              icon="hero-sparkles"
              tone={:brand}
              label={gettext("Redesign Sample")}
              href="/manage/redesign-test"
            />
            <.rd_cmd_item
              icon="hero-rectangle-stack"
              tone={:brand}
              label={gettext("Catalog")}
              href="/manage/catalog"
            />
            <.rd_cmd_item
              icon="hero-building-library"
              tone={:brand}
              label={gettext("GLAM Hub")}
              href="/manage/glam"
            />
            <.rd_cmd_item
              icon="hero-user-group"
              tone={:brand}
              label={gettext("Members")}
              href="/manage/members"
            />
            <.rd_cmd_item
              icon="hero-cog-6-tooth"
              tone={:brand}
              label={gettext("Settings")}
              href="/manage/settings"
            />
          </.rd_cmd_group>

          <div data-rd-cmd-empty class="hidden px-4 py-10 text-center text-tertiary text-sm">
            {gettext("No results found")}
          </div>
        </div>

        <div class="px-4 py-2.5 border-t border-subtle flex items-center justify-between text-xs text-tertiary t-mono">
          <span>↑↓ {gettext("navigate")}</span>
          <span>⏎ {gettext("select")}</span>
          <span>⌘K {gettext("close")}</span>
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp rd_cmd_group(assigns) do
    ~H"""
    <div data-rd-cmd-group class="mb-2">
      <p class="t-label text-tertiary px-3 py-1.5">{@title}</p>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :tone, :atom, default: :brand
  attr :label, :string, required: true
  attr :meta, :string, default: nil
  attr :href, :string, required: true

  defp rd_cmd_item(assigns) do
    ~H"""
    <.link
      navigate={@href}
      data-rd-cmd-result
      data-rd-cmd-search={@label}
      class="flex items-center gap-3 px-3 py-2.5 rounded-lg hover-surface transition-colors"
    >
      <.icon name={@icon} class={"w-5 h-5 #{tone_text(@tone)}"} />
      <span class="text-sm text-primary flex-1">{@label}</span>
      <%= if @meta do %>
        <kbd class="t-mono text-xs text-tertiary">{@meta}</kbd>
      <% end %>
    </.link>
    """
  end

  @doc """
  Renders an empty-state block.
  """
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :tone, :atom, default: :brand
  slot :actions

  def rd_empty_state(assigns) do
    ~H"""
    <div class="text-center py-12 px-6">
      <div class="inline-flex items-center justify-center w-14 h-14 rounded-2xl mb-4 #{tone_soft_bg(@tone)}">
        <.icon name={@icon} class={"w-7 h-7 #{tone_text(@tone)}"} />
      </div>
      <h3 class="t-h3 text-primary text-lg mb-1">{@title}</h3>
      <%= if @description do %>
        <p class="text-sm text-secondary max-w-sm mx-auto">{@description}</p>
      <% end %>
      <%= if @actions do %>
        <div class="mt-4 flex items-center justify-center gap-2">{render_slot(@actions)}</div>
      <% end %>
    </div>
    """
  end

  @doc """
  A styled primary button matching the redesign.
  """
  attr :href, :string, default: nil
  attr :type, :string, default: "button"
  attr :tone, :atom, default: :brand
  attr :variant, :atom, default: :solid
  attr :size, :atom, default: :md
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def rd_button(assigns) do
    assigns = assign(assigns, :classes, button_classes(assigns))

    ~H"""
    <%= if @href do %>
      <.link href={@href} class={@classes}>
        {render_slot(@inner_block)}
      </.link>
    <% else %>
      <button type={@type} class={@classes} {@rest}>
        {render_slot(@inner_block)}
      </button>
    <% end %>
    """
  end

  defp button_classes(assigns) do
    base =
      "inline-flex items-center justify-center gap-1.5 font-medium rounded-lg transition-colors"

    size_class =
      case assigns[:size] do
        :sm -> "px-3 py-1.5 text-sm"
        :lg -> "px-5 py-2.5 text-base"
        _ -> "px-4 py-2 text-sm"
      end

    variant_class =
      case {assigns[:variant], assigns[:tone]} do
        {:solid, _} ->
          "bg-voile-primary text-white hover:brightness-110"

        {:soft, tone} ->
          "#{tone_soft_bg(tone)} #{tone_text(tone)} hover:brightness-95"

        {:outline, tone} ->
          "border border-subtle #{tone_text(tone)} hover-surface"

        _ ->
          "bg-voile-primary text-white hover:brightness-110"
      end

    "#{base} #{size_class} #{variant_class} #{assigns[:class] || ""}"
  end

  # ===========================================================================
  # DRAFT REPLACEMENT COMPONENTS
  #
  # Brand-styled successors to legacy VoileDashboardComponents /
  # CoreComponents. These are scaffolded — the API (attr/slot) is stable and
  # each renders a v1 using the design tokens — but NONE are adopted by any
  # real page yet. Review them on the /manage/redesign-test "Legacy" tab.
  # ===========================================================================

  # ---------- rd_pagination (replaces VoileDashboardComponents.pagination/1, 21 files) ----------

  @doc """
  Brand-styled pagination. Drop-in replacement for the legacy `pagination/1`.

  ## Modes
    * **link** — pass `:path`; renders `<.link patch>` (URL built from `:params`).
    * **button** — omit `:path`; renders `<.button phx-click={event} phx-value-page>`.

  DRAFT — not yet adopted.
  """
  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :path, :string, default: nil
  attr :event, :string, default: "paginate"
  attr :params, :map, default: %{}

  def rd_pagination(assigns) do
    assigns = assign(assigns, :range, rd_pagination_range(assigns.page, assigns.total_pages))

    ~H"""
    <nav class="flex items-center gap-1" aria-label={gettext("Pagination")}>
      <.rd_page_button
        page={@page - 1}
        disabled={@page <= 1}
        path={@path}
        event={@event}
        params={@params}
      >
        <.icon name="hero-chevron-left" class="w-4 h-4" />
      </.rd_page_button>

      <%= for item <- @range do %>
        <%= if item == :ellipsis do %>
          <span class="px-2 text-tertiary t-mono">…</span>
        <% else %>
          <.rd_page_button
            page={item}
            active={item == @page}
            path={@path}
            event={@event}
            params={@params}
          >
            {item}
          </.rd_page_button>
        <% end %>
      <% end %>

      <.rd_page_button
        page={@page + 1}
        disabled={@page >= @total_pages}
        path={@path}
        event={@event}
        params={@params}
      >
        <.icon name="hero-chevron-right" class="w-4 h-4" />
      </.rd_page_button>
    </nav>
    """
  end

  attr :page, :integer, required: true
  attr :active, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :path, :string, default: nil
  attr :event, :string, default: "paginate"
  attr :params, :map, default: %{}
  slot :inner_block, required: true

  defp rd_page_button(assigns) do
    ~H"""
    <%= if @disabled do %>
      <span
        class="inline-flex items-center justify-center min-w-9 h-9 px-2 rounded-lg text-tertiary cursor-not-allowed"
        aria-disabled="true"
      >
        {render_slot(@inner_block)}
      </span>
    <% else %>
      <%= if @path do %>
        <.link
          patch={rd_page_url(@path, @page, @params)}
          class={rd_page_class(@active)}
          aria-label={gettext("Page %{page}", page: @page)}
          aria-current={@active && "page"}
        >
          {render_slot(@inner_block)}
        </.link>
      <% else %>
        <button
          type="button"
          phx-click={@event}
          phx-value-page={@page}
          class={rd_page_class(@active)}
          aria-current={@active && "page"}
        >
          {render_slot(@inner_block)}
        </button>
      <% end %>
    <% end %>
    """
  end

  defp rd_page_class(true),
    do:
      "inline-flex items-center justify-center min-w-9 h-9 px-2 rounded-lg bg-voile-primary text-white font-semibold"

  defp rd_page_class(_),
    do:
      "inline-flex items-center justify-center min-w-9 h-9 px-2 rounded-lg text-secondary hover:text-primary hover:bg-tone-brand-soft transition-colors"

  defp rd_page_url(path, page, params) do
    query = params |> Map.put("page", page) |> URI.encode_query()
    "#{path}?#{query}"
  end

  defp rd_pagination_range(_page, total) when total <= 7, do: Enum.to_list(1..total)

  defp rd_pagination_range(page, total) do
    cond do
      page <= 3 -> [1, 2, 3, 4, :ellipsis, total]
      page >= total - 2 -> [1, :ellipsis, total - 3, total - 2, total - 1, total]
      true -> [1, :ellipsis, page - 1, page, page + 1, :ellipsis, total]
    end
  end

  # ---------- rd_settings_shell (replaces dashboard_settings_sidebar/plugin_settings_sidebar/side_bar_dashboard) ----------

  @doc """
  Two-pane "sub-nav + content" shell for settings, plugins, master-data and
  metaresource pages. Replaces `dashboard_settings_sidebar/1` (12 files),
  `plugin_settings_sidebar/1` (3 files), and the inline master/metaresource
  sidebars in `dashboard.html.heex`.

  `items` is a list of maps: `%{label: "...", path: "/...", icon: "hero-..."}`
  (icon optional). DRAFT — not yet adopted.
  """
  attr :title, :string, default: nil
  attr :items, :list, required: true
  attr :current_path, :string, default: nil
  slot :inner_block, required: true

  def rd_settings_shell(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-[220px_1fr] gap-6">
      <aside class="rd-card p-3 h-fit lg:sticky lg:top-20">
        <%= if @title do %>
          <p class="t-label text-tertiary px-3 mb-2">{@title}</p>
        <% end %>
        <nav class="space-y-0.5">
          <%= for item <- @items do %>
            <.link
              navigate={item.path}
              class={[
                "flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm transition-colors",
                rd_settings_active?(@current_path, item) &&
                  "bg-tone-brand-soft text-voile-primary font-semibold",
                !rd_settings_active?(@current_path, item) &&
                  "text-secondary hover:text-primary hover:bg-tone-brand-soft"
              ]}
            >
              <%= if item[:icon] do %>
                <.icon name={item.icon} class="w-4 h-4 shrink-0" />
              <% end %>
              <span class="truncate">{item.label}</span>
            </.link>
          <% end %>
        </nav>
      </aside>
      <div class="min-w-0">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp rd_settings_active?(current_path, %{path: path}) do
    String.starts_with?(current_path || "", path)
  end

  # ---------- rd_table (replaces CoreComponents.table) ----------

  @doc """
  Brand-styled data table. Replaces the core `<.table>` with redesign tokens:
  brand-tinted header, row hover, optional empty slot, and an actions column.

  Columns use `:let={row}`:

      <:col :let={row} label="Title">{row.title}</:col>

  DRAFT — not yet adopted. (LiveStream support is pending; currently iterates a list.)
  """
  attr :id, :string, required: true
  attr :rows, :any, required: true
  attr :row_id, :any, default: nil

  slot :col, required: true do
    attr :label, :string
  end

  slot :action
  slot :empty

  def rd_table(assigns) do
    ~H"""
    <div class="rd-card overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-subtle">
              <th
                :for={col <- @col}
                class="t-label text-secondary text-left font-semibold px-4 py-3 whitespace-nowrap"
              >
                {col[:label]}
              </th>
              <%= if @action do %>
                <th class="t-label text-secondary text-right font-semibold px-4 py-3"></th>
              <% end %>
            </tr>
          </thead>
          <tbody id={@id}>
            <tr
              :for={row <- @rows}
              id={@row_id && @row_id.(row)}
              class="border-b border-subtle last:border-0 hover-surface transition-colors"
            >
              <td :for={col <- @col} class="px-4 py-3 text-primary align-top">
                {render_slot(col, row)}
              </td>
              <%= if @action do %>
                <td class="px-4 py-3 text-right whitespace-nowrap">
                  <%= for action <- @action do %>
                    {render_slot(action, row)}
                  <% end %>
                </td>
              <% end %>
            </tr>
          </tbody>
        </table>
      </div>
      <%= if @rows == [] && @empty do %>
        <div class="p-6">{render_slot(@empty)}</div>
      <% end %>
    </div>
    """
  end

  # ---------- rd_input (brand restyle of CoreComponents.input) ----------

  @doc """
  Brand restyle wrapper around the core `<.input>`. Forwards the common attrs
  and adds the `rd-input` class so the redesign focus ring (2px voile-primary,
  2px offset) applies once the CSS lands. DRAFT — focus-ring CSS pending.
  """
  attr :field, Phoenix.HTML.FormField, default: nil
  attr :name, :any
  attr :value, :any
  attr :type, :string, default: "text"
  attr :label, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  def rd_input(assigns) do
    assigns =
      assign(
        assigns,
        :rd_class,
        ["rd-input", assigns[:class]] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
      )

    ~H"""
    <.input
      field={@field}
      name={@name}
      value={@value}
      type={@type}
      label={@label}
      class={@rd_class}
      {@rest}
    />
    """
  end

  # ---------- rd_search_insights (replaces search_stats_widget/1) ----------

  @doc """
  Brand-styled search-insights widget. Replaces `search_stats_widget/1`.
  `stats` shape: `%{total_searches: n, popular_queries: [{q, count}], recent_activity: [...]}`.
  DRAFT — not yet adopted.
  """
  attr :stats, :map, default: %{}
  attr :action_path, :string, default: nil

  def rd_search_insights(assigns) do
    stats = assigns.stats

    assigns =
      assigns
      |> assign(:total, stats[:total_searches] || 0)
      |> assign(:popular, stats[:popular_queries] || [])

    ~H"""
    <div class="rd-card p-5">
      <div class="flex items-center justify-between mb-3">
        <h3 class="t-h3 text-primary text-lg">{gettext("Search insights")}</h3>
        <%= if @action_path do %>
          <.link navigate={@action_path} class="text-sm text-voile-primary hover:underline">
            {gettext("Analytics")} →
          </.link>
        <% end %>
      </div>
      <p class="t-stat text-primary text-2xl">{@total}</p>
      <p class="t-label text-tertiary mt-1">{gettext("Searches today")}</p>
      <%= if @popular != [] do %>
        <p class="t-label text-tertiary mt-4 mb-2">{gettext("Popular queries")}</p>
        <div class="flex flex-wrap gap-1.5">
          <%= for {query, count} <- Enum.take(@popular, 5) do %>
            <span class="rd-chip">
              {query}<span class="text-tertiary t-mono text-[10px]">{count}</span>
            </span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ---------- rd_modal + rd_confirm_delete (replaces collection_modal/delete_modal) ----------

  @doc """
  Brand-styled modal shell. Replaces `collection_modal/1`. Wraps the core
  `<.modal>` with an optional eyebrow + title + body + optional footer.
  DRAFT — not yet adopted.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :eyebrow, :string, default: nil
  attr :title, :string, default: nil
  slot :inner_block, required: true
  slot :footer

  def rd_modal(assigns) do
    ~H"""
    <.modal id={@id} show={@show} on_cancel={@on_cancel}>
      <%= if @eyebrow do %>
        <p class="t-label text-voile-primary mb-1">{@eyebrow}</p>
      <% end %>
      <%= if @title do %>
        <h2 class="t-h3 text-primary text-xl mb-3">{@title}</h2>
      <% end %>
      <div class="text-secondary text-sm">{render_slot(@inner_block)}</div>
      <%= if @footer do %>
        <div class="flex items-center justify-end gap-2 pt-4 mt-4 border-t border-subtle">
          {render_slot(@footer)}
        </div>
      <% end %>
    </.modal>
    """
  end

  @doc """
  Destructive confirmation modal. Replaces `delete_modal/1` and the ad-hoc
  delete modals. DRAFT — not yet adopted.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :title, :string, default: nil
  attr :confirm_label, :string, default: gettext("Delete")
  attr :on_cancel, JS, default: %JS{}
  attr :on_confirm, JS, default: %JS{}
  slot :inner_block, required: true

  def rd_confirm_delete(assigns) do
    ~H"""
    <.rd_modal
      id={@id}
      show={@show}
      on_cancel={@on_cancel}
      eyebrow={gettext("Destructive action")}
      title={@title || gettext("Are you sure?")}
    >
      <p>{render_slot(@inner_block)}</p>
      <:footer>
        <.rd_button tone={:brand} variant={:outline} size={:md} phx-click={@on_cancel}>
          {gettext("Cancel")}
        </.rd_button>
        <.rd_button tone={:error} variant={:solid} size={:md} phx-click={@on_confirm}>
          <.icon name="hero-trash" class="w-4 h-4" />
          {@confirm_label}
        </.rd_button>
      </:footer>
    </.rd_modal>
    """
  end

  # ---------- rd_flash_group + rd_locale_switcher (brand restyle of core) ----------

  @doc """
  Brand-styled flash group. Drop-in for the core `<.flash_group>` used at the
  top of the redesign layout. DRAFT — delegates to core; brand restyle pending.
  """
  attr :flash, :map, required: true
  attr :id, :string, default: "rd-flash-group"

  def rd_flash_group(assigns) do
    ~H"""
    <.flash_group flash={@flash} id={@id} />
    """
  end

  @doc """
  Brand-styled locale switcher. Drop-in for the core `<.locale_switcher>`.
  DRAFT — delegates to core; brand restyle pending.
  """
  attr :current_path, :string, default: "/"
  attr :class, :string, default: nil

  def rd_locale_switcher(assigns) do
    ~H"""
    <.locale_switcher current_path={@current_path} class={@class} />
    """
  end
end
