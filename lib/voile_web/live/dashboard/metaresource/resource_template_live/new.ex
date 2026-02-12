defmodule VoileWeb.Dashboard.MetaResource.ResourceTemplateLive.New do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Metadata.ResourceTemplate
  alias VoileWeb.Dashboard.MetaResource.ResourceTemplateLive.FormComponent

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:resource_template, %ResourceTemplate{})
     |> assign(:page_title, gettext("New Resource Template"))
     |> assign(:live_action, :new)}
  end

  @impl true
  def handle_event("reorder_by_index", params, socket) do
    # Forward the event to the FormComponent
    send_update(FormComponent,
      id: :new,
      action: :reorder_by_index,
      params: params
    )

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New Resource Template"))
    |> assign(:resource_template, %ResourceTemplate{})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={FormComponent}
      id={:new}
      current_user={@current_scope.user}
      resource_template={@resource_template}
      patch={~p"/manage/metaresource/resource_template"}
      return_to={~p"/manage/metaresource/resource_template"}
    />
    """
  end
end
