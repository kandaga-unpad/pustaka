defmodule Voile.ExternalBookSearch do
  @moduledoc """
  External book search module that aggregates results from OpenLibrary, Google Books, and OpenAlex.
  """

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

  @doc """
  Search all external book sources and return combined results.
  Each result includes a `source` field indicating where it came from.
  """
  def search(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    # Run all searches in parallel
    results =
      Task.async_stream(
        [
          fn -> OpenLibrary.search(query, limit) end,
          fn -> GoogleBooks.search(query, limit) end,
          fn -> OpenAlex.search(query, limit) end
        ],
        fn task -> task.() end,
        timeout: 15_000
      )
      |> Enum.reduce([], fn
        {:ok, {:ok, results}}, acc -> results ++ acc
        {:ok, {:error, _}}, acc -> acc
        {:error, _}, acc -> acc
      end)

    # Sort by relevance (simple alphabetical for now)
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
end
