defmodule VoileWeb.Dashboard.Catalog.Attachment.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog.Attachment
  alias VoileWeb.Auth.Authorization
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    unless Authorization.can?(socket, "attachments.read") do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access attachments")
        |> push_navigate(to: ~p"/manage")

      {:ok, socket}
    else
      current_user = socket.assigns.current_scope.user

      socket =
        socket
        |> stream(:attachments, [])
        |> assign(:page, 1)
        |> assign(:total_pages, 0)
        |> assign(:search, "")
        |> assign(:attachments_count, 0)
        |> assign(:attachments_empty?, true)
        |> assign(:current_user, current_user)
        |> assign(:filter_access_level, "")
        |> assign(:filter_file_type, "")
        |> assign(:filter_attachable_type, "")
        |> assign(:active_filters_count, 0)

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    page = socket.assigns.page
    per_page = 20
    search = params["q"] || socket.assigns.search
    _current_user = socket.assigns.current_user

    filters = build_filters_from_params(params)
    active_count = count_active_filters(filters)

    {attachments, total_pages} = list_attachments_paginated(page, per_page, search, filters)

    # Preload associations for display
    attachments =
      attachments
      |> Repo.preload([:allowed_roles, :allowed_users, :access_settings_updated_by])

    socket
    |> stream(:attachments, attachments, reset: true)
    |> assign(:attachments_empty?, attachments == [])
    |> assign(:attachments_count, length(attachments))
    |> assign(:total_pages, total_pages)
    |> assign(:page_title, "Manage Attachments")
    |> assign(:search, search)
    |> assign(:filter_access_level, filters[:access_level] || "")
    |> assign(:filter_file_type, filters[:file_type] || "")
    |> assign(:filter_attachable_type, filters[:attachable_type] || "")
    |> assign(:active_filters_count, active_count)
  end

  defp apply_action(socket, :manage_access, %{"id" => id}) do
    authorize!(socket, "attachments.update")

    attachment =
      Attachment
      |> Repo.get!(id)
      |> Repo.preload([:allowed_roles, :allowed_users, :access_settings_updated_by])

    # Get all available roles
    roles = Repo.all(from r in Voile.Schema.Accounts.Role, order_by: r.name)

    socket
    |> assign(:page_title, "Manage Access - #{attachment.original_name}")
    |> assign(:attachment, attachment)
    |> assign(:all_roles, roles)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    authorize!(socket, "attachments.delete")

    attachment = Repo.get!(Attachment, id)
    {:ok, _} = Repo.delete(attachment)

    socket =
      socket
      |> put_flash(:info, "Attachment deleted successfully")
      |> stream_delete(:attachments, attachment)
      |> assign(:attachments_count, max((socket.assigns[:attachments_count] || 1) - 1, 0))

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 20
    search = socket.assigns[:search] || ""

    filters = %{
      access_level: socket.assigns.filter_access_level,
      file_type: socket.assigns.filter_file_type,
      attachable_type: socket.assigns.filter_attachable_type
    }

    {attachments, total_pages} = list_attachments_paginated(page, per_page, search, filters)

    attachments =
      attachments
      |> Repo.preload([:allowed_roles, :allowed_users, :access_settings_updated_by])

    socket =
      socket
      |> stream(:attachments, attachments, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:attachments_empty?, attachments == [])
      |> assign(:attachments_count, length(attachments))

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    query_params = build_query_params(socket.assigns, q)
    {:noreply, push_patch(socket, to: ~p"/manage/catalog/attachments?#{query_params}")}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    query_params = build_query_params(socket.assigns, "")
    {:noreply, push_patch(socket, to: ~p"/manage/catalog/attachments?#{query_params}")}
  end

  @impl true
  def handle_event("filter_change", params, socket) do
    filters = build_filters_from_params(params)
    search = socket.assigns.search
    query_params = build_query_params(%{filters: filters}, search)

    {:noreply, push_patch(socket, to: ~p"/manage/catalog/attachments?#{query_params}")}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    query_params = build_query_params(%{filters: %{}}, socket.assigns.search)
    {:noreply, push_patch(socket, to: ~p"/manage/catalog/attachments?#{query_params}")}
  end

  @impl true
  def handle_info({:access_updated, attachment_id}, socket) do
    # Refresh the specific attachment
    attachment =
      Attachment
      |> Repo.get!(attachment_id)
      |> Repo.preload([:allowed_roles, :allowed_users, :access_settings_updated_by])

    socket =
      socket
      |> stream_insert(:attachments, attachment)
      |> put_flash(:info, "Access settings updated successfully")

    {:noreply, socket}
  end

  # Helper functions
  defp list_attachments_paginated(page, per_page, search, filters) do
    offset = (page - 1) * per_page

    query = from(a in Attachment, order_by: [desc: a.inserted_at])

    query =
      if search != "" do
        search_term = "%#{search}%"

        from a in query,
          where:
            ilike(a.original_name, ^search_term) or
              ilike(a.file_name, ^search_term) or
              ilike(a.description, ^search_term)
      else
        query
      end

    query =
      if filters[:access_level] && filters[:access_level] != "" do
        from a in query, where: a.access_level == ^filters[:access_level]
      else
        query
      end

    query =
      if filters[:file_type] && filters[:file_type] != "" do
        from a in query, where: a.file_type == ^filters[:file_type]
      else
        query
      end

    query =
      if filters[:attachable_type] && filters[:attachable_type] != "" do
        from a in query, where: a.attachable_type == ^filters[:attachable_type]
      else
        query
      end

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = ceil(total_count / per_page)

    attachments =
      query
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    {attachments, total_pages}
  end

  defp build_filters_from_params(params) do
    %{}
    |> maybe_add_filter(:access_level, params["access_level"])
    |> maybe_add_filter(:file_type, params["file_type"])
    |> maybe_add_filter(:attachable_type, params["attachable_type"])
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp count_active_filters(filters) do
    filters
    |> Map.values()
    |> Enum.reject(&(&1 == nil || &1 == ""))
    |> length()
  end

  defp build_query_params(assigns, search) do
    filters = Map.get(assigns, :filters, %{})

    params = %{}

    params =
      if search && search != "" do
        Map.put(params, :q, search)
      else
        params
      end

    params =
      if filters[:access_level] && filters[:access_level] != "" do
        Map.put(params, :access_level, filters[:access_level])
      else
        params
      end

    params =
      if filters[:file_type] && filters[:file_type] != "" do
        Map.put(params, :file_type, filters[:file_type])
      else
        params
      end

    params =
      if filters[:attachable_type] && filters[:attachable_type] != "" do
        Map.put(params, :attachable_type, filters[:attachable_type])
      else
        params
      end

    params
  end

  defp format_file_size(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1_048_576 -> "#{Float.round(bytes / 1024, 2)} KB"
      bytes < 1_073_741_824 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      true -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
    end
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  defp access_level_badge_class("public"), do: "badge-success"
  defp access_level_badge_class("limited"), do: "badge-warning"
  defp access_level_badge_class("restricted"), do: "badge-error"
  defp access_level_badge_class(_), do: "badge-ghost"
end
