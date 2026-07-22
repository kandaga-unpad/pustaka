defmodule Voile.Dashboard.Stats do
  @moduledoc """
  Context for dashboard statistics.

  Lifts the GLAM / catalog / member statistics queries that previously lived as
  private functions inside `VoileWeb.Dashboard.Glam.Index` and
  `VoileWeb.DashboardLive` so the new dashboard home (Phase 2 of the redesign)
  can feed the GLAM strip without duplicating the logic.

  All queries honor node scoping: when the given user has a `node_id`, counts
  are restricted to that node; super admins (with `node_id == nil`) see
  everything.
  """

  import Ecto.Query

  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.{Collection, Item}
  alias Voile.Schema.Metadata.ResourceClass
  alias Voile.Schema.System.Node

  @doc """
  Computes GLAM statistics scoped to the given user's node.

  Returns a map with both the nested per-type breakdown (consumed by the legacy
  `glam_navigation_cards` component) and flat `*_count` keys (consumed by the
  v2 `voile_glam_strip`). `*_delta` keys are present but always `0` — trend data
  is tracked separately and can be wired in a later phase.
  """
  def get_glam_statistics(user) do
    gallery_count = count_collections_by_glam("Gallery", user)
    library_count = count_collections_by_glam("Library", user)
    archive_count = count_collections_by_glam("Archive", user)
    museum_count = count_collections_by_glam("Museum", user)

    total_collections = gallery_count + library_count + archive_count + museum_count
    total_items = count_items(user)
    total_nodes = Repo.aggregate(Node, :count, :id)
    resource_classes = Repo.aggregate(ResourceClass, :count, :id)

    %{
      gallery: %{count: gallery_count, percentage: percentage(gallery_count, total_collections)},
      library: %{count: library_count, percentage: percentage(library_count, total_collections)},
      archive: %{count: archive_count, percentage: percentage(archive_count, total_collections)},
      museum: %{count: museum_count, percentage: percentage(museum_count, total_collections)},
      gallery_count: gallery_count,
      library_count: library_count,
      archive_count: archive_count,
      museum_count: museum_count,
      gallery_delta: 0,
      library_delta: 0,
      archive_delta: 0,
      museum_delta: 0,
      total_collections: total_collections,
      total_items: total_items,
      total_nodes: total_nodes,
      resource_classes: resource_classes
    }
  end

  @doc """
  Returns the most recently created collections scoped to the user's node,
  preloading the associations the dashboard rows need to render.
  """
  def list_recent_collections(limit, user) do
    base =
      from(c in Collection,
        join: rc in assoc(c, :resource_class),
        order_by: [desc: c.inserted_at],
        limit: ^limit,
        preload: [:resource_class, :mst_creator]
      )

    base
    |> maybe_filter_by_node(user)
    |> Repo.all()
  end

  @doc """
  Computes catalog statistics scoped to the user's node.
  """
  def get_catalog_stats(user) do
    %{
      total_collections: count_collections(user),
      published_collections: count_collections(user, status: "published"),
      total_items: count_items(user),
      available_items: count_items(user, availability: "available")
    }
  end

  @doc """
  Computes member statistics scoped to the user's node.
  """
  def get_member_stats(user) do
    %{
      total_members: count_members(user),
      active_members: count_members(user, active?: true),
      suspended_members: count_members(user, suspended?: true),
      expiring_soon: count_members(user, expiring_in_days: 30),
      expired_members: count_members(user, expired?: true)
    }
  end

  # ---------------------------------------------------------------------------
  # Builders
  # ---------------------------------------------------------------------------

  defp count_collections_by_glam(glam_type, user) do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == ^glam_type
    )
    |> maybe_filter_by_node(user)
    |> Repo.aggregate(:count, :id)
  end

  defp count_collections(user, opts \\ []) do
    Collection
    |> maybe_filter_by_node(user)
    |> maybe_where(:status, Keyword.get(opts, :status))
    |> Repo.aggregate(:count, :id)
  end

  defp count_items(user, opts \\ []) do
    Item
    |> maybe_join_collection_by_node(user)
    |> maybe_where(:availability, Keyword.get(opts, :availability))
    |> Repo.aggregate(:count, :id)
  end

  defp count_members(user, opts \\ []) do
    User
    |> maybe_filter_members_by_node(user)
    |> member_filter(opts)
    |> Repo.aggregate(:count, :id)
  end

  defp member_filter(q, active?: true) do
    where(q, [u], u.manually_suspended == false or is_nil(u.manually_suspended))
  end

  defp member_filter(q, suspended?: true) do
    where(q, [u], u.manually_suspended == true)
  end

  defp member_filter(q, expired?: true) do
    where(q, [u], not is_nil(u.expiry_date) and u.expiry_date < ^Date.utc_today())
  end

  defp member_filter(q, expiring_in_days: days) do
    horizon = Date.add(Date.utc_today(), days)

    where(
      q,
      [u],
      not is_nil(u.expiry_date) and u.expiry_date <= ^horizon and
        u.expiry_date >= ^Date.utc_today()
    )
  end

  defp member_filter(q, _), do: q

  # When scoping items by node we must join through the collection because items
  # inherit their node through `collection.unit_id`.
  defp maybe_join_collection_by_node(q, %{node_id: nil}), do: q

  defp maybe_join_collection_by_node(q, %{node_id: node_id}) do
    from(i in q, join: c in assoc(i, :collection), where: c.unit_id == ^node_id)
  end

  # Collections & items scope by `unit_id`; the User schema uses `node_id`.
  defp maybe_filter_by_node(q, %{node_id: nil}), do: q
  defp maybe_filter_by_node(q, %{node_id: node_id}), do: where(q, [a], a.unit_id == ^node_id)

  defp maybe_filter_members_by_node(q, %{node_id: nil}), do: q

  defp maybe_filter_members_by_node(q, %{node_id: node_id}),
    do: where(q, [u], u.node_id == ^node_id)

  defp maybe_where(q, _field, nil), do: q
  defp maybe_where(q, :status, value), do: where(q, [a], a.status == ^value)
  defp maybe_where(q, :availability, value), do: where(q, [a], a.availability == ^value)

  defp percentage(_count, 0), do: 0
  defp percentage(count, total), do: Float.round(count / total * 100, 3)
end
