defmodule Voile.ExternalBookSearch.GoogleBooks do
  @moduledoc """
  Google Books API adapter for book search.
  """

  alias Voile.ExternalBookSearch.Book

  @base_url "https://www.googleapis.com/books/v1/volumes"

  @doc """
  Search Google Books for books matching the query.
  """
  def search(query, limit \\ 10) do
    params = [
      q: query,
      maxResults: limit,
      printType: "books",
      orderBy: "relevance"
    ]

    case Req.get(@base_url,
           params: params,
           receive_timeout: 20_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        items = Map.get(body, "items", [])
        {:ok, Enum.map(items, &parse_result/1)}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_result(item) do
    volume_info = Map.get(item, "volumeInfo", %{})

    # Get thumbnail
    image_links = Map.get(volume_info, "imageLinks", %{})
    thumbnail = Map.get(image_links, "thumbnail") || Map.get(image_links, "smallThumbnail")

    # Get authors
    authors = Map.get(volume_info, "authors", [])

    # Get description
    description = Map.get(volume_info, "description")

    # Get published date
    published_date = Map.get(volume_info, "publishedDate")

    # Get ISBNs
    industry_identifiers = Map.get(volume_info, "industryIdentifiers", [])

    isbn =
      Enum.find_value(industry_identifiers, fn identifier ->
        case Map.get(identifier, "type") do
          "ISBN_13" -> Map.get(identifier, "identifier")
          "ISBN_10" -> Map.get(identifier, "identifier")
          _ -> nil
        end
      end)

    # Get page count
    page_count = Map.get(volume_info, "pageCount")

    %Book{
      source: "googlebooks",
      external_id: Map.get(item, "id"),
      open_library_id: nil,
      title: Map.get(volume_info, "title", "Unknown Title"),
      authors: authors,
      publisher: Map.get(volume_info, "publisher"),
      published_date: published_date,
      description: description,
      thumbnail: thumbnail,
      isbn: isbn,
      page_count: page_count
    }
  end
end
