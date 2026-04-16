defmodule Voile.Schema.Library.Feats do
  @moduledoc """
  The Library Features context.

  Handles Read On Spot functionality for tracking item usage within the library,
  including scanning, recording, and reporting.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo

  alias Voile.Schema.Library.ReadOnSpot
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.System.Node
  alias Voile.Schema.Master.Location

  # -----------------------------------------------------------------------
  # Node & Location helpers
  # -----------------------------------------------------------------------

  def list_nodes do
    Repo.all(from n in Node, order_by: [asc: n.name])
  end

  def list_locations_by_node(node_id) do
    from(l in Location,
      where: l.node_id == ^node_id and l.is_active == true,
      order_by: [asc: l.location_name]
    )
    |> Repo.all()
  end

  # -----------------------------------------------------------------------
  # Item lookup for scanning
  # -----------------------------------------------------------------------

  def find_item_by_barcode(term) when is_binary(term) do
    term = String.trim(term)

    from(i in Item,
      where: i.barcode == ^term or i.item_code == ^term or i.inventory_code == ^term,
      preload: [:collection, :item_location, :node]
    )
    |> Repo.all()
  end

  # -----------------------------------------------------------------------
  # Read On Spot records
  # -----------------------------------------------------------------------

  def record_read_on_spot(attrs) when is_map(attrs) do
    %ReadOnSpot{}
    |> ReadOnSpot.changeset(attrs)
    |> Repo.insert()
  end

  def list_read_on_spots(opts \\ []) do
    query =
      from r in ReadOnSpot,
        order_by: [desc: fragment("COALESCE(?, ?)", r.read_at, r.inserted_at)],
        preload: [:node, :location, :recorded_by, item: :collection]

    query =
      if node_id = opts[:node_id] do
        where(query, [r], r.node_id == ^node_id)
      else
        query
      end

    query =
      if location_id = opts[:location_id] do
        where(query, [r], r.location_id == ^location_id)
      else
        query
      end

    query =
      if date_from = opts[:date_from] do
        where(query, [r], fragment("COALESCE(?, ?)", r.read_at, r.inserted_at) >= ^date_from)
      else
        query
      end

    query =
      if date_to = opts[:date_to] do
        where(query, [r], fragment("COALESCE(?, ?)", r.read_at, r.inserted_at) <= ^date_to)
      else
        query
      end

    query =
      if limit = opts[:limit] do
        limit(query, ^limit)
      else
        query
      end

    Repo.all(query)
  end

  def count_today(node_id \\ nil) do
    today = Date.utc_today()
    start_dt = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")
    end_dt = DateTime.new!(today, ~T[23:59:59], "Etc/UTC")

    query =
      from r in ReadOnSpot,
        where:
          fragment("COALESCE(?, ?)", r.read_at, r.inserted_at) >= ^start_dt and
            fragment("COALESCE(?, ?)", r.read_at, r.inserted_at) <= ^end_dt,
        select: count(r.id)

    query =
      if node_id do
        where(query, [r], r.node_id == ^node_id)
      else
        query
      end

    Repo.one(query) || 0
  end

  def count_this_month(node_id \\ nil) do
    today = Date.utc_today()
    start_of_month = Date.new!(today.year, today.month, 1)
    start_dt = DateTime.new!(start_of_month, ~T[00:00:00], "Etc/UTC")

    query =
      from r in ReadOnSpot,
        where: fragment("COALESCE(?, ?)", r.read_at, r.inserted_at) >= ^start_dt,
        select: count(r.id)

    query =
      if node_id do
        where(query, [r], r.node_id == ^node_id)
      else
        query
      end

    Repo.one(query) || 0
  end

  # -----------------------------------------------------------------------
  # Reports
  # -----------------------------------------------------------------------

  def daily_report(opts \\ [], pagination \\ []) do
    page = pagination[:page] || 1
    per_page = pagination[:per_page] || 25

    base_query =
      from r in ReadOnSpot,
        left_join: l in assoc(r, :location),
        join: n in assoc(r, :node),
        select: %{
          date: fragment("COALESCE(?, ?)::date", r.read_at, r.inserted_at),
          count: count(r.id),
          location_id: r.location_id,
          location_name: fragment("COALESCE(?, ?)", l.location_name, "—"),
          node_id: r.node_id,
          node_name: n.name
        },
        group_by: [
          fragment("COALESCE(?, ?)::date", r.read_at, r.inserted_at),
          r.location_id,
          l.location_name,
          r.node_id,
          n.name
        ],
        order_by: [
          desc: fragment("COALESCE(?, ?)::date", r.read_at, r.inserted_at),
          asc: n.name,
          asc: l.location_name
        ]

    query = apply_report_filters(base_query, opts)

    total_query = from(s in subquery(query), select: count())
    total = Repo.one(total_query) || 0
    data = query |> limit(^per_page) |> offset(^((page - 1) * per_page)) |> Repo.all()

    {data, total}
  end

  def monthly_report(opts \\ [], pagination \\ []) do
    page = pagination[:page] || 1
    per_page = pagination[:per_page] || 25

    base_query =
      from r in ReadOnSpot,
        left_join: l in assoc(r, :location),
        join: n in assoc(r, :node),
        select: %{
          month: fragment("DATE_TRUNC('month', COALESCE(?, ?))", r.read_at, r.inserted_at),
          count: count(r.id),
          location_id: r.location_id,
          location_name: fragment("COALESCE(?, ?)", l.location_name, "—"),
          node_id: r.node_id,
          node_name: n.name
        },
        group_by: [
          fragment("DATE_TRUNC('month', COALESCE(?, ?))", r.read_at, r.inserted_at),
          r.location_id,
          l.location_name,
          r.node_id,
          n.name
        ],
        order_by: [
          desc: fragment("DATE_TRUNC('month', COALESCE(?, ?))", r.read_at, r.inserted_at),
          asc: n.name,
          asc: l.location_name
        ]

    query = apply_report_filters(base_query, opts)

    total_query = from(s in subquery(query), select: count())
    total = Repo.one(total_query) || 0
    data = query |> limit(^per_page) |> offset(^((page - 1) * per_page)) |> Repo.all()

    {data, total}
  end

  @doc """
  Returns paginated detailed records for a specific date (daily) or month (monthly).
  opts: node_id, location_id, date (ISO8601 string), type ("daily"|"monthly"), page, per_page
  Returns {records, total_count}
  """
  def report_detail(opts \\ []) do
    type = opts[:type] || "daily"
    page = opts[:page] || 1
    per_page = opts[:per_page] || 20

    base_query =
      from r in ReadOnSpot,
        left_join: l in assoc(r, :location),
        join: n in assoc(r, :node),
        join: i in assoc(r, :item),
        left_join: c in assoc(i, :collection),
        left_join: cr in assoc(c, :mst_creator),
        left_join: rb in assoc(r, :recorded_by),
        order_by: [desc: fragment("COALESCE(?, ?)", r.read_at, r.inserted_at)],
        select: %{
          id: r.id,
          read_at: r.read_at,
          inserted_at: r.inserted_at,
          node_name: n.name,
          location_name: fragment("COALESCE(?, ?)", l.location_name, "—"),
          item_code: i.item_code,
          barcode: i.barcode,
          title: fragment("COALESCE(?, ?)", c.title, "Unknown Title"),
          author: cr.creator_name,
          recorded_by: rb.email
        }

    query = apply_detail_filters(base_query, opts, type)

    total = Repo.aggregate(query, :count, :id)
    records = query |> limit(^per_page) |> offset(^((page - 1) * per_page)) |> Repo.all()

    {records, total}
  end

  defp apply_detail_filters(query, opts, "daily") do
    query =
      if node_id = opts[:node_id] do
        where(query, [r], r.node_id == ^node_id)
      else
        query
      end

    query =
      if location_id = opts[:location_id] do
        where(query, [r], r.location_id == ^location_id)
      else
        query
      end

    if date_str = opts[:date] do
      case Date.from_iso8601(date_str) do
        {:ok, date} ->
          start_dt = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
          end_dt = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

          where(
            query,
            [r],
            fragment("COALESCE(?, ?)", r.read_at, r.inserted_at) >= ^start_dt and
              fragment("COALESCE(?, ?)", r.read_at, r.inserted_at) <= ^end_dt
          )

        _ ->
          query
      end
    else
      query
    end
  end

  defp apply_detail_filters(query, opts, "monthly") do
    query =
      if node_id = opts[:node_id] do
        where(query, [r], r.node_id == ^node_id)
      else
        query
      end

    query =
      if location_id = opts[:location_id] do
        where(query, [r], r.location_id == ^location_id)
      else
        query
      end

    if date_str = opts[:date] do
      case String.split(date_str, "-") do
        [year_str, month_str | _] ->
          year = String.to_integer(year_str)
          month = String.to_integer(month_str)
          start_dt = DateTime.new!(Date.new!(year, month, 1), ~T[00:00:00], "Etc/UTC")
          last_day = Date.days_in_month(Date.new!(year, month, 1))
          end_dt = DateTime.new!(Date.new!(year, month, last_day), ~T[23:59:59], "Etc/UTC")

          where(
            query,
            [r],
            fragment("COALESCE(?, ?)", r.read_at, r.inserted_at) >= ^start_dt and
              fragment("COALESCE(?, ?)", r.read_at, r.inserted_at) <= ^end_dt
          )

        _ ->
          query
      end
    else
      query
    end
  end

  defp apply_report_filters(query, opts) do
    query =
      if node_id = opts[:node_id] do
        where(query, [r], r.node_id == ^node_id)
      else
        query
      end

    query =
      if location_id = opts[:location_id] do
        where(query, [r], r.location_id == ^location_id)
      else
        query
      end

    query =
      if date_from = opts[:date_from] do
        where(query, [r], fragment("COALESCE(?, ?)", r.read_at, r.inserted_at) >= ^date_from)
      else
        query
      end

    if date_to = opts[:date_to] do
      where(query, [r], fragment("COALESCE(?, ?)", r.read_at, r.inserted_at) <= ^date_to)
    else
      query
    end
  end
end
