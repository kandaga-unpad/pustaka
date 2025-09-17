defmodule VoileWeb.Dashboard.Master.LocationsLive.Edit do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias VoileWeb.Dashboard.Master.LocationsLive.FormComponent

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    location = Master.get_locations!(id)

    {:ok,
     socket
     |> assign(:location, location)
     |> assign(:page_title, "Edit Location")
     |> assign(:live_action, :edit)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Location")
    |> assign(:location, Master.get_locations!(id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={FormComponent}
      id={:edit}
      title={@page_title}
      action={@live_action}
      location={@location}
      patch={~p"/manage/master/locations"}
    />
    """
  end
end
