defmodule Voile.Catalog.CollectionCsvImporter do
  @moduledoc """
  Simplified CSV importer for collections with dynamic property columns.

  ## New CSV Format (Simplified)

  Instead of complex field naming (collection_field_1_name, collection_field_1_label, etc.),
  this version uses property names directly as column headers.

  ### Basic Columns (Required)
  - title (required)
  - description (required)
  - status (required)
  - access_level (required)
  - creator_id (required)
  - unit_id (required for auto-generating codes)

  ### Auto-Generated Codes
  - collection_code - Auto-generated if left empty (requires unit_id)
  - item_N_item_code - Auto-generated if left empty (requires unit_id, type_id)
  - item_N_inventory_code - Auto-generated if left empty (requires unit_id, type_id)

  ### Optional Columns
  - thumbnail
  - collection_type
  - sort_order
  - parent_id
  - type_id (recommended for better code generation)
  - template_id

  ### Dynamic Property Columns
  Any column that matches a property's local_name will be automatically
  added as a collection field. For example:

  - author → Creates collection field with name="author"
  - subject → Creates collection field with name="subject"
  - publisher → Creates collection field with name="publisher"
  - isbn → Creates collection field with name="isbn"

  ### Item Columns (up to 50 items)
  - item_N_item_code
  - item_N_inventory_code
  - item_N_location
  - item_N_status
  - item_N_condition
  - item_N_availability
  - item_N_price
  - item_N_acquisition_date
  - item_N_rfid_tag
  - item_N_unit_id
  - item_N_item_location_id

  ## Example CSV (with codes auto-generated)

  ```csv
  title,description,status,access_level,creator_id,unit_id,type_id,author,subject,publisher,item_1_location
  Elixir Book,A guide,published,public,1,1,2,José Valim,Programming,Pragmatic,Section A
  ```

  This creates:
  - 1 collection (with auto-generated collection_code)
  - 3 collection fields (author, subject, publisher)
  - 1 item (with auto-generated item_code and inventory_code)

  ## Example CSV (with explicit codes)

  ```csv
  collection_code,title,description,status,access_level,creator_id,unit_id,author,subject,publisher,item_1_item_code,item_1_inventory_code,item_1_location
  COL001,Elixir Book,A guide,published,public,1,1,José Valim,Programming,Pragmatic,ITEM001,INV001,Section A
  ```

  This creates:
  - 1 collection (with specified collection_code)
  - 3 collection fields (author, subject, publisher)
  - 1 item (with specified codes)
  """

  alias Voile.Repo
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Metadata.Property
  alias Voile.Utils.ItemHelper
  require Logger

  @reserved_columns ~w(
    collection_code title description status access_level thumbnail
    collection_type sort_order parent_id type_id template_id creator_id unit_id
  )

  @doc """
  Import collections from uploaded CSV content.

  ## Options

  - `:skip_errors` - Continue importing even if some rows fail (default: false)
  - `:batch_size` - Number of records to process at once (default: 100)
  - `:dry_run` - Validate without saving to database (default: false)
  - `:current_user` - Current user performing the import (for logging)
  """
  def import_from_upload(csv_content, opts \\ []) do
    skip_errors = Keyword.get(opts, :skip_errors, false)
    batch_size = Keyword.get(opts, :batch_size, 100)
    dry_run = Keyword.get(opts, :dry_run, false)

    # Load all properties for mapping
    properties = load_properties()

    csv_content
    |> parse_csv()
    |> process_rows(skip_errors, batch_size, dry_run, properties)
  end

  defp load_properties do
    Property
    |> Repo.all()
    |> Map.new(fn prop -> {prop.local_name, prop} end)
  end

  defp parse_csv(content) do
    # NimbleCSV expects a binary string, not a list
    # Remove any BOM and normalize line endings
    content =
      content
      |> String.replace("\r\n", "\n")
      |> String.replace("\r", "\n")
      |> String.trim()

    NimbleCSV.RFC4180.parse_string(content, skip_headers: false)
  end

  defp process_rows([headers | rows], skip_errors, batch_size, dry_run, properties) do
    # Identify which columns are properties
    property_columns = identify_property_columns(headers, properties)

    results = %{
      total: length(rows),
      success: 0,
      failed: 0,
      errors: [],
      imported_ids: [],
      warnings: []
    }

    rows
    |> Enum.with_index(1)
    |> Enum.chunk_every(batch_size)
    |> Enum.reduce(results, fn batch, acc ->
      process_batch(batch, headers, property_columns, properties, acc, skip_errors, dry_run)
    end)
    |> add_warnings(property_columns, properties)
    |> format_results()
  end

  defp identify_property_columns(headers, properties) do
    headers
    |> Enum.reject(&(&1 in @reserved_columns))
    |> Enum.reject(&String.starts_with?(&1, "item_"))
    |> Enum.map(fn header ->
      case Map.get(properties, header) do
        nil -> {:unknown, header}
        prop -> {:known, header, prop}
      end
    end)
  end

  defp add_warnings(results, property_columns, _properties) do
    unknown_columns =
      property_columns
      |> Enum.filter(fn
        {:unknown, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:unknown, col} -> col end)

    if unknown_columns != [] do
      warning =
        "Unknown property columns (will be ignored): #{Enum.join(unknown_columns, ", ")}"

      %{results | warnings: [warning | results.warnings]}
    else
      results
    end
  end

  defp process_batch(batch, headers, property_columns, properties, results, skip_errors, dry_run) do
    Enum.reduce(batch, results, fn {row, row_number}, acc ->
      case process_row(row, headers, property_columns, properties, row_number, dry_run) do
        {:ok, collection} ->
          %{
            acc
            | success: acc.success + 1,
              imported_ids: [collection.id | acc.imported_ids]
          }

        {:error, reason} ->
          error = %{row: row_number, reason: format_error(reason)}
          Logger.warning("Row #{row_number} failed: #{inspect(reason)}")

          if skip_errors do
            %{acc | failed: acc.failed + 1, errors: [error | acc.errors]}
          else
            throw({:import_error, error})
          end
      end
    end)
  catch
    {:import_error, error} ->
      %{results | failed: results.failed + 1, errors: [error | results.errors]}
  end

  defp process_row(row, headers, property_columns, properties, row_number, dry_run) do
    row_data = Enum.zip(headers, row) |> Map.new()

    with {:ok, collection_attrs} <- extract_collection_attrs(row_data),
         {:ok, collection_fields} <-
           extract_collection_fields_from_properties(row_data, property_columns, properties),
         {:ok, items} <- extract_items(row_data) do
      # Combine all attributes
      full_attrs =
        collection_attrs
        |> Map.put(:collection_fields, collection_fields)
        |> Map.put(:items, items)

      if dry_run do
        # Just validate
        changeset = Collection.changeset(%Collection{}, full_attrs)

        if changeset.valid? do
          {:ok, %{id: "dry-run-#{row_number}", changeset: changeset}}
        else
          {:error, changeset}
        end
      else
        # Actually save
        save_collection(full_attrs)
      end
    end
  end

  defp extract_collection_attrs(row_data) do
    # Get basic attributes
    collection_code = get_value(row_data, "collection_code")
    unit_id = parse_integer(get_value(row_data, "unit_id"))
    collection_type = get_value(row_data, "collection_type") || "standard"

    # Generate collection_code if not provided
    final_collection_code =
      if is_nil(collection_code) or collection_code == "" do
        generate_collection_code(unit_id, collection_type)
      else
        collection_code
      end

    attrs = %{
      collection_code: final_collection_code,
      title: get_value(row_data, "title"),
      description: get_value(row_data, "description"),
      status: get_value(row_data, "status"),
      access_level: get_value(row_data, "access_level"),
      thumbnail: get_value(row_data, "thumbnail"),
      collection_type: collection_type,
      sort_order: parse_integer(get_value(row_data, "sort_order")),
      parent_id: get_value(row_data, "parent_id"),
      type_id: parse_integer(get_value(row_data, "type_id")),
      template_id: parse_integer(get_value(row_data, "template_id")),
      creator_id: parse_integer(get_value(row_data, "creator_id")),
      unit_id: unit_id
    }

    # Remove nil values
    attrs = Enum.reject(attrs, fn {_k, v} -> is_nil(v) end) |> Map.new()

    {:ok, attrs}
  end

  defp extract_collection_fields_from_properties(row_data, property_columns, _properties) do
    fields =
      property_columns
      |> Enum.with_index(1)
      |> Enum.map(fn {col_info, index} ->
        case col_info do
          {:known, col_name, property} ->
            value = get_value(row_data, col_name)

            if value do
              %{
                name: property.local_name,
                label: property.label,
                value: value,
                value_lang: "en",
                type_value: property.type_value || "text",
                property_id: property.id,
                sort_order: index
              }
            else
              nil
            end

          {:unknown, _col_name} ->
            # Skip unknown columns
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, fields}
  end

  defp extract_items(row_data) do
    # Get collection attributes for code generation
    unit_id = parse_integer(get_value(row_data, "unit_id"))
    type_id = parse_integer(get_value(row_data, "type_id"))
    title = get_value(row_data, "title")

    # Get unit abbreviation and type name for code generation
    {unit_abbr, type_name} = get_unit_and_type_names(unit_id, type_id)

    # Generate a placeholder collection_id for code generation
    # This will be replaced when the collection is actually created
    temp_collection_id = Ecto.UUID.generate()
    time_identifier = System.system_time(:second)

    items =
      1..50
      |> Enum.map(fn i ->
        item_code = get_value(row_data, "item_#{i}_item_code")
        inventory_code = get_value(row_data, "item_#{i}_inventory_code")
        location = get_value(row_data, "item_#{i}_location")

        # At least location is required to create an item
        if location do
          # Generate codes if not provided
          final_item_code =
            if is_nil(item_code) or item_code == "" do
              ItemHelper.generate_item_code(
                unit_abbr,
                type_name,
                temp_collection_id,
                time_identifier,
                to_string(i)
              )
            else
              item_code
            end

          final_inventory_code =
            if is_nil(inventory_code) or inventory_code == "" do
              ItemHelper.generate_inventory_code(
                unit_abbr,
                type_name,
                title || "Collection",
                i
              )
            else
              inventory_code
            end

          %{
            item_code: final_item_code,
            inventory_code: final_inventory_code,
            location: location,
            status: get_value(row_data, "item_#{i}_status") || "active",
            condition: get_value(row_data, "item_#{i}_condition") || "good",
            # default to in_processing when not provided by CSV
            availability: get_value(row_data, "item_#{i}_availability") || "in_processing",
            price: parse_decimal(get_value(row_data, "item_#{i}_price")),
            acquisition_date: parse_date(get_value(row_data, "item_#{i}_acquisition_date")),
            rfid_tag: get_value(row_data, "item_#{i}_rfid_tag"),
            unit_id: parse_integer(get_value(row_data, "item_#{i}_unit_id")),
            item_location_id: parse_integer(get_value(row_data, "item_#{i}_item_location_id"))
          }
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, items}
  end

  defp save_collection(attrs) do
    Repo.transaction(fn ->
      %Collection{}
      |> Collection.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, collection} -> collection
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp get_value(map, key) do
    value = Map.get(map, key, "")

    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp generate_collection_code(unit_id, collection_type) do
    unit_abbr = if unit_id, do: get_unit_abbr(unit_id), else: "UNK"
    timestamp = :os.system_time(:second)
    random_suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)

    "COLLECTION-#{unit_abbr}-#{collection_type}-#{timestamp}-#{random_suffix}"
  end

  defp get_unit_abbr(unit_id) do
    try do
      node = Voile.Schema.System.get_node!(unit_id)
      node.abbr
    rescue
      _ -> "UNK"
    end
  end

  defp get_unit_and_type_names(unit_id, type_id) do
    unit_abbr =
      if unit_id do
        try do
          node = Voile.Schema.System.get_node!(unit_id)
          node.abbr
        rescue
          _ -> "UNK"
        end
      else
        "UNK"
      end

    type_name =
      if type_id do
        try do
          resource_class = Voile.Schema.Metadata.get_resource_class!(type_id)
          resource_class.local_name
        rescue
          _ -> "item"
        end
      else
        "item"
      end

    {unit_abbr, type_name}
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_decimal(nil), do: nil
  defp parse_decimal(""), do: nil

  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> nil
    end
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp format_error(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join("; ")
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)

  defp format_results(results) do
    if results.failed > 0 and results.success == 0 do
      {:error, results}
    else
      {:ok, results}
    end
  end

  @doc """
  Generate a simplified template based on available properties.
  """
  def generate_template do
    properties = Repo.all(Property) |> Enum.take(10)

    headers =
      [
        "collection_code",
        "title",
        "description",
        "status",
        "access_level",
        "thumbnail",
        "creator_id",
        "collection_type",
        "unit_id"
      ] ++
        Enum.map(properties, & &1.local_name) ++
        [
          "item_1_item_code",
          "item_1_inventory_code",
          "item_1_location",
          "item_1_status",
          "item_1_condition",
          "item_1_availability",
          "item_1_price"
        ]

    {headers, properties}
  end

  @doc """
  Get available properties for template generation.
  """
  def list_available_properties do
    Property
    |> Repo.all()
    |> Enum.map(fn prop ->
      %{
        id: prop.id,
        local_name: prop.local_name,
        label: prop.label,
        type_value: prop.type_value
      }
    end)
  end
end
