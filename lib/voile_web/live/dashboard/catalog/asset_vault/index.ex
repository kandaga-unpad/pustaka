defmodule VoileWeb.Dashboard.Catalog.AssetVault.Index do
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
        # grid or list
        |> assign(:view_mode, "grid")
        |> assign(:loading_folder, false)
        |> assign(:sidebar_collapsed, false)
        |> assign(:root_folders, list_root_folders())
        |> assign(:folder_path_ids, get_folder_path_ids(nil))
        |> allow_upload(:attachments,
          accept: :any,
          max_entries: 10,
          max_file_size: 100_000_000,
          progress: &handle_progress/3,
          auto_upload: true
        )

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    page = socket.assigns.page
    # More items per page for grid view
    per_page = 24
    search = params["q"] || socket.assigns.search

    filters = build_filters_from_params(params)
    active_count = count_active_filters(filters)

    {attachments, total_pages} =
      list_attachments_paginated(
        page,
        per_page,
        search,
        filters,
        socket.assigns.current_folder_id
      )

    # Preload associations for display
    attachments =
      attachments
      |> Repo.preload([:allowed_roles, :allowed_users, :access_settings_updated_by])

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
    |> assign(:folder_path_ids, get_folder_path_ids(socket.assigns.current_folder_id))
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
      |> assign(:attachments_list, List.delete(socket.assigns.attachments_list, attachment))
      |> assign(:attachments_count, max((socket.assigns[:attachments_count] || 1) - 1, 0))

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 24
    search = socket.assigns[:search] || ""

    filters = %{
      access_level: socket.assigns.filter_access_level,
      file_type: socket.assigns.filter_file_type,
      attachable_type: socket.assigns.filter_attachable_type
    }

    {attachments, total_pages} =
      list_attachments_paginated(
        page,
        per_page,
        search,
        filters,
        socket.assigns.current_folder_id
      )

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
    search = socket.assigns.search
    query_params = build_query_params(%{filters: filters}, search)

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
        # Refresh the list
        page = socket.assigns.page
        per_page = 24
        search = socket.assigns.search

        filters = %{
          access_level: socket.assigns.filter_access_level,
          file_type: socket.assigns.filter_file_type,
          attachable_type: socket.assigns.filter_attachable_type
        }

        {attachments, total_pages} =
          list_attachments_paginated(
            page,
            per_page,
            search,
            filters,
            socket.assigns.current_folder_id
          )

        attachments =
          attachments
          |> Repo.preload([:allowed_roles, :allowed_users, :access_settings_updated_by])

        socket =
          socket
          |> stream(:attachments, attachments, reset: true)
          |> assign(:attachments_list, attachments)
          |> assign(:attachments_count, length(attachments))
          |> assign(:total_pages, total_pages)
          |> assign(:attachments_empty?, attachments == [])
          |> assign(:root_folders, list_root_folders())
          |> assign(:folder_path_ids, get_folder_path_ids(socket.assigns.current_folder_id))
          |> put_flash(:info, "Folder created successfully")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to create folder: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("navigate_folder", %{"id" => folder_id}, socket) do
    # Get the folder
    folder = Repo.get!(Attachment, folder_id)

    # Update breadcrumbs - rebuild path to this folder
    breadcrumbs = build_breadcrumbs_to_folder(folder)

    # Update current folder and show loading state
    socket =
      socket
      |> assign(:current_folder_id, folder.id)
      |> assign(:breadcrumbs, breadcrumbs)
      |> assign(:page, 1)
      |> assign(:loading_folder, true)
      |> assign(:folder_path_ids, get_folder_path_ids(folder.id))

    # Load folder contents
    {:noreply, apply_action(socket, :index, %{})}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, !socket.assigns.sidebar_collapsed)}
  end

  @impl true
  def handle_event("navigate_breadcrumb", %{"id" => folder_id}, socket) do
    folder_id = if folder_id == "", do: nil, else: folder_id

    # Find the breadcrumb index
    breadcrumbs = socket.assigns.breadcrumbs
    index = Enum.find_index(breadcrumbs, &(&1.id == folder_id))

    if index do
      # Keep breadcrumbs up to this point
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
  def handle_event("delete_folder", %{"id" => id}, socket) do
    authorize!(socket, "attachments.delete")

    folder = Repo.get!(Attachment, id)

    # Check if folder has children
    children_count = Repo.aggregate(from(a in Attachment, where: a.parent_id == ^id), :count, :id)

    if children_count > 0 do
      {:noreply, put_flash(socket, :error, "Cannot delete folder that contains items")}
    else
      {:ok, _} = Repo.delete(folder)

      socket =
        socket
        |> put_flash(:info, "Folder deleted successfully")
        |> stream_delete(:attachments, folder)
        |> assign(:attachments_count, max((socket.assigns[:attachments_count] || 1) - 1, 0))
        |> assign(:root_folders, list_root_folders())
        |> assign(:folder_path_ids, get_folder_path_ids(socket.assigns.current_folder_id))

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_view_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, mode)}
  end

  @impl true
  def handle_event("save_attachments", _params, socket) do
    results = consume_uploaded_entries(socket, :attachments, &upload_attachment/2)
    successful_uploads = Enum.filter(results, &match?({:ok, _}, &1))
    failed_uploads = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(failed_uploads) do
      attachment_ids = Enum.map(successful_uploads, fn {:ok, id} -> id end)

      # Refresh the attachments list
      page = socket.assigns.page
      per_page = 24
      search = socket.assigns.search

      filters = %{
        access_level: socket.assigns.filter_access_level,
        file_type: socket.assigns.filter_file_type,
        attachable_type: socket.assigns.filter_attachable_type
      }

      {attachments, total_pages} =
        list_attachments_paginated(
          page,
          per_page,
          search,
          filters,
          socket.assigns.current_folder_id
        )

      attachments =
        attachments
        |> Repo.preload([:allowed_roles, :allowed_users, :access_settings_updated_by])

      socket =
        socket
        |> stream(:attachments, attachments, reset: true)
        |> assign(:attachments_list, attachments)
        |> assign(:attachments_count, length(attachments))
        |> assign(:total_pages, total_pages)
        |> assign(:attachments_empty?, attachments == [])
        |> put_flash(:info, "Successfully uploaded #{length(attachment_ids)} file(s)")

      {:noreply, socket}
    else
      error_messages = Enum.map(failed_uploads, fn {:error, msg} -> msg end)
      {:noreply, put_flash(socket, :error, "Upload failed: #{Enum.join(error_messages, "; ")}")}
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachments, ref)}
  end

  # Upload progress handler
  def handle_progress(:attachments, _entry, socket) do
    {:noreply, socket}
  end

  # Helper functions
  defp list_attachments_paginated(page, per_page, search, filters, current_folder_id) do
    offset = (page - 1) * per_page

    query = from(a in Attachment, order_by: [desc: a.inserted_at])

    # Filter by current folder
    query =
      if current_folder_id do
        from a in query, where: a.parent_id == ^current_folder_id
      else
        from a in query, where: is_nil(a.parent_id)
      end

    # Only show asset_vault and folder types
    query = from a in query, where: a.attachable_type in ["asset_vault", "folder"]

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

  # File type icons
  defp file_type_icon("image"), do: "hero-photo"
  defp file_type_icon("video"), do: "hero-video-camera"
  defp file_type_icon("audio"), do: "hero-musical-note"
  defp file_type_icon("document"), do: "hero-document-text"
  defp file_type_icon("archive"), do: "hero-archive-box"
  defp file_type_icon("software"), do: "hero-cpu-chip"
  defp file_type_icon(_), do: "hero-document"

  # Check if attachment has thumbnail (for images)
  defp has_thumbnail?(attachment) do
    attachment.file_type == "image"
  end

  # Generate thumbnail URL (using the existing storage system)
  defp thumbnail_url(attachment) do
    if attachment.file_type == "image" do
      # For now, return the original image URL
      # In the future, this would generate/return actual thumbnails
      build_file_url(attachment.file_path)
    else
      # Return file type icon for non-images
      nil
    end
  end

  # Build file URL based on storage configuration
  defp build_file_url(file_path) do
    # file_path already contains the URL returned by storage adapter
    # For local storage: "/uploads/folder/filename"
    # For S3: full S3 URL
    file_path
  end

  # Format bytes for display
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when bytes < 1_073_741_824,
    do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_073_741_824, 1)} GB"

  # Upload attachment function for consume_uploaded_entries
  defp upload_attachment(
         %{path: temp_path, client_name: filename, client_type: mime_type},
         socket
       ) do
    # Upload file using Client.Storage
    case Client.Storage.upload(
           %{
             path: temp_path,
             filename: filename,
             content_type: mime_type
           },
           folder: "asset_vault"
         ) do
      {:ok, file_url} ->
        # Determine file type
        file_type = Attachment.determine_file_type(mime_type)

        # Get file size
        {:ok, file_stat} = File.stat(temp_path)
        file_size = file_stat.size

        # Create attachment record
        attachment_attrs = %{
          file_name: Path.basename(file_url),
          original_name: filename,
          file_path: file_url,
          file_size: file_size,
          mime_type: mime_type,
          file_type: file_type,
          attachable_type: "asset_vault",
          parent_id: socket.assigns.current_folder_id,
          access_level: "public"
        }

        case Repo.insert(Attachment.changeset(%Attachment{}, attachment_attrs)) do
          {:ok, attachment} ->
            {:ok, attachment.id}

          {:error, changeset} ->
            {:error, "Failed to create attachment record: #{inspect(changeset.errors)}"}
        end

      {:error, reason} ->
        {:error, "File upload failed: #{inspect(reason)}"}
    end
  end

  # Helper functions
  defp count_folder_items(folder_id) do
    Repo.aggregate(
      from(a in Attachment, where: a.parent_id == ^folder_id),
      :count,
      :id
    )
  end

  # Sidebar functions
  defp list_root_folders do
    Repo.all(
      from a in Attachment,
        where: a.attachable_type == "folder" and is_nil(a.parent_id),
        order_by: a.file_name
    )
  end

  # Get all ancestor folder IDs for the current folder (including itself)
  defp get_folder_path_ids(current_folder_id) do
    if current_folder_id do
      get_ancestor_ids(current_folder_id) ++ [current_folder_id]
    else
      []
    end
  end

  # Recursively get all ancestor IDs
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

  # Build breadcrumbs from root to the given folder
  defp build_breadcrumbs_to_folder(folder) do
    # Reverse to get root-to-leaf order
    ancestor_ids = get_ancestor_ids(folder.id) |> Enum.reverse()
    all_ids = ancestor_ids ++ [folder.id]

    # Get all folders in the path and order them by the path order
    folders_map =
      Repo.all(from a in Attachment, where: a.id in ^all_ids)
      |> Enum.into(%{}, &{&1.id, &1})

    # Order folders according to all_ids (path order)
    folders = Enum.map(all_ids, &folders_map[&1])

    # Build breadcrumbs starting with root
    breadcrumbs = [%{name: "Asset Vault", id: nil}]

    # Add each folder in path order
    Enum.reduce(folders, breadcrumbs, fn folder, acc ->
      acc ++ [%{name: folder.file_name, id: folder.id}]
    end)
  end

  # Helper functions
  defp humanize_upload_error(:too_large), do: "File is too large"
  defp humanize_upload_error(:not_accepted), do: "File type not accepted"
  defp humanize_upload_error(:too_many_files), do: "Too many files selected"
  defp humanize_upload_error(_), do: "Upload failed"
end
