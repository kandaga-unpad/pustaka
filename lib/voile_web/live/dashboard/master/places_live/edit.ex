defmodule VoileWeb.Dashboard.Master.PlacesLive.Edit do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias VoileWeb.Dashboard.Master.PlacesLive.FormComponent

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    place = Master.get_places!(id)

    {:ok,
     socket
     |> assign(:place, place)
     |> assign(:page_title, "Edit Place")
     |> assign(:live_action, :edit)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Place")
    |> assign(:place, Master.get_places!(id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={FormComponent}
      id={:edit}
      title={@page_title}
      action={@live_action}
      place={@place}
      patch={~p"/manage/master/places"}
    />
    """
  end
end
