defmodule VoileWeb.Dashboard.Master.TopicLive.Edit do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias VoileWeb.Dashboard.Master.TopicLive.FormComponent
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user

    unless Authorization.can?(user, "metadata.manage") do
      socket =
        socket
        |> put_flash(
          :error,
          gettext("Access Denied: You don't have permission to access this page")
        )
        |> push_navigate(to: ~p"/manage/master")

      {:ok, socket}
    else
      topic = Master.get_topic!(id)

      {:ok,
       socket
       |> assign(:topic, topic)
       |> assign(:page_title, gettext("Edit Topic"))
       |> assign(:live_action, :edit)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit Topic"))
    |> assign(:topic, Master.get_topic!(id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={FormComponent}
      id={:edit}
      title={@page_title}
      action={@live_action}
      topic={@topic}
      patch={~p"/manage/master/topics"}
    />
    """
  end
end
