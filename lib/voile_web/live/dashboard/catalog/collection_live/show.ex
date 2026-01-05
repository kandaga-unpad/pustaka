defmodule VoileWeb.Dashboard.Catalog.CollectionLive.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog
  alias Voile.Schema.Master
  alias Voile.Schema.Metadata
  alias Voile.Schema.System

  @impl true
  def mount(_params, _session, socket) do
    # Check read permission for viewing collection details
    authorize!(socket, "collections.read")

    collection_type = Metadata.list_resource_class()
    collection_properties = Metadata.list_metadata_properties_by_vocabulary()
    creator = Master.list_mst_creator()
    node_location = System.list_nodes()

    time_identifier = DateTime.utc_now() |> DateTime.to_unix()

    socket =
      socket
      |> assign(:collection_type, collection_type)
      |> assign(:collection_properties, collection_properties)
      |> assign(:creator, creator)
      |> assign(:creator_searching, false)
      |> assign(:node_location, node_location)
      |> assign(:step, 1)
      |> assign(:show_add_collection_field, true)
      |> assign(:show_close_confirm, false)
      |> assign(:time_identifier, time_identifier)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    collection = Catalog.get_collection!(id)

    # Preserve query parameters from the index page (search, filters)
    query_params = Map.drop(params, ["id"])

    socket =
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:collection, collection)
      |> assign(:patch, ~p"/manage/catalog/collections/#{collection}")
      |> assign(:back_query_params, query_params)
      |> assign(:transfer_item, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("request_transfer", %{"item-id" => item_id}, socket) do
    item = Catalog.get_item!(item_id)

    {:noreply,
     socket
     |> assign(:transfer_item, item)
     |> assign(:live_action, :request_transfer)}
  end

  @impl true
  def handle_event("cancel_transfer", _params, socket) do
    {:noreply,
     socket
     |> assign(:transfer_item, nil)
     |> assign(:live_action, :show)}
  end

  @impl true
  def handle_event("attempt_close_collection_modal", _params, socket) do
    {:noreply, assign(socket, :show_close_confirm, true)}
  end

  @impl true
  def handle_event("cancel_close_collection_modal", _params, socket) do
    {:noreply, assign(socket, :show_close_confirm, false)}
  end

  defp page_title(:show), do: "Show Collection"
  defp page_title(:edit), do: "Edit Collection"

  defp file_type_icon("image") do
    assigns = %{}

    ~H"""
    <svg class="h-15 w-15 text-green-400" fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp file_type_icon("document") do
    assigns = %{}

    ~H"""
    <svg class="h-15 w-15 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4zm2 6a1 1 0 011-1h6a1 1 0 110 2H7a1 1 0 01-1-1zm1 3a1 1 0 100 2h6a1 1 0 100-2H7z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp file_type_icon("video") do
    assigns = %{}

    ~H"""
    <svg class="h-15 w-15 text-voile-primary" fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M2 6a2 2 0 012-2h6a2 2 0 012 2v4a2 2 0 01-2 2H4a2 2 0 01-2-2V6zm12.553 1.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp file_type_icon("audio") do
    assigns = %{}

    ~H"""
    <svg class="h-15 w-15 text-yellow-400" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
      <path
        fill-rule="evenodd"
        d="M19.5 3.75a.75.75 0 01.75.75v12.063a4.125 4.125 0 11-1.5-3.188V7.098l-9 2.25v8.465a4.125 4.125 0 11-1.5-3.188V6a.75.75 0 01.576-.73l10.5-2.25a.75.75 0 01.174-.02z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp file_type_icon("software") do
    assigns = %{}

    ~H"""
    <svg class="h-15 w-15 text-indigo-400" fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M12.316 3.051a1 1 0 01.633 1.265l-4 12a1 1 0 11-1.898-.632l4-12a1 1 0 011.265-.633zM5.707 6.293a1 1 0 010 1.414L3.414 10l2.293 2.293a1 1 0 11-1.414 1.414l-3-3a1 1 0 010-1.414l3-3a1 1 0 011.414 0zm8.586 0a1 1 0 011.414 0l3 3a1 1 0 010 1.414l-3 3a1 1 0 11-1.414-1.414L16.586 10l-2.293-2.293a1 1 0 010-1.414z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp file_type_icon("archive") do
    assigns = %{}

    ~H"""
    <svg class="h-15 w-15 text-orange-400" fill="currentColor" viewBox="0 0 20 20">
      <path d="M4 3a2 2 0 100 4h12a2 2 0 100-4H4z" />
      <path
        fill-rule="evenodd"
        d="M3 8h14v7a2 2 0 01-2 2H5a2 2 0 01-2-2V8zm5 3a1 1 0 011-1h2a1 1 0 110 2H9a1 1 0 01-1-1z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp file_type_icon(_) do
    assigns = %{}

    ~H"""
    <svg class="h-15 w-15 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when bytes < 1_073_741_824,
    do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_073_741_824, 1)} GB"

  defp badge_color("image"), do: "bg-blue-100 text-blue-700"
  defp badge_color("document"), do: "bg-green-100 text-green-700"
  defp badge_color("video"), do: "bg-red-100 text-red-700"
  defp badge_color("audio"), do: "bg-yellow-100 text-yellow-700"
  defp badge_color("software"), do: "bg-voile-primary/10 text-voile-primary"
  defp badge_color("archive"), do: "bg-orange-100 text-orange-700"
  defp badge_color(_), do: "bg-gray-100 text-gray-700"

  # Map each status/condition/availability to colors
  @status_colors %{
    "active" => "bg-green-100 text-green-800",
    "inactive" => "bg-gray-100 text-gray-800",
    "lost" => "bg-red-100 text-red-800",
    "damaged" => "bg-yellow-100 text-yellow-800"
  }

  @condition_colors %{
    "new" => "bg-green-100 text-green-800",
    "good" => "bg-blue-100 text-blue-800",
    "fair" => "bg-yellow-100 text-yellow-800",
    "poor" => "bg-red-100 text-red-800"
  }

  @availability_colors %{
    "available" => "bg-green-100 text-green-800",
    "loaned" => "bg-blue-100 text-blue-800",
    "reserved" => "bg-yellow-100 text-yellow-800",
    "maintenance" => "bg-gray-100 text-gray-800"
  }

  defp badge(assigns) do
    ~H"""
    <span class={"#{@class} text-xs font-medium px-2.5 py-0 rounded-full"}>
      {String.capitalize(@value)}
    </span>
    """
  end

  defp status_badge(status) do
    assigns = %{
      value: status,
      class: Map.get(@status_colors, status, "bg-gray-100 text-gray-800")
    }

    badge(assigns)
  end

  defp condition_badge(condition) do
    assigns = %{
      value: condition,
      class: Map.get(@condition_colors, condition, "bg-gray-100 text-gray-800")
    }

    badge(assigns)
  end

  defp availability_badge(availability) do
    assigns = %{
      value: availability,
      class: Map.get(@availability_colors, availability, "bg-gray-100 text-gray-800")
    }

    badge(assigns)
  end
end
