defmodule VoileWeb.Dashboard.Catalog.CollectionLive.Review do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog

  import Voile.Utils.DateHelper, only: [to_local_time: 1]

  @impl true
  def mount(_params, _session, socket) do
    # Check if user has permission to review collections
    # Only super_admin and admin roles can review
    unless can_review?(socket.assigns.current_scope.user) do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to review collections")
        |> push_navigate(to: ~p"/manage/catalog/collections")

      {:ok, socket}
    else
      # Initialize page state
      page = 1
      per_page = 10
      current_user = socket.assigns.current_scope.user
      search_query = ""
      filter_status = ""

      {collections, total_pages, total_count} =
        list_review_collections(page, per_page, current_user, search_query, filter_status)

      socket =
        socket
        |> stream(:collections, collections)
        |> assign(:page, page)
        |> assign(:total_pages, total_pages)
        |> assign(:total_count, total_count)
        |> assign(:collections_empty?, collections == [])
        |> assign(:selected_collection, nil)
        |> assign(:action_type, nil)
        |> assign(:review_notes, "")
        |> assign(:show_view_modal, false)
        |> assign(:search_query, search_query)
        |> assign(:filter_status, filter_status)

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Review Collections")
    |> assign(:selected_collection, nil)
    |> assign(:action_type, nil)
  end

  defp apply_action(socket, :review, %{"id" => id}) do
    collection = Catalog.get_collection!(id)

    # Verify collection is in pending status
    if collection.status != "pending" do
      socket
      |> put_flash(:error, "This collection is not pending review")
      |> push_navigate(to: ~p"/manage/catalog/collections/review")
    else
      socket
      |> assign(:page_title, "Review: #{collection.title}")
      |> assign(:selected_collection, collection)
      |> assign(:action_type, nil)
    end
  end

  @impl true
  def handle_event("view_collection", %{"id" => id}, socket) do
    collection = Catalog.get_collection!(id)

    socket =
      socket
      |> assign(:selected_collection, collection)
      |> assign(:show_view_modal, true)
      |> assign(:action_type, nil)
      |> assign(:review_notes, "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_view_modal", _params, socket) do
    socket =
      socket
      |> assign(:selected_collection, nil)
      |> assign(:show_view_modal, false)
      |> assign(:action_type, nil)
      |> assign(:review_notes, "")

    {:noreply, socket}
  end

  # All handle_event/3 clauses grouped together
  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 10
    current_user = socket.assigns.current_scope.user
    search_query = socket.assigns.search_query
    filter_status = socket.assigns.filter_status

    {collections, total_pages, total_count} =
      list_review_collections(page, per_page, current_user, search_query, filter_status)

    socket =
      socket
      |> stream(:collections, collections, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:collections_empty?, collections == [])

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "search_filter",
        %{"search" => search_query, "status" => filter_status},
        socket
      ) do
    page = 1
    per_page = 10
    current_user = socket.assigns.current_scope.user

    {collections, total_pages, total_count} =
      list_review_collections(page, per_page, current_user, search_query, filter_status)

    socket =
      socket
      |> stream(:collections, collections, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:collections_empty?, collections == [])
      |> assign(:search_query, search_query)
      |> assign(:filter_status, filter_status)

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_approve", _params, socket) do
    socket = assign(socket, :action_type, :approve)
    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_reject", _params, socket) do
    socket = assign(socket, :action_type, :reject)
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_action", _params, socket) do
    socket =
      socket
      |> assign(:action_type, nil)
      |> assign(:review_notes, "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_notes", %{"notes" => notes}, socket) do
    {:noreply, assign(socket, :review_notes, notes)}
  end

  @impl true
  def handle_event("approve_collection", %{"id" => id}, socket) do
    collection = Catalog.get_collection!(id)
    reviewer = socket.assigns.current_scope.user
    notes = socket.assigns.review_notes

    case Catalog.approve_collection(collection, reviewer, notes) do
      {:ok, _updated_collection} ->
        # Refresh the list
        page = socket.assigns.page
        per_page = 10
        current_user = socket.assigns.current_scope.user

        {collections, total_pages, total_count} =
          Catalog.list_pending_collections_paginated(page, per_page, current_user)

        socket =
          socket
          |> put_flash(:info, "Collection approved and published successfully")
          |> stream(:collections, collections, reset: true)
          |> assign(:total_pages, total_pages)
          |> assign(:total_count, total_count)
          |> assign(:collections_empty?, collections == [])
          |> assign(:selected_collection, nil)
          |> assign(:action_type, nil)
          |> assign(:review_notes, "")
          |> assign(:show_view_modal, false)

        {:noreply, socket}

      {:error, :invalid_status} ->
        {:noreply,
         socket
         |> put_flash(:error, "Collection is not in pending status")
         |> assign(:selected_collection, nil)
         |> assign(:action_type, nil)
         |> assign(:show_view_modal, false)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to approve collection: #{inspect(changeset.errors)}")
         |> assign(:selected_collection, nil)
         |> assign(:action_type, nil)
         |> assign(:show_view_modal, false)}
    end
  end

  @impl true
  def handle_event("reject_collection", %{"id" => id}, socket) do
    collection = Catalog.get_collection!(id)
    reviewer = socket.assigns.current_scope.user
    reason = socket.assigns.review_notes

    if String.trim(reason) == "" do
      {:noreply, put_flash(socket, :error, "Please provide a reason for rejection")}
    else
      case Catalog.reject_collection(collection, reviewer, reason) do
        {:ok, _updated_collection} ->
          # Refresh the list
          page = socket.assigns.page
          per_page = 10
          current_user = socket.assigns.current_scope.user

          {collections, total_pages, total_count} =
            Catalog.list_pending_collections_paginated(page, per_page, current_user)

          socket =
            socket
            |> put_flash(:info, "Collection rejected and sent back to draft")
            |> stream(:collections, collections, reset: true)
            |> assign(:total_pages, total_pages)
            |> assign(:total_count, total_count)
            |> assign(:collections_empty?, collections == [])
            |> assign(:selected_collection, nil)
            |> assign(:action_type, nil)
            |> assign(:review_notes, "")
            |> assign(:show_view_modal, false)

          {:noreply, socket}

        {:error, :invalid_status} ->
          {:noreply,
           socket
           |> put_flash(:error, "Collection is not in pending status")
           |> assign(:selected_collection, nil)
           |> assign(:action_type, nil)
           |> assign(:show_view_modal, false)}

        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to reject collection: #{inspect(changeset.errors)}")
           |> assign(:selected_collection, nil)
           |> assign(:action_type, nil)
           |> assign(:show_view_modal, false)}
      end
    end
  end

  # Helper to scope collection list for review
  defp list_review_collections(page, per_page, user, search_query, filter_status) do
    is_super_admin =
      user
      |> Repo.preload(:roles)
      |> Map.get(:roles, [])
      |> Enum.any?(fn role -> role.name == "super_admin" end)

    node_id = if is_super_admin, do: nil, else: user.node_id

    Catalog.list_pending_collections_paginated(
      page,
      per_page,
      user,
      search_query,
      filter_status,
      node_id
    )
  end

  # Helper function to check if user can review collections
  defp can_review?(user) do
    user = Repo.preload(user, :roles)

    Enum.any?(user.roles, fn role ->
      role.name in ["super_admin", "admin"]
    end)
  end

  # Helper function for status badge styling
  defp status_badge_class("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_badge_class("draft"), do: "bg-gray-100 text-gray-800"
  defp status_badge_class("published"), do: "bg-green-100 text-green-800"
  defp status_badge_class("archived"), do: "bg-red-100 text-red-800"
  defp status_badge_class(_), do: "bg-gray-100 text-gray-800"
end
