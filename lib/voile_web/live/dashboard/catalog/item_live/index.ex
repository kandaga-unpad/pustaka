defmodule VoileWeb.Dashboard.Catalog.ItemLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Item

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    per_page = 10
    {items, total_pages} = Catalog.list_items_paginated(page, per_page)

    socket =
      socket
      |> stream(:items, items)
      |> assign(:page_title, "Listing Items")
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Item")
    |> assign(:item, Catalog.get_item!(id))
  end

  defp apply_action(socket, :new, _params) do
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
    {:noreply, stream_insert(socket, :items, item)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    item = Catalog.get_item!(id)
    {:ok, _} = Catalog.delete_item(item)

    {:noreply, stream_delete(socket, :items, item)}
  end
end
