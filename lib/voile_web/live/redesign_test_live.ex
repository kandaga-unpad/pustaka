defmodule VoileWeb.RedesignTestLive do
  @moduledoc """
  Sample LiveView showcasing the Voile dashboard redesign (v2).

  Renders a complete dashboard home page using only the new design system
  primitives defined in `VoileWeb.RedesignComponents`. Data is static demo
  data — no database calls — so the page is fast and the design can be
  evaluated without depending on seed state.

  Layout: `VoileWeb.Layouts.redesign` (sidebar + topbar + bottom nav + lite footer).
  Route: `/manage/redesign-test`
  """

  use VoileWeb, :live_view_redesign

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:page_title, gettext("Redesign Sample"))
      |> assign(:breadcrumb, [
        %{label: gettext("Manage"), path: "/manage"},
        %{label: gettext("Redesign Sample"), path: nil}
      ])
      |> assign(:notification_count, 3)
      |> assign(:greeting, build_greeting(user))
      |> assign(:glam_stats, demo_glam_stats())
      |> assign(:today_stats, demo_today_stats())
      |> assign(:attention_items, demo_attention_items())
      |> assign(:member_metrics, demo_member_metrics())
      |> assign(:catalog_metrics, demo_catalog_metrics())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
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
        <.rd_button href="/manage/members/management/new" tone={:brand} variant={:outline} size={:md}>
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

      <.rd_section_card
        title={gettext("Quick actions")}
        icon="hero-bolt"
        tone={:brand}
      >
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
          <.rd_action_link
            icon="hero-magnifying-glass"
            tone={:warning}
            label={gettext("Item lookup")}
            description={gettext("Search by code or title")}
            href="/manage/catalog/items"
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
    """
  end

  # ----------------------------------------------------------------------------
  # Private helpers — rd_action_link (small composite used in the page above)
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
      class="flex items-center gap-3 p-3 rounded-lg border border-subtle hover:bg-[color:var(--color-surface-3-light)] transition-colors group"
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
end
