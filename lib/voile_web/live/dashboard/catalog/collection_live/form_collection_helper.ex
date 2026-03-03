defmodule VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper do
  use VoileWeb, :live_component

  import Voile.Utils.ItemHelper

  alias Client.Storage
  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Collection
  alias Voile.Repo
  alias Voile.Schema.Master
  alias Voile.Schema.Metadata

  @doc """
  Ensures the collection has a unique UUID that won't cause barcode collisions.

  For new collections, this checks if the current UUID's barcode prefix (last 12 chars)
  collides with any existing collection. If so, it generates a new unique UUID.

  For existing collections (edit mode), this returns the params unchanged since
  the collection ID should not be changed.

  ## Parameters

    - collection_params: The collection parameters map containing "id" key
    - action: :new or :edit

  ## Returns

    - {:ok, updated_params} - Params with unique UUID
    - {:error, :max_attempts_reached} - If unable to find unique UUID
  """
  def ensure_unique_collection_uuid(collection_params, :edit) do
    # For edit mode, we don't change the collection ID
    # But we should verify that the existing ID doesn't collide with others
    # (this would be a data integrity issue, but we handle it gracefully)
    {:ok, collection_params}
  end

  def ensure_unique_collection_uuid(collection_params, :new) do
    collection_id = collection_params["id"]

    # Check if the current UUID's barcode prefix collides with existing collections
    barcode_prefix = extract_barcode_prefix(collection_id)

    if barcode_prefix && Catalog.barcode_prefix_exists(barcode_prefix) do
      # Collision detected - generate a new unique UUID
      case generate_unique_collection_uuid(&Catalog.barcode_prefix_exists/1) do
        {:ok, new_uuid} ->
          # Update the collection ID and regenerate item codes if items exist
          updated_params = update_collection_id_in_params(collection_params, new_uuid)
          {:ok, updated_params}

        {:error, reason} ->
          {:error, reason}
      end
    else
      # No collision, use the existing UUID
      {:ok, collection_params}
    end
  end

  @doc false
  defp update_collection_id_in_params(collection_params, new_uuid) do
    old_id = collection_params["id"]

    # Update the collection ID
    updated_params = Map.put(collection_params, "id", new_uuid)

    # Update item codes if items exist
    items = collection_params["items"] || %{}

    updated_items =
      items
      |> Enum.map(fn {key, item_data} ->
        updated_item = update_item_with_new_collection_id(item_data, old_id, new_uuid)
        {key, updated_item}
      end)
      |> Enum.into(%{})

    Map.put(updated_params, "items", updated_items)
  end

  @doc false
  defp update_item_with_new_collection_id(item_data, _old_collection_id, new_collection_id) do
    # Extract the index from the current item_code
    # Item code format: unit-type-collection_uuid-timestamp-index
    current_item_code = item_data["item_code"]

    if current_item_code do
      # Get the index (last segment after the last hyphen)
      index =
        current_item_code
        |> String.split("-")
        |> List.last()

      # Extract unit and type from the existing item_code. The unit segment was
      # already generated from the librarian's node abbr (via add_item_to_form),
      # so parsing it back here preserves the correct node-based unit assignment.
      parts = String.split(current_item_code, "-")

      unit = Enum.at(parts, 0) || "unk"
      type = Enum.at(parts, 1) || "unk"

      # Get the time_identifier from socket assigns if available, or use current time
      time_identifier = System.system_time(:millisecond)

      # Generate new codes with the new collection ID
      new_item_code = generate_item_code(unit, type, new_collection_id, time_identifier, index)
      new_barcode = generate_barcode_from_item_code(new_item_code)

      # Update inventory code as well
      new_inventory_code = generate_inventory_code(unit, type, new_collection_id, index)

      item_data
      |> Map.put("item_code", new_item_code)
      |> Map.put("inventory_code", new_inventory_code)
      |> Map.put("barcode", new_barcode)
    else
      item_data
    end
  end

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
    type_id = current_params["type_id"]
    collection_title = current_params["title"]

    # The unit is determined by the librarian's assigned node (current_scope.user.node_id),
    # NOT the collection's unit_id. An item's location is owned by the node that adds it;
    # the same collection metadata can be split across multiple nodes, each with its own
    # item codes and inventory codes.
    librarian_node_id = socket.assigns.current_scope.user.node_id

    unit_data =
      if librarian_node_id && librarian_node_id != "",
        do: Voile.Schema.System.get_node!(librarian_node_id) || %{abbr: "UNK", name: "Unknown"},
        else: %{abbr: "UNK", name: "Unknown"}

    type_data =
      if type_id && type_id != "",
        do: Metadata.get_resource_class!(type_id) || %{local_name: "UNK"},
        else: %{local_name: "UNK"}

    # Get current items
    current_items = current_params["items"] || %{}

    # Generate new item
    new_index = map_size(current_items)

    # Precompute codes so we can also generate the barcode immediately for the UI
    item_code =
      generate_item_code(
        unit_data.abbr,
        type_data.local_name,
        collection_id,
        socket.assigns.time_identifier,
        to_string(new_index + 1)
      )

    inventory_code =
      generate_inventory_code(
        unit_data.abbr,
        type_data.local_name,
        collection_id || collection_title,
        to_string(new_index + 1)
      )

    barcode = generate_barcode_from_item_code(item_code)

    new_item = %{
      "item_code" => item_code,
      # Use collection identifier (uuid) to match seed/db style. Fall back to
      # collection title if collection_id is missing.
      "inventory_code" => inventory_code,
      "barcode" => barcode,
      "item_location_id" => librarian_node_id,
      "location" => "",
      "status" => "active",
      # Schema defines allowed conditions as: excellent, good, fair, poor, damaged
      # Use "good" as a sane default instead of the previously used "new" which
      # is not in the allowed list and caused validation failures.
      "condition" => "good",
      # Default availability should start as "in_processing" instead of
      # "available".  This matches the new requirement and avoids the user
      # having to remember to change it when adding items.
      "availability" => "in_processing",
      # unit_id reflects the librarian's node, not the collection's node,
      # because the item physically belongs to the node that registered it.
      "unit_id" => librarian_node_id,
      "legacy_item_code" => nil
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
    # Try to fetch the collection field (non-bang to handle already-deleted gracefully)
    case Catalog.get_collection_field(id) do
      nil ->
        # Field not found (already deleted), return unchanged socket
        socket

      field ->
        # Delete the field from database
        user_id = socket.assigns.current_scope.user.id

        case Catalog.delete_collection_field(field, user_id) do
          {:ok, _} ->
            # Re-fetch authoritative collection state from DB (with preloads)
            # so the UI reliably reflects the deletion without stale form state.
            coll_id = socket.assigns.collection.id

            updated_collection =
              try do
                Catalog.get_collection!(coll_id)
                |> Repo.preload([:mst_creator, :items, collection_fields: [:metadata_properties]])
              rescue
                _ -> socket.assigns.collection
              end

            # Extract any unsaved (no DB id) fields from the current form params
            # so they are preserved across the DB-refresh rebuild.
            current_form_params = socket.assigns.form.params || %{}
            current_form_fields = Map.get(current_form_params, "collection_fields", %{})

            unsaved_form_fields =
              current_form_fields
              |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
              |> Enum.map(fn {_, v} -> v end)
              |> Enum.reject(fn field_data ->
                field_id = field_data["id"] || field_data[:id]
                field_id not in [nil, ""]
              end)

            # Build persisted-field params from the refreshed DB state
            db_field_params =
              (updated_collection.collection_fields || [])
              |> Enum.map(fn cf ->
                %{
                  "id" => cf.id,
                  "label" => cf.label,
                  "name" => cf.name,
                  "information" =>
                    case Map.get(cf, :metadata_properties) do
                      %Ecto.Association.NotLoaded{} -> ""
                      nil -> ""
                      mp -> mp.information
                    end,
                  "type_value" => cf.type_value,
                  "value_lang" => cf.value_lang,
                  "value" => cf.value,
                  "sort_order" => cf.sort_order,
                  "property_id" => cf.property_id
                }
              end)

            # Merge: persisted DB fields first, then unsaved in-memory fields
            field_params =
              (db_field_params ++ unsaved_form_fields)
              |> Enum.with_index()
              |> Enum.into(%{}, fn {v, idx} -> {to_string(idx), v} end)

            item_params =
              (updated_collection.items || [])
              |> Enum.with_index()
              |> Enum.into(%{}, fn {item, idx} ->
                {to_string(idx),
                 %{
                   "id" => item.id,
                   "item_code" => item.item_code,
                   "inventory_code" => item.inventory_code,
                   "barcode" => Map.get(item, :barcode, ""),
                   "location" => item.location,
                   "item_location_id" => item.item_location_id,
                   "unit_id" => item.unit_id,
                   "status" => item.status,
                   "condition" => item.condition,
                   "availability" => item.availability
                 }}
              end)

            initial_params = %{
              "id" => updated_collection.id,
              "title" => updated_collection.title || "",
              "description" => updated_collection.description || "",
              "status" => updated_collection.status || "draft",
              "access_level" => updated_collection.access_level || "private",
              "type_id" => updated_collection.type_id,
              "unit_id" => updated_collection.unit_id,
              "creator_id" => updated_collection.creator_id,
              "thumbnail" => updated_collection.thumbnail || "",
              "parent_id" => updated_collection.parent_id,
              "collection_type" => updated_collection.collection_type,
              "sort_order" => updated_collection.sort_order || 1,
              "collection_fields" => field_params,
              "items" => item_params
            }

            changeset = Catalog.change_collection(updated_collection, initial_params)

            socket
            |> assign(:form, to_form(changeset, action: :validate))
            |> assign(:collection, updated_collection)
            |> assign(:original_collection, updated_collection)
            |> assign(:chosen_collection_field, nil)
            |> assign(:delete_field_confirmation_id, nil)

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
        user_id = socket.assigns.current_scope.user.id

        case Catalog.delete_item(item, user_id) do
          {:ok, _} ->
            # Re-fetch authoritative collection state from DB (with preloads)
            # and rebuild the form so the UI reflects the deletion reliably.
            coll_id = socket.assigns.collection.id

            updated_collection =
              try do
                Catalog.get_collection!(coll_id)
                |> Repo.preload([:mst_creator, :items, collection_fields: [:metadata_properties]])
              rescue
                _ -> socket.assigns.collection
              end

            # Build form params from the authoritative collection so we preserve
            # any remaining items when the user adds a new one later.
            item_params =
              (updated_collection.items || [])
              |> Enum.with_index()
              |> Enum.into(%{}, fn {item, idx} ->
                {to_string(idx),
                 %{
                   "id" => item.id,
                   "item_code" => item.item_code,
                   "inventory_code" => item.inventory_code,
                   "barcode" => Map.get(item, :barcode, ""),
                   "location" => item.location,
                   "item_location_id" => item.item_location_id,
                   "unit_id" => item.unit_id,
                   "status" => item.status,
                   "condition" => item.condition,
                   "availability" => item.availability
                 }}
              end)

            field_params =
              (updated_collection.collection_fields || [])
              |> Enum.with_index()
              |> Enum.into(%{}, fn {field, idx} ->
                {to_string(idx),
                 %{
                   "id" => field.id,
                   "label" => field.label,
                   "information" =>
                     case Map.get(field, :metadata_properties) do
                       %Ecto.Association.NotLoaded{} -> ""
                       nil -> ""
                       mp -> mp.information
                     end,
                   "type_value" => field.type_value,
                   "value_lang" => field.value_lang,
                   "value" => field.value,
                   "sort_order" => field.sort_order
                 }}
              end)

            initial_params =
              %{
                "id" => updated_collection.id,
                "title" => updated_collection.title || "",
                "description" => updated_collection.description || "",
                "status" => updated_collection.status || "draft",
                "access_level" => updated_collection.access_level || "private",
                "type_id" => updated_collection.type_id,
                "unit_id" => updated_collection.unit_id,
                "creator_id" => updated_collection.creator_id,
                "thumbnail" => updated_collection.thumbnail || "",
                "parent_id" => updated_collection.parent_id,
                "collection_type" => updated_collection.collection_type,
                "sort_order" => updated_collection.sort_order || 1,
                "collection_fields" => field_params,
                "items" => item_params
              }

            changeset = Catalog.change_collection(updated_collection, initial_params)

            socket
            |> assign(:form, to_form(changeset, action: :validate))
            |> assign(:collection, updated_collection)
            |> assign(:original_collection, updated_collection)
            |> assign(:chosen_item_field, nil)
            |> assign(:delete_item_confirmation_id, nil)

          {:error, _} ->
            socket
            |> put_flash(:error, "Could not delete item")
        end
    end
  end

  def confirm_field_deletion(id, socket) do
    case Catalog.get_collection_field(id) do
      nil ->
        # Field was already deleted (e.g. a previous deletion succeeded but the
        # UI hadn't re-rendered yet). Silently clear the confirmation state so
        # the LiveView process doesn't crash.
        socket
        |> assign(:delete_field_confirmation_id, nil)
        |> assign(:chosen_collection_field, nil)
        |> put_flash(:info, "Field has already been removed.")

      chosen_collection_field ->
        socket
        |> assign(:delete_field_confirmation_id, id)
        |> assign(:chosen_collection_field, chosen_collection_field)
    end
  end

  def confirm_item_deletion(id, socket) do
    case Catalog.get_item(id) do
      nil ->
        socket
        |> assign(:delete_item_confirmation_id, nil)
        |> assign(:chosen_item_field, nil)
        |> put_flash(:info, "Item has already been removed.")

      chosen_item ->
        socket
        |> assign(:delete_item_confirmation_id, id)
        |> assign(:chosen_item_field, chosen_item)
    end
  end

  def search_properties(query, socket) do
    filtered = filter_properties(socket.assigns.collection_properties, query)

    socket
    |> assign(:property_search, query)
    |> assign(:filtered_properties, filtered)
  end

  def handle_delete_thumbnail(%{"thumbnail" => thumbnail_path}, socket) do
    source = socket.assigns.thumbnail_source
    attachment_id = socket.assigns.thumbnail_attachment_id

    socket =
      case source do
        "local" ->
          # Cancel uploads and delete attachment if exists
          uploads = socket.assigns.uploads

          socket =
            Enum.reduce(uploads.thumbnail.entries, socket, fn entry, sock ->
              cancel_upload(sock, :thumbnail, entry.ref)
            end)

          if attachment_id do
            case Repo.get(Voile.Schema.Catalog.Attachment, attachment_id) do
              nil -> :ok
              attachment -> Repo.delete(attachment)
            end
          end

          socket

        "vault" ->
          # Just clear, don't delete the existing attachment
          socket

        "url" ->
          # Delete the attachment we created
          if attachment_id do
            case Repo.get(Voile.Schema.Catalog.Attachment, attachment_id) do
              nil -> :ok
              attachment -> Repo.delete(attachment)
            end
          end

          socket

        _ ->
          socket
      end

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

          unit_id =
            case collection.unit_id || socket.assigns.form.params["unit_id"] do
              "" -> nil
              id -> id
            end

          # Get file size
          {:ok, stat} = File.stat(path)
          file_size = stat.size

          case Storage.upload(upload,
                 folder: "thumbnails",
                 generate_filename: true,
                 unit_id: unit_id
               ) do
            {:ok, file_url} ->
              # Create attachment record for thumbnail
              case create_thumbnail_attachment(collection, file_url, entry, file_size, unit_id) do
                {:ok, attachment} -> {:ok, [file_url, attachment.id]}
                :ok -> {:ok, [file_url, nil]}
              end

            {:error, error_message} ->
              {:error, error_message}
          end
        end)

      case result do
        [[url, attachment_id]] ->
          form_params =
            (socket.assigns.form.params || %{})
            |> Map.put("thumbnail", url)
            |> Map.put("thumbnail_source", "local")
            |> Map.put("thumbnail_attachment_id", attachment_id)

          socket =
            socket
            |> assign(:form, %{socket.assigns.form | params: form_params})
            |> assign(:collection, %{socket.assigns.collection | thumbnail: url})
            |> assign(:thumbnail_source, "local")
            |> assign(:thumbnail_attachment_id, attachment_id)
            |> assign(:asset_vault_files, Catalog.list_all_attachments())

          {:noreply, socket}

        [{:error, error_message}] ->
          {:noreply, put_flash(socket, :error, error_message)}

        _ ->
          {:noreply, put_flash(socket, :error, "Unexpected upload result: #{inspect(result)}")}
      end
    else
      {:noreply, socket}
    end
  end

  # Create attachment record for collection thumbnail
  defp create_thumbnail_attachment(_collection, file_url, entry, file_size, _unit_id) do
    # Extract file_key from file_url
    file_key =
      cond do
        String.starts_with?(file_url, "/uploads/") ->
          String.trim_leading(file_url, "/uploads/")

        String.contains?(file_url, "/uploads/") ->
          file_url |> String.split("/uploads/") |> List.last()

        true ->
          file_url
      end

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Create attachment in asset vault so it appears there
    attrs = %{
      id: Ecto.UUID.generate(),
      attachable_type: "asset_vault",
      attachable_id: nil,
      file_name: Path.basename(file_url),
      original_name: entry.client_name,
      file_path: file_url,
      file_key: file_key,
      file_size: file_size,
      mime_type: entry.client_type,
      file_type: Voile.Schema.Catalog.Attachment.determine_file_type(entry.client_type),
      description: "Thumbnail uploaded for collection",
      unit_id: nil,
      parent_id: nil,
      is_primary: false,
      sort_order: 0,
      inserted_at: now,
      updated_at: now
    }

    case Voile.Repo.insert(struct(Voile.Schema.Catalog.Attachment, attrs)) do
      {:ok, attachment} -> {:ok, attachment}
      {:error, _} -> :ok
    end
  end

  def save_collection(socket, :edit, collection_params) do
    # Validate that all items have item_location_id
    # items = collection_params["items"] || %{}

    # invalid_items =
    #   Enum.filter(items, fn {_key, item} -> item["item_location_id"] in [nil, ""] end)

    # if invalid_items != [] do
    #   {:noreply,
    #    socket
    #    |> put_flash(:error, "All items must have a location selected.")
    #    |> assign(:form, to_form(socket.assigns.form, action: :validate))}
    # else
    updated_by = socket.assigns.current_scope.user.id

    collection_params =
      collection_params
      |> Map.put("updated_by_id", updated_by)
      |> add_barcodes_to_items()

    case Catalog.update_collection(
           socket.assigns.original_collection,
           collection_params,
           updated_by
         ) do
      {:ok, collection} ->
        notify_parent({:saved, collection})

        {:noreply,
         socket
         |> put_flash(:info, "Collection updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end

    # end
  end

  def save_collection(socket, :new, collection_params) do
    # Validate that all items have item_location_id
    # items = collection_params["items"] || %{}

    # invalid_items =
    #   Enum.filter(items, fn {_key, item} -> item["item_location_id"] in [nil, ""] end)

    # if invalid_items != [] do
    #   {:noreply,
    #    socket
    #    |> put_flash(:error, "All items must have a location selected.")
    #    |> assign(:form, to_form(socket.assigns.form, action: :validate))}
    # else

    # Ensure unique collection UUID to prevent barcode collisions
    case ensure_unique_collection_uuid(collection_params, :new) do
      {:ok, collection_params} ->
        get_unit_abbr =
          if collection_params["unit_id"] do
            default_node = Voile.Schema.System.get_default_node()

            case Voile.Schema.System.get_node!(collection_params["unit_id"]) do
              nil -> default_node.abbr || "UNK"
              node -> node.abbr
            end
          else
            default_node = Voile.Schema.System.get_default_node()

            case default_node do
              nil -> "UNK"
              node -> node.abbr
            end
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

        case Catalog.create_collection(collection_params, created_by) do
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

      {:error, :max_attempts_reached} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to generate unique collection ID. Please try again.")}
    end

    # end
  end

  def save_collection_as_draft(socket, :edit, collection_params) do
    # For draft, allow saving without item_location_id
    updated_by = socket.assigns.current_scope.user.id

    draft_params =
      collection_params
      |> Map.put("updated_by_id", updated_by)
      |> Map.put("status", "draft")
      |> add_barcodes_to_items()

    case Catalog.update_collection(socket.assigns.original_collection, draft_params, updated_by) do
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
    # Ensure unique collection UUID to prevent barcode collisions
    case ensure_unique_collection_uuid(collection_params, :new) do
      {:ok, collection_params} ->
        # For draft, allow saving without item_location_id
        get_unit_abbr =
          if collection_params["unit_id"] do
            default_node = Voile.Schema.System.get_default_node()

            case Voile.Schema.System.get_node!(collection_params["unit_id"]) do
              nil -> default_node.abbr || "UNK"
              node -> node.abbr
            end
          else
            default_node = Voile.Schema.System.get_default_node()

            case default_node do
              nil -> "UNK"
              node -> node.abbr
            end
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

        case Catalog.create_collection(draft_params, created_by) do
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

      {:error, :max_attempts_reached} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to generate unique collection ID. Please try again.")}
    end
  end

  defp handle_delete_thumbnail_new(_thumbnail_path, socket) do
    collection_attrs = Map.put(socket.assigns.form.params, "thumbnail", nil)
    changeset = Catalog.change_collection(%Catalog.Collection{}, collection_attrs)

    socket =
      socket
      |> assign(:collection, %{socket.assigns.collection | thumbnail: nil})
      |> assign(:form, to_form(changeset))
      |> put_flash(:info, "Thumbnail removed")

    {:noreply, socket}
  end

  defp handle_delete_thumbnail_edit(_thumbnail_path, socket) do
    collection = socket.assigns.collection
    user_id = socket.assigns.current_scope.user.id

    case Catalog.update_collection(collection, %{thumbnail: nil}, user_id) do
      {:ok, updated_collection} ->
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

  # Note: barcode generation is provided by Voile.Utils.ItemHelper.generate_barcode_from_item_code/1

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

  def handle_add_thumbnail_from_url(url, socket) do
    if url == "" or url == nil do
      {:noreply, put_flash(socket, :error, "Please provide a valid URL")}
    else
      # Fetch the image from URL
      case Req.get(url, redirect: true) do
        {:ok, %{status: 200, body: body, headers: headers}} ->
          # Check if it's an image
          content_type =
            case headers["content-type"] || headers["Content-Type"] do
              [ct | _] when is_binary(ct) -> ct
              ct when is_binary(ct) -> ct
              _ -> ""
            end

          if String.starts_with?(content_type, "image/") do
            # Determine filename
            filename =
              case headers["content-disposition"] do
                [cd | _] ->
                  case Regex.run(~r/filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/, cd) do
                    [_, _, _, filename] -> filename
                    [_, filename] -> filename
                    _ -> Path.basename(url)
                  end

                _ ->
                  Path.basename(url)
              end

            # Create temp file
            temp_path =
              Path.join(
                System.tmp_dir(),
                "thumbnail_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}_#{filename}"
              )

            File.write!(temp_path, body)

            # Create Plug.Upload
            upload = %Plug.Upload{
              path: temp_path,
              filename: filename,
              content_type: content_type
            }

            # Upload to storage
            collection = socket.assigns.collection
            unit_id = collection.unit_id || socket.assigns.form.params["unit_id"]

            case Storage.upload(upload,
                   folder: "thumbnails",
                   generate_filename: true,
                   unit_id: unit_id
                 ) do
              {:ok, file_url} ->
                # Create attachment
                file_size = byte_size(body)
                entry = %{client_name: filename, client_type: content_type}

                case create_thumbnail_attachment(collection, file_url, entry, file_size, unit_id) do
                  {:ok, attachment} ->
                    # Update form
                    updated_params =
                      socket.assigns.form.params
                      |> Map.put("thumbnail", file_url)
                      |> Map.put("thumbnail_source", "url")
                      |> Map.put("thumbnail_attachment_id", attachment.id)

                    changeset =
                      Catalog.change_collection(socket.assigns.collection, updated_params)

                    # Clean up temp file
                    File.rm(temp_path)

                    socket =
                      socket
                      |> assign(:form, to_form(changeset, action: :validate))
                      |> assign(:thumbnail_source, "url")
                      |> assign(:thumbnail_attachment_id, attachment.id)
                      |> assign(:asset_vault_files, Catalog.list_all_attachments())
                      |> put_flash(:info, "Thumbnail added from URL successfully")

                    {:noreply, socket}

                  :ok ->
                    # Update form without attachment_id
                    updated_params =
                      socket.assigns.form.params
                      |> Map.put("thumbnail", file_url)
                      |> Map.put("thumbnail_source", "url")
                      |> Map.put("thumbnail_attachment_id", nil)

                    changeset =
                      Catalog.change_collection(socket.assigns.collection, updated_params)

                    File.rm(temp_path)

                    socket =
                      socket
                      |> assign(:form, to_form(changeset, action: :validate))
                      |> assign(:thumbnail_source, "url")
                      |> assign(:thumbnail_attachment_id, nil)
                      |> assign(:asset_vault_files, Catalog.list_all_attachments())
                      |> put_flash(:info, "Thumbnail added from URL successfully")

                    {:noreply, socket}
                end

              {:error, error} ->
                File.rm(temp_path)
                {:noreply, put_flash(socket, :error, "Failed to upload image: #{inspect(error)}")}
            end
          else
            {:noreply, put_flash(socket, :error, "URL does not point to a valid image")}
          end

        {:ok, %{status: status}} ->
          {:noreply, put_flash(socket, :error, "Failed to fetch image: HTTP #{status}")}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, "Failed to fetch image: #{inspect(error)}")}
      end
    end
  end
end
