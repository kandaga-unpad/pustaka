defmodule VoileWeb.Dashboard.Glam.Gallery.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Catalog.Item

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    # Get gallery-specific collections
    gallery_collections = get_gallery_collections()

    # Compute global aggregates (not limited to the preview list)
    total_collections = get_gallery_total_collections()
    total_items = get_gallery_total_items()
    published_collections = get_gallery_published_collections()

    socket =
      socket
      |> assign(:page_title, gettext("Gallery Dashboard"))
      |> assign(:breadcrumb, [
        %{label: gettext("Manage"), path: "/manage"},
        %{label: gettext("GLAM"), path: "/manage/glam"},
        %{label: gettext("Gallery"), path: nil}
      ])
      |> assign(:gallery_collections, gallery_collections)
      |> assign(:total_collections, total_collections)
      |> assign(:total_items, total_items)
      |> assign(:published_collections, published_collections)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.voile_page_header
      eyebrow={gettext("GLAM · Gallery")}
      title={gettext("Gallery Management")}
      description={gettext("Manage visual arts, photographs, and artistic collections")}
      icon="hero-photo"
      tone={:glam_gallery}
    >
      <:actions>
        <.voile_button
          href="/manage/catalog/collections/new"
          tone={:glam_gallery}
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
        tone={:glam_gallery}
      />
      <.voile_stat_card
        label={gettext("Total items")}
        value={@total_items}
        icon="hero-cube"
        tone={:glam_gallery}
      />
      <.voile_stat_card
        label={gettext("Published")}
        value={@published_collections}
        icon="hero-check-badge"
        tone={:success}
      />
    </div>

    <.voile_section_card title={gettext("Quick actions")} icon="hero-bolt" tone={:glam_gallery}>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-2">
        <.voile_action_link
          icon="hero-rectangle-stack"
          tone={:glam_gallery}
          label={gettext("View collections")}
          description={gettext("Browse all gallery collections")}
          href="/manage/catalog/collections?glam_type=Gallery"
        />
        <.voile_action_link
          icon="hero-plus-circle"
          tone={:success}
          label={gettext("New collection")}
          description={gettext("Create a new gallery collection")}
          href="/manage/catalog/collections/new"
        />
        <.voile_action_link
          icon="hero-cube"
          tone={:info}
          label={gettext("View items")}
          description={gettext("Browse all gallery items")}
          href="/manage/catalog/items?glam_type=Gallery"
        />
      </div>
    </.voile_section_card>
    """
  end

  # Private helper functions

  defp get_gallery_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Gallery",
      order_by: [desc: c.inserted_at],
      limit: 50,
      preload: [:resource_class, :items]
    )
    |> Repo.all()
  end

  # Aggregate helpers that count across the whole DB (not limited)
  defp get_gallery_total_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Gallery"
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_gallery_total_items do
    from(i in Item,
      join: c in assoc(i, :collection),
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Gallery"
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_gallery_published_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Gallery" and c.status == "published"
    )
    |> Repo.aggregate(:count, :id)
  end
end
