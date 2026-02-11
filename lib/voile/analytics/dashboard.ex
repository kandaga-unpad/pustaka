defmodule Voile.Analytics.Dashboard do
  @moduledoc """
  Dashboard analytics context for retrieving GLAM system statistics.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo
  alias Voile.Schema.Catalog.{Collection, Item}
  alias Voile.Schema.System.Node
  alias Voile.Schema.Metadata.ResourceClass
  alias Voile.Schema.Accounts.User

  @doc """
  Get total count of node collections across all nodes.
  """
  def get_node_collection_count do
    from(c in Collection,
      join: n in Node,
      on: c.unit_id == n.id,
      select: count(c.id)
    )
    |> Repo.one()
  end

  @doc """
  Get favorite books based on most recent activity or some criteria.
  For now, we'll get recently added items that are books.
  """
  def get_favorite_books(limit \\ 5) do
    from(i in Item,
      join: c in Collection,
      on: i.collection_id == c.id,
      join: rc in ResourceClass,
      on: c.type_id == rc.id,
      where: rc.glam_type == "Library",
      where: i.availability == "available",
      where: c.status == "published",
      order_by: [desc: i.inserted_at],
      limit: ^limit,
      preload: [collection: [:resource_class]]
    )
    |> Repo.all()
  end

  @doc """
  Get new books/items added recently.
  """
  def get_new_books(limit \\ 5) do
    from(i in Item,
      join: c in Collection,
      on: i.collection_id == c.id,
      join: rc in ResourceClass,
      on: c.type_id == rc.id,
      where: i.inserted_at >= ago(7, "day"),
      where: i.availability == "available",
      order_by: [desc: i.inserted_at],
      limit: ^limit,
      preload: [collection: [:resource_class]]
    )
    |> Repo.all()
  end

  @doc """
  Get most active users based on recent activity.
  For now, we'll get recently registered users as a placeholder.
  """
  def get_most_active_users(limit \\ 5) do
    from(u in User,
      where: not is_nil(u.confirmed_at),
      order_by: [desc: u.inserted_at],
      limit: ^limit,
      select: %{
        id: u.id,
        email: u.email,
        username: u.username,
        fullname: u.fullname,
        user_image: u.user_image,
        inserted_at: u.inserted_at,
        confirmed_at: u.confirmed_at
      }
    )
    |> Repo.all()
  end

  @doc """
  Get category breakdown of collections by resource class (GLAM type).
  """
  def get_collection_categories do
    from(c in Collection,
      join: rc in ResourceClass,
      on: c.type_id == rc.id,
      group_by: rc.glam_type,
      select: %{
        category: rc.glam_type,
        count: count(c.id)
      }
    )
    |> Repo.all()
  end

  @doc """
  Get collection count per node with node details.
  """
  def get_node_collection_counts do
    nodes = Voile.Schema.System.list_nodes()

    Enum.map(nodes, fn node ->
      collection_count = Voile.Schema.Catalog.count_collections(node.id)

      %{
        id: node.id,
        name: node.name,
        abbr: node.abbr,
        image: node.image,
        description: node.description,
        collection_count: collection_count,
        color: pick_node_color(node.id)
      }
    end)
  end

  @doc """
  Get total count of items across all collections.
  """
  def get_total_item_count do
    from(i in Item,
      select: count(i.id)
    )
    |> Repo.one()
  end

  # Helper function to get gradient class for node colors
  @node_colors [
    "from-blue-400 to-blue-600",
    "from-green-400 to-green-600",
    "from-indigo-400 to-indigo-600",
    "voile-gradient",
    "from-pink-400 to-pink-600",
    "from-yellow-400 to-yellow-600",
    "from-red-400 to-red-600",
    "from-teal-400 to-teal-600"
  ]

  defp pick_node_color(id) do
    idx = :erlang.phash2(id, length(@node_colors))
    Enum.at(@node_colors, idx)
  end

  @doc """
  Get comprehensive dashboard statistics.
  """
  def get_dashboard_stats do
    # Use try-catch for each stat to prevent one failure from breaking the entire dashboard
    %{
      node_collection_count: safe_execute(&get_node_collection_count/0, 0),
      total_item_count: safe_execute(&get_total_item_count/0, 0),
      favorite_books: safe_execute(fn -> get_favorite_books() end, []),
      new_books: safe_execute(fn -> get_new_books() end, []),
      most_active_users: safe_execute(fn -> get_most_active_users() end, []),
      collection_categories: safe_execute(&get_collection_categories/0, []),
      node_collections: safe_execute(&get_node_collection_counts/0, [])
    }
  end

  # Helper function to safely execute database queries
  defp safe_execute(func, default_value) do
    try do
      func.()
    rescue
      _ -> default_value
    catch
      _ -> default_value
    end
  end
end
