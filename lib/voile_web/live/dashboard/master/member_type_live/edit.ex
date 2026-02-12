defmodule VoileWeb.Dashboard.Master.MemberTypeLive.Edit do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias VoileWeb.Dashboard.Master.MemberTypeLive.FormComponent
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user

    if !Authorization.can?(user, "metadata.manage") do
      socket =
        socket
        |> put_flash(
          :error,
          gettext("Access Denied: You don't have permission to access this page")
        )
        |> push_navigate(to: ~p"/manage/master")

      {:ok, socket}
    else
      member_type = Master.get_member_type!(id)

      {:ok,
       socket
       |> assign(:member_type, member_type)
       |> assign(:page_title, gettext("Edit Member Type"))
       |> assign(:live_action, :edit)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit Member Type"))
    |> assign(:member_type, Master.get_member_type!(id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={FormComponent}
      id={:edit}
      title={@page_title}
      action={@live_action}
      member_type={@member_type}
      patch={~p"/manage/master/member_types"}
    />
    """
  end
end
