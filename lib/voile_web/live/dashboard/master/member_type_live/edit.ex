defmodule VoileWeb.Dashboard.Master.MemberTypeLive.Edit do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias VoileWeb.Dashboard.Master.MemberTypeLive.FormComponent

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    member_type = Master.get_member_type!(id)

    {:ok,
     socket
     |> assign(:member_type, member_type)
     |> assign(:page_title, "Edit Member Type")
     |> assign(:live_action, :edit)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Member Type")
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
