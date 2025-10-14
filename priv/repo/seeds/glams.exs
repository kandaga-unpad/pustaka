# GLAM Collections Seeds
# This file contains seed data for Gallery, Library, Archive, and Museum collections
# Generated from CSV data files in scripts/csv_data/

alias Voile.Repo
alias Voile.Schema.Catalog.Collection
alias Voile.Schema.Catalog.CollectionField
alias Voile.Schema.Catalog.Item
alias Voile.Schema.Metadata.Property
alias Voile.Schema.Metadata.ResourceClass
alias Voile.Schema.System.Node
alias Voile.Utils.ItemHelper
alias Client.Storage

# Define CSV parser using NimbleCSV
# Use a unique module name to avoid redefinition warnings
unless Code.ensure_loaded?(GLAMCSVParser) do
  NimbleCSV.define(GLAMCSVParser, separator: ",", escape: "\"")
end

defmodule GLAMSeeds do
  @moduledoc """
  Seeds for GLAM collections based on CSV data
  """

  @base_url "https://kandaga.unpad.ac.id/backoffice/assets/"

  def seed_all do
    IO.puts("🎨 Seeding GLAM collections...")

    # Ensure we have the required resource classes and properties
    ensure_resource_classes()
    ensure_properties()
    ensure_default_creator()

    # Get the Kandaga unit ID (assuming it exists)
    kandaga_unit =
      Repo.get_by(Node, abbr: "Kandaga") || Repo.get_by(Node, name: "Perpustakaan Pusat")

    if kandaga_unit do
      seed_collections_from_csv(kandaga_unit)
    else
      IO.puts("⚠️  Kandaga unit not found, skipping GLAM collections")
    end

    IO.puts("✅ GLAM collections seeded successfully")
  end

  defp ensure_resource_classes do
    # Define the GLAM resource classes we need
    resource_classes = [
      %{
        local_name: "gallery",
        label: "Gallery Collection",
        glam_type: "Gallery",
        information:
          "Gallery collection items including visual arts, photographs, and exhibitions",
        vocabulary_id: 5
      },
      %{
        local_name: "archive",
        label: "Archive Collection",
        glam_type: "Archive",
        information: "Archive collection items including historical documents and records",
        vocabulary_id: 5
      },
      %{
        local_name: "museum",
        label: "Museum Collection",
        glam_type: "Museum",
        information: "Museum collection items including artifacts and cultural heritage objects",
        vocabulary_id: 5
      }
    ]

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.each(resource_classes, fn rc ->
      # Check if resource class already exists by local_name
      case Repo.get_by(ResourceClass, local_name: rc.local_name) do
        nil ->
          # Insert without hardcoded ID - let PostgreSQL auto-generate
          Repo.insert!(
            struct(
              ResourceClass,
              Map.merge(rc, %{
                inserted_at: now,
                updated_at: now
              })
            )
          )

          IO.puts("  ✓ Created resource class: #{rc.local_name}")

        existing ->
          IO.puts("  ✓ Resource class '#{rc.local_name}' already exists (ID: #{existing.id})")
      end
    end)
  end

  defp ensure_properties do
    # Define the properties we need for GLAM collections
    properties = [
      %{
        local_name: "glam_creator",
        label: "Creator",
        type_value: "text",
        information: "Person or organization responsible for creating the collection item",
        vocabulary_id: 5
      },
      %{
        local_name: "glam_institution",
        label: "Institution",
        type_value: "text",
        information: "Institution or organization that holds or manages the collection",
        vocabulary_id: 5
      },
      %{
        local_name: "glam_location",
        label: "Location",
        type_value: "text",
        information: "Physical or geographical location of the collection item",
        vocabulary_id: 5
      },
      %{
        local_name: "glam_type",
        label: "Type",
        type_value: "text",
        information: "Classification or category type of the collection item",
        vocabulary_id: 5
      },
      %{
        local_name: "glam_keywords",
        label: "Keywords",
        type_value: "text",
        information: "Descriptive keywords or tags associated with the collection item",
        vocabulary_id: 5
      },
      %{
        local_name: "glam_created_date",
        label: "Created Date",
        type_value: "date",
        information: "Date when the original item was created",
        vocabulary_id: 5
      },
      %{
        local_name: "glam_publication_date",
        label: "Publication Date",
        type_value: "date",
        information: "Date when the item was published or made available",
        vocabulary_id: 5
      },
      %{
        local_name: "glam_directus_id",
        label: "Directus ID",
        type_value: "text",
        information: "Original identifier from the Directus content management system",
        vocabulary_id: 5
      }
    ]

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Store property IDs for later use
    property_map =
      Enum.reduce(properties, %{}, fn prop, acc ->
        # Check if property already exists by local_name
        property =
          case Repo.get_by(Property,
                 local_name: prop.local_name,
                 vocabulary_id: prop.vocabulary_id
               ) do
            nil ->
              # Insert without hardcoded ID
              inserted =
                Repo.insert!(
                  struct(
                    Property,
                    Map.merge(prop, %{
                      inserted_at: now,
                      updated_at: now
                    })
                  )
                )

              IO.puts("  ✓ Created property: #{prop.local_name}")
              inserted

            existing ->
              IO.puts("  ✓ Property '#{prop.local_name}' already exists (ID: #{existing.id})")
              existing
          end

        # Map the short name to property ID for easy lookup
        short_name = String.replace_prefix(prop.local_name, "glam_", "")
        Map.put(acc, short_name, property.id)
      end)

    # Store in process dictionary for use in insert_collection_fields
    Process.put(:glam_property_ids, property_map)
  end

  defp ensure_default_creator do
    alias Voile.Schema.Master.Creator

    case Repo.get(Creator, 1) do
      nil ->
        case Repo.get_by(Creator, creator_name: "System") do
          nil ->
            Repo.insert!(
              struct(Creator, %{
                id: 1,
                creator_name: "System",
                creator_contact: "",
                affiliation: "System",
                type: "institution",
                inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
                updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
              })
            )

          existing ->
            IO.puts("  ℹ️  System creator already exists with ID #{existing.id}")
        end

      _existing ->
        IO.puts("  ✓ Default creator (ID 1) already exists")
    end
  end

  defp seed_collections_from_csv(kandaga_unit) do
    # Get resource class IDs dynamically
    gallery_rc = Repo.get_by(ResourceClass, local_name: "gallery")
    archive_rc = Repo.get_by(ResourceClass, local_name: "archive")
    museum_rc = Repo.get_by(ResourceClass, local_name: "museum")

    # Read and process Gallery CSV
    gallery_file = "scripts/csv_data/gallery/koleksi_gallery 20250917-3256.csv"

    if File.exists?(gallery_file) && gallery_rc do
      IO.puts("📸 Processing Gallery collections...")
      gallery_collections = parse_gallery_csv(gallery_file)
      insert_collections(gallery_collections, gallery_rc.id, kandaga_unit, "GALLERY")
      IO.puts("✅ Processed #{length(gallery_collections)} gallery collections")
    end

    # Read and process Archive CSV
    archive_file = "scripts/csv_data/archive/koleksi_archive 20250917-32930.csv"

    if File.exists?(archive_file) && archive_rc do
      IO.puts("📄 Processing Archive collections...")
      archive_collections = parse_archive_csv(archive_file)
      insert_collections(archive_collections, archive_rc.id, kandaga_unit, "ARCHIVE")
      IO.puts("✅ Processed #{length(archive_collections)} archive collections")
    end

    # Read and process Museum CSV
    museum_file = "scripts/csv_data/museum/koleksi_museum 20250917-32637.csv"

    if File.exists?(museum_file) && museum_rc do
      IO.puts("🏛️  Processing Museum collections...")
      museum_collections = parse_museum_csv(museum_file)
      insert_collections(museum_collections, museum_rc.id, kandaga_unit, "MUSEUM")
      IO.puts("✅ Processed #{length(museum_collections)} museum collections")
    end
  end

  defp parse_gallery_csv(file_path) do
    file_path
    |> File.stream!()
    |> GLAMCSVParser.parse_stream(skip_headers: false)
    # Skip header row
    |> Stream.drop(1)
    |> Enum.map(fn row ->
      [
        id,
        _status,
        _date_created,
        _user_updated,
        _date_updated,
        judul,
        tipe_koleksi,
        pembuat_koleksi,
        lembaga_penanggungjawab,
        lokasi_koleksi,
        keterangan_koleksi,
        keywords,
        tanggal_dibuat,
        tanggal_publikasi,
        _user_created_first_name,
        _user_created_last_name,
        thumbnail_id,
        _thumbnail_filename
      ] = row

      %{
        id: id,
        title: judul,
        creator: parse_empty_string(pembuat_koleksi),
        type: tipe_koleksi,
        institution: lembaga_penanggungjawab,
        location: lokasi_koleksi,
        description: clean_html(keterangan_koleksi),
        keywords: parse_keywords(keywords),
        created_date: parse_date(tanggal_dibuat),
        publication_date: parse_date(tanggal_publikasi),
        directus_id: id,
        thumbnail_id: parse_empty_string(thumbnail_id)
      }
    end)
  end

  defp parse_archive_csv(file_path) do
    file_path
    |> File.stream!()
    |> GLAMCSVParser.parse_stream(skip_headers: false)
    # Skip header row
    |> Stream.drop(1)
    |> Enum.map(fn row ->
      [
        id,
        judul,
        pembuat_koleksi,
        _status,
        tipe_koleksi,
        _date_created,
        _user_updated,
        _date_updated,
        lembaga_penanggungjawab,
        lokasi_koleksi,
        keterangan_koleksi,
        keywords,
        tanggal_dibuat,
        tanggal_publikasi,
        thumbnail,
        _user_created_first_name,
        _user_created_last_name
      ] = row

      %{
        id: id,
        title: judul,
        creator: parse_empty_string(pembuat_koleksi),
        type: tipe_koleksi,
        institution: lembaga_penanggungjawab,
        location: parse_empty_string(lokasi_koleksi),
        description: clean_html(keterangan_koleksi),
        keywords: parse_keywords(keywords),
        created_date: parse_date(tanggal_dibuat),
        publication_date: parse_date(tanggal_publikasi),
        directus_id: id,
        thumbnail_id: parse_empty_string(thumbnail)
      }
    end)
  end

  defp parse_museum_csv(file_path) do
    file_path
    |> File.stream!()
    |> GLAMCSVParser.parse_stream(skip_headers: false)
    # Skip header row
    |> Stream.drop(1)
    |> Enum.map(fn row ->
      [
        _status,
        judul,
        pembuat_koleksi,
        tipe_koleksi,
        id,
        _user_created,
        _date_created,
        _user_updated,
        _date_updated,
        lembaga_penanggungjawab,
        lokasi_koleksi,
        keterangan_koleksi,
        keywords,
        tanggal_dibuat,
        tanggal_publikasi,
        thumbnail_id
      ] = row

      %{
        id: id,
        title: judul,
        creator: parse_empty_string(pembuat_koleksi),
        type: parse_empty_string(tipe_koleksi),
        institution: lembaga_penanggungjawab,
        location: parse_empty_string(lokasi_koleksi),
        description: clean_html(keterangan_koleksi),
        keywords: parse_keywords(keywords),
        created_date: parse_date(tanggal_dibuat),
        publication_date: parse_date(tanggal_publikasi),
        directus_id: id,
        thumbnail_id: parse_empty_string(thumbnail_id)
      }
    end)
  end

  defp parse_empty_string(nil), do: nil
  defp parse_empty_string(""), do: nil
  defp parse_empty_string(value), do: String.trim(value)

  defp parse_keywords(nil), do: []
  defp parse_keywords(""), do: []

  defp parse_keywords(keywords_str) do
    # Handle JSON array format like ["keyword1","keyword2"]
    case Jason.decode(keywords_str) do
      {:ok, keywords} when is_list(keywords) ->
        keywords

      _ ->
        # Fallback: try to split by comma
        keywords_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  rescue
    _ -> []
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp clean_html(nil), do: nil
  defp clean_html(""), do: nil

  defp clean_html(html_text) do
    # Basic HTML tag removal - for more sophisticated cleaning, consider using a proper HTML parser
    html_text
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace(~r/&nbsp;/, " ")
    |> String.replace(~r/&amp;/, "&")
    |> String.replace(~r/&lt;/, "<")
    |> String.replace(~r/&gt;/, ">")
    |> String.trim()
  end

  defp insert_collections(collections, resource_class_id, unit, type_prefix) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.with_index(collections, 1)
    |> Enum.each(fn {collection_data, index} ->
      collection_code = generate_collection_code(unit.abbr, type_prefix, index)

      # Use UUID from CSV as collection ID
      collection_id = collection_data.id

      # Download thumbnail if available
      thumbnail_filename = download_thumbnail(collection_data.thumbnail_id, collection_id)

      collection = %{
        id: collection_id,
        collection_code: collection_code,
        title: collection_data.title,
        description: collection_data.description,
        type_id: resource_class_id,
        unit_id: unit.id,
        status: "published",
        access_level: "public",
        thumbnail: thumbnail_filename || "",
        # Default creator, adjust as needed
        creator_id: 1,
        inserted_at: now,
        updated_at: now
      }

      case Repo.get(Collection, collection_id) do
        nil ->
          inserted_collection = Repo.insert!(struct(Collection, collection))
          insert_collection_fields(inserted_collection.id, collection_data, now)

          # Create a default item for this collection
          create_default_item(inserted_collection, unit, now, index)

          if rem(index, 50) == 0 do
            IO.puts("  📝 Processed #{index} collections...")
          end

        _existing ->
          # Check if item already exists for this collection
          existing_item = Repo.get_by(Item, collection_id: collection_id)

          if is_nil(existing_item) do
            existing_collection = Repo.get!(Collection, collection_id)
            create_default_item(existing_collection, unit, now, index)
          end

          if rem(index, 50) == 0 do
            IO.puts("  ⏭️  Skipped #{index} existing collections...")
          end
      end
    end)
  end

  defp insert_collection_fields(collection_id, collection_data, now) do
    # Get property IDs from process dictionary
    property_ids = Process.get(:glam_property_ids, %{})

    fields = [
      # creator
      {Map.get(property_ids, "creator"), "glam_creator", "Creator", collection_data.creator,
       "text", 1},
      # institution
      {Map.get(property_ids, "institution"), "glam_institution", "Institution",
       collection_data.institution, "text", 2},
      # location
      {Map.get(property_ids, "location"), "glam_location", "Location", collection_data.location,
       "text", 3},
      # type
      {Map.get(property_ids, "type"), "glam_type", "Type", collection_data.type, "text", 4},
      # keywords
      {Map.get(property_ids, "keywords"), "glam_keywords", "Keywords",
       format_keywords(collection_data.keywords), "text", 5},
      # created_date
      {Map.get(property_ids, "created_date"), "glam_created_date", "Created Date",
       collection_data.created_date, "date", 6},
      # publication_date
      {Map.get(property_ids, "publication_date"), "glam_publication_date", "Publication Date",
       collection_data.publication_date, "date", 7},
      # directus_id
      {Map.get(property_ids, "directus_id"), "glam_directus_id", "Directus ID",
       collection_data.directus_id, "text", 8}
    ]

    Enum.each(fields, fn {property_id, name, label, value, type_value, sort_order} ->
      if value && property_id do
        field_data = %{
          id: Ecto.UUID.generate(),
          collection_id: collection_id,
          property_id: property_id,
          name: name,
          label: label,
          value: to_string(value),
          # Default to Indonesian
          value_lang: "id",
          type_value: type_value,
          sort_order: sort_order,
          inserted_at: now,
          updated_at: now
        }

        Repo.insert!(struct(CollectionField, field_data))
      end
    end)
  end

  defp format_keywords([]), do: nil
  defp format_keywords(keywords) when is_list(keywords), do: Enum.join(keywords, ", ")
  defp format_keywords(keywords), do: keywords

  defp generate_collection_code(unit_abbr, type_prefix, index) do
    timestamp = :os.system_time(:second)

    "COLLECTION-#{unit_abbr}-#{type_prefix}-#{timestamp}-#{String.pad_leading(to_string(index), 6, "0")}"
  end

  defp create_default_item(collection, unit, now, _index) do
    # Get resource class data for the collection
    resource_class = Repo.get(ResourceClass, collection.type_id)
    resource_class_name = if resource_class, do: resource_class.local_name, else: "item"

    # Generate time identifier (similar to item_importer)
    time_identifier = System.system_time(:second)

    # Generate item codes using ItemHelper
    item_code =
      ItemHelper.generate_item_code(
        unit.abbr,
        resource_class_name,
        collection.id,
        time_identifier,
        "1"
      )

    inventory_code =
      ItemHelper.generate_inventory_code(
        unit.abbr,
        resource_class_name,
        collection.id,
        1
      )

    item_data = %{
      id: Ecto.UUID.generate(),
      collection_id: collection.id,
      item_code: item_code,
      inventory_code: inventory_code,
      location: unit.name,
      status: "active",
      condition: "good",
      availability: "non_circulating",
      unit_id: unit.id,
      inserted_at: now,
      updated_at: now
    }

    Repo.insert!(struct(Item, item_data))
  end

  defp download_thumbnail(nil, _collection_id), do: nil
  defp download_thumbnail("", _collection_id), do: nil

  defp download_thumbnail(thumbnail_id, collection_id) do
    # Build download URL
    download_url = @base_url <> thumbnail_id

    try do
      IO.puts("  📷 Downloading thumbnail: #{download_url}")

      # Download using Req
      case Req.get(download_url, redirect: true) do
        {:ok, %{status: 200, body: body, headers: headers}} ->
          # Determine content type and extension
          content_type = get_content_type_from_headers(headers)
          extension = get_extension_from_content_type(content_type)

          # Create a temporary file
          temp_filename = "thumbnail_#{collection_id}_#{thumbnail_id}#{extension}"
          temp_dir = System.tmp_dir!()
          temp_path = Path.join(temp_dir, temp_filename)

          # Write downloaded content to temp file
          File.write!(temp_path, body)

          # Create Plug.Upload struct for Storage module
          upload = %Plug.Upload{
            path: temp_path,
            filename: temp_filename,
            content_type: content_type
          }

          # Upload using Storage module with glams folder
          case Storage.upload(upload,
                 folder: "glams",
                 unit_id: 20,
                 generate_filename: true,
                 preserve_extension: true
               ) do
            {:ok, file_url} ->
              # Clean up temp file
              File.rm(temp_path)
              IO.puts("  ✅ Saved thumbnail: #{file_url}")
              file_url

            {:error, reason} ->
              # Clean up temp file
              File.rm(temp_path)
              IO.puts("  ⚠️  Failed to save thumbnail: #{reason}")
              nil
          end

        {:ok, %{status: status}} ->
          IO.puts("  ⚠️  Failed to download thumbnail (HTTP #{status}): #{download_url}")
          nil

        {:error, reason} ->
          IO.puts("  ⚠️  Error downloading thumbnail: #{inspect(reason)}")
          nil
      end
    rescue
      e ->
        IO.puts("  ⚠️  Exception downloading thumbnail: #{inspect(e)}")
        nil
    end
  end

  defp get_content_type_from_headers(headers) do
    headers
    |> Enum.find(fn {key, _value} -> String.downcase(key) == "content-type" end)
    |> case do
      {_key, content_type} when is_binary(content_type) ->
        String.split(content_type, ";") |> hd() |> String.trim()

      # Default fallback
      _ ->
        "image/jpeg"
    end
  end

  defp get_extension_from_content_type(content_type) do
    case content_type do
      "image/jpeg" -> ".jpg"
      "image/jpg" -> ".jpg"
      "image/png" -> ".png"
      "image/gif" -> ".gif"
      "image/webp" -> ".webp"
      # Default fallback
      _ -> ".jpg"
    end
  end
end

# Run the seeding
GLAMSeeds.seed_all()
