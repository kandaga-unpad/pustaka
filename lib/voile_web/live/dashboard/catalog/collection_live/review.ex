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

      # Store collection IDs for batch selection
      collection_ids = Enum.map(collections, fn c -> c.id end)

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
        |> assign(:selected_collection_ids, [])
        |> assign(:batch_action_type, nil)
        |> assign(:current_page_collection_ids, collection_ids)

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

    collection_ids = Enum.map(collections, fn c -> c.id end)

    socket =
      socket
      |> stream(:collections, collections, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:collections_empty?, collections == [])
      |> assign(:selected_collection_ids, [])
      |> assign(:current_page_collection_ids, collection_ids)

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

    collection_ids = Enum.map(collections, fn c -> c.id end)

    socket =
      socket
      |> stream(:collections, collections, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:collections_empty?, collections == [])
      |> assign(:search_query, search_query)
      |> assign(:filter_status, filter_status)
      |> assign(:selected_collection_ids, [])
      |> assign(:current_page_collection_ids, collection_ids)

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

  # Batch selection event handlers
  @impl true
  def handle_event("toggle_selection", %{"collection_id" => id, "value" => value}, socket) do
    selected_ids = socket.assigns.selected_collection_ids

    # value is "on" when checked, nil/empty when unchecked
    is_selected = value == "on"

    updated_ids =
      if is_selected do
        [id | selected_ids] |> Enum.uniq()
      else
        Enum.reject(selected_ids, fn sid -> sid == id end)
      end

    {:noreply, assign(socket, :selected_collection_ids, updated_ids)}
  end

  @impl true
  def handle_event("select_all", _params, socket) do
    # Use the stored collection IDs for the current page
    {:noreply,
     assign(socket, :selected_collection_ids, socket.assigns.current_page_collection_ids)}
  end

  @impl true
  def handle_event("select_none", _params, socket) do
    {:noreply, assign(socket, :selected_collection_ids, [])}
  end

  # Batch action event handlers
  @impl true
  def handle_event("confirm_batch_approve", _params, socket) do
    socket = assign(socket, :batch_action_type, :approve)
    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_batch_reject", _params, socket) do
    socket = assign(socket, :batch_action_type, :reject)
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_batch_action", _params, socket) do
    socket =
      socket
      |> assign(:batch_action_type, nil)
      |> assign(:review_notes, "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("execute_batch_approve", _params, socket) do
    selected_ids = socket.assigns.selected_collection_ids
    reviewer = socket.assigns.current_scope.user
    notes = socket.assigns.review_notes

    collections = Catalog.get_collections_for_review(selected_ids)

    {success_count, failed_count, errors} =
      Catalog.batch_approve_collections(collections, reviewer, notes)

    # Refresh the list
    page = socket.assigns.page
    per_page = 10
    current_user = socket.assigns.current_scope.user
    search_query = socket.assigns.search_query
    filter_status = socket.assigns.filter_status

    {refreshed_collections, total_pages, total_count} =
      list_review_collections(page, per_page, current_user, search_query, filter_status)

    refreshed_collection_ids = Enum.map(refreshed_collections, fn c -> c.id end)

    socket =
      socket
      |> stream(:collections, refreshed_collections, reset: true)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:collections_empty?, refreshed_collections == [])
      |> assign(:selected_collection_ids, [])
      |> assign(:batch_action_type, nil)
      |> assign(:review_notes, "")
      |> assign(:current_page_collection_ids, refreshed_collection_ids)

    socket =
      cond do
        failed_count == 0 ->
          put_flash(socket, :info, "Successfully approved #{success_count} collection(s)")

        success_count == 0 ->
          error_details = Enum.map_join(errors, ", ", fn e -> "#{e.title}: #{e.error}" end)
          put_flash(socket, :error, "Failed to approve all collections. Errors: #{error_details}")

        true ->
          error_details = Enum.map_join(errors, ", ", fn e -> "#{e.title}: #{e.error}" end)

          put_flash(
            socket,
            :warning,
            "Approved #{success_count} collection(s), #{failed_count} failed. Errors: #{error_details}"
          )
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("execute_batch_reject", _params, socket) do
    selected_ids = socket.assigns.selected_collection_ids
    reviewer = socket.assigns.current_scope.user
    reason = socket.assigns.review_notes

    if String.trim(reason) == "" do
      {:noreply, put_flash(socket, :error, "Please provide a reason for rejection")}
    else
      collections = Catalog.get_collections_for_review(selected_ids)

      {success_count, failed_count, errors} =
        Catalog.batch_reject_collections(collections, reviewer, reason)

      # Refresh the list
      page = socket.assigns.page
      per_page = 10
      current_user = socket.assigns.current_scope.user
      search_query = socket.assigns.search_query
      filter_status = socket.assigns.filter_status

      {refreshed_collections, total_pages, total_count} =
        list_review_collections(page, per_page, current_user, search_query, filter_status)

      refreshed_collection_ids = Enum.map(refreshed_collections, fn c -> c.id end)

      socket =
        socket
        |> stream(:collections, refreshed_collections, reset: true)
        |> assign(:total_pages, total_pages)
        |> assign(:total_count, total_count)
        |> assign(:collections_empty?, refreshed_collections == [])
        |> assign(:selected_collection_ids, [])
        |> assign(:batch_action_type, nil)
        |> assign(:review_notes, "")
        |> assign(:current_page_collection_ids, refreshed_collection_ids)

      socket =
        cond do
          failed_count == 0 ->
            put_flash(socket, :info, "Successfully rejected #{success_count} collection(s)")

          success_count == 0 ->
            error_details = Enum.map_join(errors, ", ", fn e -> "#{e.title}: #{e.error}" end)

            put_flash(
              socket,
              :error,
              "Failed to reject all collections. Errors: #{error_details}"
            )

          true ->
            error_details = Enum.map_join(errors, ", ", fn e -> "#{e.title}: #{e.error}" end)

            put_flash(
              socket,
              :warning,
              "Rejected #{success_count} collection(s), #{failed_count} failed. Errors: #{error_details}"
            )
        end

      {:noreply, socket}
    end
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

        collection_ids = Enum.map(collections, fn c -> c.id end)

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
          |> assign(:selected_collection_ids, [])
          |> assign(:current_page_collection_ids, collection_ids)

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

          collection_ids = Enum.map(collections, fn c -> c.id end)

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
            |> assign(:selected_collection_ids, [])
            |> assign(:current_page_collection_ids, collection_ids)

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
