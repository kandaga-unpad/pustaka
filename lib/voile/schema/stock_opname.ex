defmodule Voile.Schema.StockOpname do
  @moduledoc """
  The StockOpname context for inventory checking functionality.

  Handles stock opname (inventory check) sessions where librarians scan and verify
  physical items against database records.
  """

  import Ecto.Query, warn: false
  require Logger

  alias Voile.Repo

  alias Voile.Schema.StockOpname.{Session, LibrarianAssignment, Item, Notifier}
  alias Voile.Schema.Catalog.Item, as: CatalogItem
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Metadata.ResourceClass

  # ===========================================================================
  # SESSION MANAGEMENT
  # ===========================================================================

  @doc """
  Creates a new stock opname session (Super Admin only).

  ## Examples

      iex> create_session(%{title: "Jan 2026 Inventory", ...}, admin_user)
      {:ok, %Session{}}

  """
  def create_session(attrs \\ %{}, user) do
    %Session{}
    |> Session.changeset(Map.put(attrs, "created_by_id", user.id))
    |> Repo.insert()
  end

  @doc """
  List stock opname sessions with pagination and filters.

  ## Filter options:
    * `:status` - Filter by session status
    * `:node_id` - Filter by node
    * `:created_by_id` - Filter by creator
    * `:from_date` - Filter sessions created after this date
    * `:to_date` - Filter sessions created before this date
  """
  def list_sessions(page \\ 1, per_page \\ 10, filters \\ %{}) do
    base_query =
      from s in Session,
        order_by: [desc: s.inserted_at],
        preload: [:created_by, :reviewed_by, librarian_assignments: :user]

    query =
      base_query
      |> maybe_filter_by_status(filters[:status])
      |> maybe_filter_by_date_range(filters[:from_date], filters[:to_date])
      |> maybe_filter_by_creator(filters[:created_by_id])

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = ceil(total_count / per_page)
    offset = (page - 1) * per_page

    sessions =
      query
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    {sessions, total_pages, total_count}
  end

  defp maybe_filter_by_status(query, nil), do: query
  defp maybe_filter_by_status(query, ""), do: query
  defp maybe_filter_by_status(query, status), do: from(s in query, where: s.status == ^status)

  defp maybe_filter_by_date_range(query, nil, nil), do: query

  defp maybe_filter_by_date_range(query, from_date, nil) when not is_nil(from_date) do
    from(s in query, where: s.inserted_at >= ^from_date)
  end

  defp maybe_filter_by_date_range(query, nil, to_date) when not is_nil(to_date) do
    from(s in query, where: s.inserted_at <= ^to_date)
  end

  defp maybe_filter_by_date_range(query, from_date, to_date) do
    from(s in query, where: s.inserted_at >= ^from_date and s.inserted_at <= ^to_date)
  end

  defp maybe_filter_by_creator(query, nil), do: query
  defp maybe_filter_by_creator(query, ""), do: query

  defp maybe_filter_by_creator(query, creator_id),
    do: from(s in query, where: s.created_by_id == ^creator_id)

  @doc """
  Get a single stock opname session with all associations preloaded.
  """
  def get_session!(id) do
    Session
    |> Repo.get!(id)
    |> Repo.preload([
      :created_by,
      :updated_by,
      :reviewed_by,
      librarian_assignments: [:user],
      items: [:item, :collection, :checked_by]
    ])
  end

  @doc """
  Get a session without preloading items (for performance).
  Use this when you don't need the items list.
  """
  def get_session_without_items!(id) do
    Session
    |> Repo.get!(id)
    |> Repo.preload([
      :created_by,
      :updated_by,
      :reviewed_by,
      librarian_assignments: [:user]
    ])
  end

  @doc """
  Update a stock opname session.
  """
  def update_session(%Session{} = session, attrs, user) do
    session
    |> Session.changeset(Map.put(attrs, "updated_by_id", user.id))
    |> Repo.update()
  end

  @doc """
  @doc \"""
  Start a stock opname session (draft → in_progress).
  Only Super Admin can start sessions.
  Cannot start if status is "initializing".
  """
  def start_session(%Session{status: "initializing"} = _session, _admin_user) do
    {:error, :still_initializing}
  end

  def start_session(%Session{status: "draft"} = session, admin_user) do
    result =
      session
      |> Ecto.Changeset.change(%{
        status: "in_progress",
        started_at: DateTime.utc_now() |> DateTime.truncate(:second),
        updated_by_id: admin_user.id
      })
      |> Repo.update()

    case result do
      {:ok, updated_session} ->
        # Get librarians assigned to this session and send notification
        librarians = list_session_librarians(updated_session)

        Task.start(fn ->
          Notifier.deliver_session_started_notification(updated_session, librarians)
        end)

        {:ok, updated_session}

      error ->
        error
    end
  end

  def start_session(%Session{}, _admin_user) do
    {:error, :invalid_status}
  end

  @doc """
  Delete a stock opname session.
  Only allowed for 'approved' or 'cancelled' sessions.
  """
  def delete_session(%Session{status: status} = session, _user)
      when status in ["approved", "cancelled"] do
    Repo.delete(session)
  end

  def delete_session(%Session{}, _user) do
    {:error, :invalid_status_for_deletion}
  end

  @doc """
  Cancel a stock opname session.
  """
  def cancel_session(%Session{} = session, admin_user) do
    session
    |> Ecto.Changeset.change(%{
      status: "cancelled",
      updated_by_id: admin_user.id
    })
    |> Repo.update()
  end

  # ===========================================================================
  # LIBRARIAN ASSIGNMENT
  # ===========================================================================

  @doc """
  Get all librarians assigned to a session with their user details.
  """
  def list_session_librarians(%Session{} = session) do
    from(a in LibrarianAssignment,
      where: a.session_id == ^session.id,
      join: u in assoc(a, :user),
      select: u
    )
    |> Repo.all()
  end

  @doc """
  Assign librarians to a session.
  Creates LibrarianAssignment records for each user.
  """
  @dialyzer {:nowarn_function, assign_librarians: 3}
  def assign_librarians(%Session{} = session, user_ids, _admin_user)
      when is_list(user_ids) do
    # Validate that at least one librarian is assigned
    if user_ids == [] do
      {:error, :no_librarians_assigned}
    else
      result =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:assignments, fn repo, _changes ->
          assignments =
            Enum.map(user_ids, fn user_id ->
              %LibrarianAssignment{}
              |> LibrarianAssignment.changeset(%{
                session_id: session.id,
                user_id: user_id,
                work_status: "pending"
              })
              |> repo.insert()
            end)

          errors = Enum.filter(assignments, fn result -> match?({:error, _}, result) end)

          if errors == [] do
            {:ok, Enum.map(assignments, fn {:ok, a} -> a end)}
          else
            {:error, List.first(errors) |> elem(1)}
          end
        end)
        |> Ecto.Multi.run(:set_initializing, fn repo, %{assignments: _assignments} ->
          # Set status to initializing before spawning background task
          updated =
            session
            |> Ecto.Changeset.change(status: "initializing")
            |> repo.update!()

          {:ok, updated}
        end)
        |> Repo.transaction()

      case result do
        {:ok, %{assignments: assignments, set_initializing: updated_session}} ->
          # Spawn background task to initialize items
          Task.start(fn ->
            initialize_session_items_async(updated_session)
          end)

          {:ok, %{updated_session | librarian_assignments: assignments}}

        {:error, _failed_operation, failed_value, _changes_so_far} ->
          {:error, failed_value}
      end
    end
  end

  # Initialize session items asynchronously in batches.
  # Called from background task after session creation.
  defp initialize_session_items_async(%Session{} = session) do
    Logger.info("Starting async initialization for session #{session.id}")

    # Build query based on session scope - just get IDs
    items_query =
      from i in CatalogItem,
        where: i.unit_id in ^session.node_ids,
        join: c in Collection,
        on: c.id == i.collection_id,
        join: rc in ResourceClass,
        on: rc.id == c.type_id,
        where: rc.glam_type in ^session.collection_types,
        select: %{id: i.id, collection_id: i.collection_id}

    items_query =
      case session.scope_type do
        "collection" when not is_nil(session.scope_id) ->
          from i in items_query, where: i.collection_id == ^session.scope_id

        "location" when not is_nil(session.scope_id) ->
          from i in items_query, where: i.unit_id == ^session.scope_id

        _ ->
          items_query
      end

    items = Repo.all(items_query)
    total_items = length(items)

    Logger.info("Found #{total_items} items for session #{session.id}")

    # Update session total_items (keep status as initializing)
    session
    |> Ecto.Changeset.change(total_items: total_items)
    |> Repo.update!()

    # Batch insert with optimal batch size (PostgreSQL param limit / 8 fields)
    # Max safe: 65535 / 8 = 8191, using 5000 for safety margin
    batch_size = 5000
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second)

    items
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.each(fn {batch, index} ->
      opname_items =
        Enum.map(batch, fn item ->
          %{
            id: Ecto.UUID.generate(),
            session_id: session.id,
            item_id: item.id,
            collection_id: item.collection_id,
            check_status: "pending",
            has_changes: false,
            inserted_at: timestamp,
            updated_at: timestamp
          }
        end)

      # Insert batch
      Repo.insert_all(Item, opname_items)

      Logger.info(
        "Inserted batch #{index + 1} (#{length(batch)} items) for session #{session.id}"
      )
    end)

    # Update session status to draft after initialization completes
    updated_session =
      session
      |> Ecto.Changeset.change(status: "draft")
      |> Repo.update!()

    Logger.info(
      "Completed async initialization for session #{updated_session.id}, status changed to #{updated_session.status}"
    )

    :ok
  catch
    kind, reason ->
      Logger.error(
        "Failed to initialize session #{session.id}: #{inspect(kind)} - #{inspect(reason)}"
      )

      # Mark session as failed
      session
      |> Ecto.Changeset.change(%{
        status: "draft",
        notes: "Initialization failed: #{inspect(reason)}"
      })
      |> Repo.update()

      :error
  end

  @doc """
  Count the number of items currently added to a session.
  """
  def count_session_items(%Session{id: session_id}) do
    from(i in Item, where: i.session_id == ^session_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Check if all assigned librarians have completed their work.
  """
  def all_librarians_completed?(%Session{} = session) do
    session = Repo.preload(session, :librarian_assignments, force: true)

    Enum.all?(session.librarian_assignments, fn assignment ->
      assignment.work_status == "completed"
    end)
  end

  @doc """
  Start a librarian's work session.
  """
  def start_librarian_work(%Session{} = session, user) do
    assignment =
      Repo.get_by(LibrarianAssignment, session_id: session.id, user_id: user.id)

    if assignment do
      assignment
      |> Ecto.Changeset.change(%{
        work_status: "in_progress",
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.update()
    else
      {:error, :not_assigned}
    end
  end

  @doc """
  Complete a librarian's work session.
  """
  def complete_librarian_work(%Session{} = session, user, notes \\ nil) do
    assignment =
      Repo.get_by(LibrarianAssignment, session_id: session.id, user_id: user.id)

    cond do
      assignment ->
        # Regular librarian - update their assignment
        assignment
        |> Ecto.Changeset.change(%{
          work_status: "completed",
          completed_at: DateTime.utc_now() |> DateTime.truncate(:second),
          notes: notes
        })
        |> Repo.update()

      VoileWeb.Auth.Authorization.is_super_admin?(user) ->
        # Super admin without assignment - allow completion (they can scan without assignment)
        {:ok, :completed}

      true ->
        {:error, :not_assigned}
    end
  end

  @doc """
  Get librarian's progress in a session.
  Returns virtual assignment for super admins who aren't explicitly assigned.
  """
  def get_librarian_progress(%Session{} = session, user) do
    assignment =
      Repo.get_by(LibrarianAssignment, session_id: session.id, user_id: user.id)

    if assignment do
      {:ok, assignment}
    else
      # Check if user is super admin - allow them to scan without assignment
      if VoileWeb.Auth.Authorization.is_super_admin?(user) do
        # Return a virtual assignment for super admin
        items_checked =
          from(i in Item,
            where: i.session_id == ^session.id and i.checked_by_id == ^user.id,
            select: count(i.id)
          )
          |> Repo.one()

        virtual_assignment = %LibrarianAssignment{
          id: Ecto.UUID.generate(),
          session_id: session.id,
          user_id: user.id,
          work_status: "in_progress",
          items_checked: items_checked || 0,
          started_at: nil,
          completed_at: nil,
          notes: nil
        }

        {:ok, virtual_assignment}
      else
        {:error, :not_assigned}
      end
    end
  end

  # ===========================================================================
  # ITEM SCANNING AND CHECKING
  # ===========================================================================

  @doc """
  Search for items by barcode, legacy_item_code, or item_code.
  Returns a list to handle duplicates.
  """
  def find_items_for_scanning(%Session{} = session, search_term)
      when is_binary(search_term) do
    search_term = String.trim(search_term)

    # Search in items that are part of this session
    from(oi in Item,
      where: oi.session_id == ^session.id,
      join: i in CatalogItem,
      on: i.id == oi.item_id,
      where:
        i.barcode == ^search_term or
          i.legacy_item_code == ^search_term or
          i.item_code == ^search_term,
      preload: [:item, :collection]
    )
    |> Repo.all()
  end

  @doc """
  Add an item to the session with snapshot (transaction-based).
  This is called when initializing the session, not during scanning.
  """
  def add_item_to_session(%Session{} = session, item_id, _user) do
    item = Voile.Schema.Catalog.get_item!(item_id)

    attrs = Item.minimal_item_attrs(item.id, item.collection_id, session.id)

    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Mark an item as checked with changes recorded in JSONB.

  ## Parameters
  - session: The stock opname session
  - opname_item_id: The ID of the stock_opname_item record
  - changes: Map of changes found by librarian, e.g. %{"status" => "damaged", "condition" => "poor"}
  - scanned_barcode: Optional barcode scanned by librarian
  - notes: Optional notes about the check
  - user: The librarian checking the item

  ## Returns
  - {:ok, updated_item} on success
  - {:error, reason} on failure
  """
  @dialyzer {:nowarn_function, check_item: 5}
  def check_item(%Session{} = session, opname_item_id, changes, notes, user) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:lock_item, fn repo, _changes ->
      # Lock the opname_item row to prevent concurrent updates
      opname_item =
        from(oi in Item,
          where: oi.id == ^opname_item_id and oi.session_id == ^session.id,
          lock: "FOR UPDATE"
        )
        |> repo.one()

      if opname_item do
        {:ok, opname_item}
      else
        {:error, :not_found}
      end
    end)
    |> Ecto.Multi.update(:update_item, fn %{lock_item: opname_item} ->
      attrs = %{
        changes: changes || %{},
        check_status: "checked",
        scanned_at: DateTime.utc_now() |> DateTime.truncate(:second),
        checked_by_id: user.id,
        notes: notes,
        has_changes: map_size(changes || %{}) > 0
      }

      require Logger
      Logger.debug("Check item attrs: #{inspect(attrs)}")
      Logger.debug("Changes map: #{inspect(changes)}")
      Logger.debug("Notes: #{inspect(notes)}")

      opname_item
      |> Item.changeset(attrs)
    end)
    |> Ecto.Multi.run(:update_counters, fn repo, %{update_item: updated_item} ->
      # Update session counters
      session = repo.get!(Session, session.id)

      new_checked_count =
        from(oi in Item,
          where: oi.session_id == ^session.id and oi.check_status == "checked"
        )
        |> repo.aggregate(:count, :id)

      # Count missing items based on availability field in changes JSONB
      new_missing_count =
        from(oi in Item,
          where:
            oi.session_id == ^session.id and
              fragment("?->>'availability' = 'missing'", oi.changes)
        )
        |> repo.aggregate(:count, :id)

      new_changes_count =
        from(oi in Item,
          where: oi.session_id == ^session.id and oi.has_changes == true
        )
        |> repo.aggregate(:count, :id)

      session
      |> Ecto.Changeset.change(%{
        checked_items: new_checked_count,
        missing_items: new_missing_count,
        items_with_changes: new_changes_count
      })
      |> repo.update()

      # Update librarian's checked count
      assignment = repo.get_by(LibrarianAssignment, session_id: session.id, user_id: user.id)

      if assignment do
        librarian_checked_count =
          from(oi in Item,
            where: oi.session_id == ^session.id and oi.checked_by_id == ^user.id
          )
          |> repo.aggregate(:count, :id)

        assignment
        |> Ecto.Changeset.change(items_checked: librarian_checked_count)
        |> repo.update!()
      end

      {:ok, updated_item}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_item: opname_item}} ->
        # Preload associations for display
        opname_item = Repo.preload(opname_item, [:item, :collection, :checked_by])
        {:ok, opname_item}

      {:error, _step, error, _changes} ->
        {:error, error}
    end
  end

  @doc """
  Get session statistics.
  """
  def get_session_statistics(%Session{} = session) do
    session = Repo.preload(session, :items, force: true)

    %{
      total_items: session.total_items,
      checked_items: session.checked_items,
      pending_items: session.total_items - session.checked_items,
      missing_items: session.missing_items,
      items_with_changes: session.items_with_changes,
      progress_percentage:
        if(session.total_items > 0,
          do: Float.round(session.checked_items / session.total_items * 100, 2),
          else: 0.0
        )
    }
  end

  @doc """
  Recalculate and update session counters based on actual item states.
  Useful for fixing counter drift or after manual database updates.
  """
  def recalculate_session_counters(%Session{} = session) do
    checked_count =
      from(oi in Item,
        where: oi.session_id == ^session.id and oi.check_status == "checked"
      )
      |> Repo.aggregate(:count, :id)

    # Count missing items based on availability field in changes JSONB
    missing_count =
      from(oi in Item,
        where:
          oi.session_id == ^session.id and fragment("?->>'availability' = 'missing'", oi.changes)
      )
      |> Repo.aggregate(:count, :id)

    changes_count =
      from(oi in Item,
        where: oi.session_id == ^session.id and oi.has_changes == true
      )
      |> Repo.aggregate(:count, :id)

    session
    |> Ecto.Changeset.change(%{
      checked_items: checked_count,
      missing_items: missing_count,
      items_with_changes: changes_count
    })
    |> Repo.update()
  end

  @doc """
  List session items filtered by check status.
  """
  def list_session_items(%Session{} = session, check_status \\ nil) do
    query =
      from oi in Item,
        where: oi.session_id == ^session.id,
        order_by: [desc: oi.updated_at],
        preload: [:item, :collection, :checked_by]

    query =
      if check_status do
        from oi in query, where: oi.check_status == ^check_status
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  List recent checked items for a specific user with limit.
  Optimized query that limits at database level to avoid loading all items.
  """
  def list_recent_checked_items_by_user(%Session{} = session, user, limit \\ 10) do
    from(oi in Item,
      where: oi.session_id == ^session.id,
      where: oi.check_status == "checked",
      where: oi.checked_by_id == ^user.id,
      order_by: [desc: oi.updated_at],
      limit: ^limit,
      preload: [:item, :collection, :checked_by]
    )
    |> Repo.all()
  end

  @doc """
  List items with changes for a session.
  Optimized query with database-level filtering.
  """
  def list_items_with_changes(%Session{} = session) do
    from(oi in Item,
      where: oi.session_id == ^session.id,
      where: oi.has_changes == true,
      order_by: [desc: oi.updated_at],
      preload: [:item, :collection, :checked_by]
    )
    |> Repo.all()
  end

  @doc """
  List items with changes with pagination.
  """
  def list_items_with_changes_paginated(%Session{} = session, page \\ 1, per_page \\ 20) do
    query =
      from(oi in Item,
        where: oi.session_id == ^session.id,
        where: oi.has_changes == true,
        order_by: [desc: oi.updated_at],
        preload: [:item, :collection, :checked_by]
      )

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = ceil(total_count / per_page)

    items =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      items: items,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      has_prev: page > 1,
      has_next: page < total_pages
    }
  end

  @doc """
  List missing items for a session.
  Optimized query with database-level filtering.
  Missing items are tracked by changes->>'availability' = 'missing'.
  """
  def list_missing_items(%Session{} = session) do
    from(oi in Item,
      where: oi.session_id == ^session.id,
      where: fragment("?->>'availability' = 'missing'", oi.changes),
      order_by: [desc: oi.updated_at],
      preload: [:item, :collection, :checked_by]
    )
    |> Repo.all()
  end

  @doc """
  List missing items with pagination.
  """
  def list_missing_items_paginated(%Session{} = session, page \\ 1, per_page \\ 20) do
    query =
      from(oi in Item,
        where: oi.session_id == ^session.id,
        where: fragment("?->>'availability' = 'missing'", oi.changes),
        order_by: [desc: oi.updated_at],
        preload: [:item, :collection, :checked_by]
      )

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = ceil(total_count / per_page)

    items =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      items: items,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      has_prev: page > 1,
      has_next: page < total_pages
    }
  end

  @doc """
  List session items with pagination.
  """
  def list_session_items_paginated(
        %Session{} = session,
        page \\ 1,
        per_page \\ 50,
        filters \\ %{}
      ) do
    check_status = Map.get(filters, :check_status)
    has_changes = Map.get(filters, :has_changes)

    query =
      from oi in Item,
        where: oi.session_id == ^session.id,
        order_by: [desc: oi.updated_at],
        preload: [:item, :collection, :checked_by]

    query =
      if check_status do
        from oi in query, where: oi.check_status == ^check_status
      else
        query
      end

    query =
      if has_changes do
        from oi in query, where: oi.has_changes == true
      else
        query
      end

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = ceil(total_count / per_page)

    items =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      items: items,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      has_prev: page > 1,
      has_next: page < total_pages
    }
  end

  # ===========================================================================
  # SESSION COMPLETION AND REVIEW
  # ===========================================================================

  @doc """
  Complete a stock opname session (in_progress → pending_review).
  Flags unscanned items as missing within the session scope.
  Only Super Admin can complete sessions.
  """
  @dialyzer {:nowarn_function, complete_session: 2}
  def complete_session(
        %Session{status: "in_progress"} = session,
        admin_user
      ) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:flag_missing, fn repo, _changes ->
      # Flag unscanned items as missing
      {count, _} =
        from(oi in Item,
          where: oi.session_id == ^session.id and oi.check_status == "pending"
        )
        |> repo.update_all(
          set: [
            check_status: "missing",
            updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
          ]
        )

      {:ok, count}
    end)
    |> Ecto.Multi.run(:update_session, fn repo, %{flag_missing: missing_count} ->
      session
      |> Ecto.Changeset.change(%{
        status: "pending_review",
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        updated_by_id: admin_user.id,
        missing_items: missing_count
      })
      |> repo.update()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_session: session}} -> {:ok, session}
      {:error, _step, error, _changes} -> {:error, error}
    end
  end

  def complete_session(%Session{}, _admin_user) do
    {:error, :invalid_status}
  end

  @doc """
  List sessions pending review (Super Admin).
  """
  def list_sessions_pending_review(page \\ 1, per_page \\ 10) do
    list_sessions(page, per_page, %{status: "pending_review"})
  end

  @doc """
  Get session review summary with detailed statistics.
  """
  def get_session_review_summary(%Session{} = session) do
    session = Repo.preload(session, [:items, librarian_assignments: [:user]], force: true)

    items_by_status =
      Enum.group_by(session.items, & &1.check_status)
      |> Enum.map(fn {status, items} -> {status, length(items)} end)
      |> Enum.into(%{})

    items_with_changes =
      Enum.filter(session.items, & &1.has_changes)

    %{
      session: session,
      statistics: get_session_statistics(session),
      items_by_status: items_by_status,
      items_with_changes: items_with_changes,
      librarians: session.librarian_assignments
    }
  end

  @doc """
  Approve a stock opname session and apply all changes to main tables.
  """
  def approve_session(session, admin_user, notes \\ nil)

  @dialyzer {:nowarn_function, approve_session: 3}
  def approve_session(
        %Session{status: "pending_review"} = session,
        admin_user,
        notes
      ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:apply_changes, fn repo, _changes ->
      # Step 1: Mark all unchecked (pending) items as missing in catalog
      {unchecked_count, _} =
        from(i in CatalogItem,
          join: oi in Item,
          on: oi.item_id == i.id,
          where: oi.session_id == ^session.id,
          where: oi.check_status == "pending"
        )
        |> repo.update_all(
          set: [
            availability: "missing",
            updated_by_id: admin_user.id,
            updated_at: now
          ]
        )

      # Step 2: Mark items with availability changed to "missing" in catalog
      {missing_count, _} =
        from(i in CatalogItem,
          join: oi in Item,
          on: oi.item_id == i.id,
          where: oi.session_id == ^session.id,
          where: fragment("?->>'availability' = 'missing'", oi.changes)
        )
        |> repo.update_all(
          set: [
            availability: "missing",
            updated_by_id: admin_user.id,
            updated_at: now
          ]
        )

      # Step 3: Apply changes from JSONB to catalog items
      # Use efficient batch updates for large datasets (500k+ items)
      items_with_changes =
        from(oi in Item,
          where: oi.session_id == ^session.id,
          where: oi.has_changes == true,
          where: oi.check_status == "checked",
          where: not is_nil(oi.changes),
          select: %{
            item_id: oi.item_id,
            changes: oi.changes
          }
        )
        |> repo.all()

      # Process in chunks of 1000 to avoid memory issues
      changes_count =
        items_with_changes
        |> Enum.chunk_every(1000)
        |> Enum.reduce(0, fn chunk, acc ->
          # Build batch update queries for each field that changed
          # Batch update status
          status_updates =
            chunk
            |> Enum.filter(&Map.has_key?(&1.changes, "status"))
            |> Enum.map(&{&1.item_id, &1.changes["status"]})

          if status_updates != [] do
            {ids, values} = Enum.unzip(status_updates)

            repo.query!(
              "UPDATE items SET status = data.value, updated_by_id = $1, updated_at = $2
               FROM (SELECT unnest($3::uuid[]) as id, unnest($4::text[]) as value) AS data
               WHERE items.id = data.id",
              [admin_user.id, now, ids, values]
            )
          end

          # Batch update condition
          condition_updates =
            chunk
            |> Enum.filter(&Map.has_key?(&1.changes, "condition"))
            |> Enum.map(&{&1.item_id, &1.changes["condition"]})

          if condition_updates != [] do
            {ids, values} = Enum.unzip(condition_updates)

            repo.query!(
              "UPDATE items SET condition = data.value, updated_by_id = $1, updated_at = $2
               FROM (SELECT unnest($3::uuid[]) as id, unnest($4::text[]) as value) AS data
               WHERE items.id = data.id",
              [admin_user.id, now, ids, values]
            )
          end

          # Batch update availability
          availability_updates =
            chunk
            |> Enum.filter(&Map.has_key?(&1.changes, "availability"))
            |> Enum.map(&{&1.item_id, &1.changes["availability"]})

          if availability_updates != [] do
            {ids, values} = Enum.unzip(availability_updates)

            repo.query!(
              "UPDATE items SET availability = data.value, updated_by_id = $1, updated_at = $2
               FROM (SELECT unnest($3::uuid[]) as id, unnest($4::text[]) as value) AS data
               WHERE items.id = data.id",
              [admin_user.id, now, ids, values]
            )
          end

          # Batch update location
          location_updates =
            chunk
            |> Enum.filter(&Map.has_key?(&1.changes, "location"))
            |> Enum.map(&{&1.item_id, &1.changes["location"]})

          if location_updates != [] do
            {ids, values} = Enum.unzip(location_updates)

            repo.query!(
              "UPDATE items SET location = data.value, updated_by_id = $1, updated_at = $2
               FROM (SELECT unnest($3::uuid[]) as id, unnest($4::text[]) as value) AS data
               WHERE items.id = data.id",
              [admin_user.id, now, ids, values]
            )
          end

          # Batch update item_location_id
          item_location_updates =
            chunk
            |> Enum.filter(&Map.has_key?(&1.changes, "item_location_id"))
            |> Enum.map(&{&1.item_id, &1.changes["item_location_id"]})

          if item_location_updates != [] do
            {ids, values} = Enum.unzip(item_location_updates)

            repo.query!(
              "UPDATE items SET item_location_id = data.value, updated_by_id = $1, updated_at = $2
               FROM (SELECT unnest($3::uuid[]) as id, unnest($4::integer[]) as value) AS data
               WHERE items.id = data.id",
              [admin_user.id, now, ids, values]
            )
          end

          acc + length(chunk)
        end)

      {:ok, {changes_count, missing_count, unchecked_count}}
    end)
    |> Ecto.Multi.update(:update_session, fn _changes ->
      session
      |> Ecto.Changeset.change(%{
        status: "approved",
        approved_at: now,
        reviewed_at: now,
        reviewed_by_id: admin_user.id,
        review_notes: notes
      })
    end)
    |> Repo.transaction(timeout: :infinity)
    |> case do
      {:ok, %{update_session: session}} -> {:ok, session}
      {:error, _step, error, _changes} -> {:error, error}
    end
  end

  def approve_session(%Session{}, _admin_user, _notes) do
    {:error, :invalid_status}
  end

  @doc """
  Reject a stock opname session.
  """
  def reject_session(
        %Session{status: "pending_review"} = session,
        admin_user,
        reason
      ) do
    session
    |> Ecto.Changeset.change(%{
      status: "rejected",
      reviewed_at: DateTime.utc_now() |> DateTime.truncate(:second),
      reviewed_by_id: admin_user.id,
      rejection_reason: reason
    })
    |> Repo.update()
  end

  def reject_session(%Session{}, _admin_user, _reason) do
    {:error, :invalid_status}
  end

  @doc """
  Request revision on a session (send back to librarians).
  """
  def request_session_revision(
        %Session{status: "pending_review"} = session,
        admin_user,
        notes
      ) do
    session
    |> Ecto.Changeset.change(%{
      status: "in_progress",
      reviewed_by_id: admin_user.id,
      review_notes: notes,
      updated_by_id: admin_user.id
    })
    |> Repo.update()
  end

  def request_session_revision(%Session{}, _admin_user, _notes) do
    {:error, :invalid_status}
  end
end
