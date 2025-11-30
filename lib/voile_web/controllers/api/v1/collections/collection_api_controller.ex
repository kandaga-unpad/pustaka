defmodule VoileWeb.API.V1.Collections.CollectionApiController do
  use VoileWeb, :controller
  use PhoenixSwagger

  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Collection

  action_fallback VoileWeb.API.FallbackController

  swagger_path :index do
    get("/v1/collections")
    summary("List all collections")
    description("Returns a paginated list of collections with optional search")
    produces("application/json")
    tag("Collections")
    security([%{Bearer: []}])

    parameters do
      page(:query, :integer, "Page number", required: false, default: 1)
      search(:query, :string, "Search keyword for filtering collections", required: false)

      status(:query, :string, "Filter by publication status",
        required: false,
        enum: ["draft", "pending", "published", "archived"]
      )

      access_level(:query, :string, "Filter by access control level",
        required: false,
        enum: ["public", "private", "restricted"]
      )

      glam_type(:query, :string, "Filter by GLAM type", required: false)
      unit_id(:query, :integer, "Filter by organization unit/node ID", required: false)
    end

    response(200, "OK", Schema.ref(:CollectionsResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    search_keyword = Map.get(params, "search", "")

    filters = %{
      status: Map.get(params, "status"),
      access_level: Map.get(params, "access_level"),
      glam_type: Map.get(params, "glam_type"),
      node_id: Map.get(params, "unit_id")
    }

    {collections, total_pages} =
      Catalog.list_collections_paginated(page, 10, search_keyword, filters)

    pagination = %{
      page_number: page,
      page_size: 10,
      total_pages: total_pages
    }

    conn
    |> put_status(:ok)
    |> render(:index, collections: collections, pagination: pagination)
  end

  swagger_path :create do
    post("/v1/collections")
    summary("Create a new collection")
    description("Creates a new collection with the provided parameters")
    produces("application/json")
    consumes("application/json")
    tag("Collections")
    security([%{Bearer: []}])

    parameters do
      collection(:body, Schema.ref(:CollectionInput), "Collection parameters", required: true)
    end

    response(201, "Created", Schema.ref(:CollectionResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResponse))
    response(500, "Internal Server Error")
  end

  def create(conn, %{"collection" => collection_params}) do
    case Catalog.create_collection(collection_params) do
      {:ok, %Collection{} = collection} ->
        conn
        |> put_status(:created)
        |> render(:show, collection: collection)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(VoileWeb.API.FallbackController)
        |> render(:error, changeset: changeset)
    end
  end

  swagger_path :show do
    get("/v1/collections/{id}")
    summary("Get a collection by ID")
    description("Returns a single collection by its ID")
    produces("application/json")
    tag("Collections")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Collection ID (UUID)",
        required: true,
        example: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9"
      )
    end

    response(200, "OK", Schema.ref(:CollectionResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(500, "Internal Server Error")
  end

  def show(conn, %{"id" => id}) do
    case Catalog.get_collection!(id) do
      nil ->
        {:error, :not_found}

      %Collection{} = collection ->
        conn
        |> put_status(:ok)
        |> render(:show, collection: collection)
    end
  end

  swagger_path :update do
    put("/v1/collections/{id}")
    summary("Update a collection")
    description("Updates an existing collection with the provided parameters")
    produces("application/json")
    consumes("application/json")
    tag("Collections")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Collection ID (UUID)",
        required: true,
        example: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9"
      )

      collection(:body, Schema.ref(:CollectionInput), "Collection parameters", required: true)
    end

    response(200, "OK", Schema.ref(:CollectionResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResponse))
    response(500, "Internal Server Error")
  end

  def update(conn, %{"id" => id, "collection" => collection_params}) do
    case Catalog.get_collection!(id) do
      nil ->
        {:error, :not_found}

      %Collection{} = collection ->
        case Catalog.update_collection(collection, collection_params) do
          {:ok, %Collection{} = updated_collection} ->
            conn
            |> put_status(:ok)
            |> render(:show, collection: updated_collection)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(VoileWeb.API.FallbackController)
            |> render(:error, changeset: changeset)
        end
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/v1/collections/{id}")
    summary("Delete a collection")
    description("Deletes an existing collection by its ID")
    produces("application/json")
    tag("Collections")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Collection ID (UUID)",
        required: true,
        example: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9"
      )
    end

    response(204, "No Content")
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResponse))
    response(500, "Internal Server Error")
  end

  def delete(conn, %{"id" => id}) do
    case Catalog.get_collection!(id) do
      nil ->
        {:error, :not_found}

      %Collection{} = collection ->
        case Catalog.delete_collection(collection) do
          {:ok, %Collection{}} ->
            conn
            |> send_resp(:no_content, "")

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(VoileWeb.API.FallbackController)
            |> render(:error, changeset: changeset)
        end
    end
  end

  def swagger_definitions do
    %{
      Collection:
        swagger_schema do
          title("Collection")
          description("A collection entity in the catalog system")

          properties do
            id(:string, "Unique identifier (UUID)", required: true, format: "uuid")
            collection_code(:string, "Unique code for the collection")
            title(:string, "Title of the collection", required: true)
            description(:string, "Detailed description of the collection", required: true)
            thumbnail(:string, "URL of the collection thumbnail", required: true)

            status(:string, "Publication status",
              required: true,
              enum: ["draft", "pending", "published", "archived"]
            )

            access_level(:string, "Access control level",
              required: true,
              enum: ["public", "private", "restricted"]
            )

            collection_type(:string, "Type of collection",
              enum: ["series", "book", "movie", "album", "course", "other"]
            )

            sort_order(:integer, "Sort order for display")
            old_biblio_id(:integer, "Legacy bibliography ID")
            parent_id(:string, "Parent collection ID (UUID)", format: "uuid")
            type_id(:integer, "Resource class ID")
            template_id(:integer, "Resource template ID")
            creator_id(:integer, "Creator ID", required: true)
            unit_id(:integer, "Organization unit/node ID")
            created_by_id(:string, "User ID who created this collection", format: "uuid")
            updated_by_id(:string, "User ID who last updated this collection", format: "uuid")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end

          example(%{
            id: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9",
            collection_code: "SF-001",
            title: "Science Fiction Collection",
            description:
              "A collection of classic science fiction novels from the golden age of sci-fi.",
            thumbnail: "https://example.com/thumbnails/sf-collection.jpg",
            status: "published",
            access_level: "public",
            collection_type: "series",
            sort_order: 1,
            parent_id: nil,
            type_id: 7,
            template_id: 3,
            creator_id: 42,
            unit_id: 5,
            created_by_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
            updated_by_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
            inserted_at: "2024-01-01T12:00:00Z",
            updated_at: "2024-01-02T12:00:00Z"
          })
        end,
      CollectionInput:
        swagger_schema do
          title("CollectionInput")
          description("Input schema for creating or updating a collection")

          properties do
            collection_code(:string, "Unique code for the collection")
            title(:string, "Title of the collection", required: true)
            description(:string, "Detailed description of the collection", required: true)
            thumbnail(:string, "URL of the collection thumbnail", required: true)

            status(:string, "Publication status",
              required: true,
              enum: ["draft", "pending", "published", "archived"]
            )

            access_level(:string, "Access control level",
              required: true,
              enum: ["public", "private", "restricted"]
            )

            collection_type(:string, "Type of collection",
              enum: ["series", "book", "movie", "album", "course", "other"]
            )

            sort_order(:integer, "Sort order for display")
            parent_id(:string, "Parent collection ID (UUID)", format: "uuid")
            type_id(:integer, "Resource class ID")
            template_id(:integer, "Resource template ID")
            creator_id(:integer, "Creator ID", required: true)
            unit_id(:integer, "Organization unit/node ID")
            created_by_id(:string, "User ID creating this collection", format: "uuid")
            updated_by_id(:string, "User ID updating this collection", format: "uuid")
          end

          example(%{
            collection_code: "SF-001",
            title: "Science Fiction Collection",
            description: "A collection of classic science fiction novels.",
            thumbnail: "https://example.com/thumbnails/sf-collection.jpg",
            status: "published",
            access_level: "public",
            collection_type: "series",
            sort_order: 1,
            creator_id: 42,
            type_id: 7,
            template_id: 3,
            unit_id: 5
          })
        end,
      CollectionResponse:
        swagger_schema do
          title("CollectionResponse")
          description("Response containing a single collection")

          properties do
            data(Schema.ref(:Collection), "Collection data", required: true)
          end

          example(%{
            data: %{
              id: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9",
              collection_code: "SF-001",
              title: "Science Fiction Collection",
              description: "A collection of classic science fiction novels.",
              thumbnail: "https://example.com/thumbnails/sf-collection.jpg",
              status: "published",
              access_level: "public",
              collection_type: "series",
              sort_order: 1,
              creator_id: 42,
              type_id: 7,
              template_id: 3,
              inserted_at: "2024-01-01T12:00:00Z",
              updated_at: "2024-01-02T12:00:00Z"
            }
          })
        end,
      CollectionsResponse:
        swagger_schema do
          title("CollectionsResponse")
          description("Response containing a paginated list of collections")

          properties do
            data(Schema.array(:Collection), "Array of collections", required: true)
            pagination(Schema.ref(:Pagination), "Pagination metadata", required: true)
          end

          example(%{
            data: [
              %{
                id: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9",
                collection_code: "SF-001",
                title: "Science Fiction Collection",
                status: "published",
                access_level: "public"
              }
            ],
            pagination: %{
              page_number: 1,
              page_size: 10,
              total_pages: 5
            }
          })
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
        end,
      ErrorResponse:
        swagger_schema do
          title("ErrorResponse")
          description("Error response with validation details")

          properties do
            errors(Schema.ref(:Errors), "Validation errors", required: true)
          end

          example(%{
            errors: %{
              title: ["This field is required"],
              status: ["Status tidak valid"]
            }
          })
        end,
      Errors:
        swagger_schema do
          title("Errors")
          description("Map of field names to error messages")
          type(:object)
          additional_properties(true)
        end
    }
  end
end
