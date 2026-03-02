defmodule Voile.ExternalBookSearch do
  @moduledoc """
  External book search module that aggregates results from OpenLibrary, Google Books, and OpenAlex.
  """

  require Logger

  alias Voile.ExternalBookSearch.OpenLibrary
  alias Voile.ExternalBookSearch.GoogleBooks
  alias Voile.ExternalBookSearch.OpenAlex

  defmodule Book do
    @moduledoc """
    External book data structure.
    """

    @derive Jason.Encoder
    @enforce_keys [:source, :title]
    defstruct [
      :source,
      :external_id,
      :open_library_id,
      :title,
      :authors,
      :publisher,
      :published_date,
      :description,
      :thumbnail,
      :isbn,
      :page_count
    ]

    @type t :: %__MODULE__{
            source: String.t(),
            external_id: String.t() | nil,
            open_library_id: String.t() | nil,
            title: String.t(),
            authors: [String.t()],
            publisher: String.t() | nil,
            published_date: String.t() | nil,
            description: String.t() | nil,
            thumbnail: String.t() | nil,
            isbn: String.t() | nil,
            page_count: integer() | nil
          }
  end

  @rate_limit_table :external_book_search_rate_limit
  @default_cooldown 60_000

  defp ensure_rate_table do
    case :ets.whereis(@rate_limit_table) do
      :undefined -> :ets.new(@rate_limit_table, [:named_table, :public, read_concurrency: true])
      _ -> :ok
    end
  end

  defp source_allowed?(source) do
    ensure_rate_table()

    case :ets.lookup(@rate_limit_table, source) do
      [{^source, until}] -> System.system_time(:millisecond) >= until
      [] -> true
    end
  end

  def mark_rate_limited(source, cooldown_ms \\ @default_cooldown) do
    ensure_rate_table()
    until = System.system_time(:millisecond) + cooldown_ms
    :ets.insert(@rate_limit_table, {source, until})
    :ok
  end

  @doc """
  Search all external book sources and return combined results.
  Each result includes a `source` field indicating where it came from.
  """
  def search(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    tasks = []

    tasks =
      if source_allowed?("openlibrary"),
        do: tasks ++ [fn -> OpenLibrary.search(query, limit) end],
        else: tasks

    tasks =
      if source_allowed?("googlebooks"),
        do: tasks ++ [fn -> GoogleBooks.search(query, limit) end],
        else: tasks

    tasks =
      if source_allowed?("openalex"),
        do: tasks ++ [fn -> OpenAlex.search(query, limit) end],
        else: tasks

    results =
      Task.async_stream(tasks, fn task -> task.() end,
        timeout: 15_000,
        on_timeout: :kill_task
      )
      |> Enum.reduce([], fn
        {:ok, {:ok, results}}, acc ->
          results ++ acc

        {:ok, {:error, {:http_error, 429}}} = entry, acc ->
          # mark whichever source returned 429 and log it
          Logger.warning("external book search rate limited: #{inspect(entry)}")
          acc

        {:ok, {:error, _reason}} = entry, acc ->
          Logger.error("external book search error: #{inspect(entry)}")
          acc

        {:error, _reason} = entry, acc ->
          Logger.error("external book search task failed: #{inspect(entry)}")
          acc

        {:exit, _reason} = entry, acc ->
          # task crashed or timed out
          Logger.error("external book search task exited: #{inspect(entry)}")
          acc
      end)

    Enum.sort_by(results, & &1.title)
  end

  @doc """
  Search a specific source only.
  """
  def search_source(query, source, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    case source do
      "openlibrary" -> OpenLibrary.search(query, limit)
      "googlebooks" -> GoogleBooks.search(query, limit)
      "openalex" -> OpenAlex.search(query, limit)
      _ -> {:error, :unknown_source}
    end
  end

  @doc """
  Convert external book data to collection attributes for prefill.
  """
  def to_collection_attrs(%Book{} = external_book) do
    %{}
    |> maybe_put("title", external_book.title)
    |> maybe_put("description", external_book.description)
    |> maybe_put("thumbnail", external_book.thumbnail)
    |> maybe_put("external_source", external_book.source)
    |> maybe_put("external_id", external_book.external_id)
    |> maybe_put(
      "external_authors",
      if(external_book.authors != [], do: Enum.join(external_book.authors, ", "))
    )
    |> maybe_put("external_publisher", external_book.publisher)
    |> maybe_put("external_published_date", external_book.published_date)
    |> maybe_put("external_isbn", external_book.isbn)
    |> maybe_put("external_olia", external_book.open_library_id)
  end

  defp maybe_put(_map, _key, nil), do: %{}
  defp maybe_put(_map, _key, ""), do: %{}
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # Used in adapters to prevent repeating on 429
  # new Req versions expect a `fun/2` (request, response_or_exception)
  def retry_no_429(_request, %{status: 429}), do: false

  def retry_no_429(request, response_or_exception),
    do: Req.Steps.retry({request, response_or_exception})
end
