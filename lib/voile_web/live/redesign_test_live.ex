defmodule VoileWeb.RedesignTestLive do
  @moduledoc """
  Visual showcase of the Voile dashboard redesign (v2) design system.

  A tabbed "kitchen sink" for reviewing every token, primitive, and layout
  defined by the redesign. Used to evaluate the new visual language before
  migrating `/manage/*` pages onto it.

  Data is static demo data — no database queries for content — so the page is
  fast and the design can be judged independently of seed state. The brand
  palette section DOES read live colors from `SystemSetting` so reviewers see
  exactly what the super-admin configured at `/manage/settings/apps`.

  Layout: `VoileWeb.Layouts.redesign` (sidebar + topbar + bottom nav + lite footer).
  Route: `/manage/redesign-test`
  """

  use VoileWeb, :live_view_redesign

  alias Voile.Schema.System

  @tabs [:foundations, :components, :layouts, :patterns, :legacy]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:page_title, gettext("Redesign · Design System"))
      |> assign(:tab, :foundations)
      |> assign(:breadcrumb, [
        %{label: gettext("Manage"), path: "/manage"},
        %{label: gettext("Redesign"), path: nil}
      ])
      |> assign(:notification_count, 3)
      |> assign(:greeting, build_greeting(user))
      |> assign(:brand_colors, read_brand_colors())
      |> assign(:glam_stats, demo_glam_stats())
      |> assign(:today_stats, demo_today_stats())
      |> assign(:attention_items, demo_attention_items())
      |> assign(:member_metrics, demo_member_metrics())
      |> assign(:catalog_metrics, demo_catalog_metrics())
      |> assign(:legacy_glam_stats, demo_legacy_glam_stats())
      |> assign(:legacy_collections, demo_legacy_collections())
      |> assign(:legacy_members, demo_legacy_members())

    {:ok, socket}
  end

  @impl true
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    with {:ok, atom} <- safe_to_atom(tab),
         true <- atom in @tabs do
      {:noreply, assign(socket, :tab, atom)}
    else
      _ -> {:noreply, socket}
    end
  end

  # The legacy dashboard_search_widget fires "search" on phx-change. Since the
  # showcase only displays it (no real search context), swallow the event so
  # interacting with the demo does not crash the LiveView.
  def handle_event("search", _params, socket), do: {:noreply, socket}

  defp safe_to_atom(tab) when is_binary(tab) do
    {:ok, String.to_existing_atom(tab)}
  rescue
    ArgumentError -> :error
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.rd_page_header
      eyebrow={gettext("Design system · v2")}
      title={gettext("Voile Dashboard Redesign")}
      description={
        gettext(
          "A live showcase of the new design tokens, components, and layouts. Brand colors below reflect your live /manage/settings/apps configuration."
        )
      }
      icon="hero-sparkles"
      tone={:brand}
    />

    <.tab_bar current={@tab} />

    <%= case @tab do %>
      <% :foundations -> %>
        <.render_foundations brand_colors={@brand_colors} />
      <% :components -> %>
        <.render_components />
      <% :layouts -> %>
        <.render_layouts
          greeting={@greeting}
          glam_stats={@glam_stats}
          today_stats={@today_stats}
          attention_items={@attention_items}
          member_metrics={@member_metrics}
          catalog_metrics={@catalog_metrics}
        />
      <% :patterns -> %>
        <.render_patterns />
      <% :legacy -> %>
        <.render_legacy
          glam_stats={@legacy_glam_stats}
          collections={@legacy_collections}
          members={@legacy_members}
        />
    <% end %>
    """
  end

  # ----------------------------------------------------------------------------
  # Tab bar
  # ----------------------------------------------------------------------------

  attr :current, :atom, required: true

  defp tab_bar(assigns) do
    ~H"""
    <div class="mb-8 sticky top-0 z-10 -mx-4 px-4 py-3 lg:-mx-8 lg:px-8 surface-page border-b border-subtle">
      <div class="inline-flex flex-wrap p-1 rounded-xl border border-subtle surface-card gap-1">
        <%= for tab <- tabs() do %>
          <button
            type="button"
            phx-click="select_tab"
            phx-value-tab={tab}
            class={[
              "px-4 py-2 rounded-lg text-sm font-medium transition-colors",
              @current == tab && "bg-voile-primary text-white shadow-sm",
              @current != tab && "text-secondary hover:text-primary hover:bg-tone-brand-soft"
            ]}
          >
            {tab_label(tab)}
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp tab_label(:foundations), do: gettext("Foundations")
  defp tab_label(:components), do: gettext("Components")
  defp tab_label(:layouts), do: gettext("Layouts")
  defp tab_label(:patterns), do: gettext("Patterns")
  defp tab_label(:legacy), do: gettext("Legacy")

  defp tabs, do: @tabs

  # ----------------------------------------------------------------------------
  # TAB: Foundations
  # ----------------------------------------------------------------------------

  attr :brand_colors, :list, required: true

  defp render_foundations(assigns) do
    ~H"""
    <.showcase_section
      eyebrow={gettext("Color · 4.2.1")}
      title={gettext("Brand palette")}
      description={
        gettext(
          "These six tokens drive the whole system. They live in SystemSetting and are editable at /manage/settings/apps. The swatches below show the live, currently-applied values."
        )
      }
    >
      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
        <%= for color <- @brand_colors do %>
          <.swatch
            name={color.name}
            token={color.token}
            bg={color.value}
            value={color.value}
            badge={color.source}
          />
        <% end %>
      </div>
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("Color · 4.2.2")}
      title={gettext("GLAM type colors")}
      description={
        gettext(
          "First-class semantic tokens. A library card is always blue, an archive card is always amber — color plus icon plus label, never color alone."
        )
      }
    >
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <.swatch
          name="Gallery"
          token="--color-glam-gallery"
          bg="var(--color-glam-gallery)"
          value="rose"
        />
        <.swatch
          name="Library"
          token="--color-glam-library"
          bg="var(--color-glam-library)"
          value="blue"
        />
        <.swatch
          name="Archive"
          token="--color-glam-archive"
          bg="var(--color-glam-archive)"
          value="amber"
        />
        <.swatch
          name="Museum"
          token="--color-glam-museum"
          bg="var(--color-glam-museum)"
          value="emerald"
        />
      </div>
      <p class="t-label text-tertiary mt-4 mb-2">{gettext("Soft variants (badges, icon chips)")}</p>
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <.swatch
          name="Gallery soft"
          token="--color-glam-gallery-soft"
          bg="var(--color-glam-gallery-soft)"
          value="12% wash"
        />
        <.swatch
          name="Library soft"
          token="--color-glam-library-soft"
          bg="var(--color-glam-library-soft)"
          value="12% wash"
        />
        <.swatch
          name="Archive soft"
          token="--color-glam-archive-soft"
          bg="var(--color-glam-archive-soft)"
          value="12% wash"
        />
        <.swatch
          name="Museum soft"
          token="--color-glam-museum-soft"
          bg="var(--color-glam-museum-soft)"
          value="12% wash"
        />
      </div>
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("Color · 4.2.4")}
      title={gettext("Functional colors")}
      description={
        gettext(
          "Status is always color + icon + text. These tones back badges, stat-card icons, and inline messages."
        )
      }
    >
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <.swatch name="Info" token="--color-voile-info" bg="var(--color-voile-info)" value="tips" />
        <.swatch
          name="Success"
          token="--color-voile-success"
          bg="var(--color-voile-success)"
          value="confirmed"
        />
        <.swatch
          name="Warning"
          token="--color-voile-warning"
          bg="var(--color-voile-warning)"
          value="pending"
        />
        <.swatch
          name="Error"
          token="--color-voile-error"
          bg="var(--color-voile-error)"
          value="overdue"
        />
      </div>
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("Color · 4.2.3")}
      title={gettext("Surface scale")}
      description={
        gettext(
          "A five-step scale per mode, each step faintly amethyst-tinted so even pure white feels Voile. Used via .surface-page / .surface-card / .surface-raised / .surface-overlay / .border-subtle."
        )
      }
    >
      <p class="t-label text-tertiary mb-2">{gettext("Light")}</p>
      <div class="grid grid-cols-5 gap-2 mb-4">
        <.swatch
          name="1 · page"
          token="--color-surface-1-light"
          bg="var(--color-surface-1-light)"
          value="99.5%"
        />
        <.swatch
          name="2 · card"
          token="--color-surface-2-light"
          bg="var(--color-surface-2-light)"
          value="98%"
        />
        <.swatch
          name="3 · raised"
          token="--color-surface-3-light"
          bg="var(--color-surface-3-light)"
          value="96%"
        />
        <.swatch
          name="4 · border"
          token="--color-surface-4-light"
          bg="var(--color-surface-4-light)"
          value="94%"
        />
        <.swatch
          name="5 · muted"
          token="--color-surface-5-light"
          bg="var(--color-surface-5-light)"
          value="90%"
        />
      </div>
      <p class="t-label text-tertiary mb-2">{gettext("Dark")}</p>
      <div class="grid grid-cols-5 gap-2">
        <.swatch
          name="1 · page"
          token="--color-surface-1-dark"
          bg="var(--color-surface-1-dark)"
          value="15%"
        />
        <.swatch
          name="2 · card"
          token="--color-surface-2-dark"
          bg="var(--color-surface-2-dark)"
          value="18%"
        />
        <.swatch
          name="3 · raised"
          token="--color-surface-3-dark"
          bg="var(--color-surface-3-dark)"
          value="22%"
        />
        <.swatch
          name="4 · border"
          token="--color-surface-4-dark"
          bg="var(--color-surface-4-dark)"
          value="28%"
        />
        <.swatch
          name="5 · muted"
          token="--color-surface-5-dark"
          bg="var(--color-surface-5-dark)"
          value="35%"
        />
      </div>
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("Type · 4.3")}
      title={gettext("Typography")}
      description={
        gettext(
          "Kanit for headings, Noto Sans for body, JetBrains Mono for codes and IDs. No global h1–h6 styles — use these named primitives instead."
        )
      }
    >
      <div class="divide-y divide-[color:var(--color-surface-4-light)] dark:divide-[color:var(--color-surface-4-dark)]">
        <.specimen
          class_name="t-display"
          sample={gettext("The calm confidence of a well-run institution")}
          meta="t-display · 48/56 · Kanit 600"
        />
        <.specimen
          class_name="t-h1"
          sample={gettext("Today's circulation overview")}
          meta="t-h1 · 32/40 · Kanit 600"
        />
        <.specimen
          class_name="t-h2"
          sample={gettext("Attention required")}
          meta="t-h2 · 24/32 · Kanit 600"
        />
        <.specimen
          class_name="t-h3"
          sample={gettext("Member overview")}
          meta="t-h3 · 20/28 · Kanit 600"
        />
        <.specimen
          class_name="t-h4"
          sample={gettext("Quick actions")}
          meta="t-h4 · 16/24 · Kanit 600"
        />
        <.specimen
          class_name="t-label"
          sample={gettext("Library · Overview")}
          meta="t-label · 12/16 · Noto 600 · uppercase"
        />
        <.specimen
          class_name="t-mono"
          sample="INV-2026-04821"
          meta="t-mono · 13/20 · JetBrains 500"
        />
        <.specimen class_name="t-stat" sample="1,204" meta="t-stat · 36/42 · Kanit 700 · tabular" />
      </div>
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("Tokens · 5")}
      title={gettext("Elevation, motion & layout")}
      description={gettext("The invisible primitives that make the system feel cohesive.")}
    >
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <.rd_section_card title={gettext("Elevation")} icon="hero-square-3-stack-3d" tone={:brand}>
          <div class="space-y-3">
            <%= for {name, shadow} <- [
              {"shadow-xs", "var(--shadow-xs)"},
              {"shadow-sm", "var(--shadow-sm)"},
              {"shadow-md", "var(--shadow-md)"},
              {"shadow-lg", "var(--shadow-lg)"},
              {"shadow-xl", "var(--shadow-xl)"},
              {"shadow-brand", "var(--shadow-brand)"}
            ] do %>
              <div class="flex items-center gap-3">
                <div
                  class="w-16 h-10 rounded-lg surface-card"
                  style={"box-shadow: #{shadow}"}
                >
                </div>
                <span class="t-mono text-secondary text-xs">{name}</span>
              </div>
            <% end %>
          </div>
        </.rd_section_card>

        <.rd_section_card title={gettext("Motion")} icon="hero-bolt" tone={:warning}>
          <div class="space-y-2">
            <%= for {name, ms} <- [
              {"--ease-immediate", "120ms"},
              {"--ease-smooth", "180ms"},
              {"--ease-enter", "220ms"},
              {"--ease-exit", "160ms"},
              {"--ease-emphasis", "400ms"}
            ] do %>
              <div class="flex items-center justify-between text-sm py-1">
                <span class="t-mono text-secondary text-xs">{name}</span>
                <span class="t-mono text-tertiary text-xs">{ms}</span>
              </div>
            <% end %>
            <p class="text-xs text-tertiary mt-2">
              {gettext("All motion honors prefers-reduced-motion.")}
            </p>
          </div>
        </.rd_section_card>

        <.rd_section_card title={gettext("Layout")} icon="hero-rectangle-group" tone={:glam_library}>
          <div class="space-y-2">
            <%= for {name, val} <- [
              {"--layout-sidebar-w", "264px"},
              {"--layout-sidebar-collapsed-w", "80px"},
              {"--layout-content-max", "1440px"},
              {"--layout-gutter", "24px"},
              {"--layout-header-h", "64px"},
              {"--layout-bottom-nav-h", "64px"}
            ] do %>
              <div class="flex items-center justify-between text-sm py-1">
                <span class="t-mono text-secondary text-xs">{name}</span>
                <span class="t-mono text-tertiary text-xs">{val}</span>
              </div>
            <% end %>
          </div>
        </.rd_section_card>
      </div>
    </.showcase_section>
    """
  end

  # ----------------------------------------------------------------------------
  # TAB: Components
  # ----------------------------------------------------------------------------

  defp render_components(assigns) do
    ~H"""
    <.showcase_section
      eyebrow={gettext("Primitive · 7.1")}
      title={gettext("Buttons")}
      description={
        gettext(
          "rd_button in every tone × variant × size. The solid brand button is the primary action on a page."
        )
      }
    >
      <div class="space-y-4">
        <div>
          <p class="t-label text-tertiary mb-2">{gettext("Variants (brand tone)")}</p>
          <div class="flex flex-wrap items-center gap-2">
            <.rd_button tone={:brand} variant={:solid} size={:md}>
              <.icon name="hero-bolt" class="w-4 h-4" /> {gettext("Solid")}
            </.rd_button>
            <.rd_button tone={:brand} variant={:soft} size={:md}>
              <.icon name="hero-bolt" class="w-4 h-4" /> {gettext("Soft")}
            </.rd_button>
            <.rd_button tone={:brand} variant={:outline} size={:md}>
              <.icon name="hero-bolt" class="w-4 h-4" /> {gettext("Outline")}
            </.rd_button>
          </div>
        </div>
        <div>
          <p class="t-label text-tertiary mb-2">{gettext("Sizes (solid brand)")}</p>
          <div class="flex flex-wrap items-center gap-2">
            <.rd_button tone={:brand} variant={:solid} size={:sm}>{gettext("Small")}</.rd_button>
            <.rd_button tone={:brand} variant={:solid} size={:md}>{gettext("Medium")}</.rd_button>
            <.rd_button tone={:brand} variant={:solid} size={:lg}>{gettext("Large")}</.rd_button>
          </div>
        </div>
        <div>
          <p class="t-label text-tertiary mb-2">{gettext("Tones (solid)")}</p>
          <div class="flex flex-wrap items-center gap-2">
            <.rd_button tone={:brand} variant={:solid}>{gettext("Brand")}</.rd_button>
            <.rd_button tone={:info} variant={:solid}>{gettext("Info")}</.rd_button>
            <.rd_button tone={:success} variant={:solid}>{gettext("Success")}</.rd_button>
            <.rd_button tone={:warning} variant={:solid}>{gettext("Warning")}</.rd_button>
            <.rd_button tone={:error} variant={:solid}>{gettext("Error")}</.rd_button>
            <.rd_button tone={:glam_library} variant={:solid}>{gettext("Library")}</.rd_button>
            <.rd_button tone={:glam_archive} variant={:solid}>{gettext("Archive")}</.rd_button>
          </div>
        </div>
      </div>
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("Primitive · 7.1")}
      title={gettext("Stat cards")}
      description={
        gettext(
          "rd_stat_card — brand-aware, with optional trend arrow and sparkline. The loading state renders a shimmer skeleton."
        )
      }
    >
      <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3 md:gap-4">
        <.rd_stat_card
          label={gettext("Active loans")}
          value={247}
          icon="hero-book-open"
          tone={:success}
          trend={%{direction: :up, value: "+12", period: gettext("today")}}
          sparkline={[180, 195, 210, 205, 220, 235, 247]}
        />
        <.rd_stat_card
          label={gettext("Due today")}
          value={18}
          icon="hero-clock"
          tone={:warning}
          trend={%{direction: :flat, value: "0", period: gettext("vs yesterday")}}
        />
        <.rd_stat_card
          label={gettext("Overdue")}
          value={7}
          icon="hero-exclamation-triangle"
          tone={:error}
          trend={%{direction: :down, value: "-2", period: gettext("vs yesterday")}}
          sparkline={[12, 11, 10, 9, 8, 9, 7]}
        />
        <.rd_stat_card
          label={gettext("Loading…")}
          value={nil}
          icon="hero-arrow-path"
          tone={:brand}
          loading={true}
        />
      </div>
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("Primitive · 7.1")}
      title={gettext("GLAM strip")}
      description={
        gettext(
          "The centerpiece of the dashboard home. Four tiles, fully brand-tinted, one per GLAM type. Numbers come from glam_stats."
        )
      }
    >
      <.rd_glam_strip stats={demo_glam_stats()} />
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("Primitive · 7.1")}
      title={gettext("Section card, metric rows & activity feed")}
      description={
        gettext(
          "The composition primitives. metric_row shows label + value + an optional proportional bar; activity_feed unifies every recent-items list."
        )
      }
    >
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <.rd_section_card
          title={gettext("Member overview")}
          icon="hero-user-group"
          tone={:glam_library}
        >
          <.rd_metric_row label={gettext("Active members")} value={1024} total={1204} tone={:success} />
          <.rd_metric_row label={gettext("Suspended")} value={12} total={1204} tone={:error} />
          <.rd_metric_row
            label={gettext("Expiring in 30 days")}
            value={47}
            total={1204}
            tone={:warning}
          />
          <.rd_metric_row label={gettext("Expired")} value={93} total={1204} tone={:brand} />
        </.rd_section_card>

        <.rd_section_card title={gettext("Attention required")} icon="hero-bell-alert" tone={:error}>
          <.rd_activity_feed
            items={Enum.take(demo_attention_items(), 3)}
            empty_text={gettext("Nothing needs your attention right now.")}
          />
        </.rd_section_card>
      </div>
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("Primitive · 7.1")}
      title={gettext("Empty state")}
      description={
        gettext(
          "Warm, helpful, never blamey. Always pairs an icon-chip with a title, description, and optional actions."
        )
      }
    >
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <.rd_section_card>
          <.rd_empty_state
            icon="hero-archive-box"
            title={gettext("No collections yet")}
            description={gettext("Create your first catalog collection to get started.")}
            tone={:brand}
          >
            <:actions>
              <.rd_button tone={:brand} variant={:solid} size={:sm}>
                <.icon name="hero-plus" class="w-4 h-4" /> {gettext("New collection")}
              </.rd_button>
            </:actions>
          </.rd_empty_state>
        </.rd_section_card>
        <.rd_section_card>
          <.rd_empty_state
            icon="hero-check-badge"
            title={gettext("All caught up")}
            description={gettext("No overdue loans today — nicely done.")}
            tone={:success}
          />
        </.rd_section_card>
        <.rd_section_card>
          <.rd_empty_state
            icon="hero-magnifying-glass"
            title={gettext("No results found")}
            description={gettext("Try a different keyword or clear your filters.")}
            tone={:info}
          />
        </.rd_section_card>
      </div>
    </.showcase_section>
    """
  end

  # ----------------------------------------------------------------------------
  # TAB: Layouts
  # ----------------------------------------------------------------------------

  attr :greeting, :string, required: true
  attr :glam_stats, :map, required: true
  attr :today_stats, :map, required: true
  attr :attention_items, :list, required: true
  attr :member_metrics, :map, required: true
  attr :catalog_metrics, :map, required: true

  defp render_layouts(assigns) do
    ~H"""
    <.showcase_section
      eyebrow={gettext("Page · 8.1")}
      title={gettext("Dashboard home (librarian role)")}
      description={
        gettext(
          "A realistic composition of the primitives into the new /manage home. Role-aware: a librarian sees circulation widgets; an archivist sees intake and transfers."
        )
      }
    >
      <div class="rounded-2xl border border-subtle overflow-hidden">
        <div class="surface-page p-4 md:p-6">
          <.rd_page_header
            eyebrow={gettext("Library · Overview")}
            title={@greeting}
            description={
              gettext(
                "You have 3 reservations to confirm and 2 overdue loans. Press ⌘K anywhere to jump to a page."
              )
            }
            icon="hero-sparkles"
            tone={:brand}
          >
            <:actions>
              <.rd_button href="/manage/glam/library/ledger" tone={:brand} variant={:solid} size={:md}>
                <.icon name="hero-bolt" class="w-4 h-4" />
                {gettext("Start transaction")}
              </.rd_button>
              <.rd_button
                href="/manage/members/management/new"
                tone={:brand}
                variant={:outline}
                size={:md}
              >
                <.icon name="hero-user-plus" class="w-4 h-4" />
                {gettext("Add member")}
              </.rd_button>
            </:actions>
          </.rd_page_header>

          <.rd_glam_strip stats={@glam_stats} />

          <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3 md:gap-4 mb-6">
            <.rd_stat_card
              label={gettext("Active loans")}
              value={@today_stats.active_loans}
              icon="hero-book-open"
              tone={:success}
              trend={%{direction: :up, value: "+12", period: gettext("today")}}
              sparkline={[180, 195, 210, 205, 220, 235, 247]}
            />
            <.rd_stat_card
              label={gettext("Due today")}
              value={@today_stats.due_today}
              icon="hero-clock"
              tone={:warning}
              trend={%{direction: :up, value: "+3", period: gettext("vs yesterday")}}
              sparkline={[8, 12, 9, 14, 11, 16, 18]}
            />
            <.rd_stat_card
              label={gettext("Overdue")}
              value={@today_stats.overdue}
              icon="hero-exclamation-triangle"
              tone={:error}
              trend={%{direction: :down, value: "-2", period: gettext("vs yesterday")}}
              sparkline={[12, 11, 10, 9, 8, 9, 7]}
            />
            <.rd_stat_card
              label={gettext("Reservations")}
              value={@today_stats.reservations}
              icon="hero-bookmark"
              tone={:info}
              trend={%{direction: :up, value: "+5", period: gettext("today")}}
              sparkline={[4, 6, 5, 7, 9, 10, 12]}
            />
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-6">
            <.rd_section_card
              title={gettext("Attention required")}
              icon="hero-bell-alert"
              tone={:error}
              action_label={gettext("View all")}
              action_path="/manage/glam/library/circulation"
              class="lg:col-span-2"
            >
              <.rd_activity_feed
                items={@attention_items}
                empty_text={gettext("Nothing needs your attention right now.")}
              />
            </.rd_section_card>

            <.rd_section_card title={gettext("Quick actions")} icon="hero-bolt" tone={:brand}>
              <div class="grid grid-cols-1 gap-2">
                <.rd_action_link
                  icon="hero-banknotes"
                  tone={:brand}
                  label={gettext("Start transaction")}
                  description={gettext("Checkout, return, or renew an item")}
                  href="/manage/glam/library/ledger"
                />
                <.rd_action_link
                  icon="hero-user-plus"
                  tone={:info}
                  label={gettext("Add member")}
                  description={gettext("Register a new library member")}
                  href="/manage/members/management/new"
                />
                <.rd_action_link
                  icon="hero-document-plus"
                  tone={:success}
                  label={gettext("New collection")}
                  description={gettext("Create a catalog collection")}
                  href="/manage/catalog/collections/new"
                />
              </div>
            </.rd_section_card>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <.rd_section_card
              title={gettext("Member overview")}
              icon="hero-user-group"
              tone={:glam_library}
              action_label={gettext("Details")}
              action_path="/manage/settings/user_dashboard"
            >
              <.rd_metric_row
                label={gettext("Active members")}
                value={@member_metrics.active}
                total={@member_metrics.total}
                tone={:success}
              />
              <.rd_metric_row
                label={gettext("Suspended")}
                value={@member_metrics.suspended}
                total={@member_metrics.total}
                tone={:error}
              />
              <.rd_metric_row
                label={gettext("Expiring in 30 days")}
                value={@member_metrics.expiring_soon}
                total={@member_metrics.total}
                tone={:warning}
              />
              <.rd_metric_row
                label={gettext("Expired")}
                value={@member_metrics.expired}
                total={@member_metrics.total}
                tone={:brand}
              />
            </.rd_section_card>

            <.rd_section_card
              title={gettext("Catalog snapshot")}
              icon="hero-rectangle-stack"
              tone={:glam_archive}
              action_label={gettext("Browse")}
              action_path="/manage/catalog/collections"
            >
              <.rd_metric_row
                label={gettext("Total collections")}
                value={@catalog_metrics.collections}
                tone={:info}
              />
              <.rd_metric_row
                label={gettext("Published")}
                value={@catalog_metrics.published}
                total={@catalog_metrics.collections}
                tone={:success}
              />
              <.rd_metric_row
                label={gettext("Total items")}
                value={@catalog_metrics.items}
                tone={:brand}
              />
              <.rd_metric_row
                label={gettext("Available")}
                value={@catalog_metrics.available}
                total={@catalog_metrics.items}
                tone={:glam_library}
              />
            </.rd_section_card>
          </div>
        </div>
      </div>
      <p class="text-xs text-tertiary mt-3">
        {gettext(
          "This mockup is wrapped in a bordered frame so it can be reviewed inside the live shell. The real /manage page renders directly in the content area."
        )}
      </p>
    </.showcase_section>
    """
  end

  # ----------------------------------------------------------------------------
  # TAB: Patterns
  # ----------------------------------------------------------------------------

  defp render_patterns(assigns) do
    ~H"""
    <.showcase_section
      eyebrow={gettext("State · 2.3")}
      title={gettext("Loading skeletons")}
      description={
        gettext(
          "Never show zeros that jump to real numbers. Skeletons shimmer in the surface tone and collapse to a static block under prefers-reduced-motion."
        )
      }
    >
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
        <.rd_stat_card
          label={gettext("Loading")}
          value={nil}
          icon="hero-arrow-path"
          tone={:brand}
          loading={true}
        />
        <.rd_stat_card
          label={gettext("Loading")}
          value={nil}
          icon="hero-arrow-path"
          tone={:success}
          loading={true}
        />
        <.rd_stat_card
          label={gettext("Loading")}
          value={nil}
          icon="hero-arrow-path"
          tone={:warning}
          loading={true}
        />
        <.rd_stat_card
          label={gettext("Loading")}
          value={nil}
          icon="hero-arrow-path"
          tone={:error}
          loading={true}
        />
      </div>
      <.rd_section_card
        title={gettext("Skeleton list")}
        icon="hero-list-bullet"
        tone={:brand}
        class="mt-4"
      >
        <div class="space-y-3">
          <%= for _ <- 1..4 do %>
            <div class="flex items-center gap-3">
              <div class="skeleton w-8 h-8 rounded-lg shrink-0"></div>
              <div class="flex-1 space-y-2">
                <div class="skeleton h-3 w-1/3"></div>
                <div class="skeleton h-3 w-1/2"></div>
              </div>
              <div class="skeleton h-3 w-10"></div>
            </div>
          <% end %>
        </div>
      </.rd_section_card>
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("State · 4.6")}
      title={gettext("Tone & microcopy")}
      description={
        gettext("Warm, helpful, never blamey. Success is quiet — no exclamation marks, no emoji.")
      }
    >
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <.rd_section_card title={gettext("Empty")} icon="hero-inbox" tone={:info}>
          <div class="space-y-3">
            <div class={"p-3 rounded-lg #{tone_soft_bg(:info)}"}>
              <p class="text-sm #{tone_text(:info)}">
                {gettext("No overdue loans today — nicely done.")}
              </p>
            </div>
            <div class={"p-3 rounded-lg #{tone_soft_bg(:success)}"}>
              <p class="text-sm #{tone_text(:success)}">
                {gettext("Member saved.")}
              </p>
            </div>
          </div>
        </.rd_section_card>

        <.rd_section_card title={gettext("Error")} icon="hero-exclamation-circle" tone={:error}>
          <div class={"p-3 rounded-lg #{tone_soft_bg(:error)}"}>
            <p class="text-sm #{tone_text(:error)}">
              {gettext(
                "Couldn't save the member: the email is already used by another member. Try a different one."
              )}
            </p>
          </div>
          <p class="text-xs text-tertiary mt-3">
            {gettext("Plain, specific, recoverable — and it says what to do next.")}
          </p>
        </.rd_section_card>
      </div>
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("Feature · 7.1")}
      title={gettext("Command palette")}
      description={
        gettext(
          "Press ⌘K (or the topbar search pill) to open it. It fuzzy-filters navigation, quick actions, and (in production) collections, items, and members."
        )
      }
    >
      <div class="flex flex-wrap items-center gap-3">
        <button
          type="button"
          phx-click={JS.dispatch("voile:open-command-palette")}
          class="rd-chip"
        >
          <.icon name="hero-magnifying-glass" class="w-4 h-4" />
          <span>{gettext("Open command palette")}</span>
          <kbd class="ml-2 t-mono text-tertiary">⌘K</kbd>
        </button>
        <p class="text-sm text-secondary">
          {gettext("Keyboard-only operable: ↑↓ navigate, ⏎ select, Esc closes.")}
        </p>
      </div>
    </.showcase_section>
    """
  end

  # ----------------------------------------------------------------------------
  # TAB: Legacy — the current/existing components, for refactor review
  # ----------------------------------------------------------------------------

  attr :glam_stats, :map, required: true
  attr :collections, :list, required: true
  attr :members, :list, required: true

  defp render_legacy(assigns) do
    ~H"""
    <.showcase_section
      eyebrow={gettext("Refactor plan · §7.2")}
      title={gettext("Existing dashboard components")}
      description={
        gettext(
          "Every component from VoileDashboardComponents + CoreComponents that the current /manage surfaces use, rendered here so the visual language can be reviewed before restyle. The badge on each is its planned fate (per the redesign doc)."
        )
      }
    >
      <p class="t-label text-tertiary mb-1">{gettext("Navigation chrome")}</p>
      <p class="text-xs text-secondary mb-3">
        {gettext(
          "nav_bar renders inline (shown below). dashboard_menu_bar and dashboard_mobile_menu use fixed/overlay positioning and are documented only — they are slated for removal."
        )}
      </p>

      <.legacy_demo
        name="nav_bar/1"
        signature={gettext(~s(attr :active_nav, :string · reads app_logo_url from settings))}
        action="REMOVE"
        usage={gettext("1 file · dashboard layout only")}
      >
        <div class="rounded-xl overflow-hidden">
          <.nav_bar active_nav="/manage/catalog" />
        </div>
      </.legacy_demo>

      <.legacy_demo
        name="dashboard_menu_bar/1"
        signature={gettext(~s(attr :active_menu, :user, :current_path))}
        action="REMOVE"
        usage={gettext("1 file · layout only")}
      >
        <p class="text-sm text-secondary italic">
          {gettext(
            "Not rendered live — contains a fixed bottom nav that overlaps the redesign shell. Replaced by rd_bottom_nav."
          )}
        </p>
      </.legacy_demo>

      <.legacy_demo
        name="dashboard_mobile_menu/1"
        signature={gettext(~s(attr :active_menu, :user))}
        action="REMOVE"
        usage={gettext("1 file · layout only")}
      >
        <p class="text-sm text-secondary italic">
          {gettext(
            "Not rendered live — fixed slide-up overlay. Replaced by the command palette + bottom nav overflow."
          )}
        </p>
      </.legacy_demo>
    </.showcase_section>

    <.showcase_section eyebrow={gettext("Refactor plan · §7.2")} title={gettext("Stat cards & GLAM")}>
      <.legacy_demo
        name="stat_card/1"
        signature={
          gettext(~s(attr :title, :value, :icon, :color ["blue|green|purple|orange"], :trend))
        }
        action="REPLACE"
        usage={gettext("5 files · → rd_stat_card")}
      >
        <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
          <.stat_card
            title={gettext("Total Members")}
            value={1204}
            icon="hero-users"
            color="blue"
            trend="+12%"
          />
          <.stat_card title={gettext("Active Loans")} value={247} icon="hero-book-open" color="green" />
          <.stat_card
            title={gettext("Overdue")}
            value={7}
            icon="hero-exclamation-triangle"
            color="orange"
          />
          <.stat_card
            title={gettext("Collections")}
            value={3204}
            icon="hero-rectangle-stack"
            color="purple"
          />
        </div>
      </.legacy_demo>

      <.legacy_demo
        name="glam_navigation_cards/1"
        signature={gettext(~s(attr :glam_stats · per-type count/percentage + total_nodes))}
        action="REFACTOR"
        usage={gettext("1 file · → rd_glam_strip")}
      >
        <.glam_navigation_cards glam_stats={@glam_stats} />
      </.legacy_demo>

      <.legacy_demo
        name="glam_type_card/1"
        signature={
          gettext(~s(attr :type, :title, :description, :icon, :color, :count, :percentage, :link))
        }
        action="KEEP"
        usage={gettext("internal only · restyle")}
      >
        <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
          <.glam_type_card
            type="library"
            title="Library"
            description="Books & publications"
            icon="hero-book-open"
            color="blue"
            count={8732}
            percentage={45}
            link="/manage/glam/library"
          />
          <.glam_type_card
            type="archive"
            title="Archive"
            description="Historical documents"
            icon="hero-archive-box"
            color="amber"
            count={412}
            percentage={12}
            link="/manage/glam/archive"
          />
        </div>
      </.legacy_demo>

      <.legacy_demo
        name="glam_card/1 (CoreComponents)"
        signature={gettext(~s(attr :title, :description, :icon, :count, :percentage, :path, :color))}
        action="REVIEW"
        usage={gettext("hardcoded Tailwind palette colors")}
      >
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <.glam_card
            title="Gallery"
            description="Visual arts"
            icon="hero-photo"
            count={1204}
            percentage={38.5}
            path="/manage/glam/gallery"
            color="purple"
          />
          <.glam_card
            title="Library"
            description="Books"
            icon="hero-book-open"
            count={8732}
            percentage={45.0}
            path="/manage/glam/library"
            color="blue"
          />
        </div>
      </.legacy_demo>
    </.showcase_section>

    <.showcase_section eyebrow={gettext("Refactor plan · §7.2")} title={gettext("Lists & members")}>
      <.legacy_demo
        name="recent_collection_item/1"
        signature={gettext(~s(attr :collection · needs resource_class.glam_type, mst_creator))}
        action="REPLACE"
        usage={gettext("1 file · → rd_activity_feed")}
      >
        <div class="space-y-2 max-w-xl">
          <%= for collection <- @collections do %>
            <.recent_collection_item collection={collection} />
          <% end %>
        </div>
      </.legacy_demo>

      <.legacy_demo
        name="recent_member_item/1 (CoreComponents)"
        signature={gettext(~s(attr :member · fullname, username, inserted_at, manually_suspended))}
        action="KEEP"
        usage={gettext("restyle")}
      >
        <div class="space-y-2 max-w-xl">
          <%= for member <- @members do %>
            <.recent_member_item member={member} />
          <% end %>
        </div>
      </.legacy_demo>

      <.legacy_demo
        name="members_navigation_cards/1 (CoreComponents)"
        signature={gettext(~s(attr :members_stats · ignored, 3 hardcoded cards))}
        action="REVIEW"
        usage={gettext("hardcoded Tailwind palette colors")}
      >
        <.members_navigation_cards members_stats={%{}} />
      </.legacy_demo>
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("Refactor plan · §2.2 #3")}
      title={gettext("Search")}
      description={
        gettext(
          "dashboard_search_widget ships debug UI (Query: … | Searching: … | Results: …) — note it below. It is slated for removal, replaced by the command palette."
        )
      }
    >
      <.legacy_demo
        name="dashboard_search_widget/1"
        signature={gettext(~s(attr :search_query, :search_results, :searching))}
        action="REMOVE"
        usage={gettext("2 files · → command palette · has debug UI")}
      >
        <div class="max-w-xl">
          <.dashboard_search_widget
            search_query="sejarah"
            search_results={[]}
            searching={false}
          />
        </div>
      </.legacy_demo>

      <.legacy_demo
        name="search_stats_widget/1"
        signature={gettext("no attrs · assign_new default zeroed stats")}
        action="KEEP"
        usage={gettext("2 files · restyle")}
      >
        <div class="max-w-xl">
          <.search_stats_widget />
        </div>
      </.legacy_demo>
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("Refactor plan · §7.2")}
      title={gettext("Sidebars & pagination")}
    >
      <.legacy_demo
        name="side_bar_dashboard/1"
        signature={gettext(~s(attr :active_side · slot :inner_block))}
        action="KEEP"
        usage={gettext("used by settings/plugin/master sidebars")}
      >
        <div class="max-w-xs">
          <.side_bar_dashboard>
            <h6 class="font-semibold mb-2">Master Data</h6>
            <div class="flex flex-col gap-2">
              <.link navigate="#" class="default-menu active-menu">Creators</.link>
              <.link navigate="#" class="default-menu">Publishers</.link>
              <.link navigate="#" class="default-menu">Locations</.link>
            </div>
          </.side_bar_dashboard>
        </div>
      </.legacy_demo>

      <.legacy_demo
        name="dashboard_settings_sidebar/1"
        signature={gettext(~s(attr :current_path, :is_super_admin, :menu_items))}
        action="KEEP"
        usage={gettext("12 files · highest-usage sidebar · restyle")}
      >
        <div class="max-w-xs overflow-hidden">
          <.dashboard_settings_sidebar current_path="/manage/settings/apps" is_super_admin={true} />
        </div>
      </.legacy_demo>

      <.legacy_demo
        name="pagination/1"
        signature={gettext("attr :page, :total_pages, :path (link mode) | :event (button mode)")}
        action="KEEP"
        usage={gettext("21 files · highest blast radius · restyle in place")}
      >
        <div class="max-w-xl">
          <.pagination page={3} total_pages={8} path="/manage/catalog/collections?page=3" />
        </div>
      </.legacy_demo>

      <.legacy_demo
        name="breadcrumb/1 (CoreComponents)"
        signature={gettext(~s(attr :items · list of label/path maps))}
        action="KEEP"
        usage={gettext("restyle")}
      >
        <.breadcrumb items={[
          %{label: gettext("Manage"), path: "/manage"},
          %{label: gettext("Catalog"), path: "/manage/catalog"},
          %{label: gettext("Collections"), path: nil}
        ]} />
      </.legacy_demo>
    </.showcase_section>

    <.showcase_section eyebrow={gettext("Refactor plan")} title={gettext("Modals & misc")}>
      <.legacy_demo
        name="delete_modal/1"
        signature={gettext(~s(attr :id · hardcoded #delete-modal ids))}
        action="REVIEW"
        usage={gettext("0 call sites · possibly dead · use CoreComponents confirm_delete instead")}
      >
        <p class="text-sm text-secondary italic mb-2">
          {gettext(
            "Not shown open by default — it is a hidden dialog. Listed because it appears unused; prefer confirm_delete from CoreComponents."
          )}
        </p>
        <.delete_modal id="legacy-delete-modal-demo" />
      </.legacy_demo>

      <.legacy_demo
        name="theme_toggle/1 (CoreComponents)"
        signature={gettext("no attr · 3-way system/light/dark")}
        action="KEEP"
        usage={gettext("already wired via phx:set-theme")}
      >
        <div class="inline-block">
          <.theme_toggle />
        </div>
      </.legacy_demo>
    </.showcase_section>

    <.showcase_section
      eyebrow={gettext("Bridging · draft API")}
      title={gettext("rd_ replacements (not yet adopted)")}
      description={
        gettext(
          "Brand-styled successors for every gap above. The API is stable and each renders with design tokens, but no real page uses them yet. These are what the legacy components migrate onto."
        )
      }
    >
      <.legacy_demo
        name="rd_pagination/1"
        signature={gettext("attr :page, :total_pages, :path (link) | :event (button), :params")}
        action="DRAFT"
        usage={gettext("replaces pagination/1 · 21 files")}
      >
        <div class="flex flex-col gap-4">
          <div>
            <p class="t-label text-tertiary mb-2">{gettext("Link mode")}</p>
            <.rd_pagination page={3} total_pages={12} path="/manage/catalog/collections" />
          </div>
          <div>
            <p class="t-label text-tertiary mb-2">{gettext("Button mode (small range)")}</p>
            <.rd_pagination page={2} total_pages={4} event="paginate" />
          </div>
        </div>
      </.legacy_demo>

      <.legacy_demo
        name="rd_settings_shell/1"
        signature={gettext(~s(attr :title, :items, :current_path · slot :inner_block))}
        action="DRAFT"
        usage={gettext("replaces settings/plugin/master sidebars · 16 files")}
      >
        <.rd_settings_shell
          title={gettext("Settings")}
          current_path="/manage/settings/apps"
          items={draft_settings_items()}
        >
          <div class="rd-card p-5">
            <h3 class="t-h3 text-primary text-lg mb-2">{gettext("Branding")}</h3>
            <p class="text-secondary text-sm">
              {gettext(
                "The form for the selected sub-nav page renders here. The sub-nav stays sticky as the content scrolls."
              )}
            </p>
          </div>
        </.rd_settings_shell>
      </.legacy_demo>

      <.legacy_demo
        name="rd_table/1"
        signature={gettext("attr :id, :rows, :row_id · slots :col (label), :action, :empty")}
        action="DRAFT"
        usage={gettext("replaces CoreComponents.table")}
      >
        <.rd_table id="draft-table" rows={draft_table_rows()} row_id={&("row-" <> &1.id)}>
          <:col :let={row} label={gettext("Code")}>{row.code}</:col>
          <:col :let={row} label={gettext("Title")}>{row.title}</:col>
          <:col :let={row} label={gettext("GLAM")}>{row.glam}</:col>
          <:action :let={row}>
            <.rd_button
              tone={:brand}
              variant={:soft}
              size={:sm}
              href={"/manage/catalog/collections/#{row.id}"}
            >
              {gettext("Open")}
            </.rd_button>
          </:action>
        </.rd_table>
      </.legacy_demo>

      <.legacy_demo
        name="rd_input/1"
        signature={gettext(~s(attr :field, :class · forwards :rest to CoreComponents.input))}
        action="DRAFT"
        usage={gettext("brand restyle of CoreComponents.input")}
      >
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 max-w-lg">
          <.rd_input name="title" type="text" label={gettext("Title")} value="Sejarah Indonesia" />
          <.rd_input name="email" type="email" label={gettext("Email")} value="" />
          <.rd_input name="code" type="text" label={gettext("Item code")} value="INV-2026-04821" />
          <.rd_input name="count" type="number" label={gettext("Copies")} value={3} />
        </div>
      </.legacy_demo>

      <.legacy_demo
        name="rd_search_insights/1"
        signature={gettext(~s(attr :stats · total_searches, popular_queries, recent_activity))}
        action="DRAFT"
        usage={gettext("replaces search_stats_widget/1")}
      >
        <div class="max-w-md">
          <.rd_search_insights
            stats={draft_search_stats()}
            action_path="/manage/settings/metrics"
          />
        </div>
      </.legacy_demo>

      <.legacy_demo
        name="rd_glam_tile/1"
        signature={gettext(~s(attr :type, :count, :delta, :href))}
        action="DRAFT"
        usage={gettext("replaces glam_type_card/1 (standalone tile)")}
      >
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 md:gap-4">
          <.rd_glam_tile type={:library} count={8732} delta={47} href="/manage/glam/library" />
          <.rd_glam_tile type={:archive} count={412} delta={0} href="/manage/glam/archive" />
          <.rd_glam_tile type={:gallery} count={1204} delta={12} href="/manage/glam/gallery" />
          <.rd_glam_tile type={:museum} count={158} delta={3} href="/manage/glam/museum" />
        </div>
      </.legacy_demo>

      <.legacy_demo
        name="rd_modal/1 · rd_confirm_delete/1"
        signature={
          gettext(~s(attr :id, :show, :on_cancel, :eyebrow, :title · slots :inner_block, :footer))
        }
        action="DRAFT"
        usage={gettext("replaces collection_modal / delete_modal")}
      >
        <div class="flex flex-wrap items-center gap-2">
          <.rd_button
            tone={:brand}
            variant={:solid}
            size={:md}
            phx-click={show_modal("rd-draft-confirm")}
          >
            <.icon name="hero-trash" class="w-4 h-4" />
            {gettext("Preview confirm-delete")}
          </.rd_button>
          <span class="text-xs text-tertiary">
            {gettext("Opens a live modal — click backdrop or Cancel to dismiss.")}
          </span>
        </div>
        <.rd_confirm_delete
          id="rd-draft-confirm"
          show={false}
          title={gettext("Delete Sejarah Indonesia Vol. 3?")}
          confirm_label={gettext("Delete")}
          on_cancel={hide_modal("rd-draft-confirm")}
          on_confirm={hide_modal("rd-draft-confirm")}
        >
          {gettext("This collection has 18 items. The action cannot be undone.")}
        </.rd_confirm_delete>
      </.legacy_demo>

      <.legacy_demo
        name="rd_flash_group/1 · rd_locale_switcher/1"
        signature={gettext("thin brand wrappers around CoreComponents · restyle pending")}
        action="DRAFT"
        usage={gettext("delegating wrappers")}
      >
        <div class="flex flex-wrap items-center gap-4">
          <.rd_locale_switcher current_path="/manage/redesign-test" />
          <span class="text-xs text-tertiary">
            {gettext(
              "Flash group renders at the top of the layout (already in use via core flash_group)."
            )}
          </span>
        </div>
      </.legacy_demo>
    </.showcase_section>
    """
  end

  attr :name, :string, required: true
  attr :signature, :string, required: true
  attr :action, :string, required: true
  attr :usage, :string, default: nil
  slot :inner_block, required: true

  defp legacy_demo(assigns) do
    ~H"""
    <div class="mb-6">
      <div class="flex items-center gap-2 mb-2 flex-wrap">
        <code class="t-mono text-sm text-primary font-semibold">{@name}</code>
        <span class={action_badge_class(@action)}>{@action}</span>
        <%= if @usage do %>
          <span class="text-xs text-tertiary">{@usage}</span>
        <% end %>
      </div>
      <p class="t-mono text-xs text-tertiary mb-3">{@signature}</p>
      <div class="rounded-xl border border-subtle p-4 surface-page overflow-x-auto">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp action_badge_class("REMOVE"),
    do:
      "text-[10px] px-1.5 py-0.5 rounded-full font-semibold bg-tone-error-soft text-voile-error uppercase tracking-wide"

  defp action_badge_class("REPLACE"),
    do:
      "text-[10px] px-1.5 py-0.5 rounded-full font-semibold bg-tone-warning-soft text-voile-warning uppercase tracking-wide"

  defp action_badge_class("REFACTOR"),
    do:
      "text-[10px] px-1.5 py-0.5 rounded-full font-semibold bg-tone-warning-soft text-voile-warning uppercase tracking-wide"

  defp action_badge_class("REVIEW"),
    do:
      "text-[10px] px-1.5 py-0.5 rounded-full font-semibold bg-tone-info-soft text-voile-info uppercase tracking-wide"

  defp action_badge_class(_),
    do:
      "text-[10px] px-1.5 py-0.5 rounded-full font-semibold bg-tone-success-soft text-voile-success uppercase tracking-wide"

  # ----------------------------------------------------------------------------
  # Showcase primitives (private, showcase-only)
  # ----------------------------------------------------------------------------

  attr :eyebrow, :string, default: nil
  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :inner_block, required: true

  defp showcase_section(assigns) do
    ~H"""
    <section class="mb-10">
      <%= if @eyebrow do %>
        <p class="t-label text-voile-primary mb-1.5">{@eyebrow}</p>
      <% end %>
      <h2 class="t-h2 text-primary text-xl md:text-2xl">{@title}</h2>
      <%= if @description do %>
        <p class="text-secondary mt-1.5 text-sm max-w-2xl mb-4">{@description}</p>
      <% else %>
        <div class="mb-4"></div>
      <% end %>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :name, :string, required: true
  attr :token, :string, required: true
  attr :bg, :string, required: true
  attr :value, :string, default: nil
  attr :badge, :string, default: nil

  defp swatch(assigns) do
    ~H"""
    <div class="rd-card overflow-hidden">
      <div class="h-16 w-full border-b border-subtle" style={"background-color: #{@bg}"}></div>
      <div class="p-2.5">
        <div class="flex items-center justify-between gap-1">
          <p class="text-xs font-semibold text-primary truncate">{@name}</p>
          <%= if @badge do %>
            <span class={[
              "text-[9px] px-1.5 py-0.5 rounded-full font-semibold uppercase tracking-wide",
              @badge == gettext("Live") && "bg-tone-success-soft text-voile-success",
              @badge != gettext("Live") && "bg-tone-info-soft text-voile-info"
            ]}>
              {@badge}
            </span>
          <% end %>
        </div>
        <p class="t-mono text-[10px] text-tertiary truncate mt-0.5">{@token}</p>
        <%= if @value do %>
          <p class="t-mono text-[10px] text-secondary truncate mt-0.5">{@value}</p>
        <% end %>
      </div>
    </div>
    """
  end

  attr :class_name, :string, required: true
  attr :sample, :string, required: true
  attr :meta, :string, required: true

  defp specimen(assigns) do
    ~H"""
    <div class="flex flex-col md:flex-row md:items-baseline gap-1 md:gap-6 py-4">
      <div class={[@class_name, "flex-1 min-w-0 text-primary"]}>
        {@sample}
      </div>
      <span class="t-mono text-xs text-tertiary shrink-0">{@meta}</span>
    </div>
    """
  end

  # ----------------------------------------------------------------------------
  # Composite: action link (used in dashboard mockup)
  # ----------------------------------------------------------------------------

  attr :icon, :string, required: true
  attr :tone, :atom, required: true
  attr :label, :string, required: true
  attr :description, :string, required: true
  attr :href, :string, required: true

  defp rd_action_link(assigns) do
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

  # ----------------------------------------------------------------------------
  # Brand color reader — pulls live values from SystemSetting
  # ----------------------------------------------------------------------------

  defp read_brand_colors do
    [
      %{key: "app_main_color", name: gettext("Primary"), token: "--color-voile-primary"},
      %{key: "app_secondary_color", name: gettext("Secondary"), token: "--color-voile-secondary"},
      %{key: "app_surface_color", name: gettext("Surface"), token: "--color-voile-surface"},
      %{
        key: "app_surface_variant",
        name: gettext("Surface variant"),
        token: "--color-voile-surface-variant"
      },
      %{
        key: "app_surface_dark",
        name: gettext("Surface dark"),
        token: "--color-voile-surface-dark"
      },
      %{key: "app_accent_color", name: gettext("Accent"), token: "--color-voile-accent"}
    ]
    |> Enum.map(fn entry ->
      seeded = seed_default(entry.key)

      case System.get_setting_value(entry.key, nil) do
        nil ->
          Map.merge(entry, %{value: seeded, source: gettext("CSS default")})

        value ->
          Map.merge(entry, %{value: value, source: gettext("Live")})
      end
    end)
  end

  defp seed_default("app_main_color"), do: "#C166FF"
  defp seed_default("app_secondary_color"), do: "#A78BFA"
  defp seed_default("app_surface_color"), do: "#F6F3FF"
  defp seed_default("app_surface_variant"), do: "#EFE9FF"
  defp seed_default("app_surface_dark"), do: "#0F0820"
  defp seed_default("app_accent_color"), do: "#C4B5FD"
  defp seed_default(_), do: "#C166FF"

  # ----------------------------------------------------------------------------
  # Static demo data
  # ----------------------------------------------------------------------------

  defp build_greeting(user) do
    hour = DateTime.utc_now().hour

    salutation =
      cond do
        hour < 11 -> gettext("Good morning")
        hour < 17 -> gettext("Good afternoon")
        true -> gettext("Good evening")
      end

    name = Map.get(user || %{}, :fullname) || Map.get(user || %{}, :username) || gettext("there")
    "#{salutation}, #{String.split(name) |> List.first()}"
  end

  defp demo_glam_stats do
    %{
      gallery_count: 1204,
      gallery_delta: 12,
      library_count: 8732,
      library_delta: 47,
      archive_count: 412,
      archive_delta: 0,
      museum_count: 158,
      museum_delta: 3
    }
  end

  defp demo_today_stats do
    %{
      active_loans: 247,
      due_today: 18,
      overdue: 7,
      reservations: 12
    }
  end

  defp demo_attention_items do
    [
      %{
        icon: "hero-exclamation-triangle",
        tone: :error,
        title: gettext("Sejarah Indonesia Vol. 3 — overdue 4 days"),
        subtitle: gettext("Member: Budi Santoso · borrowed 12 Jul"),
        meta: "4d"
      },
      %{
        icon: "hero-bookmark",
        tone: :warning,
        title: gettext("\"Nusantara\" ready for pickup"),
        subtitle: gettext("Member: Sari Wijaya · holds until 6 PM"),
        meta: "2h"
      },
      %{
        icon: "hero-user-minus",
        tone: :warning,
        title: gettext("Expiring membership: Andi Pratama"),
        subtitle: gettext("3 days remaining · sent reminder 2 days ago"),
        meta: "3d"
      },
      %{
        icon: "hero-archive-box-arrow-down",
        tone: :info,
        title: gettext("Transfer request: 2 items pending review"),
        subtitle: gettext("From Kandaga · requested by Rina"),
        meta: "1h"
      },
      %{
        icon: "hero-clock",
        tone: :brand,
        title: gettext("Requisition awaiting approval"),
        subtitle: gettext("New acquisition proposal · from Department of History"),
        meta: "5h"
      }
    ]
  end

  defp demo_member_metrics do
    %{
      total: 1204,
      active: 1024,
      suspended: 12,
      expiring_soon: 47,
      expired: 93
    }
  end

  defp demo_catalog_metrics do
    %{
      collections: 3204,
      published: 2890,
      items: 18_420,
      available: 15_302
    }
  end

  defp demo_legacy_glam_stats do
    %{
      gallery: %{count: 1204, percentage: 38.5},
      library: %{count: 8732, percentage: 45.0},
      archive: %{count: 412, percentage: 12.0},
      museum: %{count: 158, percentage: 4.5},
      total_nodes: 6
    }
  end

  defp demo_legacy_collections do
    [
      %{
        id: 42,
        title: gettext("Sejarah Indonesia Vol. 3"),
        resource_class: %{glam_type: "Library"},
        mst_creator: %{creator_name: "Hamidy, Amin"}
      },
      %{
        id: 43,
        title: gettext("Nusantara Bark Paintings"),
        resource_class: %{glam_type: "Gallery"},
        mst_creator: nil
      },
      %{
        id: 44,
        title: gettext("Colonial Archive Bundle 1920"),
        resource_class: %{glam_type: "Archive"},
        mst_creator: %{creator_name: "Kandaga Archive"}
      }
    ]
  end

  defp demo_legacy_members do
    [
      %{
        fullname: "Budi Santoso",
        username: "budi.s",
        inserted_at: ~U[2026-06-15 10:00:00Z],
        manually_suspended: false
      },
      %{
        fullname: "Sari Wijaya",
        username: "sari.w",
        inserted_at: ~U[2025-11-02 08:30:00Z],
        manually_suspended: true
      }
    ]
  end

  defp draft_settings_items do
    [
      %{label: gettext("Branding"), path: "/manage/settings/apps", icon: "hero-paint-brush"},
      %{label: gettext("Profile"), path: "/manage/settings/user_profile", icon: "hero-user"},
      %{label: gettext("Permissions"), path: "/manage/settings/permissions", icon: "hero-key"},
      %{label: gettext("Nodes"), path: "/manage/settings/nodes", icon: "hero-building-library"},
      %{
        label: gettext("API tokens"),
        path: "/manage/settings/api_manager",
        icon: "hero-code-bracket"
      }
    ]
  end

  defp draft_table_rows do
    [
      %{id: "1", code: "INV-2026-04821", title: "Sejarah Indonesia Vol. 3", glam: "Library"},
      %{id: "2", code: "GAL-2025-00112", title: "Nusantara Bark Paintings", glam: "Gallery"},
      %{id: "3", code: "ARC-2024-00077", title: "Colonial Archive Bundle", glam: "Archive"}
    ]
  end

  defp draft_search_stats do
    %{
      total_searches: 1820,
      popular_queries: [{"sejarah", 148}, {"sains", 92}, {"nusantara", 64}, {"islam", 41}]
    }
  end
end
