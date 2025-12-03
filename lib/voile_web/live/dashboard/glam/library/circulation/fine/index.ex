defmodule VoileWeb.Dashboard.Glam.Library.Circulation.Fine.Index do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Glam.Library.Circulation.Helpers

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Library.Fine
  alias Voile.Schema.Catalog
  alias VoileWeb.Auth.Authorization
  alias Voile.Schema.System

  @impl true
  def mount(_params, _session, socket) do
    # Check permission for managing fines
    unless Authorization.can?(socket, "circulation.manage_fines") do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access fine management")
        |> push_navigate(to: ~p"/manage/glam/library/circulation")

      {:ok, socket}
    else
      user = socket.assigns.current_scope.user
      is_super_admin = Authorization.is_super_admin?(user)

      {node_id, nodes, selected_node_id} =
        if is_super_admin do
          {nil, System.list_nodes(), nil}
        else
          {user.node_id, [], user.node_id}
        end

      page = 1
      per_page = 15
      filters = %{status: "all", type: "all"}

      {fines, total_pages, _} =
        if is_super_admin do
          Circulation.list_fines_paginated_with_filters(page, per_page, filters)
        else
          Circulation.list_fines_paginated_with_filters_by_node(page, per_page, filters, node_id)
        end

      socket =
        socket
        |> stream(:fines, fines)
        |> assign(:page, page)
        |> assign(:total_pages, total_pages)
        |> assign(:filter_status, "all")
        |> assign(:filter_type, "all")
        |> assign(:node_id, node_id)
        |> assign(:is_super_admin, is_super_admin)
        |> assign(:nodes, nodes)
        |> assign(:selected_node_id, selected_node_id)

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Library Fines")
  end

  defp apply_action(socket, :new, _params) do
    changeset = Fine.changeset(%Fine{}, %{})

    socket
    |> assign(:page_title, "New Fine")
    |> assign(:fine, %Fine{})
    |> assign(:fine_form, to_form(changeset))
    |> assign(:item_suggestions, [])
    |> assign(:item_search_text, "")
    |> assign(:selected_item_id, nil)
  end

  @impl true
  def handle_event("item_search", %{"item_search" => query}, socket) do
    q = String.trim(query || "")

    if q == "" do
      {:noreply,
       socket
       |> assign(:item_suggestions, [])
       |> assign(:item_search_text, "")
       |> assign(:selected_item_id, nil)}
    else
      {items, _total_pages, _} = Catalog.search_items_paginated(q, 1, 10)

      {:noreply,
       socket
       |> assign(:item_suggestions, items)
       |> assign(:item_search_text, q)}
    end
  end

  @impl true
  def handle_event("choose_item", %{"item_id" => item_id}, socket) do
    # item_id comes as string from the DOM
    id = String.to_integer(item_id)
    item = Catalog.get_item!(id)

    display_text =
      if item.collection && item.collection.title do
        "#{item.item_code} — #{item.collection.title}"
      else
        "#{item.item_code}"
      end

    {:noreply,
     socket
     |> assign(:selected_item_id, id)
     |> assign(:item_search_text, display_text)
     |> assign(:item_suggestions, [])}
  end

  @impl true
  def handle_event("create_fine", %{"fine" => fine_params}, socket) do
    fine_params =
      if Map.has_key?(fine_params, "member_id") do
        member_id = get_id_from_member_identifier(fine_params["member_id"])
        Map.put(fine_params, "member_id", member_id)
      else
        fine_params
      end

    case Circulation.create_fine(fine_params) do
      {:ok, fine} ->
        socket =
          socket
          |> stream_insert(:fines, fine, at: 0)
          |> put_flash(:info, "Fine created successfully")
          |> push_patch(to: ~p"/manage/glam/library/circulation/fines")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> assign(:fine_form, to_form(changeset))
          |> put_flash(:error, "Failed to create fine: #{extract_error_message(changeset)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter", %{"status" => status, "type" => type}, socket) do
    socket =
      socket
      |> assign(:filter_status, status)
      |> assign(:filter_type, type)
      |> reload_fines()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_node", %{"node_id" => node_id_str}, socket) do
    node_id = if node_id_str in [nil, "all", ""], do: nil, else: String.to_integer(node_id_str)

    socket =
      socket
      |> assign(:node_id, node_id)
      |> assign(:selected_node_id, node_id)
      |> reload_fines()

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 15
    is_super_admin = socket.assigns.is_super_admin
    node_id = socket.assigns.node_id

    filters = %{
      status: socket.assigns.filter_status,
      type: socket.assigns.filter_type
    }

    {fines, total_pages, _} =
      if is_super_admin do
        Circulation.list_fines_paginated_with_filters(page, per_page, filters)
      else
        Circulation.list_fines_paginated_with_filters_by_node(page, per_page, filters, node_id)
      end

    socket =
      socket
      |> stream(:fines, fines, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end

  defp reload_fines(socket) do
    page = 1
    per_page = 15
    is_super_admin = socket.assigns.is_super_admin
    node_id = socket.assigns.node_id

    filters = %{
      status: socket.assigns.filter_status,
      type: socket.assigns.filter_type
    }

    {fines, total_pages, _} =
      if is_super_admin do
        Circulation.list_fines_paginated_with_filters(page, per_page, filters)
      else
        Circulation.list_fines_paginated_with_filters_by_node(page, per_page, filters, node_id)
      end

    socket
    |> stream(:fines, fines, reset: true)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
  end

  defp extract_error_message(changeset) do
    changeset
    |> Map.get(:errors, [])
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end
end
