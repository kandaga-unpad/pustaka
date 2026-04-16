defmodule Voile.StockOpnameFixtures do
  @moduledoc """
  Test helpers for setting up stock opname entities.

  Provides factory functions that wire up the full dependency chain:
  Node → ResourceClass → Collection → Item → Session → StockOpname.Item

  All fixtures use direct `Repo.insert!` for speed where possible, falling back
  to context functions when business logic is required (e.g. `create_session/2`).

  ## Sandbox note

  `approve_session/3` internally uses `Task.async_stream` which spawns tasks
  that need DB access. Call `allow_sandbox/1` with the test process PID before
  invoking `approve_session` so those tasks can borrow the sandbox connection.
  """

  import Ecto.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Catalog.Item, as: CatalogItem
  alias Voile.Schema.Metadata.ResourceClass

  alias Voile.Schema.StockOpname.{Item, Session}
  alias Voile.Schema.System.Node

  # ---------------------------------------------------------------------------
  # Infrastructure helpers
  # ---------------------------------------------------------------------------

  @doc """
  Create a minimal `Node` (unit) used by collections and items.
  """
  def node_fixture(attrs \\ %{}) do
    {:ok, node} =
      attrs
      |> Enum.into(%{
        name: "Test Library #{System.unique_integer()}",
        abbr: "TL#{System.unique_integer([:positive])}",
        image: "placeholder.png"
      })
      |> Voile.Schema.System.create_node()

    node
  end

  @doc """
  Create a `ResourceClass` with `glam_type: "Library"` by default.
  Required because `Collection` has a non-nullable `type_id` FK.
  """
  def resource_class_fixture(attrs \\ %{}) do
    {:ok, rc} =
      attrs
      |> Enum.into(%{
        label: "Monograph #{System.unique_integer()}",
        local_name: "monograph_#{System.unique_integer()}",
        information: "Test resource class",
        glam_type: "Library"
      })
      |> Voile.Schema.Metadata.create_resource_class()

    rc
  end

  @doc """
  Create a minimal `User` (admin) used as the session creator / reviewer.
  """
  def admin_user_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "admin#{n}@example.com",
        username: "admin#{n}",
        password: "hello world!"
      })
      |> Voile.Schema.Accounts.register_user()

    user
  end

  # ---------------------------------------------------------------------------
  # Collection / Item helpers
  # ---------------------------------------------------------------------------

  @doc """
  Create a `Collection` that belongs to the given node and resource class.
  Requires an admin user for the `created_by_id` field.
  """
  def collection_fixture(%Node{} = node, %ResourceClass{} = rc, %User{} = admin, attrs \\ %{}) do
    n = System.unique_integer([:positive])
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Insert directly to avoid the Task.start side-effects inside
    # Catalog.create_collection/2 (collection logger, hooks) which use DB
    # connections outside the sandbox and cause connection-leak errors in tests.
    collection =
      Repo.insert!(%Collection{
        title: Map.get(attrs, :title, "Test Collection #{n}"),
        collection_code: Map.get(attrs, :collection_code, "COL-#{n}"),
        description: Map.get(attrs, :description, "A test collection"),
        status: Map.get(attrs, :status, "published"),
        access_level: Map.get(attrs, :access_level, "public"),
        thumbnail: Map.get(attrs, :thumbnail, "thumb.png"),
        type_id: Map.get(attrs, :type_id, rc.id),
        unit_id: Map.get(attrs, :unit_id, node.id),
        creator_id: Map.get(attrs, :creator_id, ensure_master_creator(admin)),
        created_by_id: Map.get(attrs, :created_by_id, admin.id),
        inserted_at: now,
        updated_at: now
      })

    collection
  end

  @doc """
  Create a `CatalogItem` belonging to `collection` on `node`, with
  `availability: "available"` by default.

  Pass `availability:` in `attrs` to override (e.g. `"loaned"`).
  """
  def catalog_item_fixture(
        %Collection{} = collection,
        %Node{} = node,
        %User{} = admin,
        attrs \\ %{}
      ) do
    n = System.unique_integer([:positive])
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Insert directly to avoid the Task.start side-effects inside
    # Catalog.create_item/2 (collection logger, hooks) that would try to use
    # DB connections outside the sandbox and cause connection-leak errors.
    # We also skip `barcode` because that column does not exist in the test DB
    # schema (no migration has been run for it yet).
    item =
      Repo.insert!(%CatalogItem{
        item_code: Map.get(attrs, :item_code, "ITM-#{n}"),
        inventory_code: Map.get(attrs, :inventory_code, "INV-#{n}"),
        location: Map.get(attrs, :location, "Shelf A"),
        status: Map.get(attrs, :status, "active"),
        condition: Map.get(attrs, :condition, "good"),
        availability: Map.get(attrs, :availability, "available"),
        collection_id: Map.get(attrs, :collection_id, collection.id),
        unit_id: Map.get(attrs, :unit_id, node.id),
        created_by_id: Map.get(attrs, :created_by_id, admin.id),
        inserted_at: now,
        updated_at: now
      })

    item
  end

  # ---------------------------------------------------------------------------
  # Session helpers
  # ---------------------------------------------------------------------------

  @doc """
  Create a `Session` in `"pending_review"` status that already contains
  the provided `catalog_items` as `StockOpname.Item` rows.

  This is the main setup helper for approval-flow tests. It bypasses the
  normal initialization pipeline by directly inserting the session and items
  at the correct status, keeping tests fast and focused.

  ## Options

  - `node_ids` — defaults to `[node.id]`
  - `collection_types` — defaults to `["Library"]`
  - `scope_type` — defaults to `"all"`
  """
  def pending_review_session_fixture(
        %Node{} = node,
        %User{} = admin,
        catalog_items,
        opts \\ []
      ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    session =
      Repo.insert!(%Session{
        title: "Test Session #{System.unique_integer()}",
        session_code: "SO-TEST-#{System.unique_integer([:positive])}",
        description: "Fixture session",
        node_ids: Keyword.get(opts, :node_ids, [node.id]),
        collection_types: Keyword.get(opts, :collection_types, ["Library"]),
        scope_type: Keyword.get(opts, :scope_type, "all"),
        status: "pending_review",
        started_at: now,
        completed_at: now,
        total_items: length(catalog_items),
        checked_items: 0,
        missing_items: 0,
        items_with_changes: 0,
        created_by_id: admin.id
      })

    session
  end

  @doc """
  Insert a `StockOpname.Item` row for `catalog_item` into `session`
  with `check_status: "pending"` (default — never scanned).
  """
  def opname_item_fixture(%Session{} = session, %CatalogItem{} = catalog_item, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        session_id: session.id,
        item_id: catalog_item.id,
        collection_id: catalog_item.collection_id,
        check_status: "pending"
      })

    Repo.insert!(Item.changeset(%Item{}, attrs))
  end

  @doc """
  Insert a `StockOpname.Item` with `check_status: "missing"` — simulates
  a librarian explicitly marking the item as not found on the shelf.
  """
  def opname_item_missing_fixture(%Session{} = session, %CatalogItem{} = catalog_item) do
    opname_item_fixture(session, catalog_item, %{check_status: "missing"})
  end

  @doc """
  Insert a `StockOpname.Item` with `check_status: "checked"` and the given
  `changes` map — simulates a librarian scanning the item and recording
  field differences.

  Example:
      opname_item_checked_fixture(session, item, %{"condition" => "poor"})
  """
  def opname_item_checked_fixture(
        %Session{} = session,
        %CatalogItem{} = catalog_item,
        changes \\ %{},
        %User{} = checked_by
      ) do
    opname_item_fixture(session, catalog_item, %{
      check_status: "checked",
      changes: changes,
      has_changes: map_size(changes) > 0,
      scanned_at: DateTime.utc_now() |> DateTime.truncate(:second),
      checked_by_id: checked_by.id
    })
  end

  # ---------------------------------------------------------------------------
  # Sandbox helpers
  # ---------------------------------------------------------------------------

  @doc """
  Allow the `Task.async_stream` worker tasks spawned inside `approve_session/3`
  to check out connections from the current test's sandbox.

  Call this **before** invoking `approve_session/3` in any test that exercises
  the Step-3 JSONB change application path (i.e. when there are checked items
  with a non-empty `changes` map).

      setup do
        Voile.StockOpnameFixtures.allow_sandbox(self())
        :ok
      end
  """
  def allow_sandbox(test_pid) do
    Sandbox.mode(Repo, {:shared, test_pid})
  end

  # ---------------------------------------------------------------------------
  # Reload helpers
  # ---------------------------------------------------------------------------

  @doc """
  Reload a `CatalogItem` from the database, discarding any cached struct.
  Useful in tests to assert the state after an approval has been applied.

  Only selects columns that are guaranteed to exist in the DB to avoid errors
  when the Ecto schema is ahead of the migration state (e.g. `barcode`).
  """
  def reload_catalog_item(%CatalogItem{id: id}) do
    from(i in CatalogItem,
      where: i.id == ^id,
      select: %{
        id: i.id,
        availability: i.availability,
        condition: i.condition,
        status: i.status,
        location: i.location
      }
    )
    |> Repo.one!()
  end

  @doc """
  Reload multiple `CatalogItem` structs by their IDs.
  Returns a map of `%{id => map}` for easy assertion.

  Only selects columns that are guaranteed to exist in the DB to avoid errors
  when the Ecto schema is ahead of the migration state (e.g. `barcode`).
  """
  def reload_catalog_items(catalog_items) do
    ids = Enum.map(catalog_items, & &1.id)

    from(i in CatalogItem,
      where: i.id in ^ids,
      select: %{
        id: i.id,
        availability: i.availability,
        condition: i.condition,
        status: i.status,
        location: i.location
      }
    )
    |> Repo.all()
    |> Map.new(&{&1.id, &1})
  end

  @doc """
  Reload a `Collection` status from the database.
  Returns a map with `:id` and `:status` keys.
  """
  def reload_collection(%Collection{id: id}) do
    from(c in Collection,
      where: c.id == ^id,
      select: %{id: c.id, status: c.status}
    )
    |> Repo.one!()
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  # Ensure there is at least one Creator record and return its integer id.
  # `Collection.changeset` requires a non-null `creator_id`.
  # We bypass `get_or_create_creator/1` here because that function uses
  # `on_conflict: ..., conflict_target: :creator_name` which requires a unique
  # index on `creator_name` — not guaranteed to exist in the test DB.
  defp ensure_master_creator(%User{} = _user) do
    creator =
      Repo.insert!(%Voile.Schema.Master.Creator{
        creator_name: "Test Creator #{System.unique_integer()}",
        type: "Person",
        affiliation: "N/A",
        creator_contact: "N/A"
      })

    creator.id
  end
end
