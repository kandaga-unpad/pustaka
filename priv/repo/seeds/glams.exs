# GLAM Collections Seeds
# This file contains seed data for Gallery, Library, Archive, and Museum collections
# Generated from CSV data files in scripts/csv_data/

alias Voile.Repo
alias Voile.Schema.Catalog.Collection
alias Voile.Schema.Catalog.CollectionField
alias Voile.Schema.Metadata.Property
alias Voile.Schema.Metadata.ResourceClass
alias Voile.Schema.System.Node

# Define CSV parser using NimbleCSV
# Use a unique module name to avoid redefinition warnings
unless Code.ensure_loaded?(GLAMCSVParser) do
  NimbleCSV.define(GLAMCSVParser, separator: ",", escape: "\"")
end

defmodule GLAMSeeds do
  @moduledoc """
  Seeds for GLAM collections based on CSV data
  """

  def seed_all do
    IO.puts("🎨 Seeding GLAM collections...")

    # Ensure we have the required resource classes and properties
    ensure_resource_classes()
    ensure_properties()

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
    resource_classes = [
      %{
        id: 50,
        local_name: "gallery",
        glam_type: "gallery",
        name: "Gallery Collection",
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
      },
      %{
        id: 51,
        local_name: "archive",
        glam_type: "archive",
        name: "Archive Collection",
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
      },
      %{
        id: 52,
        local_name: "museum",
        glam_type: "museum",
        name: "Museum Collection",
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
    ]

    Enum.each(resource_classes, fn rc ->
      case Repo.get(ResourceClass, rc.id) do
        nil -> Repo.insert!(struct(ResourceClass, rc))
        _ -> :ok
      end
    end)
  end

  defp ensure_properties do
    properties = [
      %{
        id: 300,
        local_name: "creator",
        label: "Creator",
        type_value: "text",
        information: "Person or organization responsible for creating the collection item",
        vocabulary_id: 5
      },
      %{
        id: 301,
        local_name: "institution",
        label: "Institution",
        type_value: "text",
        information: "Institution or organization that holds or manages the collection",
        vocabulary_id: 5
      },
      %{
        id: 302,
        local_name: "location",
        label: "Location",
        type_value: "text",
        information: "Physical or geographical location of the collection item",
        vocabulary_id: 5
      },
      %{
        id: 303,
        local_name: "type",
        label: "Type",
        type_value: "text",
        information: "Classification or category type of the collection item",
        vocabulary_id: 5
      },
      %{
        id: 304,
        local_name: "keywords",
        label: "Keywords",
        type_value: "text",
        information: "Descriptive keywords or tags associated with the collection item",
        vocabulary_id: 5
      },
      %{
        id: 305,
        local_name: "created_date",
        label: "Created Date",
        type_value: "date",
        information: "Date when the original item was created",
        vocabulary_id: 5
      },
      %{
        id: 306,
        local_name: "publication_date",
        label: "Publication Date",
        type_value: "date",
        information: "Date when the item was published or made available",
        vocabulary_id: 5
      },
      %{
        id: 307,
        local_name: "directus_id",
        label: "Directus ID",
        type_value: "text",
        information: "Original identifier from the Directus content management system",
        vocabulary_id: 5
      }
    ]

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.each(properties, fn prop ->
      case Repo.get(Property, prop.id) do
        nil ->
          Repo.insert!(
            struct(
              Property,
              Map.merge(prop, %{
                # Default owner, adjust as needed
                inserted_at: now,
                updated_at: now
              })
            )
          )

        _ ->
          :ok
      end
    end)
  end

  defp seed_collections_from_csv(kandaga_unit) do
    # Read and process Gallery CSV
    gallery_file = "scripts/csv_data/gallery/koleksi_gallery 20250917-3256.csv"

    if File.exists?(gallery_file) do
      IO.puts("📸 Processing Gallery collections...")
      gallery_collections = parse_gallery_csv(gallery_file)
      insert_collections(gallery_collections, 50, kandaga_unit, "GALLERY")
      IO.puts("✅ Processed #{length(gallery_collections)} gallery collections")
    end

    # Read and process Archive CSV
    archive_file = "scripts/csv_data/archive/koleksi_archive 20250917-32930.csv"

    if File.exists?(archive_file) do
      IO.puts("📄 Processing Archive collections...")
      archive_collections = parse_archive_csv(archive_file)
      insert_collections(archive_collections, 51, kandaga_unit, "ARCHIVE")
      IO.puts("✅ Processed #{length(archive_collections)} archive collections")
    end

    # Read and process Museum CSV
    museum_file = "scripts/csv_data/museum/koleksi_museum 20250917-32637.csv"

    if File.exists?(museum_file) do
      IO.puts("🏛️  Processing Museum collections...")
      museum_collections = parse_museum_csv(museum_file)
      insert_collections(museum_collections, 52, kandaga_unit, "MUSEUM")
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
        _thumbnail_id,
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
        directus_id: id
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
        _thumbnail,
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
        directus_id: id
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
        id,
        _status,
        judul,
        pembuat_koleksi,
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
        _user_created_first_name,
        _user_created_last_name,
        _thumbnail
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
        directus_id: id
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

    # Map GLAM types to their appropriate type_id
    type_id =
      case type_prefix do
        # image
        "GALLERY" -> 26
        # document
        "ARCHIVE" -> 49
        # Physical Object
        "MUSEUM" -> 32
        _ -> resource_class_id
      end

    Enum.with_index(collections, 1)
    |> Enum.each(fn {collection_data, index} ->
      collection_code = generate_collection_code(unit.abbr, type_prefix, index)

      # Use UUID from CSV as collection ID
      collection_id = collection_data.id

      collection = %{
        id: collection_id,
        collection_code: collection_code,
        title: collection_data.title,
        description: collection_data.description,
        type_id: type_id,
        unit_id: unit.id,
        status: "published",
        access_level: "public",
        thumbnail: "",
        # Default creator, adjust as needed
        creator_id: 1,
        inserted_at: now,
        updated_at: now
      }

      case Repo.get(Collection, collection_id) do
        nil ->
          inserted_collection = Repo.insert!(struct(Collection, collection))
          insert_collection_fields(inserted_collection.id, collection_data, now)

          if rem(index, 50) == 0 do
            IO.puts("  📝 Processed #{index} collections...")
          end

        _existing ->
          if rem(index, 50) == 0 do
            IO.puts("  ⏭️  Skipped #{index} existing collections...")
          end
      end
    end)
  end

  defp insert_collection_fields(collection_id, collection_data, now) do
    fields = [
      # creator
      {300, "creator", "Creator", collection_data.creator, "text", 1},
      # institution
      {301, "institution", "Institution", collection_data.institution, "text", 2},
      # location
      {302, "location", "Location", collection_data.location, "text", 3},
      # type
      {303, "type", "Type", collection_data.type, "text", 4},
      # keywords
      {304, "keywords", "Keywords", format_keywords(collection_data.keywords), "text", 5},
      # created_date
      {305, "created_date", "Created Date", collection_data.created_date, "date", 6},
      # publication_date
      {306, "publication_date", "Publication Date", collection_data.publication_date, "date", 7},
      # directus_id
      {307, "directus_id", "Directus ID", collection_data.directus_id, "text", 8}
    ]

    Enum.each(fields, fn {property_id, name, label, value, type_value, sort_order} ->
      if value do
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
end

# Run the seeding
GLAMSeeds.seed_all()
