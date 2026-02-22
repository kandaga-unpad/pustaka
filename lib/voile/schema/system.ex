defmodule Voile.Schema.System do
  @moduledoc """
  The System context.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo

  alias Voile.Schema.System.Node
  alias Voile.Schema.System.Setting
  alias Voile.Schema.System.SystemLog
  alias Voile.Schema.System.CollectionLog
  alias Voile.Schema.System.VisitorLog
  alias Voile.Schema.System.VisitorSurvey
  alias Voile.Schema.Master.Location

  @doc """
  Returns the list of nodes.

  ## Examples

      iex> list_nodes()
      [%Node{}, ...]

  """
  def list_nodes do
    Repo.all(Node)
  end

  @doc """
  Gets a single node.

  Raises `Ecto.NoResultsError` if the Node does not exist.

  ## Examples

      iex> get_node!(123)
      %Node{}

      iex> get_node!(456)
      ** (Ecto.NoResultsError)

  """
  def get_node!(id), do: Repo.get!(Node, id)

  @doc """
  Creates a node.

  ## Examples

      iex> create_node(%{field: value})
      {:ok, %Node{}}

      iex> create_node(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_node(attrs \\ %{}) do
    %Node{}
    |> Node.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a node.

  ## Examples

      iex> update_node(node, %{field: new_value})
      {:ok, %Node{}}

      iex> update_node(node, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_node(%Node{} = node, attrs) do
    node
    |> Node.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates node loan rules specifically.
  """
  def update_node_rules(%Node{} = node, attrs) do
    update_node(node, attrs)
  end

  @doc """
  Deletes a node.

  ## Examples

      iex> delete_node(node)
      {:ok, %Node{}}

      iex> delete_node(node)
      {:error, %Ecto.Changeset{}}

  """
  def delete_node(%Node{} = node) do
    Repo.delete(node)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking node changes.

  ## Examples

      iex> change_node(node)
      %Ecto.Changeset{data: %Node{}}

  """
  def change_node(%Node{} = node, attrs \\ %{}) do
    Node.changeset(node, attrs)
  end

  @doc """
  Fetches minimal node identity for cross-app token encoding.

  Returns only display fields — no collections, no users, no heavy associations.
  Used by Curatorian when building cross-app tokens so Atrium can display
  the organization name without a separate Voile database call.

  ## Returns

      {:ok, %{
        id:   integer(),
        name: String.t(),   # display name, e.g. "SD Negeri 1 Bandung"
        abbr: String.t()    # abbreviation, e.g. "SDN1BDG"
      }}
      {:error, :not_found}

  ## Examples

      iex> get_node_basic(1)
      {:ok, %{id: 1, name: "SD Negeri 1 Bandung", abbr: "SDN1BDG"}}

      iex> get_node_basic(999)
      {:error, :not_found}
  """
  def get_node_basic(nil), do: {:error, :not_found}

  def get_node_basic(node_id) do
    result =
      Repo.one(
        from n in Node,
          where: n.id == ^node_id,
          select: %{
            id: n.id,
            name: n.name,
            abbr: n.abbr
          }
      )

    case result do
      nil -> {:error, :not_found}
      node -> {:ok, node}
    end
  end

  @doc """
  Returns the list of settings.

  ## Examples

      iex> list_settings()
      [%Setting{}, ...]

  """
  def list_settings do
    Repo.all(Setting)
  end

  @doc """
  Gets a single setting.

  Raises `Ecto.NoResultsError` if the Setting does not exist.

  ## Examples

      iex> get_setting!(123)
      %Setting{}

      iex> get_setting!(456)
      ** (Ecto.NoResultsError)

  """
  def get_setting!(id), do: Repo.get!(Setting, id)

  @doc """
  Creates a setting.

  ## Examples

      iex> create_setting(%{field: value})
      {:ok, %Setting{}}

      iex> create_setting(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_setting(attrs \\ %{}) do
    %Setting{}
    |> Setting.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a setting.

  ## Examples

      iex> update_setting(setting, %{field: new_value})
      {:ok, %Setting{}}

      iex> update_setting(setting, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_setting(%Setting{} = setting, attrs) do
    setting
    |> Setting.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a setting.

  ## Examples

      iex> delete_setting(setting)
      {:ok, %Setting{}}

      iex> delete_setting(setting)
      {:error, %Ecto.Changeset{}}

  """
  def delete_setting(%Setting{} = setting) do
    Repo.delete(setting)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking setting changes.

  ## Examples

      iex> change_setting(setting)
      %Ecto.Changeset{data: %Setting{}}

  """
  def change_setting(%Setting{} = setting, attrs \\ %{}) do
    Setting.changeset(setting, attrs)
  end

  @doc """
  Gets a setting by its name.

  ## Examples

      iex> get_setting_by_name("reservation_notifications_enabled")
      %Setting{}

      iex> get_setting_by_name("nonexistent")
      nil

  """
  def get_setting_by_name(name) do
    Repo.get_by(Setting, setting_name: name)
  end

  @doc """
  Gets a setting value by name, returns default if not found.

  ## Examples

      iex> get_setting_value("reservation_notifications_enabled", "false")
      "true"

  """
  def get_setting_value(name, default \\ nil) do
    case get_setting_by_name(name) do
      %Setting{setting_value: value} -> value
      nil -> default
    end
  end

  @doc """
  Creates or updates a setting by name.

  ## Examples

      iex> upsert_setting("reservation_notifications_enabled", "true")
      {:ok, %Setting{}}

  """
  def upsert_setting(name, value) do
    case get_setting_by_name(name) do
      nil ->
        create_setting(%{setting_name: name, setting_value: value})

      setting ->
        update_setting(setting, %{setting_value: value})
    end
  end

  @doc """
  Returns the list of system_logs.

  ## Examples

      iex> list_system_logs()
      [%SystemLog{}, ...]

  """
  def list_system_logs do
    Repo.all(SystemLog)
  end

  @doc """
  Gets a single system_log.

  Raises `Ecto.NoResultsError` if the System log does not exist.

  ## Examples

      iex> get_system_log!(123)
      %SystemLog{}

      iex> get_system_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_system_log!(id), do: Repo.get!(SystemLog, id)

  @doc """
  Creates a system_log.

  ## Examples

      iex> create_system_log(%{field: value})
      {:ok, %SystemLog{}}

      iex> create_system_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_system_log(attrs \\ %{}) do
    %SystemLog{}
    |> SystemLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a system_log.

  ## Examples

      iex> update_system_log(system_log, %{field: new_value})
      {:ok, %SystemLog{}}

      iex> update_system_log(system_log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_system_log(%SystemLog{} = system_log, attrs) do
    system_log
    |> SystemLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a system_log.

  ## Examples

      iex> delete_system_log(system_log)
      {:ok, %SystemLog{}}

      iex> delete_system_log(system_log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_system_log(%SystemLog{} = system_log) do
    Repo.delete(system_log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking system_log changes.

  ## Examples

      iex> change_system_log(system_log)
      %Ecto.Changeset{data: %SystemLog{}}

  """
  def change_system_log(%SystemLog{} = system_log, attrs \\ %{}) do
    SystemLog.changeset(system_log, attrs)
  end

  @doc """
  Returns the list of collection_logs.

  ## Examples

      iex> list_collection_logs()
      [%CollectionLog{}, ...]

  """
  def list_collection_logs do
    Repo.all(CollectionLog)
  end

  @doc """
  Gets a single collection_log.

  Raises `Ecto.NoResultsError` if the Collection log does not exist.

  ## Examples

      iex> get_collection_log!(123)
      %CollectionLog{}

      iex> get_collection_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_collection_log!(id), do: Repo.get!(CollectionLog, id)

  @doc """
  Creates a collection_log.

  ## Examples

      iex> create_collection_log(%{field: value})
      {:ok, %CollectionLog{}}

      iex> create_collection_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_collection_log(attrs \\ %{}) do
    CollectionLog.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a collection_log.

  ## Examples

      iex> update_collection_log(collection_log, %{field: new_value})
      {:ok, %CollectionLog{}}

      iex> update_collection_log(collection_log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_collection_log(%CollectionLog{} = collection_log, attrs) do
    collection_log
    |> CollectionLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a collection_log.

  ## Examples

      iex> delete_collection_log(collection_log)
      {:ok, %CollectionLog{}}

      iex> delete_collection_log(collection_log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_collection_log(%CollectionLog{} = collection_log) do
    Repo.delete(collection_log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking collection_log changes.

  ## Examples

      iex> change_collection_log(collection_log)
      %Ecto.Changeset{data: %CollectionLog{}}

  """
  def change_collection_log(%CollectionLog{} = collection_log, attrs \\ %{}) do
    CollectionLog.changeset(collection_log, attrs)
  end

  alias Voile.Schema.System.UserApiToken
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Accounts.UserRoleAssignment
  alias Voile.Schema.Accounts.Role

  ## API Token Functions

  @doc """
  Creates a new API token for a user.
  Returns {:ok, token, plain_token} where plain_token should be shown to user once.
  """
  def create_api_token(user, attrs \\ %{}) do
    attrs = Map.put(attrs, "user_id", user.id)

    # Generate the plain token
    plain_token = UserApiToken.generate_token()

    # Add the hashed token to attrs
    attrs = Map.put(attrs, "hashed_token", UserApiToken.hash_token(plain_token))

    changeset = UserApiToken.create_changeset(%UserApiToken{}, attrs)

    case Repo.insert(changeset) do
      {:ok, token} ->
        # Return the plain token - this is the ONLY time it's available
        {:ok, token, plain_token}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists all API tokens for a user
  """
  def list_user_api_tokens(user) do
    UserApiToken
    |> where([t], t.user_id == ^user.id)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists all API tokens (admin only)
  """
  def list_all_api_tokens do
    UserApiToken
    |> order_by([t], desc: t.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Gets a single API token
  """
  def get_api_token(id) do
    UserApiToken
    |> preload(:user)
    |> Repo.get(id)
  end

  @doc """
  Verifies an API token and returns the associated user.
  Updates last_used_at timestamp.
  """
  def verify_api_token(plain_token, opts \\ []) do
    ip_address = Keyword.get(opts, :ip_address)

    hashed_token = UserApiToken.hash_token(plain_token)

    query =
      from t in UserApiToken.valid_tokens_query(),
        where: t.hashed_token == ^hashed_token,
        preload: [:user]

    case Repo.one(query) do
      nil ->
        {:error, :invalid_token}

      token ->
        # Check IP whitelist if configured
        if valid_ip?(token, ip_address) do
          # Update last used timestamp
          update_token_usage(token, ip_address)
          {:ok, token.user, token}
        else
          {:error, :ip_not_allowed}
        end
    end
  end

  defp valid_ip?(%UserApiToken{ip_whitelist: nil}, _ip), do: true
  defp valid_ip?(%UserApiToken{ip_whitelist: []}, _ip), do: true

  defp valid_ip?(%UserApiToken{ip_whitelist: whitelist}, ip) when is_binary(ip) do
    ip in whitelist
  end

  defp valid_ip?(_token, _ip), do: true

  defp update_token_usage(token, ip_address) do
    token
    |> Ecto.Changeset.change(%{
      last_used_at: DateTime.utc_now() |> DateTime.truncate(:second),
      last_used_ip: ip_address
    })
    |> Repo.update()
  end

  @doc """
  Updates an API token
  """
  def update_api_token(%UserApiToken{} = token, attrs) do
    token
    |> UserApiToken.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Revokes an API token
  """
  def revoke_api_token(%UserApiToken{} = token) do
    token
    |> Ecto.Changeset.change(%{revoked_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    |> Repo.update()
  end

  @doc """
  Deletes an API token
  """
  def delete_api_token(%UserApiToken{} = token) do
    Repo.delete(token)
  end

  @doc """
  Rotates an API token (revokes old, creates new with same settings)
  """
  def rotate_api_token(%UserApiToken{} = old_token) do
    Repo.transaction(fn ->
      # Revoke old token
      {:ok, _} = revoke_api_token(old_token)

      # Create new token with same settings
      attrs = %{
        "name" => old_token.name,
        "description" => old_token.description,
        "scopes" => old_token.scopes,
        "expires_at" => old_token.expires_at,
        "ip_whitelist" => old_token.ip_whitelist,
        "user_id" => old_token.user_id
      }

      case create_api_token(%User{id: old_token.user_id}, attrs) do
        {:ok, token, plain_token} -> {token, plain_token}
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Creates a master API token for a user (non-expiring with admin privileges).
  Returns {:ok, token, plain_token} where plain_token should be shown to user once.
  Only users with super_admin role can create master tokens.
  """
  def create_master_api_token(user, attrs \\ %{}) do
    # Check if user has super_admin role
    if has_role?(user, "super_admin") do
      # Merge with master token defaults
      master_attrs = %{
        "name" => "Master Token",
        "description" => "Non-expiring master token with full access",
        "scopes" => ["admin"],
        # Never expires
        "expires_at" => nil,
        # No IP restrictions
        "ip_whitelist" => nil
      }

      # Allow overriding defaults with provided attrs
      attrs = Map.merge(master_attrs, attrs)

      create_api_token(user, attrs)
    else
      {:error, :insufficient_permissions}
    end
  end

  @doc """
  Cleans up expired tokens (run periodically via cron/quantum)
  """
  def cleanup_expired_tokens do
    from(t in UserApiToken,
      where: not is_nil(t.expires_at),
      where: t.expires_at < ^DateTime.utc_now()
    )
    |> Repo.delete_all()
  end

  # Private helper functions

  defp has_role?(%User{} = user, role_name) do
    query =
      from ura in UserRoleAssignment,
        join: r in Role,
        on: ura.role_id == r.id,
        where: ura.user_id == ^user.id,
        where: r.name == ^role_name,
        where: is_nil(ura.expires_at) or ura.expires_at > ^DateTime.utc_now()

    Repo.exists?(query)
  end

  ## Visitor Management Functions

  @doc """
  Returns the list of visitor_logs with filtering and pagination.
  """
  def list_visitor_logs(opts \\ []) do
    query = from l in VisitorLog, order_by: [desc: l.check_in_time]

    query =
      if opts[:node_id] do
        where(query, [l], l.node_id == ^opts[:node_id])
      else
        query
      end

    query =
      if opts[:location_id] do
        where(query, [l], l.location_id == ^opts[:location_id])
      else
        query
      end

    query =
      if opts[:from_date] do
        where(query, [l], l.check_in_time >= ^opts[:from_date])
      else
        query
      end

    query =
      if opts[:to_date] do
        where(query, [l], l.check_in_time <= ^opts[:to_date])
      else
        query
      end

    query =
      if opts[:search] do
        search_term = "%#{opts[:search]}%"

        where(
          query,
          [l],
          ilike(l.visitor_identifier, ^search_term) or
            ilike(l.visitor_name, ^search_term) or
            ilike(l.visitor_origin, ^search_term)
        )
      else
        query
      end

    query =
      if opts[:preload] do
        preload(query, ^opts[:preload])
      else
        query
      end

    query =
      if opts[:limit] do
        limit(query, ^opts[:limit])
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets a single visitor_log.
  """
  def get_visitor_log!(id, opts \\ []) do
    query = from l in VisitorLog, where: l.id == ^id

    query =
      if opts[:preload] do
        preload(query, ^opts[:preload])
      else
        query
      end

    Repo.one!(query)
  end

  @doc """
  Creates a visitor_log (check-in).
  """
  def create_visitor_log(attrs \\ %{}) do
    attrs = Map.put_new(attrs, "check_in_time", DateTime.utc_now())

    %VisitorLog{}
    |> VisitorLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a visitor_log (e.g., for check-out).
  """
  def update_visitor_log(%VisitorLog{} = visitor_log, attrs) do
    visitor_log
    |> VisitorLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a visitor_log.
  """
  def delete_visitor_log(%VisitorLog{} = visitor_log) do
    Repo.delete(visitor_log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking visitor_log changes.
  """
  def change_visitor_log(%VisitorLog{} = visitor_log, attrs \\ %{}) do
    VisitorLog.changeset(visitor_log, attrs)
  end

  @doc """
  Returns the list of visitor_logs with filtering and pagination.
  Returns {[logs], total_pages, total_count}
  """
  def list_visitor_logs_paginated(page \\ 1, per_page \\ 50, opts \\ []) do
    offset = (page - 1) * per_page

    query = from l in VisitorLog, order_by: [desc: l.check_in_time]

    query =
      if opts[:node_id] do
        where(query, [l], l.node_id == ^opts[:node_id])
      else
        query
      end

    query =
      if opts[:location_id] do
        where(query, [l], l.location_id == ^opts[:location_id])
      else
        query
      end

    query =
      if opts[:from_date] do
        where(query, [l], l.check_in_time >= ^opts[:from_date])
      else
        query
      end

    query =
      if opts[:to_date] do
        where(query, [l], l.check_in_time <= ^opts[:to_date])
      else
        query
      end

    query =
      if opts[:search] do
        search_term = "%#{opts[:search]}%"

        where(
          query,
          [l],
          ilike(l.visitor_identifier, ^search_term) or
            ilike(l.visitor_name, ^search_term) or
            ilike(l.visitor_origin, ^search_term)
        )
      else
        query
      end

    query =
      if opts[:preload] do
        preload(query, ^opts[:preload])
      else
        query
      end

    # Get total count
    count_query = exclude(query, :order_by) |> exclude(:preload)
    total_count = Repo.aggregate(count_query, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    # Get paginated results
    logs =
      query
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    {logs, total_pages, total_count}
  end

  @doc """
  Returns the list of visitor_surveys with filtering.
  """
  def list_visitor_surveys(opts \\ []) do
    query = from s in VisitorSurvey, order_by: [desc: s.inserted_at]

    query =
      if opts[:node_id] do
        where(query, [s], s.node_id == ^opts[:node_id])
      else
        query
      end

    query =
      if opts[:location_id] do
        where(query, [s], s.location_id == ^opts[:location_id])
      else
        query
      end

    query =
      if opts[:from_date] do
        where(query, [s], s.inserted_at >= ^opts[:from_date])
      else
        query
      end

    query =
      if opts[:to_date] do
        where(query, [s], s.inserted_at <= ^opts[:to_date])
      else
        query
      end

    query =
      if opts[:rating] do
        where(query, [s], s.rating == ^opts[:rating])
      else
        query
      end

    query =
      if opts[:preload] do
        preload(query, ^opts[:preload])
      else
        query
      end

    query =
      if opts[:limit] do
        limit(query, ^opts[:limit])
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets a single visitor_survey.
  """
  def get_visitor_survey!(id, opts \\ []) do
    query = from s in VisitorSurvey, where: s.id == ^id

    query =
      if opts[:preload] do
        preload(query, ^opts[:preload])
      else
        query
      end

    Repo.one!(query)
  end

  @doc """
  Creates a visitor_survey.
  """
  def create_visitor_survey(attrs \\ %{}) do
    %VisitorSurvey{}
    |> VisitorSurvey.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a visitor_survey.
  """
  def update_visitor_survey(%VisitorSurvey{} = visitor_survey, attrs) do
    visitor_survey
    |> VisitorSurvey.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a visitor_survey.
  """
  def delete_visitor_survey(%VisitorSurvey{} = visitor_survey) do
    Repo.delete(visitor_survey)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking visitor_survey changes.
  """
  def change_visitor_survey(%VisitorSurvey{} = visitor_survey, attrs \\ %{}) do
    VisitorSurvey.changeset(visitor_survey, attrs)
  end

  @doc """
  Returns the list of visitor_surveys with filtering and pagination.
  Returns {[surveys], total_pages, total_count}
  """
  def list_visitor_surveys_paginated(page \\ 1, per_page \\ 50, opts \\ []) do
    offset = (page - 1) * per_page

    query = from s in VisitorSurvey, order_by: [desc: s.inserted_at]

    query =
      if opts[:node_id] do
        where(query, [s], s.node_id == ^opts[:node_id])
      else
        query
      end

    query =
      if opts[:location_id] do
        where(query, [s], s.location_id == ^opts[:location_id])
      else
        query
      end

    query =
      if opts[:from_date] do
        where(query, [s], s.inserted_at >= ^opts[:from_date])
      else
        query
      end

    query =
      if opts[:to_date] do
        where(query, [s], s.inserted_at <= ^opts[:to_date])
      else
        query
      end

    query =
      if opts[:rating] do
        where(query, [s], s.rating == ^opts[:rating])
      else
        query
      end

    query =
      if opts[:preload] do
        preload(query, ^opts[:preload])
      else
        query
      end

    # Get total count
    count_query = exclude(query, :order_by) |> exclude(:preload)
    total_count = Repo.aggregate(count_query, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    # Get paginated results
    surveys =
      query
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    {surveys, total_pages, total_count}
  end

  @doc """
  Returns visitor statistics for a given period and optional filters.
  """
  def get_visitor_statistics(opts \\ []) do
    from_date = opts[:from_date] || DateTime.utc_now() |> DateTime.add(-30, :day)
    to_date = opts[:to_date] || DateTime.utc_now()
    node_id = opts[:node_id]
    location_id = opts[:location_id]

    # Total visitors
    visitors_query =
      from l in VisitorLog, where: l.check_in_time >= ^from_date and l.check_in_time <= ^to_date

    visitors_query =
      if node_id, do: where(visitors_query, [l], l.node_id == ^node_id), else: visitors_query

    visitors_query =
      if location_id,
        do: where(visitors_query, [l], l.location_id == ^location_id),
        else: visitors_query

    total_visitors = Repo.aggregate(visitors_query, :count, :id)

    # Unique visitors
    unique_visitors =
      visitors_query
      |> select([l], l.visitor_identifier)
      |> distinct(true)
      |> Repo.aggregate(:count, :id)

    # By location/room
    by_room =
      visitors_query
      |> join(:inner, [l], loc in Location, on: l.location_id == loc.id)
      |> group_by([l, loc], [loc.id, loc.location_name])
      |> select([l, loc], %{room_id: loc.id, room_name: loc.location_name, count: count(l.id)})
      |> Repo.all()

    # By origin
    by_origin =
      visitors_query
      |> where([l], not is_nil(l.visitor_origin))
      |> group_by([l], l.visitor_origin)
      |> select([l], %{origin: l.visitor_origin, count: count(l.id)})
      |> order_by([l], desc: count(l.id))
      |> limit(10)
      |> Repo.all()

    # Daily trend
    daily_trend =
      visitors_query
      |> select([l], %{
        date: fragment("DATE(?)", l.check_in_time),
        count: count(l.id)
      })
      |> group_by([l], fragment("DATE(?)", l.check_in_time))
      |> order_by([l], fragment("DATE(?)", l.check_in_time))
      |> Repo.all()

    # Survey statistics
    surveys_query =
      from s in VisitorSurvey, where: s.inserted_at >= ^from_date and s.inserted_at <= ^to_date

    surveys_query =
      if node_id, do: where(surveys_query, [s], s.node_id == ^node_id), else: surveys_query

    surveys_query =
      if location_id,
        do: where(surveys_query, [s], s.location_id == ^location_id),
        else: surveys_query

    total_surveys = Repo.aggregate(surveys_query, :count, :id)

    avg_rating =
      case Repo.aggregate(surveys_query, :avg, :rating) do
        nil -> 0.0
        avg -> Decimal.to_float(avg) |> Float.round(2)
      end

    rating_distribution =
      surveys_query
      |> group_by([s], s.rating)
      |> select([s], %{rating: s.rating, count: count(s.id)})
      |> order_by([s], s.rating)
      |> Repo.all()

    %{
      total_visitors: total_visitors,
      unique_visitors: unique_visitors,
      by_room: by_room,
      by_origin: by_origin,
      daily_trend: daily_trend,
      surveys: %{
        total: total_surveys,
        average_rating: avg_rating,
        distribution: rating_distribution
      }
    }
  end
end
