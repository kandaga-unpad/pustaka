defmodule Voile.Utils.SearchHelper do
  @moduledoc """
  Helper functions for search functionality across the application
  """

  alias Voile.Schema.Search

  @doc """
  Fetches search suggestions for autocomplete functionality
  """
  def fetch_suggestions(query, _user_role \\ nil, limit \\ 8) do
    collections = Search.search_collections(query, %{per_page: div(limit, 2)})
    items = Search.search_items(query, %{per_page: div(limit, 2)})

    collection_suggestions =
      collections.results
      |> Enum.map(&%{type: "collection", title: &1.title, id: &1.id})

    item_suggestions =
      items.results
      |> Enum.map(&%{type: "item", title: &1.collection.title, id: &1.id})

    (collection_suggestions ++ item_suggestions)
    |> Enum.take(limit)
  end

  @doc """
  Builds search filters from URL parameters
  """
  def build_filters_from_params(params) do
    params
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case key do
        "status" when value != "" -> Map.put(acc, :status, value)
        "availability" when value != "" -> Map.put(acc, :availability, value)
        "condition" when value != "" -> Map.put(acc, :condition, value)
        "collection_type" when value != "" -> Map.put(acc, :collection_type, value)
        "access_level" when value != "" -> Map.put(acc, :access_level, value)
        "location" when value != "" -> Map.put(acc, :location, value)
        _ -> acc
      end
    end)
  end

  @doc """
  Determines user role from socket assigns or conn
  """
  def get_user_role(%Phoenix.LiveView.Socket{} = socket) do
    get_user_role_from_user(socket.assigns[:current_user])
  end

  def get_user_role(%Plug.Conn{} = conn) do
    get_user_role_from_user(conn.assigns[:current_user])
  end

  def get_user_role(user) when is_map(user) do
    get_user_role_from_user(user)
  end

  defp get_user_role_from_user(nil), do: "patron"
  defp get_user_role_from_user(%{user_role: %{name: "librarian"}}), do: "librarian"

  defp get_user_role_from_user(%{user_role: %{name: name}}) when name in ["admin", "superadmin"],
    do: "librarian"

  defp get_user_role_from_user(_), do: "patron"

  @doc """
  Sanitizes search query string
  """
  def sanitize_query(query) when is_binary(query) do
    query
    |> String.trim()
    |> String.replace(~r/[^\w\s\-'"]/, "")
    # Limit query length
    |> String.slice(0, 200)
  end

  def sanitize_query(_), do: ""

  @doc """
  Builds search URL with parameters
  """
  def search_url(query, opts \\ %{}) do
    base_path = "/search"
    type = Map.get(opts, :type, "universal")
    page = Map.get(opts, :page, 1)
    advanced = Map.get(opts, :advanced, false)

    path = if advanced, do: "#{base_path}/advanced", else: base_path

    params =
      %{"q" => query, "type" => type}
      |> maybe_add_param("page", page, page > 1)

    "#{path}?#{URI.encode_query(params)}"
  end

  defp maybe_add_param(params, _key, _value, false), do: params
  defp maybe_add_param(params, key, value, true), do: Map.put(params, key, to_string(value))

  @doc """
  Formats search result counts for display
  """
  def format_result_count(0), do: "No results"
  def format_result_count(1), do: "1 result"
  def format_result_count(count) when count > 1000, do: "#{div(count, 1000)}K+ results"
  def format_result_count(count), do: "#{count} results"

  @doc """
  Extracts search terms from query for highlighting
  """
  def extract_search_terms(query) when is_binary(query) do
    query
    |> String.downcase()
    |> String.split(~r/\s+/)
    |> Enum.reject(&(String.length(&1) < 2))
    # Limit number of terms to highlight
    |> Enum.take(5)
  end

  def extract_search_terms(_), do: []
end
