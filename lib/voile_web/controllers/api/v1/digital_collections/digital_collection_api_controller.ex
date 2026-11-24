defmodule VoileWeb.API.V1.DigitalCollections.DigitalCollectionApiController do
  use VoileWeb, :controller
  use PhoenixSwagger

  alias Voile.Schema.Catalog

  action_fallback VoileWeb.API.FallbackController

  swagger_path :index do
    get("/v1/digital-collections")
    summary("List digital collections")

    description(
      "Lists published collections that carry digital attachments (e-books and " <>
        "similar readable files). Searchable and filterable by faculty/unit, " <>
        "attachment file type, and access level."
    )

    produces("application/json")
    tag("DigitalCollections")
    security([%{Bearer: []}])

    parameters do
      page(:query, :integer, "Page number", required: false, default: 1)
      limit(:query, :integer, "Number of items per page (max 100)", required: false, default: 10)

      search(:query, :string, "Search keyword (matches title, collection code, creator name)",
        required: false
      )

      unit_id(:query, :integer, "Filter by organizing unit/node (faculty) ID", required: false)

      file_type(:query, :string, "Filter by attachment file type",
        required: false,
        default: "document",
        enum: ["document", "image", "video", "audio", "software", "archive", "other", "all"]
      )

      access_level(:query, :string, "Filter by attachment access level",
        required: false,
        enum: ["public", "limited", "restricted"]
      )
    end

    response(200, "OK", Schema.ref(:DigitalCollectionsResponse))
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  def index(conn, params) do
    page = Voile.Utils.Pagination.parse_page(Map.get(params, "page"))
    per_page = Voile.Utils.Pagination.parse_per_page(Map.get(params, "limit"), 10)

    filters = %{
      search: Map.get(params, "search"),
      unit_id: Map.get(params, "unit_id"),
      file_type: Map.get(params, "file_type"),
      access_level: Map.get(params, "access_level")
    }

    {collections, total_pages, total_count} =
      Catalog.list_digital_collections_paginated(
        page,
        per_page,
        filters.search,
        filters
      )

    pagination = %{
      page_number: page,
      page_size: per_page,
      total_pages: total_pages,
      total_count: total_count
    }

    conn
    |> put_status(:ok)
    |> render(:index, collections: collections, pagination: pagination)
  end

  swagger_path :show do
    get("/v1/digital-collections/{id}")
    summary("Get a digital collection by ID")

    description(
      "Returns a single published digital collection with its full digital " <>
        "attachment list (reader/download paths) and collection metadata."
    )

    produces("application/json")
    tag("DigitalCollections")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Collection ID (UUID)",
        required: true,
        example: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9"
      )
    end

    response(200, "OK", Schema.ref(:DigitalCollectionResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(500, "Internal Server Error")
  end

  def show(conn, %{"id" => id}) do
    case Catalog.get_digital_collection(id) do
      nil ->
        {:error, :not_found}

      %Voile.Schema.Catalog.Collection{} = collection ->
        conn
        |> put_status(:ok)
        |> render(:show, collection: collection)
    end
  end

  def swagger_definitions do
    %{
      DigitalCollection:
        swagger_schema do
          title("DigitalCollection")

          description(
            "A published collection that carries digital attachments (e-books " <>
              "and similar readable files)"
          )

          properties do
            id(:string, "Unique identifier (UUID)", required: true, format: "uuid")
            collection_code(:string, "Unique code for the collection")
            title(:string, "Title of the collection", required: true)
            description(:string, "Detailed description of the collection")
            thumbnail(:string, "URL of the collection thumbnail")

            status(:string, "Publication status (always published on this endpoint)",
              required: true
            )

            access_level(:string, "Collection access control level")
            collection_url(:string, "Relative URL of the collection detail page on voile")

            attachments_count(:integer, "Number of digital attachments currently accessible")

            primary_attachment(
              Schema.ref(:DigitalAttachment),
              "The primary digital attachment (null when none)"
            )

            attachments(:array, "All digital attachments", items: Schema.ref(:DigitalAttachment))

            metadata(:array, "Collection metadata fields")

            type(Schema.ref(:DigitalCollectionType), "Resource class (collection type)")

            creator(Schema.ref(:DigitalCollectionCreator), "Primary creator")
            unit(Schema.ref(:DigitalCollectionUnit), "Organizing unit (faculty)")

            updated_at(:string, "Last update timestamp", format: "date-time")
          end

          example(%{
            id: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9",
            collection_code: "EBK-001",
            title: "Pengantar ilmu hukum tata negara",
            description: "Digital edition of the introduction to constitutional law.",
            thumbnail: "/uploads/thumbnails/ebk-001.jpg",
            status: "published",
            access_level: "public",
            collection_url: "/collections/ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9",
            attachments_count: 1,
            primary_attachment: %{
              id: "f1e2d3c4-b5a6-4789-8abc-def012345678",
              file_name: "pengantar-ilmu-hukum-tata-negara.pdf",
              mime_type: "application/pdf",
              file_type: "document",
              file_size: 1_048_576,
              access_level: "public",
              is_primary: true,
              reader_url: "/ebooks/view?id=f1e2d3c4-b5a6-4789-8abc-def012345678",
              download_url: "/attachments/f1e2d3c4-b5a6-4789-8abc-def012345678/download"
            },
            updated_at: "2024-01-02T12:00:00Z"
          })
        end,
      DigitalAttachment:
        swagger_schema do
          title("DigitalAttachment")

          description(
            "A digital file attached to a collection. file URLs are relative to " <>
              "the voile origin and enforce login/access control before serving."
          )

          properties do
            id(:string, "Attachment identifier (UUID)", required: true, format: "uuid")
            file_name(:string, "Stored file name")
            mime_type(:string, "MIME type of the file")
            file_type(:string, "File type category (document, image, …)")
            file_size(:integer, "File size in bytes")
            access_level(:string, "Access level (public, limited, restricted)")
            is_primary(:boolean, "Whether this is the primary attachment")

            reader_url(:string, "Relative URL of the voile e-book reader for this file")

            download_url(:string, "Relative URL of the ACL-enforcing download endpoint")
          end
        end,
      DigitalCollectionType:
        swagger_schema do
          title("DigitalCollectionType")
          description("Resource class (collection type) of a digital collection")

          properties do
            id(:string, "Resource class ID")
            label(:string, "Label")
            local_name(:string, "Local name")
            glam_type(:string, "GLAM type (gallery, library, archive, museum)")
          end
        end,
      DigitalCollectionCreator:
        swagger_schema do
          title("DigitalCollectionCreator")
          description("Primary creator of a digital collection")

          properties do
            id(:string, "Creator ID")
            type(:string, "Creator type (Person, Organization)")
            creator_name(:string, "Creator name")
            affiliation(:string, "Creator affiliation")
          end
        end,
      DigitalCollectionUnit:
        swagger_schema do
          title("DigitalCollectionUnit")
          description("Organizing unit (faculty/library node) of a digital collection")

          properties do
            id(:integer, "Unit/node ID")
            name(:string, "Node name")
            abbr(:string, "Node abbreviation")
            description(:string, "Node description")
          end
        end,
      DigitalCollectionsResponse:
        swagger_schema do
          title("DigitalCollectionsResponse")
          description("Paginated list of digital collections")

          properties do
            data(:array, "Digital collections", items: Schema.ref(:DigitalCollection))

            pagination(
              Schema.ref(:DigitalCollectionPagination),
              "Pagination metadata",
              required: true
            )
          end
        end,
      DigitalCollectionResponse:
        swagger_schema do
          title("DigitalCollectionResponse")
          description("Response containing a single digital collection")

          properties do
            data(Schema.ref(:DigitalCollection), "Digital collection data", required: true)
          end
        end,
      DigitalCollectionPagination:
        swagger_schema do
          title("DigitalCollectionPagination")
          description("Pagination metadata")

          properties do
            page_number(:integer, "Current page number", required: true)
            page_size(:integer, "Items per page", required: true)
            total_pages(:integer, "Total number of pages", required: true)
            total_count(:integer, "Total number of items", required: true)
          end

          example(%{page_number: 1, page_size: 10, total_pages: 3, total_count: 25})
        end
    }
  end
end
