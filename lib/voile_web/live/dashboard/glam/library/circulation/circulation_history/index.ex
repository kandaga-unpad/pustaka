defmodule VoileWeb.Dashboard.Glam.Library.Circulation.CirculationHistory.Index do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Glam.Library.Circulation.Helpers

  alias Voile.Schema.Library.Circulation
  alias VoileWeb.Auth.Authorization
  alias Voile.Schema.System

  @impl true
  def mount(_params, _session, socket) do
    # Check permission for viewing circulation history
    unless Authorization.can?(socket, "circulation.view_history") do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access circulation history")
        |> push_navigate(to: ~p"/manage/glam/library/circulation")

      {:ok, socket}
    else
      user = socket.assigns.current_scope.user
      is_super_admin = Authorization.is_super_admin?(user)

      {node_id, nodes, selected_node_id} =
        if is_super_admin do
          {nil, System.list_nodes(), nil}
        else
          {user.node_id, [], user.node_id}
        end

      page = 1
      per_page = 20

      {history, total_pages, _} =
        if is_super_admin do
          Circulation.list_circulation_history_paginated(page, per_page)
        else
          Circulation.list_circulation_history_paginated_with_filters_by_node(
            page,
            per_page,
            %{event_type: "all", query: "", from: nil, to: nil},
            node_id
          )
        end

      socket =
        socket
        |> stream(:history, history)
        |> assign(:page, page)
        |> assign(:total_pages, total_pages)
        |> assign(:filter_event_type, "all")
        |> assign(:search_query, "")
        |> assign(:date_from, nil)
        |> assign(:date_to, nil)
        |> assign(:node_id, node_id)
        |> assign(:is_super_admin, is_super_admin)
        |> assign(:nodes, nodes)
        |> assign(:selected_node_id, selected_node_id)

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Circulation History")
  end

  @impl true
  def handle_event("filter", %{"event_type" => event_type}, socket) do
    socket =
      socket
      |> assign(:filter_event_type, event_type)
      |> reload_history()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_node", %{"node_id" => node_id_str}, socket) do
    node_id = if node_id_str in [nil, "all", ""], do: nil, else: String.to_integer(node_id_str)

    socket =
      socket
      |> assign(:node_id, node_id)
      |> assign(:selected_node_id, node_id)
      |> reload_history()

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> reload_history()

    {:noreply, socket}
  end

  @impl true
  def handle_event("date_filter", %{"from" => date_from, "to" => date_to}, socket) do
    socket =
      socket
      |> assign(:date_from, parse_date(date_from))
      |> assign(:date_to, parse_date(date_to))
      |> reload_history()

    {:noreply, socket}
  end

  @impl true
  def handle_event("export", _params, socket) do
    # This would typically generate and download a CSV/Excel file
    socket =
      socket
      |> put_flash(:info, "History export functionality would be implemented here")

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 20
    is_super_admin = socket.assigns.is_super_admin
    node_id = socket.assigns.node_id

    filters = %{
      event_type: socket.assigns.filter_event_type,
      query: Map.get(socket.assigns, :search_query, ""),
      from: Map.get(socket.assigns, :date_from),
      to: Map.get(socket.assigns, :date_to)
    }

    {history, total_pages, _} =
      if is_super_admin do
        Circulation.list_circulation_history_paginated_with_filters(page, per_page, filters)
      else
        Circulation.list_circulation_history_paginated_with_filters_by_node(
          page,
          per_page,
          filters,
          node_id
        )
      end

    socket =
      socket
      |> stream(:history, history, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end

  defp reload_history(socket) do
    page = 1
    per_page = 20
    is_super_admin = socket.assigns.is_super_admin
    node_id = socket.assigns.node_id

    filters = %{
      event_type: socket.assigns.filter_event_type,
      query: Map.get(socket.assigns, :search_query, ""),
      from: Map.get(socket.assigns, :date_from),
      to: Map.get(socket.assigns, :date_to)
    }

    {history, total_pages, _} =
      if is_super_admin do
        Circulation.list_circulation_history_paginated_with_filters(page, per_page, filters)
      else
        Circulation.list_circulation_history_paginated_with_filters_by_node(
          page,
          per_page,
          filters,
          node_id
        )
      end

    socket
    |> stream(:history, history, reset: true)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
  end

  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
