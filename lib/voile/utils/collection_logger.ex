defmodule Voile.Utils.CollectionLogger do
  @moduledoc """
  Audit logging utilities for Collection operations.

  This module provides functions to log collection-related activities, errors,
  and track user actions for audit purposes in the Voile library management system.

  ## Features
  - Action logging with context (IP, user agent, session)
  - Error logging with detailed error information
  - Before/after value tracking for changes
  - Performance metrics (duration tracking)
  - Query helpers for retrieving audit logs

  ## Usage Examples

  ### Basic Action Logging
  ```elixir
  # Simple action log
  CollectionLogger.log_action(collection_id, user_id, "create")

  # Action with custom title and message
  CollectionLogger.log_action(collection_id, user_id, "publish", [
    title: "Collection Published",
    message: "Collection 'My Book Collection' was published successfully"
  ])
  ```

  ### Advanced Action Logging with Context
  ```elixir
  # Full context logging (recommended for web requests)
  CollectionLogger.log_action(collection_id, user_id, "update", [
    title: "Collection Updated",
    message: "Collection metadata was modified",
    old_values: %{title: "Old Title", status: "draft"},
    new_values: %{title: "New Title", status: "published"},
    ip_address: "192.168.1.100",
    user_agent: "Mozilla/5.0...",
    session_id: "abc123",
    request_id: "req-456",
    duration_ms: 150,
    metadata: %{fields_changed: ["title", "status"]}
  ])
  ```

  ### Error Logging
  ```elixir
  # Log validation errors
  case Collection.changeset(collection, attrs) |> Repo.update() do
    {:ok, collection} ->
      # success handling
    {:error, changeset} ->
      CollectionLogger.log_error(collection.id, user_id, "update", changeset)
  end

  # Log custom errors
  CollectionLogger.log_error(collection_id, user_id, "delete",
    "Cannot delete collection with active items")
  ```

  ### Integration in Phoenix Controllers
  ```elixir
  def update(conn, %{"id" => id, "collection" => collection_params}) do
    collection = Catalog.get_collection!(id)
    user_id = conn.assigns.current_user.id

    # Track old values before update
    old_values = Map.take(collection, [:title, :status, :description])
    start_time = System.monotonic_time(:millisecond)

    case Catalog.update_collection(collection, collection_params) do
      {:ok, updated_collection} ->
        duration = System.monotonic_time(:millisecond) - start_time
        new_values = Map.take(updated_collection, [:title, :status, :description])

        # Log successful update
        CollectionLogger.log_action(updated_collection.id, user_id, "update", [
          title: "Collection Updated",
          message: "Collection '\#{updated_collection.title}' updated successfully",
          old_values: old_values,
          new_values: new_values,
          duration_ms: duration,
          ip_address: get_ip_address(conn),
          user_agent: get_req_header(conn, "user-agent") |> List.first(),
          session_id: get_session(conn, :session_id),
          metadata: %{changed_fields: find_changed_fields(old_values, new_values)}
        ])

        render(conn, :show, collection: updated_collection)

      {:error, changeset} ->
        # Log error
        CollectionLogger.log_error(collection.id, user_id, "update", changeset, [
          ip_address: get_ip_address(conn),
          user_agent: get_req_header(conn, "user-agent") |> List.first()
        ])

        render(conn, :edit, collection: collection, changeset: changeset)
    end
  end
  ```

  ### Query Examples
  ```elixir
  # Get recent activity for a collection
  recent_logs = CollectionLogger.recent_logs(collection_id, 20)

  # Get user activity from last week
  last_week = DateTime.utc_now() |> DateTime.add(-7, :day)
  user_logs = CollectionLogger.user_activity(user_id, last_week)

  # Get all user activity
  all_user_logs = CollectionLogger.user_activity(user_id)
  ```

  ## Available Action Types
  The following action types are predefined in the schema:
  - `"create"` - Collection creation
  - `"update"` - Collection modification
  - `"delete"` - Collection deletion
  - `"publish"` - Publishing collection
  - `"unpublish"` - Unpublishing collection
  - `"archive"` - Archiving collection
  - `"restore"` - Restoring archived collection
  - `"import"` - Data import operations
  - `"export"` - Data export operations

  ## Options for log_action/4 and log_error/5

  ### Context Options (Recommended)
  - `:ip_address` - Client IP address
  - `:user_agent` - Client user agent string
  - `:session_id` - User session identifier
  - `:request_id` - Unique request identifier

  ### Change Tracking Options
  - `:old_values` - Map of values before change
  - `:new_values` - Map of values after change

  ### Performance Options
  - `:duration_ms` - Operation duration in milliseconds

  ### Custom Options
  - `:title` - Custom log title (defaults to "Collection {action}")
  - `:message` - Custom log message (defaults to "Collection was {action}")
  - `:action_type` - Override action type (defaults to action)
  - `:metadata` - Additional metadata map

  ## Best Practices

  1. **Always log in service/context layers**, not in controllers
  2. **Include context information** (IP, user agent) for security auditing
  3. **Track before/after values** for important changes
  4. **Use descriptive titles and messages** for better audit trails
  5. **Log both successes and failures** for complete audit coverage
  6. **Include performance metrics** for operation monitoring
  7. **Use structured metadata** for easier querying and analysis
  """

  import Ecto.Query
  alias Voile.Schema.System.CollectionLog
  alias Voile.Repo

  @doc """
  Logs a successful action performed on a collection.

  ## Parameters
  - `collection_id` - UUID of the collection
  - `user_id` - UUID of the user performing the action
  - `action` - String describing the action (e.g., "create", "update", "delete")
  - `opts` - Keyword list of additional options (see module documentation)

  ## Returns
  - `{:ok, %CollectionLog{}}` - Successfully logged
  - `{:error, %Ecto.Changeset{}}` - Validation or database error

  ## Examples

      # Simple logging
      {:ok, log} = CollectionLogger.log_action(collection_id, user_id, "create")

      # With context and change tracking
      {:ok, log} = CollectionLogger.log_action(collection_id, user_id, "update", [
        title: "Collection Title Updated",
        message: "Changed title from 'Old' to 'New'",
        old_values: %{title: "Old Title"},
        new_values: %{title: "New Title"},
        ip_address: "192.168.1.100",
        duration_ms: 234
      ])
  """
  def log_action(collection_id, user_id, action, opts \\ []) do
    attrs = %{
      collection_id: collection_id,
      user_id: user_id,
      action: action,
      action_type: Keyword.get(opts, :action_type, action),
      title: Keyword.get(opts, :title, "Collection #{action}"),
      message: Keyword.get(opts, :message, "Collection was #{action}"),
      old_values: Keyword.get(opts, :old_values),
      new_values: Keyword.get(opts, :new_values),
      ip_address: Keyword.get(opts, :ip_address),
      user_agent: Keyword.get(opts, :user_agent),
      session_id: Keyword.get(opts, :session_id),
      request_id: Keyword.get(opts, :request_id),
      duration_ms: Keyword.get(opts, :duration_ms),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    CollectionLog.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Logs an error that occurred during a collection operation.

  Automatically handles different error types and formats them appropriately.

  ## Parameters
  - `collection_id` - UUID of the collection
  - `user_id` - UUID of the user who attempted the action
  - `action` - String describing the attempted action
  - `error` - The error that occurred (Changeset, Exception, or string)
  - `opts` - Keyword list of additional options

  ## Returns
  - `{:ok, %CollectionLog{}}` - Successfully logged
  - `{:error, %Ecto.Changeset{}}` - Validation or database error

  ## Examples

      # Log changeset validation errors
      case Repo.update(changeset) do
        {:error, changeset} ->
          CollectionLogger.log_error(collection_id, user_id, "update", changeset)
      end

      # Log custom error messages
      CollectionLogger.log_error(collection_id, user_id, "delete",
        "Cannot delete collection with active reservations")

      # Log with context
      CollectionLogger.log_error(collection_id, user_id, "publish", error, [
        ip_address: "192.168.1.100",
        metadata: %{attempted_status: "published"}
      ])
  """
  def log_error(collection_id, user_id, action, error, opts \\ []) do
    error_message =
      case error do
        %Ecto.Changeset{} -> "Validation failed: #{inspect(error.errors)}"
        %{message: message} -> message
        binary when is_binary(binary) -> binary
        other -> inspect(other)
      end

    attrs = %{
      collection_id: collection_id,
      user_id: user_id,
      action: action,
      title: "Collection #{action} failed",
      message: error_message,
      metadata: Map.put(Keyword.get(opts, :metadata, %{}), :error_details, error)
    }

    CollectionLog.error_changeset(Map.merge(attrs, Map.new(opts)))
    |> Repo.insert()
  end

  @doc """
  Retrieves recent log entries for a specific collection.

  Returns logs ordered by most recent first, with user information preloaded.

  ## Parameters
  - `collection_id` - UUID of the collection
  - `limit` - Maximum number of logs to return (default: 10)

  ## Returns
  List of `%CollectionLog{}` structs with `:user` association preloaded

  ## Examples

      # Get last 10 logs
      logs = CollectionLogger.recent_logs(collection_id)

      # Get last 50 logs
      logs = CollectionLogger.recent_logs(collection_id, 50)

      # Access user information
      Enum.each(logs, fn log ->
        IO.puts "\#{log.user.fullname} performed \#{log.action} at \#{log.inserted_at}"
      end)
  """
  def recent_logs(collection_id, limit \\ 10) do
    CollectionLog
    |> where([l], l.collection_id == ^collection_id)
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> preload([:user])
    |> Repo.all()
  end

  @doc """
  Retrieves activity logs for a specific user.

  Returns logs ordered by most recent first, with collection information preloaded.
  Optionally filter by date range.

  ## Parameters
  - `user_id` - UUID of the user
  - `from_date` - Optional DateTime to filter logs from (default: all time)

  ## Returns
  List of `%CollectionLog{}` structs with `:collection` association preloaded

  ## Examples

      # Get all user activity
      logs = CollectionLogger.user_activity(user_id)

      # Get activity from last week
      last_week = DateTime.utc_now() |> DateTime.add(-7, :day)
      recent_logs = CollectionLogger.user_activity(user_id, last_week)

      # Get activity from specific date
      start_date = ~U[2024-01-01 00:00:00Z]
      logs = CollectionLogger.user_activity(user_id, start_date)

      # Access collection information
      Enum.each(logs, fn log ->
        collection_title = log.collection.title
        IO.puts "Action: \#{log.action} on '\#{collection_title}'"
      end)
  """
  def user_activity(user_id, from_date \\ nil) do
    query =
      CollectionLog
      |> where([l], l.user_id == ^user_id)
      |> order_by([l], desc: l.inserted_at)

    query =
      if from_date do
        where(query, [l], l.inserted_at >= ^from_date)
      else
        query
      end

    query
    |> preload([:collection])
    |> Repo.all()
  end
end
