defmodule VoileWeb.Dashboard.Master.PlacesLive.Edit do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias VoileWeb.Dashboard.Master.PlacesLive.FormComponent
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user

    unless Authorization.can?(user, "metadata.manage") do
      socket =
        socket
        |> put_flash(:error, "Access Denied: You don't have permission to access this page")
        |> push_navigate(to: ~p"/manage/master")

      {:ok, socket}
    else
      place = Master.get_places!(id)

      {:ok,
       socket
       |> assign(:place, place)
       |> assign(:page_title, "Edit Place")
       |> assign(:live_action, :edit)}
    end
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
