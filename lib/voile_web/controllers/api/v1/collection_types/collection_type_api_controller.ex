defmodule VoileWeb.API.V1.CollectionTypes.CollectionTypeApiController do
  use VoileWeb, :controller
  use PhoenixSwagger

  alias Voile.Schema.Metadata

  action_fallback VoileWeb.API.FallbackController

  swagger_path :index do
    get("/v1/collection_types")
    summary("List collection types or resource classes by GLAM type")

    description(
      "Returns either a list of GLAM types with counts, or paginated resource classes filtered by GLAM type"
    )

    produces("application/json")
    tag("Collection Types")
    security([%{Bearer: []}])

    parameters do
      page(:query, :integer, "Page number (only used when glam_type is provided)",
        required: false,
        default: 1
      )

      glam_type(
        :query,
        :string,
        "GLAM type to filter by (Gallery, Library, Archive, Museum). If not provided, returns GLAM type summary",
        required: false
      )
    end

    response(200, "OK", Schema.ref(:CollectionTypesResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    glam_type = Map.get(params, "glam_type", "")

    {collection_types, total_pages} =
      case glam_type do
        "" ->
          Metadata.list_glam_type_based_resource_classes()

        _ ->
          Metadata.list_glam_type_based_resource_classes(glam_type, page, 10)
      end

    pagination = %{
      page_number: page,
      page_size: 10,
      total_pages: total_pages
    }

    conn
    |> put_status(:ok)
    |> render(:index, collection_types: collection_types, pagination: pagination)
  end

  swagger_path :details do
    get("/v1/collection_types/details")
    summary("List resource classes with search and pagination")
    description("Returns a paginated list of resource classes with optional search functionality")
    produces("application/json")
    tag("Collection Types")
    security([%{Bearer: []}])

    parameters do
      page(:query, :integer, "Page number", required: false, default: 1)

      search(:query, :string, "Search keyword to filter resource classes by label or local name",
        required: false
      )
    end

    response(200, "OK", Schema.ref(:ResourceClassesResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  def details(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    search_keyword = Map.get(params, "search", "")

    {collection_types, total_pages} =
      Metadata.list_resource_classes_paginated(page, 10, search_keyword)

    pagination = %{
      page_number: page,
      page_size: 10,
      total_pages: total_pages
    }

    conn
    |> put_status(:ok)
    |> render(:index, collection_types: collection_types, pagination: pagination)
  end

  def swagger_definitions do
    %{
      GlamTypeSummary:
        swagger_schema do
          title("GlamTypeSummary")
          description("Summary of resource classes grouped by GLAM type")

          properties do
            name(:string, "GLAM type name (Gallery, Library, Archive, Museum)", required: true)

            total_count(:integer, "Total number of resource classes for this GLAM type",
              required: true
            )
          end

          example(%{
            name: "Library",
            total_count: 25
          })
        end,
      ResourceClass:
        swagger_schema do
          title("ResourceClass")
          description("A resource class entity representing a collection type")

          properties do
            id(:string, "Unique identifier", required: true, format: "uuid")
            label(:string, "Display label of the resource class", required: true)
            local_name(:string, "Local name of the resource class", required: true)
            information(:string, "Additional information about the resource class")
            glam_type(:string, "GLAM type (Gallery, Library, Archive, Museum)", required: true)
            vocabulary(Schema.ref(:Vocabulary), "Associated vocabulary")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end
        end,
      Vocabulary:
        swagger_schema do
          title("Vocabulary")
          description("Vocabulary associated with a resource class")

          properties do
            id(:string, "Unique identifier", format: "uuid")
            name(:string, "Vocabulary name")
            description(:string, "Vocabulary description")
          end
        end,
      CollectionTypesResponse:
        swagger_schema do
          title("CollectionTypesResponse")
          description("Response containing collection types data")

          properties do
            data(
              :array,
              "List of collection types (either GLAM type summaries or resource classes)",
              items: %{oneOf: [Schema.ref(:GlamTypeSummary), Schema.ref(:ResourceClass)]},
              required: true
            )

            pagination(Schema.ref(:Pagination), "Pagination metadata", required: true)
          end
        end,
      ResourceClassesResponse:
        swagger_schema do
          title("ResourceClassesResponse")
          description("Response containing resource classes data")

          properties do
            data(:array, "List of resource classes",
              items: Schema.ref(:ResourceClass),
              required: true
            )

            pagination(Schema.ref(:Pagination), "Pagination metadata", required: true)
          end
        end,
      Pagination:
        swagger_schema do
          title("Pagination")
          description("Pagination metadata")

          properties do
            page_number(:integer, "Current page number", required: true)
            page_size(:integer, "Number of items per page", required: true)
            total_pages(:integer, "Total number of pages", required: true)
          end

          example(%{
            page_number: 1,
            page_size: 10,
            total_pages: 5
          })
        end
    }
  end
end
