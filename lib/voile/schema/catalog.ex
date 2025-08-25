defmodule Voile.Schema.Catalog do
  @moduledoc """
  The Catalog context.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo
  alias Voile.Schema.Catalog.{Collection, Item, CollectionField, ItemFieldValue, Attachment}

  @doc """
  Returns the list of collections.

  ## Examples

      iex> list_collections()
      [%Collection{}, ...]

  """
  def list_collections do
    Repo.all(Collection)
    |> Repo.preload([
      :resource_class,
      :resource_template,
      :mst_creator,
      :node,
      :collection_fields,
      :items
    ])
  end

  @doc """
  Return the list of collections for pagination.
  ## Examples

      iex> list_collections_paginated(page, per_page)
      {[%Collection{}, ...], total_pages}
  """
  def list_collections_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from c in Collection,
        preload: [
          :resource_class,
          :resource_template,
          :mst_creator,
          :node,
          :collection_fields,
          :items
        ],
        order_by: [desc: c.inserted_at, desc: c.id],
        limit: ^per_page,
        offset: ^offset

    collections = Repo.all(query)

    total_count = Repo.aggregate(Collection, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {collections, total_pages}
  end

  @doc """
  Gets a single collection.

  Raises `Ecto.NoResultsError` if the Collection does not exist.

  ## Examples

      iex> get_collection!(123)
      %Collection{}

      iex> get_collection!(456)
      ** (Ecto.NoResultsError)

  """
  def get_collection!(id) do
    Collection
    |> Repo.get!(id)
    |> Repo.preload([
      :resource_class,
      :resource_template,
      :mst_creator,
      :node,
      :attachments,
      items: [:node],
      collection_fields: [:metadata_properties]
    ])
  end

  @doc """
  Creates a collection.

  ## Examples

      iex> create_collection(%{field: value})
      {:ok, %Collection{}}

      iex> create_collection(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_collection(attrs \\ %{}) do
    %Collection{}
    |> Collection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a collection.

  ## Examples

      iex> update_collection(collection, %{field: new_value})
      {:ok, %Collection{}}

      iex> update_collection(collection, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_collection(%Collection{} = collection, attrs) do
    collection
    |> Collection.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a collection.

  ## Examples

      iex> delete_collection(collection)
      {:ok, %Collection{}}

      iex> delete_collection(collection)
      {:error, %Ecto.Changeset{}}

  """
  def delete_collection(%Collection{} = collection) do
    Repo.delete(collection)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking collection changes.

  ## Examples

      iex> change_collection(collection)
      %Ecto.Changeset{data: %Collection{}}

  """
  def change_collection(%Collection{} = collection, attrs \\ %{}) do
    collection
    |> Repo.preload([
      :resource_class,
      :resource_template,
      :mst_creator,
      :node,
      :collection_fields,
      :items
    ])
    |> Collection.changeset(attrs)
  end

  @doc """
  Remove and nilify the thumbnail of an existing collection.
  """

  def remove_thumbnail(%Collection{id: nil} = collection) do
    dbg(collection)
    {:error, :not_persisted}
  end

  def remove_thumbnail(%Collection{} = collection) do
    # Optional: delete file if needed
    file_path =
      case collection.thumbnail do
        nil -> nil
        path -> Path.join([:code.priv_dir(:voile), "static", path])
      end

    if file_path && File.exists?(file_path), do: File.rm(file_path)

    collection
    |> Collection.remove_thumbnail_changeset()
    |> Repo.update()
  end

  @doc """
  Returns the list of items.

  ## Examples

      iex> list_items()
      [%Item{}, ...]

  """
  def list_items do
    Repo.all(Item)
  end

  @doc """
  Gets a single item.

  Raises `Ecto.NoResultsError` if the Item does not exist.

  ## Examples

      iex> get_item!(123)
      %Item{}

      iex> get_item!(456)
      ** (Ecto.NoResultsError)

  """
  def get_item!(id) do
    Item
    |> Repo.get!(id)
    |> Repo.preload([:collection, :node])
  end

  def list_items_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from i in Item,
        preload: [
          :collection,
          :node
        ],
        order_by: [desc: i.inserted_at],
        limit: ^per_page,
        offset: ^offset

    items = Repo.all(query)

    total_count = Repo.aggregate(Item, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {items, total_pages}
  end

  @doc """
  Creates a item.

  ## Examples

      iex> create_item(%{field: value})
      {:ok, %Item{}}

      iex> create_item(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_item(attrs \\ %{}) do
    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a item.

  ## Examples

      iex> update_item(item, %{field: new_value})
      {:ok, %Item{}}

      iex> update_item(item, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a item.

  ## Examples

      iex> delete_item(item)
      {:ok, %Item{}}

      iex> delete_item(item)
      {:error, %Ecto.Changeset{}}

  """
  def delete_item(%Item{} = item) do
    Repo.delete(item)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking item changes.

  ## Examples

      iex> change_item(item)
      %Ecto.Changeset{data: %Item{}}

  """
  def change_item(%Item{} = item, attrs \\ %{}) do
    Item.changeset(item, attrs)
  end

  @doc """
  Returns the list of collection_fields.

  ## Examples

      iex> list_collection_fields()
      [%CollectionField{}, ...]

  """
  def list_collection_fields do
    Repo.all(CollectionField)
  end

  @doc """
  Gets a single collection_field.

  Raises `Ecto.NoResultsError` if the Collection field does not exist.

  ## Examples

      iex> get_collection_field!(123)
      %CollectionField{}

      iex> get_collection_field!(456)
      ** (Ecto.NoResultsError)

  """
  def get_collection_field!(id), do: Repo.get!(CollectionField, id)

  @doc """
  Creates a collection_field.

  ## Examples

      iex> create_collection_field(%{field: value})
      {:ok, %CollectionField{}}

      iex> create_collection_field(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_collection_field(attrs \\ %{}) do
    %CollectionField{}
    |> CollectionField.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a collection_field.

  ## Examples

      iex> update_collection_field(collection_field, %{field: new_value})
      {:ok, %CollectionField{}}

      iex> update_collection_field(collection_field, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_collection_field(%CollectionField{} = collection_field, attrs) do
    collection_field
    |> CollectionField.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a collection_field.

  ## Examples

      iex> delete_collection_field(collection_field)
      {:ok, %CollectionField{}}

      iex> delete_collection_field(collection_field)
      {:error, %Ecto.Changeset{}}

  """
  def delete_collection_field(%CollectionField{} = collection_field) do
    Repo.delete(collection_field)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking collection_field changes.

  ## Examples

      iex> change_collection_field(collection_field)
      %Ecto.Changeset{data: %CollectionField{}}

  """
  def change_collection_field(%CollectionField{} = collection_field, attrs \\ %{}) do
    CollectionField.changeset(collection_field, attrs)
  end

  @doc """
  Returns the list of item_field_values.

  ## Examples

      iex> list_item_field_values()
      [%ItemFieldValue{}, ...]

  """
  def list_item_field_values do
    Repo.all(ItemFieldValue)
  end

  @doc """
  Gets a single item_field_value.

  Raises `Ecto.NoResultsError` if the Item field value does not exist.

  ## Examples

      iex> get_item_field_value!(123)
      %ItemFieldValue{}

      iex> get_item_field_value!(456)
      ** (Ecto.NoResultsError)

  """
  def get_item_field_value!(id), do: Repo.get!(ItemFieldValue, id)

  @doc """
  Creates a item_field_value.

  ## Examples

      iex> create_item_field_value(%{field: value})
      {:ok, %ItemFieldValue{}}

      iex> create_item_field_value(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_item_field_value(attrs \\ %{}) do
    %ItemFieldValue{}
    |> ItemFieldValue.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a item_field_value.

  ## Examples

      iex> update_item_field_value(item_field_value, %{field: new_value})
      {:ok, %ItemFieldValue{}}

      iex> update_item_field_value(item_field_value, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_item_field_value(%ItemFieldValue{} = item_field_value, attrs) do
    item_field_value
    |> ItemFieldValue.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a item_field_value.

  ## Examples

      iex> delete_item_field_value(item_field_value)
      {:ok, %ItemFieldValue{}}

      iex> delete_item_field_value(item_field_value)
      {:error, %Ecto.Changeset{}}

  """
  def delete_item_field_value(%ItemFieldValue{} = item_field_value) do
    Repo.delete(item_field_value)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking item_field_value changes.

  ## Examples

      iex> change_item_field_value(item_field_value)
      %Ecto.Changeset{data: %ItemFieldValue{}}

  """
  def change_item_field_value(%ItemFieldValue{} = item_field_value, attrs \\ %{}) do
    ItemFieldValue.changeset(item_field_value, attrs)
  end

  @doc """
  Create attachment for a given entity using the new storage system

  Supports both legacy format (%{upload: upload, description: description})
  and new format (%{file_url: file_url, filename: filename, content_type: content_type, description: description})
  """
  def create_attachment(entity, %{upload: upload, description: description} = params) do
    # Legacy format - upload the file first, then create record
    case Client.Storage.upload(upload, folder: "attachments") do
      {:ok, file_url} ->
        file_size = Map.get(params, :file_size) || get_file_size_from_upload(upload)

        create_attachment_record(entity, %{
          file_url: file_url,
          filename: upload.filename,
          content_type: upload.content_type,
          description: description,
          file_size: file_size
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  def create_attachment(
        entity,
        %{
          file_url: file_url,
          filename: filename,
          content_type: content_type,
          description: description
        } = params
      ) do
    # New format - file already uploaded
    file_size = Map.get(params, :file_size) || get_file_size_from_url(file_url)

    create_attachment_record(entity, %{
      file_url: file_url,
      filename: filename,
      content_type: content_type,
      description: description,
      file_size: file_size
    })
  end

  @doc """
  Create multiple attachments for an entity
  """
  def create_attachments(entity, files_params) when is_list(files_params) do
    results = Enum.map(files_params, &create_attachment(entity, &1))

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {successes, []} ->
        attachments = Enum.map(successes, fn {:ok, attachment} -> attachment end)
        {:ok, attachments}

      {_, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Get all attachments for an entity
  """
  def list_attachments(%Collection{id: id}) do
    Attachment
    |> Attachment.for_entity(id, "collection")
    |> Repo.all()
  end

  def list_attachments(%Item{id: id}) do
    Attachment
    |> Attachment.for_entity(id, "item")
    |> Repo.all()
  end

  @doc """
  Get one attachments based on the id
  """
  def get_attachment!(id) do
    Repo.get!(Attachment, id)
  end

  @doc """
  Get attachments filtered by file type
  """
  def list_attachments_by_type(entity, file_type) do
    entity
    |> list_attachments()
    |> Enum.filter(&(&1.file_type == file_type))
  end

  @doc """
  Get primary attachment for an entity
  """
  def get_primary_attachment(%Collection{id: id}) do
    Attachment
    |> Attachment.primary_for_entity(id, "collection")
    |> Repo.one()
  end

  def get_primary_attachment(%Item{id: id}) do
    Attachment
    |> Attachment.primary_for_entity(id, "item")
    |> Repo.one()
  end

  @doc """
  Update attachment
  """
  def update_attachment(%Attachment{} = attachment, attrs) do
    attachment
    |> Attachment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete attachment and its file using the storage system
  """
  def delete_attachment(%Attachment{} = attachment) do
    # Delete file using storage system
    case Client.Storage.delete(attachment.file_path) do
      {:ok, _} ->
        # File deleted successfully, now delete the database record
        Repo.delete(attachment)

      {:error, reason} ->
        # Log the error but still try to delete the database record
        IO.inspect("Failed to delete file #{attachment.file_path}: #{inspect(reason)}")
        Repo.delete(attachment)
    end
  end

  @doc """
  Set attachment as primary (unsets other primary attachments for the same entity)
  """
  def set_primary_attachment(%Attachment{} = attachment) do
    Repo.transaction(fn ->
      # Unset all primary attachments for this entity
      from(a in Attachment,
        where:
          a.attachable_id == ^attachment.attachable_id and
            a.attachable_type == ^attachment.attachable_type and
            a.id != ^attachment.id
      )
      |> Repo.update_all(set: [is_primary: false])

      # Set this attachment as primary
      attachment
      |> Attachment.changeset(%{is_primary: true})
      |> Repo.update()
    end)
  end

  @doc """
  Reorder attachments for an entity
  """
  def reorder_attachments(entity, attachment_ids) when is_list(attachment_ids) do
    entity_type = get_entity_type(entity)
    entity_id = entity.id

    Repo.transaction(fn ->
      attachment_ids
      |> Enum.with_index()
      |> Enum.each(fn {attachment_id, index} ->
        from(a in Attachment,
          where:
            a.id == ^attachment_id and
              a.attachable_id == ^entity_id and
              a.attachable_type == ^entity_type
        )
        |> Repo.update_all(set: [sort_order: index])
      end)
    end)
  end

  @doc """
  Get file path for serving
  """
  def get_file_url(%Attachment{} = attachment) do
    "/uploads/attachments/#{Path.basename(attachment.file_path)}"
  end

  # Private functions

  defp create_attachment_record(entity, %{
         file_url: file_url,
         filename: filename,
         content_type: content_type,
         description: description,
         file_size: file_size
       }) do
    entity_type = get_entity_type(entity)
    entity_id = entity.id

    attrs = %{
      # Extract filename from URL
      file_name: Path.basename(file_url),
      original_name: filename,
      # Store the full URL/path
      file_path: file_url,
      file_size: file_size,
      mime_type: content_type,
      file_type: Attachment.determine_file_type(content_type),
      description: description || "",
      sort_order: 0,
      is_primary: false,
      metadata: %{
        upload_date: DateTime.utc_now(),
        original_size: file_size
      },
      attachable_id: entity_id,
      attachable_type: entity_type
    }

    %Attachment{}
    |> Attachment.changeset(attrs)
    |> Repo.insert()
  end

  defp get_file_size_from_upload(%Plug.Upload{path: path}) do
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      {:error, _} -> 0
    end
  end

  defp get_file_size_from_url(file_url) do
    # For local files, try to get actual file size
    if String.starts_with?(file_url, "/uploads") do
      local_path = Path.join(["priv/static", file_url])

      case File.stat(local_path) do
        {:ok, %{size: size}} -> size
        {:error, _} -> 0
      end
    else
      # For S3 URLs, we can't easily get size, return 0
      # You might want to store size during upload for S3 files
      0
    end
  end

  defp get_entity_type(%Collection{}), do: "collection"
  defp get_entity_type(%Item{}), do: "item"

  @doc """
  Get attachment statistics for an entity
  """
  def get_attachment_stats(entity) do
    attachments = list_attachments(entity)

    %{
      total_count: length(attachments),
      total_size: Enum.sum(Enum.map(attachments, & &1.file_size)),
      by_type:
        Enum.group_by(attachments, & &1.file_type)
        |> Enum.map(fn {type, items} -> {type, length(items)} end)
        |> Enum.into(%{})
    }
  end

  @doc """
  Search attachments by filename or description
  """
  def search_attachments(entity, query) when is_binary(query) do
    entity
    |> list_attachments()
    |> Enum.filter(fn attachment ->
      String.contains?(String.downcase(attachment.file_name), String.downcase(query)) ||
        (attachment.description &&
           String.contains?(String.downcase(attachment.description), String.downcase(query)))
    end)
  end
end
