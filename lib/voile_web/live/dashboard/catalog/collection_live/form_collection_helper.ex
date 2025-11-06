defmodule VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper do
  use VoileWeb, :live_component

  import Voile.Utils.ItemHelper

  alias Client.Storage
  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Master
  alias Voile.Schema.Metadata

  def add_property_to_form(prop_id, socket) do
    # Get current form params
    current_params = socket.assigns.form.params || %{}

    existing_items = current_params["items"] || %{}

    # Get current collection fields
    current_fields = current_params["collection_fields"] || %{}

    # Get property data
    property = Metadata.get_property!(prop_id)

    # Determine next index
    new_index = map_size(current_fields)

    # Create new field
    new_field = %{
      "label" => property.label,
      "type_value" => property.type_value,
      "information" => property.information,
      "property_id" => property.id,
      "name" => String.split(property.label) |> Enum.join(""),
      "value_lang" => "id",
      "value" => nil,
      "sort_order" => new_index + 1
    }

    # Add to existing fields
    updated_fields = Map.put(current_fields, to_string(new_index), new_field)

    # Create updated params with ALL existing data
    new_params =
      current_params
      |> Map.put("collection_fields", updated_fields)
      |> Map.put("items", existing_items)

    # Create changeset and update socket
    changeset = Catalog.change_collection(socket.assigns.collection, new_params)

    socket
    |> assign(:form, to_form(changeset, action: :validate))
  end

  def add_item_to_form(socket) do
    # Get current form params
    current_params = socket.assigns.form.params || %{}
    existing_fields = current_params["collection_fields"] || %{}

    # Get collection data from form params (step 1 data)
    collection_id = current_params["id"]
    unit_id = current_params["unit_id"]
    type_id = current_params["type_id"]
    collection_title = current_params["title"]

    # Safely get unit and type data
    unit_data =
      if unit_id && unit_id != "",
        do: Voile.Schema.System.get_node!(unit_id) || %{abbr: "UNK", name: "Unknown"},
        else: %{abbr: "UNK", name: "Unknown"}

    type_data =
      if type_id && type_id != "",
        do: Metadata.get_resource_class!(type_id) || %{local_name: "UNK"},
        else: %{local_name: "UNK"}

    # Get current items
    current_items = current_params["items"] || %{}

    # Generate new item
    new_index = map_size(current_items)

    new_item = %{
      "item_code" =>
        generate_item_code(
          unit_data.abbr,
          type_data.local_name,
          collection_id,
          socket.assigns.time_identifier,
          to_string(new_index + 1)
        ),
      "inventory_code" =>
        generate_inventory_code(
          unit_data.abbr,
          type_data.local_name,
          collection_title,
          to_string(new_index + 1)
        ),
      "location" => unit_data.name,
      "status" => "active",
      "condition" => "new",
      "availability" => "available",
      "unit_id" => unit_id
    }

    # Add new item
    updated_items = Map.put(current_items, to_string(new_index), new_item)

    new_params =
      current_params
      |> Map.put("items", updated_items)
      |> Map.put("collection_fields", existing_fields)

    changeset = Collection.changeset(socket.assigns.collection, new_params)

    socket
    |> assign(:form, to_form(changeset, action: :validate))
    |> assign(:collection_has_more_than_one_item, true)
  end

  def assign_selected_creator(id, socket) do
    # First try to find in suggestions (most recent search results)
    # Then try creator_list (preloaded creators)
    # Finally, fetch from database if not found
    selected =
      Enum.find(socket.assigns.creator_suggestions, fn c -> to_string(c.id) == id end) ||
        Enum.find(socket.assigns.creator_list, fn c -> to_string(c.id) == id end) ||
        try do
          Master.get_creator!(id)
        rescue
          _ -> nil
        end

    case selected do
      nil ->
        socket
        |> assign(:creator_input, "")
        |> assign(:creator_suggestions, [])

      selected ->
        # Get current form params
        current_params = socket.assigns.form.params || %{}
        # Update form params with selected creator_id
        updated_params = Map.put(current_params, "creator_id", selected.id |> to_string())
        # Create updated changeset
        changeset = Catalog.change_collection(socket.assigns.collection, updated_params)

        socket
        |> assign(:creator_input, selected.creator_name)
        |> assign(:creator_suggestions, [])
        # Don't update collection.mst_creator here - let it be loaded by Ecto when needed
        |> assign(:form, to_form(changeset, action: :validate))
    end
  end

  def create_or_select_creator(creator_name, socket) do
    case Master.get_or_create_creator(%{creator_name: creator_name}) do
      {:ok, new_creator} ->
        updated_creator_list = [new_creator | socket.assigns.creator_list]

        # Get current form params
        current_params = socket.assigns.form.params || %{}
        # Update form params with selected creator_id
        updated_params = Map.put(current_params, "creator_id", new_creator.id |> to_string())
        # Create updated changeset
        changeset = Catalog.change_collection(socket.assigns.collection, updated_params)

        socket =
          socket
          |> assign(:creator_input, new_creator.creator_name)
          |> assign(:creator_suggestions, [])
          |> assign(:creator_list, updated_creator_list)
          |> assign(:collection, %{
            socket.assigns.collection
            | creator_id: new_creator.id
          })
          |> assign(:form, to_form(changeset, action: :validate))

        {:ok, socket}

      {:error, _reason} ->
        socket =
          socket
          |> put_flash(:error, "Failed to create new creator.")
          |> assign(:creator_suggestions, [])
          |> assign(:collection, socket.assigns.collection)

        {:error, socket}
    end
  end

  def clear_selected_creator(socket) do
    # Get current form params
    current_params = socket.assigns.form.params || %{}
    # Remove creator_id from form params
    updated_params = Map.put(current_params, "creator_id", nil)
    # Create updated changeset
    changeset = Catalog.change_collection(socket.assigns.collection, updated_params)

    socket
    |> assign(:creator_input, nil)
    |> assign(:form, to_form(changeset, action: :validate))
  end

  def delete_unsaved_field_at(index_str, socket) do
    # Always start with current form parameters
    current_params = socket.assigns.form.params || %{}

    # Get current collection fields
    current_fields = Map.get(current_params, "collection_fields", %{})

    # Convert to list while preserving order
    sorted_entries =
      current_fields
      |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
      |> Enum.map(fn {_, v} -> v end)

    # Convert index to integer
    index = String.to_integer(index_str)

    # Delete the entry at the given index
    new_list = List.delete_at(sorted_entries, index)

    # Reindex and convert back to map
    new_fields =
      new_list
      |> Enum.with_index()
      |> Enum.into(%{}, fn {entry, idx} -> {to_string(idx), entry} end)

    # Create updated params with all existing data
    new_params = Map.put(current_params, "collection_fields", new_fields)

    # Create changeset with only the parameters (not the form struct)
    changeset = Catalog.change_collection(socket.assigns.collection, new_params)

    assign(socket, form: to_form(changeset, action: :validate))
  end

  def delete_unsaved_item_at(index_str, socket) do
    current_params = socket.assigns.form.params || %{}
    current_items = Map.get(current_params, "items", %{})

    sorted_entries =
      current_items
      |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
      |> Enum.map(fn {_, v} -> v end)

    index = String.to_integer(index_str)
    new_list = List.delete_at(sorted_entries, index)

    new_items =
      new_list
      |> Enum.with_index()
      |> Enum.into(%{}, fn {entry, idx} -> {to_string(idx), entry} end)

    new_params = Map.put(current_params, "items", new_items)
    changeset = Catalog.change_collection(socket.assigns.collection, new_params)

    assign(socket, form: to_form(changeset, action: :validate))
  end

  def delete_existing_field(id, socket) do
    # Try to fetch the collection field
    case Catalog.get_collection_field!(id) do
      nil ->
        # Field not found, return unchanged socket
        socket

      field ->
        # Delete the field from database
        case Catalog.delete_collection_field(field) do
          {:ok, _} ->
            # Get current form params
            current_params = socket.assigns.form.params || %{}

            # Get current collection fields
            current_fields = Map.get(current_params, "collection_fields", %{})

            # Remove the deleted field from form state
            updated_fields =
              current_fields
              |> Enum.reject(fn {_, field_data} ->
                field_data["id"] == id || field_data[:id] == id
              end)
              |> Enum.with_index()
              |> Enum.into(%{}, fn {field_data, idx} -> {to_string(idx), field_data} end)

            # Create updated params preserving all other data
            new_params = Map.put(current_params, "collection_fields", updated_fields)

            # Create changeset with updated params
            changeset = Catalog.change_collection(socket.assigns.collection, new_params)

            # Update socket without reloading collection
            socket
            |> assign(:form, to_form(changeset, action: :validate))

          {:error, _} ->
            # Deletion failed, show error
            socket
            |> put_flash(:error, "Could not delete field")
        end
    end
  end

  def delete_existing_item(id, socket) do
    case Catalog.get_item!(id) do
      nil ->
        socket

      item ->
        case Catalog.delete_item(item) do
          {:ok, _} ->
            current_params = socket.assigns.form.params || %{}
            current_items = Map.get(current_params, "items", %{})

            updated_items =
              current_items
              |> Enum.reject(fn {_, item_data} ->
                item_data["id"] == id || item_data[:id] == id
              end)
              |> Enum.with_index()
              |> Enum.into(%{}, fn {item_data, idx} -> {to_string(idx), item_data} end)

            new_params = Map.put(current_params, "items", updated_items)
            changeset = Catalog.change_collection(socket.assigns.collection, new_params)

            socket
            |> assign(:form, to_form(changeset, action: :validate))

          {:error, _} ->
            socket
            |> put_flash(:error, "Could not delete item")
        end
    end
  end

  def confirm_field_deletion(id, socket) do
    chosen_collection_field = Catalog.get_collection_field!(id)

    socket
    |> assign(:delete_field_confirmation_id, id)
    |> assign(:chosen_collection_field, chosen_collection_field)
  end

  def confirm_item_deletion(id, socket) do
    chosen_item = Catalog.get_item!(id)

    socket
    |> assign(:delete_item_confirmation_id, id)
    |> assign(:chosen_item_field, chosen_item)
  end

  def search_properties(query, socket) do
    filtered = filter_properties(socket.assigns.collection_properties, query)

    socket
    |> assign(:property_search, query)
    |> assign(:filtered_properties, filtered)
  end

  def handle_delete_thumbnail(%{"thumbnail" => thumbnail_path}, socket) do
    uploads = socket.assigns.uploads

    # Cancel all thumbnail uploads
    socket =
      Enum.reduce(uploads.thumbnail.entries, socket, fn entry, sock ->
        cancel_upload(sock, :thumbnail, entry.ref)
      end)

    case socket.assigns.action do
      :new -> handle_delete_thumbnail_new(thumbnail_path, socket)
      :edit -> handle_delete_thumbnail_edit(thumbnail_path, socket)
      _ -> handle_delete_thumbnail_new(thumbnail_path, socket)
    end
  end

  def handle_thumbnail_progress(:thumbnail, entry, socket) do
    if entry.done? do
      # Delete old thumbnail if exists
      if socket.assigns.form.params["thumbnail"] do
        Storage.delete(socket.assigns.form.params["thumbnail"])
      end

      result =
        consume_uploaded_entries(socket, :thumbnail, fn %{path: path}, entry ->
          upload = %Plug.Upload{
            path: path,
            filename: entry.client_name,
            content_type: entry.client_type
          }

          # Upload with thumbnail-specific options including unit_id for organization
          collection = socket.assigns.collection
          unit_id = collection.unit_id || socket.assigns.form.params["unit_id"]

          Storage.upload(upload,
            folder: "thumbnails",
            generate_filename: true,
            unit_id: unit_id
          )
        end)

      case result do
        [{:ok, url}] ->
          form_params = Map.put(socket.assigns.form.params || %{}, "thumbnail", url)
          changeset = Catalog.change_collection(socket.assigns.collection, form_params)

          {:noreply,
           socket
           |> assign(:form, to_form(changeset))
           |> assign(:collection, Ecto.Changeset.apply_changes(changeset))}

        [url] when is_binary(url) ->
          form_params = Map.put(socket.assigns.form.params || %{}, "thumbnail", url)
          changeset = Catalog.change_collection(socket.assigns.collection, form_params)

          {:noreply,
           socket
           |> assign(:form, to_form(changeset))
           |> assign(:collection, Ecto.Changeset.apply_changes(changeset))}

        [{:error, error_message}] ->
          {:noreply, put_flash(socket, :error, error_message)}

        _ ->
          {:noreply, put_flash(socket, :error, "Unexpected upload result: #{inspect(result)}")}
      end
    else
      {:noreply, socket}
    end
  end

  def save_collection(socket, :edit, collection_params) do
    updated_by = socket.assigns.current_scope.user.id

    collection_params =
      collection_params
      |> Map.put("updated_by_id", updated_by)
      |> add_barcodes_to_items()

    case Catalog.update_collection(socket.assigns.original_collection, collection_params) do
      {:ok, collection} ->
        notify_parent({:saved, collection})

        {:noreply,
         socket
         |> put_flash(:info, "Collection updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def save_collection(socket, :new, collection_params) do
    get_unit_abbr =
      if collection_params["unit_id"] do
        case Voile.Schema.System.get_node!(collection_params["unit_id"]) do
          nil -> "UNK"
          node -> node.abbr
        end
      else
        "UNK"
      end

    get_collection_type =
      if collection_params["type_id"] do
        case Metadata.get_resource_class!(collection_params["type_id"]) do
          nil -> "UNK"
          rc -> rc.glam_type |> String.slice(0, 3) |> String.upcase()
        end
      else
        "UNK"
      end

    generated_code = generate_collection_code(get_unit_abbr, get_collection_type)
    created_by = socket.assigns.current_scope.user.id

    collection_params =
      collection_params
      |> Map.put("collection_code", generated_code)
      |> Map.put("created_by_id", created_by)
      |> add_barcodes_to_items()

    case Catalog.create_collection(collection_params) do
      {:ok, collection} ->
        notify_parent({:saved, collection})

        {:noreply,
         socket
         |> put_flash(:info, "Collection created successfully")
         |> push_patch(
           to: socket.assigns.patch || ~p"/manage/catalog/collections/#{collection.id}"
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def save_collection_as_draft(socket, :edit, collection_params) do
    updated_by = socket.assigns.current_scope.user.id

    draft_params =
      collection_params
      |> Map.put("updated_by_id", updated_by)
      |> Map.put("status", "draft")
      |> add_barcodes_to_items()

    case Catalog.update_collection(socket.assigns.original_collection, draft_params) do
      {:ok, collection} ->
        notify_parent({:saved, collection})

        {:noreply,
         socket
         |> put_flash(:info, "Collection saved as draft successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def save_collection_as_draft(socket, :new, collection_params) do
    get_unit_abbr =
      if collection_params["unit_id"] do
        case Voile.Schema.System.get_node!(collection_params["unit_id"]) do
          nil -> "UNK"
          node -> node.abbr
        end
      else
        "UNK"
      end

    get_collection_type =
      if collection_params["type_id"] do
        case Metadata.get_resource_class!(collection_params["type_id"]) do
          nil -> "UNK"
          rc -> rc.glam_type |> String.slice(0, 3) |> String.upcase()
        end
      else
        "UNK"
      end

    generated_code = generate_collection_code(get_unit_abbr, get_collection_type)
    created_by = socket.assigns.current_scope.user.id

    # Ensure status is set to draft and add generated code
    draft_params =
      collection_params
      |> Map.put("collection_code", generated_code)
      |> Map.put("status", "draft")
      |> Map.put("created_by_id", created_by)
      |> add_barcodes_to_items()

    case Catalog.create_collection(draft_params) do
      {:ok, collection} ->
        notify_parent({:saved, collection})

        {:noreply,
         socket
         |> put_flash(:info, "Collection saved as draft successfully")
         |> push_patch(
           to: socket.assigns.patch || ~p"/manage/catalog/collections/#{collection.id}"
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp handle_delete_thumbnail_new(thumbnail_path, socket) do
    collection_attrs = Map.put(socket.assigns.form.params, "thumbnail", nil)
    changeset = Catalog.change_collection(%Catalog.Collection{}, collection_attrs)

    delete_thumbnail_file(thumbnail_path)

    socket =
      socket
      |> assign(:collection, %{socket.assigns.collection | thumbnail: nil})
      |> assign(:form, to_form(changeset))
      |> put_flash(:info, "Thumbnail removed")

    {:noreply, socket}
  end

  defp handle_delete_thumbnail_edit(thumbnail_path, socket) do
    collection = socket.assigns.collection

    case Catalog.update_collection(collection, %{thumbnail: nil}) do
      {:ok, updated_collection} ->
        delete_thumbnail_file(thumbnail_path)

        socket =
          socket
          |> assign(:collection, updated_collection)
          |> assign(:form, to_form(Catalog.change_collection(updated_collection, %{})))
          |> put_flash(:info, "Thumbnail deleted successfully")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> assign(:form, to_form(changeset))
          |> put_flash(:error, "Failed to delete thumbnail")

        {:noreply, socket}
    end
  end

  defp delete_thumbnail_file(nil), do: :ok
  defp delete_thumbnail_file(""), do: :ok

  defp delete_thumbnail_file(thumbnail_path) do
    Storage.delete(thumbnail_path)
  end

  defp filter_properties(properties, query) when is_binary(query) and query != "" do
    query = String.downcase(query)

    properties
    |> Enum.map(fn {category, props} ->
      filtered_props =
        Enum.filter(props, fn prop ->
          String.contains?(String.downcase(prop.label), query)
        end)

      {category, filtered_props}
    end)
    |> Enum.filter(fn {_category, props} -> length(props) > 0 end)
  end

  defp filter_properties(properties, _query), do: properties

  defp notify_parent(msg),
    do: send(self(), {VoileWeb.Dashboard.Catalog.CollectionLive.FormComponent, msg})

  defp generate_collection_code(unit, collection_type) do
    timestamp = :os.system_time(:second)
    random_suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)

    "COLLECTION-#{unit}-#{collection_type}-#{timestamp}-#{random_suffix}"
  end

  # Generate barcode from item_code
  # Extracts last UUID segment + sequence number for scannable 15-char barcode
  # Example: "kandaga-book-9c195395-d002-4c2a-8bfb-c47e6d008b3a-1761276668-001"
  # Returns: "c47e6d008b3a001"
  defp generate_barcode_from_item_code(item_code) when is_binary(item_code) do
    parts = String.split(item_code, "-")

    # Need at least 3 parts: [..., uuid_segment, timestamp, sequence]
    if length(parts) >= 3 do
      uuid_segment = Enum.at(parts, -3)
      sequence = List.last(parts)
      "#{uuid_segment}#{sequence}"
    else
      # Fallback for short codes: use full code
      String.replace(item_code, "-", "") |> String.slice(0, 15)
    end
  end

  defp generate_barcode_from_item_code(_), do: ""

  # Add barcodes to all items in collection_params
  defp add_barcodes_to_items(collection_params) do
    items = collection_params["items"] || %{}

    updated_items =
      items
      |> Enum.map(fn {key, item_data} ->
        # Only generate barcode if item has an item_code and doesn't already have a barcode
        updated_item =
          if item_data["item_code"] && (!item_data["barcode"] || item_data["barcode"] == "") do
            barcode = generate_barcode_from_item_code(item_data["item_code"])
            Map.put(item_data, "barcode", barcode)
          else
            item_data
          end

        {key, updated_item}
      end)
      |> Enum.into(%{})

    Map.put(collection_params, "items", updated_items)
  end
end
