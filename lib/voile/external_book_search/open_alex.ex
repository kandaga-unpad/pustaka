defmodule Voile.ExternalBookSearch.OpenAlex do
  @moduledoc """
  OpenAlex API adapter for book search.
  """

  alias Voile.ExternalBookSearch.Book

  @base_url "https://api.openalex.org/works"

  @doc """
  Search OpenAlex for books matching the query.
  """
  def search(query, limit \\ 10) do
    # OpenAlex uses 'per_page' parameter
    params = [
      search: query,
      per_page: limit,
      filter: "type:book"
    ]

    headers = [
      {"User-Agent", "Voile/1.0 (https://github.com/voile; mailto:dev@voile.local)"}
    ]

    case Req.get(@base_url,
           params: params,
           headers: headers,
           receive_timeout: 20_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        results = Map.get(body, "results", [])
        {:ok, Enum.map(results, &parse_result/1)}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_result(work) do
    # Get primary location for best available info
    locations = Map.get(work, "locations", [])
    location = List.first(locations)
    source = if location, do: Map.get(location, "source"), else: nil

    # Get authorship (authors)
    authorship_list = Map.get(work, "authorships", [])

    authors =
      Enum.map(authorship_list, fn auth ->
        author = Map.get(auth, "author", %{})
        Map.get(author, "display_name", "Unknown Author")
      end)

    # Get publication date
    publication_date = Map.get(work, "publication_date")

    # Get title
    title = Map.get(work, "title", "Unknown Title")

    # Get description (OpenAlex uses 'abstract' as well)
    description = Map.get(work, "abstract") || Map.get(work, "description")

    # Get ISBN from best identifier (OpenAlex returns a list of ISBNs)
    ids = Map.get(work, "ids") || %{}

    isbn =
      case Map.get(ids, "isbn") do
        [first | _] -> first
        bin when is_binary(bin) -> bin
        _ -> nil
      end

    # Get page count from biblio
    biblio = Map.get(work, "biblio", %{})
    page_count = Map.get(biblio, "page_count")

    # Get publisher — host_organization may be nil even if the key is present
    host_organization = Map.get(work, "host_organization") || %{}

    publisher =
      Map.get(host_organization, "display_name") ||
        if source, do: Map.get(source, "display_name"), else: nil

    # Get thumbnail from OpenAlex
    thumbnail = get_best_thumbnail(work)

    # Get OpenAlex ID
    openalex_id = Map.get(work, "id")

    %Book{
      source: "openalex",
      external_id: openalex_id,
      open_library_id: nil,
      title: title,
      authors: authors,
      publisher: publisher,
      published_date: publication_date,
      description: description,
      thumbnail: thumbnail,
      isbn: isbn,
      page_count: page_count
    }
  end

  defp get_best_thumbnail(work) do
    # Try to get thumbnail from primary location
    locations = Map.get(work, "locations", [])

    location_with_cover =
      Enum.find(locations, fn loc ->
        case Map.get(loc, "source") do
          nil -> false
          source -> Map.get(source, "has_cover") == true
        end
      end)

    if location_with_cover do
      source = Map.get(location_with_cover, "source", %{})
      # OpenAlex provides cover images via their CDN
      source_id = Map.get(source, "id")

      if source_id do
        # Extract the OpenAlex ID from the source URL
        case String.split(source_id, "/") do
          [_, _, _, _, source_id_val] -> "https://openalex.org/#{source_id_val}-cover.jpg"
          _ -> nil
        end
      else
        nil
      end
    else
      nil
    end
  end
end
