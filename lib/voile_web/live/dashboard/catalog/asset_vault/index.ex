defmodule VoileWeb.Dashboard.Catalog.AssetVault.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog.{Attachment, Collection}
  alias VoileWeb.Auth.Authorization
  alias Client.Storage
  import Ecto.Query

  @per_page 24

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    unless Authorization.can?(socket, "attachments.read") do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access the asset vault")
        |> push_navigate(to: ~p"/manage")

      {:ok, socket}
    else
      current_user = socket.assigns.current_scope.user

      socket =
        socket
        |> stream(:attachments, [])
        |> assign(:attachments_list, [])
        |> assign(:page, 1)
        |> assign(:total_pages, 0)
        |> assign(:search, "")
        |> assign(:attachments_count, 0)
        |> assign(:attachments_empty?, true)
        |> assign(:current_user, current_user)
        |> assign(:current_folder_id, nil)
        |> assign(:breadcrumbs, [%{name: "Asset Vault", id: nil}])
        |> assign(:filter_access_level, "")
        |> assign(:filter_file_type, "")
        |> assign(:filter_attachable_type, "")
        |> assign(:active_filters_count, 0)
        # "grid" or "list"
        |> assign(:view_mode, "grid")
        |> assign(:loading_folder, false)
        |> assign(:sidebar_collapsed, false)
        |> assign(:root_folders, list_root_folders())
        |> assign(:folder_tree, build_folder_tree())
        |> assign(:folder_tree_flat, list_all_folders())
        |> assign(:folder_path_ids, get_folder_path_ids(nil))
        |> assign(:show_rename_modal, false)
        |> assign(:rename_folder_id, nil)
        |> assign(:rename_folder_name, "")
        # Upload panel
        |> assign(:show_upload_panel, false)
        # File preview
        |> assign(:preview_attachment, nil)
        # Bulk selection
        |> assign(:selected_ids, MapSet.new())
        # Move modal
        |> assign(:show_move_modal, false)
        # Sort
        |> assign(:sort_by, "inserted_at")
        |> assign(:sort_dir, "desc")
        # Stats
        |> assign(:stats, load_stats())
        |> allow_upload(:attachments,
          accept: :any,
          max_entries: 10,
          max_file_size: 100_000_000
        )

      {:ok, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Params / Action
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    page = socket.assigns.page
    search = params["q"] || socket.assigns.search
    sort_by = socket.assigns.sort_by
    sort_dir = socket.assigns.sort_dir

    filters = build_filters_from_params(params)
    active_count = count_active_filters(filters)

    {attachments, total_pages} =
      list_attachments_paginated(
        page,
        @per_page,
        search,
        filters,
        socket.assigns.current_folder_id,
        sort_by,
        sort_dir
      )

    attachments =
      Repo.preload(attachments, [:allowed_roles, :allowed_users, :access_settings_updated_by])

    socket
    |> stream(:attachments, attachments, reset: true)
    |> assign(:attachments_list, attachments)
    |> assign(:attachments_empty?, attachments == [])
    |> assign(:attachments_count, length(attachments))
    |> assign(:total_pages, total_pages)
    |> assign(:page_title, "Asset Vault")
    |> assign(:search, search)
    |> assign(:filter_access_level, filters[:access_level] || "")
    |> assign(:filter_file_type, filters[:file_type] || "")
    |> assign(:filter_attachable_type, filters[:attachable_type] || "")
    |> assign(:active_filters_count, active_count)
    |> assign(:loading_folder, false)
    |> assign(:root_folders, list_root_folders())
    |> assign(:folder_tree, build_folder_tree())
    |> assign(:folder_tree_flat, list_all_folders())
    |> assign(:folder_path_ids, get_folder_path_ids(socket.assigns.current_folder_id))
    |> assign(:stats, load_stats())
  end

  # ---------------------------------------------------------------------------
  # Events – existing
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    authorize!(socket, "attachments.delete")

    attachment = Repo.get!(Attachment, id)

    if attachment.attachable_type == "asset_vault" && attachment.attachable_id do
      case Repo.get(Collection, attachment.attachable_id) do
        nil ->
          :ok

        collection ->
          if collection.thumbnail && String.contains?(collection.thumbnail, attachment.file_key) do
            Repo.update(Ecto.Changeset.change(collection, %{thumbnail: nil}))
          end
      end
    end

    if attachment.attachable_type != "folder" && attachment.file_path do
      delete_file_from_storage(attachment.file_path)
    end

    {:ok, _} = Repo.delete(attachment)

    updated_list = Enum.reject(socket.assigns.attachments_list, &(&1.id == attachment.id))

    socket =
      socket
      |> put_flash(:info, "Attachment deleted successfully")
      |> stream_delete(:attachments, attachment)
      |> assign(:attachments_list, updated_list)
      |> assign(:attachments_count, length(updated_list))
      |> assign(:attachments_empty?, updated_list == [])
      |> assign(:selected_ids, MapSet.delete(socket.assigns.selected_ids, id))
      |> assign(:stats, load_stats())

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)

    filters = %{
      access_level: socket.assigns.filter_access_level,
      file_type: socket.assigns.filter_file_type,
      attachable_type: socket.assigns.filter_attachable_type
    }

    {attachments, total_pages} =
      list_attachments_paginated(
        page,
        @per_page,
        socket.assigns.search,
        filters,
        socket.assigns.current_folder_id,
        socket.assigns.sort_by,
        socket.assigns.sort_dir
      )

    attachments =
      Repo.preload(attachments, [:allowed_roles, :allowed_users, :access_settings_updated_by])

    socket =
      socket
      |> stream(:attachments, attachments, reset: true)
      |> assign(:attachments_list, attachments)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:attachments_empty?, attachments == [])
      |> assign(:attachments_count, length(attachments))

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    query_params = build_query_params(socket.assigns, q)
    {:noreply, push_patch(socket, to: ~p"/manage/catalog/asset-vault?#{query_params}")}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    query_params = build_query_params(socket.assigns, "")
    {:noreply, push_patch(socket, to: ~p"/manage/catalog/asset-vault?#{query_params}")}
  end

  @impl true
  def handle_event("filter_change", params, socket) do
    filters = build_filters_from_params(params)
    query_params = build_query_params(%{filters: filters}, socket.assigns.search)
    {:noreply, push_patch(socket, to: ~p"/manage/catalog/asset-vault?#{query_params}")}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    query_params = build_query_params(%{filters: %{}}, socket.assigns.search)
    {:noreply, push_patch(socket, to: ~p"/manage/catalog/asset-vault?#{query_params}")}
  end

  @impl true
  def handle_event("create_folder", %{"name" => name}, socket) do
    authorize!(socket, "attachments.create")

    folder_attrs = %{
      file_name: name,
      attachable_type: "folder",
      parent_id: socket.assigns.current_folder_id,
      access_level: "public"
    }

    case Repo.insert(Attachment.changeset(%Attachment{}, folder_attrs)) do
      {:ok, _folder} ->
        {:noreply, socket |> put_flash(:info, "Folder created successfully") |> refresh_list()}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to create folder: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("navigate_folder", %{"id" => folder_id}, socket) do
    if folder_id == "" do
      socket =
        socket
        |> assign(:current_folder_id, nil)
        |> assign(:breadcrumbs, [%{name: "Asset Vault", id: nil}])
        |> assign(:page, 1)
        |> assign(:loading_folder, true)
        |> assign(:folder_path_ids, [])

      {:noreply, apply_action(socket, :index, %{})}
    else
      folder = Repo.get!(Attachment, folder_id)
      breadcrumbs = build_breadcrumbs_to_folder(folder)

      socket =
        socket
        |> assign(:current_folder_id, folder.id)
        |> assign(:breadcrumbs, breadcrumbs)
        |> assign(:page, 1)
        |> assign(:loading_folder, true)
        |> assign(:folder_path_ids, get_folder_path_ids(folder.id))

      {:noreply, apply_action(socket, :index, %{})}
    end
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, !socket.assigns.sidebar_collapsed)}
  end

  @impl true
  def handle_event("navigate_breadcrumb", %{"id" => folder_id}, socket) do
    folder_id = if folder_id == "", do: nil, else: folder_id
    breadcrumbs = socket.assigns.breadcrumbs
    index = Enum.find_index(breadcrumbs, &(&1.id == folder_id))

    if index do
      new_breadcrumbs = Enum.take(breadcrumbs, index + 1)

      socket =
        socket
        |> assign(:current_folder_id, folder_id)
        |> assign(:breadcrumbs, new_breadcrumbs)
        |> assign(:page, 1)
        |> assign(:folder_path_ids, get_folder_path_ids(folder_id))

      {:noreply, apply_action(socket, :index, %{})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_rename_modal", %{"id" => id}, socket) do
    folder = Repo.get!(Attachment, id)

    socket =
      socket
      |> assign(:show_rename_modal, true)
      |> assign(:rename_folder_id, id)
      |> assign(:rename_folder_name, folder.file_name)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_rename_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_rename_modal, false)
      |> assign(:rename_folder_id, nil)
      |> assign(:rename_folder_name, "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("rename_folder", %{"name" => new_name}, socket) do
    authorize!(socket, "attachments.update")

    folder = Repo.get!(Attachment, socket.assigns.rename_folder_id)

    case Repo.update(Attachment.changeset(folder, %{file_name: new_name})) do
      {:ok, _} ->
        socket =
          socket
          |> assign(:show_rename_modal, false)
          |> assign(:rename_folder_id, nil)
          |> assign(:rename_folder_name, "")
          |> put_flash(:info, "Folder renamed successfully")
          |> refresh_list()

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to rename folder: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("delete_folder", %{"id" => id}, socket) do
    authorize!(socket, "attachments.delete")

    folder = Repo.get!(Attachment, id)
    children_count = Repo.aggregate(from(a in Attachment, where: a.parent_id == ^id), :count, :id)

    if children_count > 0 do
      {:noreply, put_flash(socket, :error, "Cannot delete folder that contains items")}
    else
      {:ok, _} = Repo.delete(folder)

      updated_list = Enum.reject(socket.assigns.attachments_list, &(&1.id == folder.id))

      socket =
        socket
        |> put_flash(:info, "Folder deleted successfully")
        |> stream_delete(:attachments, folder)
        |> assign(:attachments_list, updated_list)
        |> assign(:attachments_count, length(updated_list))
        |> assign(:attachments_empty?, updated_list == [])
        |> assign(:root_folders, list_root_folders())
        |> assign(:folder_tree, build_folder_tree())
        |> assign(:folder_path_ids, get_folder_path_ids(socket.assigns.current_folder_id))
        |> assign(:stats, load_stats())

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_view_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, mode)}
  end

  @impl true
  def handle_event("save_attachments", _params, socket) do
    num_entries = length(socket.assigns.uploads.attachments.entries)
    current_folder_id = socket.assigns.current_folder_id

    results =
      consume_uploaded_entries(socket, :attachments, fn meta, entry ->
        upload_attachment(meta, entry, current_folder_id)
      end)

    successful = Enum.filter(results, &match?({:ok, _}, &1))
    failed = Enum.filter(results, &match?({:error, _}, &1))

    socket =
      socket
      |> assign(:page, 1)
      |> put_flash(
        :info,
        "Uploaded #{length(successful)} out of #{num_entries} file(s) successfully"
      )
      |> refresh_list()

    socket =
      if not Enum.empty?(failed) do
        error_messages = Enum.map(failed, fn {:error, msg} -> msg end)
        put_flash(socket, :error, "Upload failed: #{Enum.join(error_messages, "; ")}")
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachments, ref)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Events – new DAM features
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("toggle_upload_panel", _params, socket) do
    {:noreply, assign(socket, :show_upload_panel, !socket.assigns.show_upload_panel)}
  end

  @impl true
  def handle_event("open_preview", %{"id" => id}, socket) do
    attachment = Enum.find(socket.assigns.attachments_list, &(&1.id == id))
    {:noreply, assign(socket, :preview_attachment, attachment)}
  end

  @impl true
  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, :preview_attachment, nil)}
  end

  @impl true
  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected = socket.assigns.selected_ids

    new_selected =
      if MapSet.member?(selected, id) do
        MapSet.delete(selected, id)
      else
        MapSet.put(selected, id)
      end

    {:noreply, assign(socket, :selected_ids, new_selected)}
  end

  @impl true
  def handle_event("select_all", _params, socket) do
    file_ids =
      socket.assigns.attachments_list
      |> Enum.reject(&(&1.attachable_type == "folder"))
      |> Enum.map(& &1.id)
      |> MapSet.new()

    {:noreply, assign(socket, :selected_ids, file_ids)}
  end

  @impl true
  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_ids, MapSet.new())}
  end

  @impl true
  def handle_event("bulk_delete", _params, socket) do
    authorize!(socket, "attachments.delete")

    selected = socket.assigns.selected_ids

    Enum.each(selected, fn id ->
      case Repo.get(Attachment, id) do
        nil ->
          :ok

        attachment ->
          if attachment.attachable_type != "folder" && attachment.file_path do
            delete_file_from_storage(attachment.file_path)
          end

          Repo.delete(attachment)
      end
    end)

    socket =
      socket
      |> assign(:selected_ids, MapSet.new())
      |> put_flash(:info, "#{MapSet.size(selected)} file(s) deleted")
      |> refresh_list()

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_move_modal", _params, socket) do
    {:noreply, assign(socket, :show_move_modal, true)}
  end

  @impl true
  def handle_event("close_move_modal", _params, socket) do
    {:noreply, assign(socket, :show_move_modal, false)}
  end

  @impl true
  def handle_event("move_selected_to", %{"folder_id" => folder_id}, socket) do
    authorize!(socket, "attachments.update")

    new_parent_id = if folder_id == "" or folder_id == "root", do: nil, else: folder_id

    selected = socket.assigns.selected_ids

    Enum.each(selected, fn id ->
      case Repo.get(Attachment, id) do
        nil ->
          :ok

        attachment ->
          if attachment.attachable_type != "folder" do
            Repo.update(Attachment.changeset(attachment, %{parent_id: new_parent_id}))
          end
      end
    end)

    socket =
      socket
      |> assign(:selected_ids, MapSet.new())
      |> assign(:show_move_modal, false)
      |> put_flash(:info, "#{MapSet.size(selected)} file(s) moved")
      |> refresh_list()

    {:noreply, socket}
  end

  @impl true
  def handle_event("sort_change", %{"by" => by}, socket) do
    current_by = socket.assigns.sort_by
    current_dir = socket.assigns.sort_dir

    {new_by, new_dir} =
      if by == current_by do
        new_dir = if current_dir == "asc", do: "desc", else: "asc"
        {by, new_dir}
      else
        default_dir =
          cond do
            by in ["inserted_at", "file_size"] -> "desc"
            true -> "asc"
          end

        {by, default_dir}
      end

    socket =
      socket
      |> assign(:sort_by, new_by)
      |> assign(:sort_dir, new_dir)
      |> assign(:page, 1)

    {:noreply, refresh_list_light(socket)}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Refresh the current list view (re-runs apply_action with current socket state)
  defp refresh_list(socket) do
    apply_action(socket, :index, %{})
  end

  # Light refresh — only re-queries the paginated list + preloads.
  # Skips folder tree, root folders, and stats (saves ~9 queries).
  defp refresh_list_light(socket) do
    filters = %{
      access_level: socket.assigns.filter_access_level,
      file_type: socket.assigns.filter_file_type,
      attachable_type: socket.assigns.filter_attachable_type
    }

    {attachments, total_pages} =
      list_attachments_paginated(
        socket.assigns.page,
        @per_page,
        socket.assigns.search,
        filters,
        socket.assigns.current_folder_id,
        socket.assigns.sort_by,
        socket.assigns.sort_dir
      )

    attachments =
      Repo.preload(attachments, [:allowed_roles, :allowed_users, :access_settings_updated_by])

    socket
    |> stream(:attachments, attachments, reset: true)
    |> assign(:attachments_list, attachments)
    |> assign(:total_pages, total_pages)
    |> assign(:attachments_empty?, attachments == [])
    |> assign(:attachments_count, length(attachments))
  end

  defp list_attachments_paginated(
         page,
         per_page,
         search,
         filters,
         current_folder_id,
         sort_by,
         sort_dir
       ) do
    offset = (page - 1) * per_page

    # Base query – only show asset_vault, folder, and collection typed attachments
    query =
      from a in Attachment,
        where: a.attachable_type in ["asset_vault", "folder", "collection"]

    # Filter by current folder
    query =
      if current_folder_id do
        from a in query, where: a.parent_id == ^current_folder_id
      else
        from a in query, where: is_nil(a.parent_id)
      end

    # Search
    query =
      if search != "" do
        term = "%#{search}%"

        from a in query,
          where:
            ilike(a.original_name, ^term) or
              ilike(a.file_name, ^term) or
              ilike(a.description, ^term)
      else
        query
      end

    # Filters
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

    # Sorting – folders always first, then files ordered by the chosen field/direction.
    # We build order_by clauses directly inside from/2 to satisfy Ecto's macro requirements.
    query =
      case {sort_by, sort_dir} do
        {"original_name", "asc"} ->
          from a in query,
            order_by: [
              asc: fragment("CASE WHEN attachable_type = 'folder' THEN 0 ELSE 1 END"),
              asc: a.original_name
            ]

        {"original_name", _} ->
          from a in query,
            order_by: [
              asc: fragment("CASE WHEN attachable_type = 'folder' THEN 0 ELSE 1 END"),
              desc: a.original_name
            ]

        {"file_size", "asc"} ->
          from a in query,
            order_by: [
              asc: fragment("CASE WHEN attachable_type = 'folder' THEN 0 ELSE 1 END"),
              asc: a.file_size
            ]

        {"file_size", _} ->
          from a in query,
            order_by: [
              asc: fragment("CASE WHEN attachable_type = 'folder' THEN 0 ELSE 1 END"),
              desc: a.file_size
            ]

        {"file_type", "asc"} ->
          from a in query,
            order_by: [
              asc: fragment("CASE WHEN attachable_type = 'folder' THEN 0 ELSE 1 END"),
              asc: a.file_type
            ]

        {"file_type", _} ->
          from a in query,
            order_by: [
              asc: fragment("CASE WHEN attachable_type = 'folder' THEN 0 ELSE 1 END"),
              desc: a.file_type
            ]

        {_, "asc"} ->
          from a in query,
            order_by: [
              asc: fragment("CASE WHEN attachable_type = 'folder' THEN 0 ELSE 1 END"),
              asc: a.inserted_at
            ]

        _ ->
          from a in query,
            order_by: [
              asc: fragment("CASE WHEN attachable_type = 'folder' THEN 0 ELSE 1 END"),
              desc: a.inserted_at
            ]
      end

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = if total_count == 0, do: 0, else: ceil(total_count / per_page)

    attachments =
      query
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    {attachments, total_pages}
  end

  # ---------------------------------------------------------------------------
  # Stats
  # ---------------------------------------------------------------------------

  defp load_stats do
    from(a in Attachment,
      where: a.attachable_type in ["asset_vault", "collection"] and a.attachable_type != "folder",
      select: %{
        total: count(a.id),
        images: count(a.id) |> filter(a.file_type == "image"),
        videos: count(a.id) |> filter(a.file_type == "video"),
        documents: count(a.id) |> filter(a.file_type == "document"),
        other: count(a.id) |> filter(a.file_type not in ["image", "video", "document"])
      }
    )
    |> Repo.one()
    |> case do
      nil -> %{total: 0, images: 0, videos: 0, documents: 0, other: 0}
      stats -> stats
    end
  end

  # ---------------------------------------------------------------------------
  # Folder tree
  # ---------------------------------------------------------------------------

  defp build_folder_tree do
    all_folders =
      Repo.all(
        from a in Attachment,
          where: a.attachable_type == "folder",
          order_by: a.file_name
      )

    # Count direct children (files + folders) per folder
    counts_query =
      from a in Attachment,
        where: not is_nil(a.parent_id),
        group_by: a.parent_id,
        select: {a.parent_id, count(a.id)}

    counts = counts_query |> Repo.all() |> Enum.into(%{})

    # Build tree recursively from root folders
    build_tree_nodes(all_folders, nil, counts)
  end

  defp build_tree_nodes(all_folders, parent_id, counts) do
    all_folders
    |> Enum.filter(&(&1.parent_id == parent_id))
    |> Enum.map(fn folder ->
      children = build_tree_nodes(all_folders, folder.id, counts)

      %{
        folder: folder,
        children: children,
        count: Map.get(counts, folder.id, 0)
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Filter / query param helpers
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Display helpers
  # ---------------------------------------------------------------------------

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

  defp file_type_icon("image"), do: "hero-photo"
  defp file_type_icon("video"), do: "hero-video-camera"
  defp file_type_icon("audio"), do: "hero-musical-note"
  defp file_type_icon("document"), do: "hero-document-text"
  defp file_type_icon("archive"), do: "hero-archive-box"
  defp file_type_icon("software"), do: "hero-cpu-chip"
  defp file_type_icon(_), do: "hero-document"

  defp has_thumbnail?(attachment) do
    attachment.file_type == "image"
  end

  defp thumbnail_url(attachment) do
    if attachment.file_type == "image" do
      build_file_url(attachment.file_path)
    else
      nil
    end
  end

  defp build_file_url(nil), do: nil

  defp build_file_url(file_path) do
    # file_path already contains the URL returned by the storage adapter:
    # - Local storage: "/uploads/folder/filename"
    # - S3: full https:// URL
    file_path
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when bytes < 1_073_741_824,
    do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_073_741_824, 1)} GB"

  # ---------------------------------------------------------------------------
  # Upload / Storage
  # ---------------------------------------------------------------------------

  defp upload_attachment(%{path: temp_path}, entry, current_folder_id) do
    filename = entry.client_name
    mime_type = entry.client_type

    case Client.Storage.upload(
           %{path: temp_path, filename: filename, content_type: mime_type},
           folder: "asset_vault"
         ) do
      {:ok, file_url} ->
        file_type = Attachment.determine_file_type(mime_type)
        {:ok, file_stat} = File.stat(temp_path)

        attachment_attrs = %{
          file_name: Path.basename(file_url),
          original_name: filename,
          file_path: file_url,
          file_size: file_stat.size,
          mime_type: mime_type,
          file_type: file_type,
          attachable_type: "asset_vault",
          parent_id: current_folder_id,
          access_level: "public"
        }

        case Repo.insert(Attachment.changeset(%Attachment{}, attachment_attrs)) do
          {:ok, attachment} -> {:ok, attachment.id}
          {:error, changeset} -> {:error, "Failed to create record: #{inspect(changeset.errors)}"}
        end

      {:error, reason} ->
        {:error, "File upload failed: #{inspect(reason)}"}
    end
  end

  defp delete_file_from_storage(file_path) do
    file_key =
      if String.starts_with?(file_path, "/uploads") do
        file_path
        |> String.trim_leading("/")
        |> String.replace_prefix("uploads/", "")
      else
        Storage.S3.extract_file_key_from_url(file_path)
      end

    case Storage.delete(file_key) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        require Logger
        Logger.warning("Failed to delete file from storage: #{inspect(reason)}")
        :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Folder / breadcrumb helpers
  # ---------------------------------------------------------------------------

  defp count_folder_items(folder_id) do
    Repo.aggregate(
      from(a in Attachment, where: a.parent_id == ^folder_id),
      :count,
      :id
    )
  end

  defp list_all_folders do
    Repo.all(
      from a in Attachment,
        where: a.attachable_type == "folder",
        order_by: a.file_name
    )
  end

  defp list_root_folders do
    Repo.all(
      from a in Attachment,
        where: a.attachable_type == "folder" and is_nil(a.parent_id),
        order_by: a.file_name
    )
  end

  defp get_folder_path_ids(current_folder_id) do
    if current_folder_id do
      get_ancestor_ids(current_folder_id) ++ [current_folder_id]
    else
      []
    end
  end

  defp get_ancestor_ids(folder_id) do
    case Repo.get(Attachment, folder_id) do
      nil ->
        []

      folder ->
        if folder.parent_id do
          [folder.parent_id | get_ancestor_ids(folder.parent_id)]
        else
          []
        end
    end
  end

  defp build_breadcrumbs_to_folder(folder) do
    ancestor_ids = get_ancestor_ids(folder.id) |> Enum.reverse()
    all_ids = ancestor_ids ++ [folder.id]

    folders_map =
      Repo.all(from a in Attachment, where: a.id in ^all_ids)
      |> Enum.into(%{}, &{&1.id, &1})

    folders = Enum.map(all_ids, &folders_map[&1])

    Enum.reduce(folders, [%{name: "Asset Vault", id: nil}], fn f, acc ->
      acc ++ [%{name: f.file_name, id: f.id}]
    end)
  end

  # ---------------------------------------------------------------------------
  # Upload error helpers
  # ---------------------------------------------------------------------------

  defp humanize_upload_error(:too_large), do: "File is too large"
  defp humanize_upload_error(:not_accepted), do: "File type not accepted"
  defp humanize_upload_error(:too_many_files), do: "Too many files selected"
  defp humanize_upload_error(_), do: "Upload failed"

  # ---------------------------------------------------------------------------
  # Function components
  # ---------------------------------------------------------------------------

  attr :node, :map, required: true
  attr :depth, :integer, required: true
  attr :current_folder_id, :string, default: nil
  attr :folder_path_ids, :list, default: []

  def folder_tree_node(assigns) do
    ~H"""
    <% is_active = @current_folder_id == @node.folder.id %>
    <% is_in_path = @node.folder.id in @folder_path_ids %>
    <button
      phx-click="navigate_folder"
      phx-value-id={@node.folder.id}
      style={"padding-left: #{(@depth - 1) * 12 + 12}px"}
      class={[
        "w-full text-left pr-2 py-1.5 rounded-md text-sm transition-colors flex items-center gap-2",
        if(is_active,
          do: "bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 font-medium",
          else: "text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"
        )
      ]}
    >
      <%= if is_in_path do %>
        <.icon name="hero-folder-open" class="w-4 h-4 text-blue-500 shrink-0" />
      <% else %>
        <.icon name="hero-folder" class="w-4 h-4 text-blue-400 shrink-0" />
      <% end %>
      <span class="truncate flex-1">{@node.folder.file_name}</span>
      <span class="text-xs text-gray-400">{@node.count}</span>
    </button>
    <%= if is_in_path and length(@node.children) > 0 do %>
      <%= for child <- @node.children do %>
        <.folder_tree_node
          node={child}
          depth={@depth + 1}
          current_folder_id={@current_folder_id}
          folder_path_ids={@folder_path_ids}
        />
      <% end %>
    <% end %>
    """
  end

  attr :node, :map, required: true
  attr :depth, :integer, required: true

  def move_folder_option(assigns) do
    ~H"""
    <button
      phx-click="move_selected_to"
      phx-value-folder_id={@node.folder.id}
      style={"padding-left: #{(@depth - 1) * 16 + 12}px"}
      class="w-full text-left pr-3 py-2 rounded-md text-sm flex items-center gap-2 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
    >
      <.icon name="hero-folder" class="w-4 h-4 text-blue-400 shrink-0" />
      <span class="truncate">{@node.folder.file_name}</span>
    </button>
    <%= for child <- @node.children do %>
      <.move_folder_option node={child} depth={@depth + 1} />
    <% end %>
    """
  end
end
