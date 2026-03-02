defmodule Voile.ExternalBookSearch do
  @moduledoc """
  External book search module that aggregates results from OpenLibrary, Google Books, and OpenAlex.

  ## Async search

  Use `search_async/3` inside LiveView processes. It runs the HTTP work in
  `Voile.TaskSupervisor` so the LiveView socket is never blocked.
  Results are delivered as `{:external_search_result, query, results}` sent to the caller pid.
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

  # ── Public API ──────────────────────────────────────────────────────────────

  @doc """
  Synchronous search. Returns a (possibly empty) list of `Book` structs.
  """
  def search(query, opts \\ []) do
    do_search(query, opts)
  end

  @doc """
  Asynchronous search for use inside LiveView processes.

  Runs HTTP work in `Voile.TaskSupervisor` so the LiveView socket is never blocked.
  Results are delivered as `{:external_search_result, query, results}` sent to `caller_pid`.
  """
  def search_async(query, caller_pid, opts \\ []) do
    Task.Supervisor.start_child(Voile.TaskSupervisor, fn ->
      results = do_search(query, opts)
      send(caller_pid, {:external_search_result, query, results})
    end)

    :ok
  end

  @doc """
  Search a specific source only (bypasses cache).
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

  # ── Private ─────────────────────────────────────────────────────────────────

  defp do_search(query, opts) do
    limit = Keyword.get(opts, :limit, 10)

    tasks = [
      fn -> OpenLibrary.search(query, limit) end,
      fn -> GoogleBooks.search(query, limit) end,
      fn -> OpenAlex.search(query, limit) end
    ]

    Task.async_stream(tasks, fn task -> task.() end,
      timeout: 25_000,
      on_timeout: :kill_task
    )
    |> Enum.reduce([], fn
      {:ok, {:ok, results}}, acc ->
        results ++ acc

      {:ok, {:error, reason}}, acc ->
        Logger.warning("external_book_search: source error: #{inspect(reason)}")
        acc

      {:error, :timeout}, acc ->
        Logger.warning("external_book_search: source timed out")
        acc

      {:exit, reason}, acc ->
        Logger.warning("external_book_search: task exited: #{inspect(reason)}")
        acc
    end)
    |> Enum.sort_by(& &1.title)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
