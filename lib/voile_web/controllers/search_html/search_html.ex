defmodule VoileWeb.SearchHTML do
  @moduledoc """
  This module contains pages rendered by SearchController.
  """

  use VoileWeb, :html

  embed_templates "*"

  @doc """
  Returns CSS classes for status badges
  """
  def status_class(status) do
    case status do
      "active" -> "bg-green-100 text-green-800"
      "inactive" -> "bg-yellow-100 text-yellow-800"
      "archived" -> "bg-gray-100 text-gray-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  @doc """
  Returns CSS classes for availability badges
  """
  def availability_class(availability) do
    case availability do
      "available" -> "bg-green-100 text-green-800"
      "checked_out" -> "bg-red-100 text-red-800"
      "reserved" -> "bg-yellow-100 text-yellow-800"
      "reference" -> "bg-blue-100 text-blue-800"
      "lost" -> "bg-red-100 text-red-800"
      "damaged" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  @doc """
  Returns CSS classes for condition badges
  """
  def condition_class(condition) do
    case condition do
      "excellent" -> "bg-green-100 text-green-800"
      "good" -> "bg-blue-100 text-blue-800"
      "fair" -> "bg-yellow-100 text-yellow-800"
      "poor" -> "bg-orange-100 text-orange-800"
      "damaged" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  @doc """
  Truncates text to a specified length
  """
  def truncate_text(text, length \\ 100)

  def truncate_text(text, length) when is_binary(text) do
    if String.length(text) <= length do
      text
    else
      String.slice(text, 0, length) <> "..."
    end
  end

  def truncate_text(nil, _length), do: ""

  @doc """
  Highlights search terms in text
  """
  def highlight_search_term(text, search_term) when is_binary(text) and is_binary(search_term) do
    if String.trim(search_term) == "" do
      text
    else
      pattern = ~r/(#{Regex.escape(search_term)})/i
      String.replace(text, pattern, "<mark class=\"bg-yellow-200\">\\1</mark>")
    end
  end

  def highlight_search_term(text, _search_term), do: text || ""

  @doc """
  Returns dynamic page title based on GLAM type
  """
  def search_page_title(glam_type) do
    case glam_type do
      "Library" -> "Search Library Collection"
      "Gallery" -> "Search Gallery Collection"
      "Archive" -> "Search Archive Collection"
      "Museum" -> "Search Museum Collection"
      _ -> "Search Collections"
    end
  end

  @doc """
  Returns dynamic page description based on GLAM type
  """
  def search_page_description(glam_type) do
    case glam_type do
      "Library" -> "Find books, journals, articles, and published materials"
      "Gallery" -> "Discover visual arts, photographs, and artistic collections"
      "Archive" -> "Explore historical documents, records, and institutional materials"
      "Museum" -> "Browse artifacts, specimens, and cultural objects"
      _ -> "Find collections and resources across all categories"
    end
  end

  @doc """
  Generates a range of page numbers for pagination
  """
  def page_range(current_page, total_pages, window \\ 5) do
    half_window = div(window, 2)

    start_page = max(1, current_page - half_window)
    end_page = min(total_pages, current_page + half_window)

    # Adjust range if we're near the beginning or end
    {start_page, end_page} =
      if end_page - start_page + 1 < window && total_pages >= window do
        if start_page == 1 do
          {start_page, min(total_pages, window)}
        else
          {max(1, total_pages - window + 1), end_page}
        end
      else
        {start_page, end_page}
      end

    start_page..end_page
  end

  @doc """
  Builds search parameters for pagination links
  """
  def build_search_params(search_params, search_type, glam_type, page) do
    base_params = %{
      "type" => search_type,
      "glam_type" => glam_type,
      "page" => page
    }

    # Flatten search params and add them to base params
    search_map =
      search_params
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        if value != "" do
          Map.put(acc, "search[#{key}]", value)
        else
          acc
        end
      end)

    Map.merge(base_params, search_map)
    |> URI.encode_query()
  end

  @doc """
  Builds complete URL for advanced search pagination
  """
  def build_advanced_search_url(search_params, search_type, glam_type, page) do
    base_url = "/search/advanced"

    # Build query parameters
    query_params = [
      {"type", search_type},
      {"glam_type", glam_type},
      {"page", page}
    ]

    # Add search parameters that have values
    search_query_params =
      search_params
      |> Enum.reduce([], fn {key, value}, acc ->
        if value != "" do
          [{"search[#{key}]", value} | acc]
        else
          acc
        end
      end)

    all_params = query_params ++ search_query_params
    query_string = URI.encode_query(all_params)
    "#{base_url}?#{query_string}"
  end

  @doc """
  Trim title for display purposes.
  """
  def trim_title(title, max_length \\ 55) do
    trimmed =
      title |> String.trim() |> String.slice(0, max_length) |> String.trim_trailing()

    if String.length(title |> String.trim()) > max_length do
      trimmed <> "..."
    else
      trimmed
    end
  end

  @doc """
  Trim and reduce description text for display purposes.
  """
  def trim_and_reduce_description(description, max_length \\ 100) do
    trimmed =
      description |> String.trim() |> String.slice(0, max_length) |> String.trim_trailing()

    if String.length(description |> String.trim()) > max_length do
      trimmed <> "..."
    else
      trimmed
    end
  end
end
