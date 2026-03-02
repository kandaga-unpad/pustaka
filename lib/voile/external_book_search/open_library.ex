defmodule Voile.ExternalBookSearch.OpenLibrary do
  @moduledoc """
  OpenLibrary API adapter for book search.
  """

  alias Voile.ExternalBookSearch.Book

  @base_url "https://openlibrary.org"

  @doc """
  Search OpenLibrary for books matching the query.
  """
  def search(query, limit \\ 10) do
    # Use the search API
    url = "#{@base_url}/search.json"

    params = [
      q: query,
      limit: limit,
      fields:
        "key,title,author_name,first_publish_year,publisher,isbn,cover_i,first_sentence,number_of_pages_median"
    ]

    # include identification in User-Agent to get higher rate limit
    headers = [
      {"User-Agent", "KandagaUnpad (chrisna.adhi@unpad.ac.id)"}
    ]

    case Req.get(url,
           params: params,
           headers: headers,
           receive_timeout: 20_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        docs = Map.get(body, "docs", [])
        {:ok, Enum.map(docs, &parse_result/1)}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_result(doc) do
    # Get cover image if available
    cover_id = Map.get(doc, "cover_i")

    thumbnail =
      if cover_id, do: "https://covers.openlibrary.org/b/id/#{cover_id}-M.jpg", else: nil

    # Get first ISBN
    isbns = Map.get(doc, "isbn", [])
    isbn = if isbns != [], do: List.first(isbns), else: nil

    # Get authors
    authors = Map.get(doc, "author_name", [])

    # Get first sentence (description)
    first_sentences = Map.get(doc, "first_sentence", [])
    description = if first_sentences != [], do: List.first(first_sentences), else: nil

    # Get Open Library key/id
    open_library_key = Map.get(doc, "key", "")
    open_library_id = if open_library_key != "", do: "OL#{open_library_key}", else: nil

    # Get published date safely
    first_publish_year = Map.get(doc, "first_publish_year")
    published_date = if first_publish_year, do: to_string(first_publish_year), else: nil

    %Book{
      source: "openlibrary",
      external_id: open_library_key,
      open_library_id: open_library_id,
      title: Map.get(doc, "title", "Unknown Title"),
      authors: authors,
      publisher: List.first(Map.get(doc, "publisher", [])),
      published_date: published_date,
      description: description,
      thumbnail: thumbnail,
      isbn: isbn,
      page_count: Map.get(doc, "number_of_pages_median")
    }
  end
end
