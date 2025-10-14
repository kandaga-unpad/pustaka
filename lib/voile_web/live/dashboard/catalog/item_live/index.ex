defmodule VoileWeb.Dashboard.Catalog.ItemLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Item

  @impl true
  def mount(_params, _session, socket) do
    # Check read permission for viewing items
    authorize!(socket, "items.read")

    page = 1
    per_page = 10
    search = ""

    # Load the first page of items on initial mount (restore previous behaviour)
    {items, total_pages} = Catalog.list_items_paginated(page, per_page)

    socket =
      socket
      |> stream(:items, items)
      |> assign(:page_title, "Listing Items")
      |> assign(:page, page)
      |> assign(:search, search)
      |> assign(:total_pages, total_pages)
      |> assign(:items_empty?, items == [])
      |> assign(:items_count, length(items))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    # Check update permission for editing items
    authorize!(socket, "items.update")

    socket
    |> assign(:page_title, "Edit Item")
    |> assign(:item, Catalog.get_item!(id))
  end

  defp apply_action(socket, :new, _params) do
    # Check create permission for creating new items
    authorize!(socket, "items.create")

    socket
    |> assign(:page_title, "New Item")
    |> assign(:item, %Item{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Items")
    |> assign(:item, nil)
  end

  @impl true
  def handle_info({VoileWeb.Dashboard.Catalog.ItemLive.FormComponent, {:saved, item}}, socket) do
    # Only insert into the visible list if user has an active search
    if socket.assigns[:search] && socket.assigns[:search] != "" do
      socket = stream_insert(socket, :items, item)
      items_count = (socket.assigns[:items_count] || 0) + 1
      {:noreply, assign(socket, %{items_empty?: false, items_count: items_count})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    # Check delete permission before deleting
    authorize!(socket, "items.delete")

    item = Catalog.get_item!(id)
    {:ok, _} = Catalog.delete_item(item)

    # If there is an active search, re-fetch the current page. Otherwise nothing to update.
    search = socket.assigns[:search] || ""

    if search != "" do
      page = socket.assigns[:page] || 1
      per_page = 10

      {items, total_pages} = Catalog.list_items_paginated(page, per_page, search)

      socket =
        socket
        |> stream(:items, items, reset: true)
        |> assign(:page, page)
        |> assign(:total_pages, total_pages)
        |> assign(:items_empty?, items == [])
        |> assign(:items_count, length(items))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page =
      case page do
        p when is_integer(p) -> p
        p when is_binary(p) -> String.to_integer(p)
        _ -> 1
      end

    per_page = 10
    search = socket.assigns[:search] || ""

    # Only paginate when the user has performed a search
    if search == "" do
      {:noreply, socket}
    else
      {items, total_pages} = Catalog.list_items_paginated(page, per_page, search)

      socket =
        socket
        |> stream(:items, items, reset: true)
        |> assign(:page, page)
        |> assign(:total_pages, total_pages)
        |> assign(:items_empty?, items == [])
        |> assign(:items_count, length(items))

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    page = 1
    per_page = 10

    # perform the search and show results
    {items, total_pages} = Catalog.list_items_paginated(page, per_page, q)

    socket =
      socket
      |> stream(:items, items, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:search, q)
      |> assign(:items_empty?, items == [])
      |> assign(:items_count, length(items))

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    # Clear current filter and show no results
    socket =
      socket
      |> stream(:items, [], reset: true)
      |> assign(:page, 1)
      |> assign(:total_pages, 0)
      |> assign(:search, "")
      |> assign(:items_empty?, true)
      |> assign(:items_count, 0)

    {:noreply, socket}
  end
end
