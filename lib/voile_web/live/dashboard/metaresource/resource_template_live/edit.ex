defmodule VoileWeb.Dashboard.MetaResource.ResourceTemplateLive.Edit do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Metadata
  alias VoileWeb.Dashboard.MetaResource.ResourceTemplateLive.FormComponent

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    resource_template = Metadata.get_resource_template!(id)

    {:ok,
     socket
     |> assign(:resource_template, resource_template)
     |> assign(:page_title, gettext("Edit Resource Template"))
     |> assign(:live_action, :edit)}
  end

  @impl true
  def handle_event("reorder_by_index", params, socket) do
    # Forward the event to the FormComponent
    send_update(FormComponent,
      id: :edit,
      action: :reorder_by_index,
      params: params
    )

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit Resource Template"))
    |> assign(:resource_template, Metadata.get_resource_template!(id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={FormComponent}
      id={:edit}
      current_user={@current_scope.user}
      resource_template={@resource_template}
      patch={~p"/manage/metaresource/resource_template/#{@resource_template.id}"}
      return_to={~p"/manage/metaresource/resource_template/#{@resource_template.id}"}
    />
    """
  end
end
