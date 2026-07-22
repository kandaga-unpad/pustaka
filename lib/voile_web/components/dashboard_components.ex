defmodule VoileWeb.DashboardComponents do
  @moduledoc """
  The Voile dashboard component library.

  These components implement the design system documented in
  `plans/dashboard-redesign.md`. They are imported automatically by the
  `live_view_dashboard` / `controller_dashboard` macros in `VoileWeb`, so every
  `/manage/*` LiveView and the metaresource controllers can use them directly.
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
  `<.voile_bottom_nav>` for mobile.
  """
  attr :current_path, :string, default: "/manage"
  attr :user, :map, default: nil

  def voile_sidebar(assigns) do
    ~H"""
    <aside
      id="voile-sidebar"
      class="voile-sidebar hidden lg:flex flex-col"
      phx-hook="Sidebar"
    >
      <div class="voile-sidebar-header">
        <.link navigate="/manage" class="voile-sidebar-brand">
          <img
            src={Voile.Schema.System.get_setting_value("app_logo_url", "/images/v.png")}
            alt={Voile.Schema.System.get_setting_value("app_name", "Voile")}
            class="voile-sidebar-logo"
          />
          <span class="voile-sidebar-brand-text t-h4 text-primary">
            {Voile.Schema.System.get_setting_value("app_name", "Voile")}
          </span>
        </.link>
        <button
          type="button"
          data-voile-sidebar-toggle
          class="voile-sidebar-toggle"
          aria-label={gettext("Collapse sidebar")}
          aria-expanded="true"
        >
          <.icon name="hero-chevron-left" class="voile-sidebar-toggle-icon-collapse w-5 h-5" />
          <.icon name="hero-chevron-right" class="voile-sidebar-toggle-icon-expand w-5 h-5" />
        </button>
      </div>

      <nav class="voile-sidebar-nav flex-1 min-h-0 overflow-y-auto px-3 py-4 space-y-6">
        <.voile_sidebar_section title={gettext("Workspace")}>
          <%= for item <- workspace_items(@current_path) do %>
            <.voile_sidebar_link item={item} current_path={@current_path} />
          <% end %>
        </.voile_sidebar_section>

        <.voile_sidebar_section title={gettext("Collections")}>
          <%= for item <- collection_items(@current_path) do %>
            <.voile_sidebar_link item={item} current_path={@current_path} />
          <% end %>
        </.voile_sidebar_section>

        <.voile_sidebar_section title={gettext("People")}>
          <%= for item <- people_items(@current_path) do %>
            <.voile_sidebar_link item={item} current_path={@current_path} />
          <% end %>
        </.voile_sidebar_section>

        <.voile_sidebar_section title={gettext("System")}>
          <%= for item <- system_items(@current_path) do %>
            <.voile_sidebar_link item={item} current_path={@current_path} />
          <% end %>
        </.voile_sidebar_section>
      </nav>

      <div class="px-3 pb-2">
        <.link
          navigate="/"
          class="flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm text-secondary hover:text-voile-primary hover:bg-tone-brand-soft transition-colors"
          title={gettext("Back to front page")}
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 shrink-0" />
          <span>{gettext("Front page")}</span>
        </.link>
      </div>

      <.voile_sidebar_user_card user={@user} />
    </aside>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp voile_sidebar_section(assigns) do
    ~H"""
    <div class="voile-sidebar-section">
      <p class="voile-sidebar-section-title t-label text-tertiary px-3 mb-2">{@title}</p>
      <div class="space-y-0.5">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :current_path, :string, required: true

  defp voile_sidebar_link(assigns) do
    ~H"""
    <%= if @item[:children] do %>
      <.voile_sidebar_parent item={@item} current_path={@current_path} />
    <% else %>
      <.voile_sidebar_leaf item={@item} current_path={@current_path} />
    <% end %>
    """
  end

  # A leaf nav item — never has children. Active when the current path is the
  # item itself OR a descendant of it (e.g. Catalog stays active on
  # /manage/catalog/collections). Pass `exact: true` for root-level items like
  # Home ("/manage") where descendant matching would highlight them on every
  # /manage/* route.
  attr :item, :map, required: true
  attr :current_path, :string, required: true
  attr :indented, :boolean, default: false

  defp voile_sidebar_leaf(assigns) do
    ~H"""
    <.link
      navigate={@item.path}
      title={@item.label}
      class={[
        "voile-nav-link",
        @indented && "voile-nav-link-child",
        leaf_active?(@current_path, @item) && "voile-nav-link-active"
      ]}
    >
      <.icon name={@item.icon} class="w-5 h-5 shrink-0" />
      <span class="voile-sidebar-label">{@item.label}</span>
      <%= if @item[:shortcut] do %>
        <kbd class="voile-sidebar-shortcut ml-auto t-mono text-tertiary hidden xl:inline">
          {@item.shortcut}
        </kbd>
      <% end %>
    </.link>
    """
  end

  defp leaf_active?(current_path, %{path: path, exact: true}),
    do: current_path == path

  defp leaf_active?(current_path, %{path: path}),
    do: path_active?(current_path, path)

  # A parent nav item with a collapsible submenu of children. The parent itself
  # is only "active" (brand bar) when the current path is the parent exactly;
  # when a child is current the parent stays neutral but auto-expands so the
  # active child is visible. Expansion is route-driven; the chevron toggles it
  # client-side (ephemeral — reverts to the route-based state on navigation).
  attr :item, :map, required: true
  attr :current_path, :string, required: true

  defp voile_sidebar_parent(assigns) do
    %{item: item, current_path: current} = assigns
    exact = current == item.path
    open = exact or String.starts_with?(current, item.path <> "/")

    assigns =
      assigns
      |> assign(:id, nav_id(item.path))
      |> assign(:exact, exact)
      |> assign(:open, open)

    ~H"""
    <div id={@id} class={["voile-nav-group", !@open && "is-collapsed"]}>
      <div class="voile-nav-parent-row">
        <.link
          navigate={@item.path}
          title={@item.label}
          class={["voile-nav-link voile-nav-parent-link flex-1", @exact && "voile-nav-link-active"]}
        >
          <.icon name={@item.icon} class="w-5 h-5 shrink-0" />
          <span class="voile-sidebar-label">{@item.label}</span>
        </.link>
        <button
          type="button"
          class="voile-nav-toggle"
          aria-label={gettext("Toggle submenu")}
          aria-expanded={to_string(@open)}
          phx-click={JS.toggle_class("is-collapsed", to: "#" <> @id)}
        >
          <.icon name="hero-chevron-down" class="voile-nav-toggle-icon w-4 h-4" />
        </button>
      </div>
      <div class="voile-nav-children">
        <%= for child <- @item.children do %>
          <.voile_sidebar_leaf item={child} current_path={@current_path} indented />
        <% end %>
      </div>
    </div>
    """
  end

  # Stable DOM id for a nav path, e.g. "/manage/glam" -> "voile-nav--manage-glam".
  defp nav_id(path) do
    "voile-nav-" <> (path |> String.trim_leading("/") |> String.replace("/", "-"))
  end

  # Current path matches when it is the path exactly or is a descendant of it.
  defp path_active?(current_path, path) do
    current_path == path or String.starts_with?(current_path, path <> "/")
  end

  attr :user, :map, default: nil

  defp voile_sidebar_user_card(assigns) do
    ~H"""
    <div class="voile-sidebar-user-card relative border-t border-subtle p-3">
      <button
        type="button"
        class="voile-sidebar-user-row flex w-full items-center gap-3 px-2 py-2 rounded-lg hover-surface transition-colors"
        phx-click={
          JS.toggle(
            to: "#voile-user-menu",
            display: "block"
          )
        }
        aria-haspopup="true"
        aria-label={gettext("Open user menu")}
      >
        <img
          src={user_avatar(@user)}
          alt={gettext("Avatar")}
          class="voile-sidebar-avatar w-9 h-9 rounded-full object-cover ring-2 ring-subtle"
        />
        <div class="voile-sidebar-user-info min-w-0 flex-1 text-left">
          <p class="text-sm font-semibold text-primary truncate">{user_name(@user)}</p>
          <p class="text-xs text-tertiary truncate">{user_role(@user)}</p>
        </div>
        <.icon name="hero-chevron-up-down" class="w-5 h-5 text-tertiary shrink-0" />
      </button>

      <.voile_user_menu_panel user={@user} menu_id="voile-user-menu" position={:up} />
    </div>
    """
  end

  # Shared dropdown panel (user info + node + profile/logout buttons).
  # `position: :up` opens above the trigger (sidebar, anchored left); `:down`
  # opens below and aligned right (topbar avatar).
  attr :user, :map, default: nil
  attr :menu_id, :string, required: true
  attr :position, :atom, values: [:up, :down], default: :down

  defp voile_user_menu_panel(assigns) do
    ~H"""
    <div
      id={@menu_id}
      class={[
        "hidden absolute z-50 voile-card p-2 shadow-lg",
        if(@position == :up,
          do: "bottom-full left-3 right-3 mb-2",
          else: "top-full right-0 mt-2 w-64"
        )
      ]}
      phx-click-away={JS.hide(to: "#" <> @menu_id)}
    >
      <div class="px-3 py-2 border-b border-subtle">
        <p class="text-sm font-semibold text-primary truncate">{user_name(@user)}</p>
        <p class="text-xs text-tertiary truncate t-mono">@{user_handle(@user)}</p>
        <p :if={user_identifier(@user)} class="text-xs text-tertiary truncate t-mono mt-0.5">
          <.icon name="hero-identification" class="w-3.5 h-3.5 inline -mt-0.5" />
          {user_identifier(@user)}
        </p>
      </div>

      <div class="px-3 py-2 border-b border-subtle">
        <p class="t-label text-tertiary">{gettext("Node")}</p>
        <p class="text-sm text-secondary truncate">
          <.icon name="hero-map-pin" class="w-4 h-4 inline -mt-0.5 text-voile-primary" />
          {user_node_name(@user)}
        </p>
      </div>

      <div class="p-1 flex flex-col gap-1">
        <.link
          navigate="/manage/settings/user_profile"
          class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm text-secondary hover:text-primary hover-surface transition-colors"
        >
          <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
          {gettext("Profile settings")}
        </.link>
        <.link
          href="/users/log_out"
          method="delete"
          class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm text-secondary hover:text-voile-error hover:bg-tone-error-soft transition-colors"
        >
          <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" />
          {gettext("Log out")}
        </.link>
      </div>
    </div>
    """
  end

  defp user_name(%{fullname: name}) when is_binary(name), do: name
  defp user_name(%{username: name}) when is_binary(name), do: name
  defp user_name(_), do: gettext("Guest")

  defp user_handle(%{username: name}) when is_binary(name), do: name
  defp user_handle(_), do: "—"

  defp user_identifier(%{identifier: identifier})
       when not is_nil(identifier),
       do: to_string(identifier)

  defp user_identifier(_), do: nil

  defp user_node_name(%{node: %{name: name}}) when is_binary(name), do: name
  defp user_node_name(_), do: gettext("Unassigned")

  defp user_avatar(%{user_image: url}) when is_binary(url), do: url
  defp user_avatar(_), do: "/images/default_avatar.jpg"

  defp user_role(%{user_type: %{name: name}}), do: name
  defp user_role(_), do: gettext("Staff")

  defp workspace_items(_current_path) do
    [
      # exact: /manage is the root, so descendant matching would highlight Home
      # on every /manage/* route. Only active on the dashboard home itself.
      %{label: gettext("Home"), path: "/manage", icon: "hero-home", shortcut: "G H", exact: true}
    ]
  end

  defp collection_items(_current_path) do
    [
      %{
        label: gettext("Catalog"),
        path: "/manage/catalog",
        icon: "hero-rectangle-stack",
        shortcut: nil,
        children: [
          %{
            label: gettext("Collections"),
            path: "/manage/catalog/collections",
            icon: "hero-archive-box"
          },
          %{label: gettext("Items"), path: "/manage/catalog/items", icon: "hero-cube"},
          %{label: gettext("Labels"), path: "/manage/catalog/labels", icon: "hero-tag"},
          %{
            label: gettext("Asset vault"),
            path: "/manage/catalog/asset-vault",
            icon: "hero-lock-closed"
          },
          %{
            label: gettext("Transfers"),
            path: "/manage/catalog/transfers",
            icon: "hero-arrows-right-left"
          },
          %{
            label: gettext("Stock opname"),
            path: "/manage/catalog/stock_opname",
            icon: "hero-clipboard-document-check"
          }
        ]
      },
      %{
        label: gettext("GLAM"),
        path: "/manage/glam",
        icon: "hero-building-library",
        shortcut: nil,
        children: [
          %{label: gettext("Gallery"), path: "/manage/glam/gallery", icon: "hero-photo"},
          %{label: gettext("Library"), path: "/manage/glam/library", icon: "hero-book-open"},
          %{label: gettext("Archive"), path: "/manage/glam/archive", icon: "hero-archive-box"},
          %{label: gettext("Museum"), path: "/manage/glam/museum", icon: "hero-cube"}
        ]
      }
    ]
  end

  defp people_items(_current_path) do
    [
      %{
        label: gettext("Members"),
        path: "/manage/members",
        icon: "hero-user-group",
        shortcut: nil,
        children: [
          %{label: gettext("Management"), path: "/manage/members/management", icon: "hero-users"},
          %{label: gettext("Reports"), path: "/manage/members/reports", icon: "hero-chart-bar"},
          %{
            label: gettext("Clearance"),
            path: "/manage/members/clearance",
            icon: "hero-document-check"
          }
        ]
      },
      %{
        label: gettext("Visitors"),
        path: "/manage/visitor/statistics",
        icon: "hero-chart-bar",
        shortcut: nil,
        children: [
          %{
            label: gettext("Statistics"),
            path: "/manage/visitor/statistics",
            icon: "hero-chart-pie"
          },
          %{label: gettext("Logs"), path: "/manage/visitor/logs", icon: "hero-list-bullet"},
          %{
            label: gettext("Surveys"),
            path: "/manage/visitor/surveys",
            icon: "hero-clipboard-document-list"
          }
        ]
      }
    ]
  end

  defp system_items(_current_path) do
    [
      %{
        label: gettext("Master data"),
        path: "/manage/master",
        icon: "hero-circle-stack",
        shortcut: nil,
        children: [
          %{label: gettext("Creators"), path: "/manage/master/creators", icon: "hero-user"},
          %{
            label: gettext("Publishers"),
            path: "/manage/master/publishers",
            icon: "hero-building-office-2"
          },
          %{
            label: gettext("Member types"),
            path: "/manage/master/member_types",
            icon: "hero-identification"
          },
          %{
            label: gettext("Frequencies"),
            path: "/manage/master/frequencies",
            icon: "hero-calendar-days"
          },
          %{label: gettext("Locations"), path: "/manage/master/locations", icon: "hero-map-pin"},
          %{label: gettext("Places"), path: "/manage/master/places", icon: "hero-map"},
          %{label: gettext("Topics"), path: "/manage/master/topics", icon: "hero-tag"}
        ]
      },
      %{
        label: gettext("Metaresource"),
        path: "/manage/metaresource",
        icon: "hero-squares-2x2",
        shortcut: nil,
        children: [
          %{
            label: gettext("Vocabularies"),
            path: "/manage/metaresource/metadata_vocabularies",
            icon: "hero-bookmark"
          },
          %{
            label: gettext("Properties"),
            path: "/manage/metaresource/metadata_properties",
            icon: "hero-squares-2x2"
          },
          %{
            label: gettext("Resource class"),
            path: "/manage/metaresource/resource_class",
            icon: "hero-square-3-stack-3d"
          },
          %{
            label: gettext("Resource template"),
            path: "/manage/metaresource/resource_template",
            icon: "hero-document-text"
          },
          %{
            label: gettext("Template properties"),
            path: "/manage/metaresource/resource_templ_property",
            icon: "hero-rectangle-group"
          }
        ]
      },
      %{
        label: gettext("Settings"),
        path: "/manage/settings",
        icon: "hero-cog-6-tooth",
        shortcut: nil,
        children: [
          %{
            label: gettext("Application"),
            path: "/manage/settings/apps",
            icon: "hero-cog-6-tooth"
          },
          %{label: gettext("Profile"), path: "/manage/settings/user_profile", icon: "hero-user"},
          %{
            label: gettext("Permissions"),
            path: "/manage/settings/permissions",
            icon: "hero-key"
          },
          %{
            label: gettext("Nodes"),
            path: "/manage/settings/nodes",
            icon: "hero-building-library"
          },
          %{
            label: gettext("Holidays"),
            path: "/manage/settings/holidays",
            icon: "hero-calendar-days"
          },
          %{
            label: gettext("Reservation notifications"),
            path: "/manage/settings/reservation_notifications",
            icon: "hero-bell"
          },
          %{
            label: gettext("API manager"),
            path: "/manage/settings/api_manager",
            icon: "hero-code-bracket"
          },
          %{label: gettext("Metrics"), path: "/manage/settings/metrics", icon: "hero-chart-bar"}
        ]
      },
      %{
        label: gettext("Plugins"),
        path: "/manage/plugins",
        icon: "hero-puzzle-piece",
        shortcut: nil
      }
    ]
  end

  @doc """
  Renders the mobile bottom navigation (visible only below lg).
  Five slots: Home, Catalog, primary-GLAM, Members, More.
  """
  attr :current_path, :string, default: "/manage"

  def voile_bottom_nav(assigns) do
    ~H"""
    <nav class="voile-bottom-nav fixed bottom-0 inset-x-0 lg:hidden grid grid-cols-5 z-40">
      <.voile_bottom_nav_item
        label={gettext("Home")}
        icon="hero-home"
        path="/manage"
        current_path={@current_path}
      />
      <.voile_bottom_nav_item
        label={gettext("Catalog")}
        icon="hero-rectangle-stack"
        path="/manage/catalog"
        current_path={@current_path}
      />
      <.voile_bottom_nav_item
        label={gettext("GLAM")}
        icon="hero-building-library"
        path="/manage/glam"
        current_path={@current_path}
      />
      <.voile_bottom_nav_item
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

  defp voile_bottom_nav_item(assigns) do
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

  def voile_topbar(assigns) do
    ~H"""
    <header class="voile-topbar px-4 lg:px-8 flex items-center gap-4">
      <div class="flex items-center gap-3 min-w-0 flex-1">
        <.link navigate="/manage" class="lg:hidden shrink-0">
          <img
            src={Voile.Schema.System.get_setting_value("app_logo_url", "/images/v.png")}
            alt={Voile.Schema.System.get_setting_value("app_name", "Voile")}
            class="w-8 h-8"
          />
        </.link>
        <.voile_breadcrumb items={@breadcrumb} current_path={@current_path} />
      </div>

      <div class="flex items-center gap-2">
        <button
          type="button"
          phx-click={JS.dispatch("voile:open-command-palette")}
          class="voile-chip hidden md:inline-flex"
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

        <.link
          navigate="/"
          class="p-2 rounded-lg text-secondary hover:text-voile-primary hover:bg-tone-brand-soft transition-colors"
          title={gettext("Back to front page")}
          aria-label={gettext("Back to front page")}
        >
          <.icon name="hero-globe-alt" class="w-5 h-5" />
        </.link>

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

        <.voile_locale_switcher current_path={@current_path} />

        <div class="hidden sm:block">
          <.theme_toggle />
        </div>

        <div class="relative">
          <button
            type="button"
            class="rounded-full ring-2 ring-subtle hover:ring-voile-primary transition-shadow"
            phx-click={JS.toggle(to: "#voile-topbar-user-menu", display: "block")}
            aria-haspopup="true"
            aria-label={gettext("Open user menu")}
          >
            <img
              src={user_avatar(@user)}
              alt={gettext("Avatar")}
              class="w-8 h-8 rounded-full object-cover"
            />
          </button>
          <.voile_user_menu_panel user={@user} menu_id="voile-topbar-user-menu" position={:down} />
        </div>
      </div>
    </header>
    """
  end

  attr :items, :list, required: true
  attr :current_path, :string, required: true

  defp voile_breadcrumb(assigns) do
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
  Renders the footer shown at the bottom of the scrolling content area.
  Sticks to the viewport bottom when content is short (via flex-1 on the
  content wrapper); scrolls naturally when content is tall.
  """
  attr :app_name, :string, default: "Voile"

  def voile_footer(assigns) do
    assigns = assign(assigns, :year, DateTime.utc_now().year)

    ~H"""
    <footer class="border-t border-subtle px-4 lg:px-8 py-6 mt-auto">
      <div class="max-w-[var(--layout-content-max)] mx-auto">
        <div class="flex flex-col md:flex-row justify-between items-center gap-4">
          <div class="text-sm text-secondary text-center md:text-left">
            <p>
              © {@year} {@app_name}. {gettext("All rights reserved.")}
            </p>
            <p class="mt-1 text-xs text-tertiary">
              {gettext("Powered by")}
              <a
                href="https://github.com/curatorian"
                target="_blank"
                rel="noopener noreferrer"
                class="hover:text-voile-primary transition-colors"
              >
                Curatorian Developer
              </a>
            </p>
          </div>

          <div class="flex items-center gap-6 text-xs text-tertiary">
            <span>
              {gettext("Built with")}
              <span class="text-voile-error mx-0.5">♥</span>
              {gettext("using")}
              <a
                href="https://github.com/curatorian/voile"
                target="_blank"
                rel="noopener noreferrer"
                class="hover:text-voile-primary transition-colors"
              >
                Voile
              </a>
            </span>
          </div>
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

  def voile_page_header(assigns) do
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

      <.voile_stat_card
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

  def voile_stat_card(assigns) do
    ~H"""
    <div class={[
      "voile-card voile-card-hover p-5 flex flex-col gap-3",
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
        <.voile_sparkline points={@sparkline} tone={@tone} />
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

  defp voile_sparkline(assigns) do
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

  def voile_glam_strip(assigns) do
    ~H"""
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 md:gap-4 mb-8">
      <.voile_glam_tile
        type={:gallery}
        count={@stats[:gallery_count] || 0}
        delta={@stats[:gallery_delta] || 0}
        href="/manage/glam/gallery"
      />
      <.voile_glam_tile
        type={:library}
        count={@stats[:library_count] || 0}
        delta={@stats[:library_delta] || 0}
        href="/manage/glam/library"
      />
      <.voile_glam_tile
        type={:archive}
        count={@stats[:archive_count] || 0}
        delta={@stats[:archive_delta] || 0}
        href="/manage/glam/archive"
      />
      <.voile_glam_tile
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
  Renders a single GLAM type tile (the public version used by `voile_glam_strip`).
  Drop-in replacement for the legacy `glam_type_card/1`. DRAFT API — stable.
  """
  def voile_glam_tile(assigns) do
    %{type: type} = assigns

    assigns =
      assigns
      |> assign(:name, glam_type_name(type))
      |> assign(:icon, glam_type_icon(type))
      |> assign(:tone, type)

    ~H"""
    <.link
      navigate={@href}
      class="voile-card voile-card-hover p-5 group relative overflow-hidden block"
    >
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

  def voile_section_card(assigns) do
    ~H"""
    <section class={["voile-card p-5 md:p-6", @class]}>
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

  def voile_metric_row(assigns) do
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

  def voile_activity_feed(assigns) do
    ~H"""
    <div class="space-y-1">
      <%= if @items == [] && @empty_text do %>
        <p class="text-sm text-tertiary text-center py-6">{@empty_text}</p>
      <% else %>
        <%= for item <- @items do %>
          <.voile_activity_item item={item} />
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :item, :map, required: true

  defp voile_activity_item(assigns) do
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

  def voile_command_palette(assigns) do
    ~H"""
    <div id="voile-command-palette" phx-hook="CommandPalette" class="hidden">
      <div data-voile-cmd-backdrop class="voile-cmd-backdrop"></div>
      <div data-voile-cmd-panel class="voile-cmd-panel">
        <div class="flex items-center gap-3 px-4 py-3 border-b border-subtle">
          <.icon name="hero-magnifying-glass" class="w-5 h-5 text-tertiary" />
          <input
            type="text"
            data-voile-cmd-input
            placeholder={gettext("Search or jump to…")}
            autocomplete="off"
            class="flex-1 bg-transparent outline-none text-base text-primary placeholder:text-tertiary"
          />
          <kbd class="t-mono text-xs text-tertiary voile-chip">Esc</kbd>
        </div>

        <div class="overflow-y-auto flex-1 p-2">
          <.voile_cmd_group title={gettext("Quick actions")}>
            <.voile_cmd_item
              icon="hero-plus"
              tone={:brand}
              label={gettext("Start a circulation transaction")}
              href="/manage/glam/library/ledger"
            />
            <.voile_cmd_item
              icon="hero-user-plus"
              tone={:brand}
              label={gettext("Add a new member")}
              href="/manage/members/management/new"
            />
            <.voile_cmd_item
              icon="hero-document-plus"
              tone={:brand}
              label={gettext("Create a new collection")}
              href="/manage/catalog/collections/new"
            />
          </.voile_cmd_group>

          <.voile_cmd_group title={gettext("Navigation")}>
            <.voile_cmd_item
              icon="hero-home"
              tone={:brand}
              label={gettext("Dashboard Home")}
              meta="G H"
              href="/manage"
            />
            <.voile_cmd_item
              icon="hero-rectangle-stack"
              tone={:brand}
              label={gettext("Catalog")}
              href="/manage/catalog"
            />
            <.voile_cmd_item
              icon="hero-building-library"
              tone={:brand}
              label={gettext("GLAM Hub")}
              href="/manage/glam"
            />
            <.voile_cmd_item
              icon="hero-user-group"
              tone={:brand}
              label={gettext("Members")}
              href="/manage/members"
            />
            <.voile_cmd_item
              icon="hero-cog-6-tooth"
              tone={:brand}
              label={gettext("Settings")}
              href="/manage/settings"
            />
          </.voile_cmd_group>

          <div data-voile-cmd-empty class="hidden px-4 py-10 text-center text-tertiary text-sm">
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

  defp voile_cmd_group(assigns) do
    ~H"""
    <div data-voile-cmd-group class="mb-2">
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

  defp voile_cmd_item(assigns) do
    ~H"""
    <.link
      navigate={@href}
      data-voile-cmd-result
      data-voile-cmd-search={@label}
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

  def voile_empty_state(assigns) do
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
  Renders a composite quick-action link: icon chip + label + description +
  trailing arrow. Used in the "Quick actions" card on the dashboard home.
  """
  attr :icon, :string, required: true
  attr :tone, :atom, required: true
  attr :label, :string, required: true
  attr :description, :string, required: true
  attr :href, :string, required: true

  def voile_action_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class="flex items-center gap-3 p-3 rounded-lg border border-subtle hover-surface transition-colors group"
    >
      <div class={"shrink-0 w-9 h-9 rounded-lg flex items-center justify-center #{tone_soft_bg(@tone)}"}>
        <.icon name={@icon} class={"w-5 h-5 #{tone_text(@tone)}"} />
      </div>
      <div class="min-w-0 flex-1">
        <p class="text-sm font-semibold text-primary">{@label}</p>
        <p class="text-xs text-secondary truncate">{@description}</p>
      </div>
      <.icon
        name="hero-arrow-right"
        class="w-4 h-4 text-tertiary group-hover:text-voile-primary transition-colors shrink-0"
      />
    </.link>
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

  def voile_button(assigns) do
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
        {:solid, tone} ->
          "#{tone_solid_bg(tone)} text-white hover:brightness-110"

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
  # real page yet. Review them in this module's source.
  # ===========================================================================

  # ---------- voile_pagination (replaces VoileDashboardComponents.pagination/1, 21 files) ----------

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

  def voile_pagination(assigns) do
    # Don't render pagination when there's only one page (or none).
    # Hides the nav entirely on empty or single-page lists.
    if assigns.total_pages <= 1 do
      ~H""
    else
      assigns = assign(assigns, :range, voile_pagination_range(assigns.page, assigns.total_pages))

      ~H"""
      <nav class="flex items-center gap-1" aria-label={gettext("Pagination")}>
        <.voile_page_button
          page={@page - 1}
          disabled={@page <= 1}
          path={@path}
          event={@event}
          params={@params}
        >
          <.icon name="hero-chevron-left" class="w-4 h-4" />
        </.voile_page_button>

        <%= for item <- @range do %>
          <%= if item == :ellipsis do %>
            <span class="px-2 text-tertiary t-mono">…</span>
          <% else %>
            <.voile_page_button
              page={item}
              active={item == @page}
              path={@path}
              event={@event}
              params={@params}
            >
              {item}
            </.voile_page_button>
          <% end %>
        <% end %>

        <.voile_page_button
          page={@page + 1}
          disabled={@page >= @total_pages}
          path={@path}
          event={@event}
          params={@params}
        >
          <.icon name="hero-chevron-right" class="w-4 h-4" />
        </.voile_page_button>
      </nav>
      """
    end
  end

  attr :page, :integer, required: true
  attr :active, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :path, :string, default: nil
  attr :event, :string, default: "paginate"
  attr :params, :map, default: %{}
  slot :inner_block, required: true

  defp voile_page_button(assigns) do
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
          patch={voile_page_url(@path, @page, @params)}
          class={voile_page_class(@active)}
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
          class={voile_page_class(@active)}
          aria-current={@active && "page"}
        >
          {render_slot(@inner_block)}
        </button>
      <% end %>
    <% end %>
    """
  end

  defp voile_page_class(true),
    do:
      "inline-flex items-center justify-center min-w-9 h-9 px-2 rounded-lg bg-voile-primary text-white font-semibold"

  defp voile_page_class(_),
    do:
      "inline-flex items-center justify-center min-w-9 h-9 px-2 rounded-lg text-secondary hover:text-primary hover:bg-tone-brand-soft transition-colors"

  defp voile_page_url(path, page, params) do
    query = params |> Map.put("page", page) |> URI.encode_query()
    "#{path}?#{query}"
  end

  defp voile_pagination_range(_page, total) when total <= 7, do: Enum.to_list(1..total)

  defp voile_pagination_range(page, total) do
    cond do
      page <= 3 -> [1, 2, 3, 4, :ellipsis, total]
      page >= total - 2 -> [1, :ellipsis, total - 3, total - 2, total - 1, total]
      true -> [1, :ellipsis, page - 1, page, page + 1, :ellipsis, total]
    end
  end

  # ---------- voile_settings_shell (replaces dashboard_settings_sidebar/plugin_settings_sidebar/side_bar_dashboard) ----------

  @doc """
  Two-pane "sub-nav + content" shell for settings, plugins, master-data and
  metaresource pages. Replaces `dashboard_settings_sidebar/1`,
  `plugin_settings_sidebar/1`, and the inline master/metaresource sidebars.

  `items` is a list of maps: `%{label: "...", path: "/...", icon: "hero-..."}`
  (icon optional). On desktop it renders a sticky left card; on mobile it
  collapses to a horizontal chip strip so it doesn't push the form below the fold.
  Use `voile_settings_nav_items/0` for the standard settings menu.
  """
  attr :title, :string, default: nil
  attr :items, :list, required: true
  attr :current_path, :string, default: nil
  slot :inner_block, required: true

  def voile_settings_shell(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-[220px_1fr] gap-6">
      <.voile_settings_nav title={@title} items={@items} current_path={@current_path} />
      <div class="min-w-0">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  The sub-navigation list used inside `voile_settings_shell`, or standalone where a
  page keeps its own layout but still wants the settings/master/plugin nav
  (e.g. a deep edit page that replaced `<.dashboard_settings_sidebar>`).
  """
  attr :title, :string, default: nil
  attr :items, :list, required: true
  attr :current_path, :string, default: nil

  def voile_settings_nav(assigns) do
    ~H"""
    <aside class="lg:voile-card lg:p-3 lg:h-fit lg:sticky lg:top-20">
      <%= if @title do %>
        <p class="t-label text-tertiary px-3 mb-2 hidden lg:block">{@title}</p>
      <% end %>
      <nav class="flex lg:flex-col gap-1 overflow-x-auto lg:overflow-visible pb-1 lg:pb-0">
        <%= for item <- @items do %>
          <.link
            navigate={item.path}
            class={[
              "flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm transition-colors whitespace-nowrap shrink-0 lg:w-full",
              voile_settings_active?(@current_path, item) &&
                "bg-tone-brand-soft text-voile-primary font-semibold",
              !voile_settings_active?(@current_path, item) &&
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
    """
  end

  defp voile_settings_active?(current_path, %{path: path}) do
    current = current_path || ""
    current == path or String.starts_with?(current, path <> "/")
  end

  @doc """
  The standard settings sub-navigation menu shared by every `/manage/settings/*`
  page. Pass to `<.voile_settings_shell items={voile_settings_nav_items()} ...>`.
  """
  def voile_settings_nav_items do
    [
      %{label: gettext("Application"), path: "/manage/settings/apps", icon: "hero-cog-6-tooth"},
      %{label: gettext("Profile"), path: "/manage/settings/user_profile", icon: "hero-user"},
      %{label: gettext("Permissions"), path: "/manage/settings/permissions", icon: "hero-key"},
      %{label: gettext("Nodes"), path: "/manage/settings/nodes", icon: "hero-building-library"},
      %{
        label: gettext("Holidays"),
        path: "/manage/settings/holidays",
        icon: "hero-calendar-days"
      },
      %{
        label: gettext("Reservation notifications"),
        path: "/manage/settings/reservation_notifications",
        icon: "hero-bell"
      },
      %{
        label: gettext("API manager"),
        path: "/manage/settings/api_manager",
        icon: "hero-code-bracket"
      },
      %{label: gettext("Metrics"), path: "/manage/settings/metrics", icon: "hero-chart-bar"}
    ]
  end

  @doc """
  The master-data sub-navigation menu shared by every `/manage/master/*` page.
  Pass to `<.voile_settings_shell items={voile_master_nav_items()} ...>`.
  """
  def voile_master_nav_items do
    [
      %{label: gettext("Creators"), path: "/manage/master/creators", icon: "hero-user"},
      %{
        label: gettext("Publishers"),
        path: "/manage/master/publishers",
        icon: "hero-building-office-2"
      },
      %{
        label: gettext("Member types"),
        path: "/manage/master/member_types",
        icon: "hero-identification"
      },
      %{
        label: gettext("Frequencies"),
        path: "/manage/master/frequencies",
        icon: "hero-calendar-days"
      },
      %{label: gettext("Locations"), path: "/manage/master/locations", icon: "hero-map-pin"},
      %{label: gettext("Places"), path: "/manage/master/places", icon: "hero-map"},
      %{label: gettext("Topics"), path: "/manage/master/topics", icon: "hero-tag"}
    ]
  end

  @doc """
  The metaresource sub-navigation menu shared by `/manage/metaresource/*` pages.
  """
  def voile_metaresource_nav_items do
    [
      %{
        label: gettext("Vocabularies"),
        path: "/manage/metaresource/metadata_vocabularies",
        icon: "hero-bookmark"
      },
      %{
        label: gettext("Properties"),
        path: "/manage/metaresource/metadata_properties",
        icon: "hero-squares-2x2"
      },
      %{
        label: gettext("Resource class"),
        path: "/manage/metaresource/resource_class",
        icon: "hero-square-3-stack-3d"
      },
      %{
        label: gettext("Resource template"),
        path: "/manage/metaresource/resource_template",
        icon: "hero-document-text"
      },
      %{
        label: gettext("Template properties"),
        path: "/manage/metaresource/resource_templ_property",
        icon: "hero-rectangle-group"
      }
    ]
  end

  # ---------- voile_table (replaces CoreComponents.table) ----------

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

  def voile_table(assigns) do
    ~H"""
    <div class="voile-card overflow-hidden">
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

  # ---------- voile_input (brand restyle of CoreComponents.input) ----------

  @doc """
  Brand restyle wrapper around the core `<.input>`. Forwards the common attrs
  and adds the `voile-input` class so the redesign focus ring (2px voile-primary,
  2px offset) applies once the CSS lands. DRAFT — focus-ring CSS pending.
  """
  attr :field, Phoenix.HTML.FormField, default: nil
  attr :name, :any
  attr :value, :any
  attr :type, :string, default: "text"
  attr :label, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  def voile_input(assigns) do
    assigns =
      assign(
        assigns,
        :voile_class,
        ["voile-input", assigns[:class]] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
      )

    ~H"""
    <.input
      field={@field}
      name={@name}
      value={@value}
      type={@type}
      label={@label}
      class={@voile_class}
      {@rest}
    />
    """
  end

  # ---------- voile_search_insights (replaces search_stats_widget/1) ----------

  @doc """
  Brand-styled search-insights widget. Replaces `search_stats_widget/1`.
  `stats` shape: `%{total_searches: n, popular_queries: [{q, count}], recent_activity: [...]}`.
  DRAFT — not yet adopted.
  """
  attr :stats, :map, default: %{}
  attr :action_path, :string, default: nil

  def voile_search_insights(assigns) do
    stats = assigns.stats

    assigns =
      assigns
      |> assign(:total, stats[:total_searches] || 0)
      |> assign(:popular, stats[:popular_queries] || [])

    ~H"""
    <div class="voile-card p-5">
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
            <span class="voile-chip">
              {query}<span class="text-tertiary t-mono text-[10px]">{count}</span>
            </span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ---------- voile_modal + voile_confirm_delete (replaces collection_modal/delete_modal) ----------

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

  def voile_modal(assigns) do
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

  def voile_confirm_delete(assigns) do
    ~H"""
    <.voile_modal
      id={@id}
      show={@show}
      on_cancel={@on_cancel}
      eyebrow={gettext("Destructive action")}
      title={@title || gettext("Are you sure?")}
    >
      <p>{render_slot(@inner_block)}</p>
      <:footer>
        <.voile_button tone={:brand} variant={:outline} size={:md} phx-click={@on_cancel}>
          {gettext("Cancel")}
        </.voile_button>
        <.voile_button tone={:error} variant={:solid} size={:md} phx-click={@on_confirm}>
          <.icon name="hero-trash" class="w-4 h-4" />
          {@confirm_label}
        </.voile_button>
      </:footer>
    </.voile_modal>
    """
  end

  # ---------- voile_flash_group + voile_locale_switcher (brand restyle of core) ----------

  @doc """
  Brand-styled flash group. Drop-in for the core `<.flash_group>` used at the
  top of the redesign layout. DRAFT — delegates to core; brand restyle pending.
  """
  attr :flash, :map, required: true
  attr :id, :string, default: "voile-flash-group"

  def voile_flash_group(assigns) do
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

  def voile_locale_switcher(assigns) do
    ~H"""
    <.locale_switcher current_path={@current_path} class={@class} />
    """
  end
end
