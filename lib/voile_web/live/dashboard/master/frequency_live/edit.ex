defmodule VoileWeb.Dashboard.Master.FrequencyLive.Edit do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias VoileWeb.Dashboard.Master.FrequencyLive.FormComponent

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    frequency = Master.get_frequency!(id)

    {:ok,
     socket
     |> assign(:frequency, frequency)
     |> assign(:page_title, "Edit Frequency")
     |> assign(:live_action, :edit)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Frequency")
    |> assign(:frequency, Master.get_frequency!(id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={FormComponent}
      id={:edit}
      title={@page_title}
      action={@live_action}
      frequency={@frequency}
      patch={~p"/manage/master/frequencies"}
    />
    """
  end
end
