defmodule VoileWeb.Dashboard.Glam.Library.Circulation.CirculationHistory.Index do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Glam.Library.Circulation.Helpers

  alias Voile.Schema.Library.Circulation

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    per_page = 20
    {history, total_pages} = Circulation.list_circulation_history_paginated(page, per_page)

    socket =
      socket
      |> stream(:history, history)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:filter_event_type, "all")
      |> assign(:search_query, "")
      |> assign(:date_from, nil)
      |> assign(:date_to, nil)

    {:ok, socket}
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

    {history, total_pages} = Circulation.list_circulation_history_paginated(page, per_page)

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
    {history, total_pages} = Circulation.list_circulation_history_paginated(page, per_page)

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
