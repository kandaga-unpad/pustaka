defmodule VoileWeb.Dashboard.Glam.Museum.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Catalog.Item

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    # Get museum-specific collections
    museum_collections = get_museum_collections()

    # Compute global aggregates (not limited to the preview list)
    total_collections = get_museum_total_collections()
    total_items = get_museum_total_items()
    published_collections = get_museum_published_collections()

    socket =
      socket
      |> assign(:page_title, gettext("Museum Dashboard"))
      |> assign(:breadcrumb, [
        %{label: gettext("Manage"), path: "/manage"},
        %{label: gettext("GLAM"), path: "/manage/glam"},
        %{label: gettext("Museum"), path: nil}
      ])
      |> assign(:museum_collections, museum_collections)
      |> assign(:total_collections, total_collections)
      |> assign(:total_items, total_items)
      |> assign(:published_collections, published_collections)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.voile_page_header
      eyebrow={gettext("GLAM · Museum")}
      title={gettext("Museum Management")}
      description={gettext("Manage artifacts, specimens, and cultural objects")}
      icon="hero-cube"
      tone={:glam_museum}
    >
      <:actions>
        <.voile_button
          href="/manage/catalog/collections/new"
          tone={:glam_museum}
          variant={:solid}
          size={:md}
        >
          <.icon name="hero-plus" class="w-4 h-4" /> {gettext("New collection")}
        </.voile_button>
      </:actions>
    </.voile_page_header>

    <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 md:gap-4 mb-6">
      <.voile_stat_card
        label={gettext("Total collections")}
        value={@total_collections}
        icon="hero-rectangle-stack"
        tone={:glam_museum}
      />
      <.voile_stat_card
        label={gettext("Total items")}
        value={@total_items}
        icon="hero-cube"
        tone={:glam_museum}
      />
      <.voile_stat_card
        label={gettext("Published")}
        value={@published_collections}
        icon="hero-check-badge"
        tone={:success}
      />
    </div>

    <.voile_section_card title={gettext("Quick actions")} icon="hero-bolt" tone={:glam_museum}>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-2">
        <.voile_action_link
          icon="hero-rectangle-stack"
          tone={:glam_museum}
          label={gettext("View collections")}
          description={gettext("Browse all museum collections")}
          href="/manage/catalog/collections?glam_type=Museum"
        />
        <.voile_action_link
          icon="hero-plus-circle"
          tone={:success}
          label={gettext("New collection")}
          description={gettext("Create a new museum collection")}
          href="/manage/catalog/collections/new"
        />
        <.voile_action_link
          icon="hero-cube"
          tone={:info}
          label={gettext("View items")}
          description={gettext("Browse all museum items")}
          href="/manage/catalog/items?glam_type=Museum"
        />
      </div>
    </.voile_section_card>
    """
  end

  # Private helper functions

  defp get_museum_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Museum",
      order_by: [desc: c.inserted_at],
      limit: 50,
      preload: [:resource_class, :items]
    )
    |> Repo.all()
  end

  # Aggregate helpers that count across the whole DB (not limited)
  defp get_museum_total_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Museum"
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_museum_total_items do
    from(i in Item,
      join: c in assoc(i, :collection),
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Museum"
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_museum_published_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Museum" and c.status == "published"
    )
    |> Repo.aggregate(:count, :id)
  end
end
