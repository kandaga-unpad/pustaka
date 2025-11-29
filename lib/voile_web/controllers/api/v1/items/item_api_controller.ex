defmodule VoileWeb.API.V1.Items.ItemApiController do
  use VoileWeb, :controller
  use PhoenixSwagger

  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Item

  action_fallback VoileWeb.API.FallbackController

  swagger_path :index do
    get("/v1/items")
    summary("List all items")
    description("Returns a paginated list of items with optional search")
    produces("application/json")
    tag("Items")
    security([%{Bearer: []}])

    parameters do
      page(:query, :integer, "Page number", required: false, default: 1)
      search(:query, :string, "Search keyword for filtering items", required: false)
    end

    response(200, "OK", Schema.ref(:ItemsResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    search_keyword = Map.get(params, "search", "")

    {items, total_pages} =
      Catalog.list_items_paginated(page, 10, search_keyword)

    pagination = %{
      page_number: page,
      page_size: 10,
      total_pages: total_pages
    }

    conn
    |> put_status(:ok)
    |> render(:index, items: items, pagination: pagination)
  end

  swagger_path :create do
    post("/v1/items")
    summary("Create a new item")
    description("Creates a new item with the provided parameters")
    produces("application/json")
    consumes("application/json")
    tag("Items")
    security([%{Bearer: []}])

    parameters do
      item(:body, Schema.ref(:ItemInput), "Item parameters", required: true)
    end

    response(201, "Created", Schema.ref(:ItemResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResponse))
    response(500, "Internal Server Error")
  end

  def create(conn, %{"item" => item_params}) do
    case Catalog.create_item(item_params) do
      {:ok, %Item{} = item} ->
        conn
        |> put_status(:created)
        |> render(:show, item: item)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(VoileWeb.API.FallbackController)
        |> render(:error, changeset: changeset)
    end
  end

  swagger_path :show do
    get("/v1/items/{id}")
    summary("Get an item by ID")
    description("Returns a single item by its ID")
    produces("application/json")
    tag("Items")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Item ID (UUID)",
        required: true,
        example: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9"
      )
    end

    response(200, "OK", Schema.ref(:ItemResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(500, "Internal Server Error")
  end

  def show(conn, %{"id" => id}) do
    case Catalog.get_item!(id) do
      nil ->
        {:error, :not_found}

      %Item{} = item ->
        conn
        |> put_status(:ok)
        |> render(:show, item: item)
    end
  end

  swagger_path :update do
    put("/v1/items/{id}")
    summary("Update an item")
    description("Updates an existing item with the provided parameters")
    produces("application/json")
    consumes("application/json")
    tag("Items")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Item ID (UUID)",
        required: true,
        example: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9"
      )

      item(:body, Schema.ref(:ItemInput), "Item parameters", required: true)
    end

    response(200, "OK", Schema.ref(:ItemResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResponse))
    response(500, "Internal Server Error")
  end

  def update(conn, %{"id" => id, "item" => item_params}) do
    case Catalog.get_item!(id) do
      nil ->
        {:error, :not_found}

      %Item{} = item ->
        case Catalog.update_item(item, item_params) do
          {:ok, %Item{} = updated_item} ->
            conn
            |> put_status(:ok)
            |> render(:show, item: updated_item)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(VoileWeb.API.FallbackController)
            |> render(:error, changeset: changeset)
        end
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/v1/items/{id}")
    summary("Delete an item")
    description("Deletes an existing item by its ID")
    produces("application/json")
    tag("Items")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Item ID (UUID)",
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
    case Catalog.get_item!(id) do
      nil ->
        {:error, :not_found}

      %Item{} = item ->
        case Catalog.delete_item(item) do
          {:ok, %Item{}} ->
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
      Item:
        swagger_schema do
          title("Item")
          description("An item entity in the catalog system")

          properties do
            id(:string, "Unique identifier (UUID)", required: true, format: "uuid")
            item_code(:string, "Item code")
            inventory_code(:string, "Inventory code")
            barcode(:string, "Barcode")
            location(:string, "Location")
            status(:string, "Status")
            condition(:string, "Condition")
            availability(:string, "Availability")
            price(:number, "Price", format: "decimal")
            acquisition_date(:string, "Acquisition date", format: "date")
            last_inventory_date(:string, "Last inventory date", format: "date")
            last_circulated(:string, "Last circulated timestamp", format: "date-time")
            rfid_tag(:string, "RFID tag")
            legacy_item_code(:string, "Legacy item code")
            collection_id(:string, "Collection ID", format: "uuid")
            unit_id(:string, "Unit ID", format: "uuid")
            item_location_id(:integer, "Item location ID")
            created_by_id(:string, "Created by user ID", format: "uuid")
            updated_by_id(:string, "Updated by user ID", format: "uuid")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end
        end,
      ItemInput:
        swagger_schema do
          title("ItemInput")
          description("Input schema for creating or updating an item")

          properties do
            item_code(:string, "Item code")
            inventory_code(:string, "Inventory code")
            barcode(:string, "Barcode")
            location(:string, "Location")
            status(:string, "Status")
            condition(:string, "Condition")
            availability(:string, "Availability")
            price(:number, "Price", format: "decimal")
            acquisition_date(:string, "Acquisition date", format: "date")
            last_inventory_date(:string, "Last inventory date", format: "date")
            last_circulated(:string, "Last circulated timestamp", format: "date-time")
            rfid_tag(:string, "RFID tag")
            legacy_item_code(:string, "Legacy item code")
            collection_id(:string, "Collection ID", format: "uuid")
            unit_id(:string, "Unit ID", format: "uuid")
            item_location_id(:integer, "Item location ID")
            created_by_id(:string, "Created by user ID", format: "uuid")
            updated_by_id(:string, "Updated by user ID", format: "uuid")
          end
        end,
      ItemResponse:
        swagger_schema do
          title("ItemResponse")
          description("Response containing a single item")

          properties do
            data(Schema.ref(:Item), "Item data", required: true)
          end
        end,
      ItemsResponse:
        swagger_schema do
          title("ItemsResponse")
          description("Response containing a paginated list of items")

          properties do
            data(:array, "List of items", items: Schema.ref(:Item), required: true)
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
        end,
      ErrorResponse:
        swagger_schema do
          title("ErrorResponse")
          description("Error response with validation details")

          properties do
            errors(Schema.ref(:Errors), "Validation errors", required: true)
          end
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
