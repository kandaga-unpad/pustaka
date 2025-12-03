defmodule VoileWeb.API.V1.Fines.FineApiController do
  use VoileWeb, :controller
  use PhoenixSwagger

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Library.Fine

  action_fallback VoileWeb.API.FallbackController

  swagger_path :index do
    get("/v1/fines")
    summary("List all fines")
    description("Returns a paginated list of fines")
    produces("application/json")
    tag("Fines")
    security([%{Bearer: []}])

    parameters do
      page(:query, :integer, "Page number", required: false, default: 1)
    end

    response(200, "OK", Schema.ref(:FinesResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()

    {fines, total_pages, total_count} =
      Circulation.list_fines_paginated(page, 10)

    pagination = %{
      page_number: page,
      page_size: 10,
      total_pages: total_pages,
      total_count: total_count
    }

    conn
    |> put_status(:ok)
    |> render(:index, fines: fines, pagination: pagination)
  end

  swagger_path :show do
    get("/v1/fines/{id}")
    summary("Get a fine by ID")
    description("Returns a single fine by its ID")
    produces("application/json")
    tag("Fines")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Fine ID (UUID)",
        required: true,
        example: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9"
      )
    end

    response(200, "OK", Schema.ref(:FineResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(500, "Internal Server Error")
  end

  def show(conn, %{"id" => id}) do
    case Circulation.get_fine!(id) do
      nil ->
        {:error, :not_found}

      %Fine{} = fine ->
        conn
        |> put_status(:ok)
        |> render(:show, fine: fine)
    end
  end

  swagger_path :create do
    post("/v1/fines")
    summary("Create a new fine")
    description("Creates a new fine with the provided parameters")
    produces("application/json")
    consumes("application/json")
    tag("Fines")
    security([%{Bearer: []}])

    parameters do
      fine(:body, Schema.ref(:FineInput), "Fine parameters", required: true)
    end

    response(201, "Created", Schema.ref(:FineResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResponse))
    response(500, "Internal Server Error")
  end

  def create(conn, %{"fine" => fine_params}) do
    case Circulation.create_fine(fine_params) do
      {:ok, %Fine{} = fine} ->
        conn
        |> put_status(:created)
        |> render(:show, fine: fine)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(VoileWeb.API.FallbackController)
        |> render(:error, changeset: changeset)
    end
  end

  swagger_path :update do
    put("/v1/fines/{id}")
    summary("Update a fine")
    description("Updates an existing fine with the provided parameters")
    produces("application/json")
    consumes("application/json")
    tag("Fines")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Fine ID (UUID)",
        required: true,
        example: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9"
      )

      fine(:body, Schema.ref(:FineInput), "Fine parameters", required: true)
    end

    response(200, "OK", Schema.ref(:FineResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResponse))
    response(500, "Internal Server Error")
  end

  def update(conn, %{"id" => id, "fine" => fine_params}) do
    case Circulation.get_fine!(id) do
      nil ->
        {:error, :not_found}

      %Fine{} = fine ->
        case Circulation.update_fine(fine, fine_params) do
          {:ok, %Fine{} = updated_fine} ->
            conn
            |> put_status(:ok)
            |> render(:show, fine: updated_fine)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(VoileWeb.API.FallbackController)
            |> render(:error, changeset: changeset)
        end
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/v1/fines/{id}")
    summary("Delete a fine")
    description("Deletes an existing fine by its ID")
    produces("application/json")
    tag("Fines")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Fine ID (UUID)",
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
    case Circulation.get_fine!(id) do
      nil ->
        {:error, :not_found}

      %Fine{} = fine ->
        case Circulation.delete_fine(fine) do
          {:ok, %Fine{}} ->
            send_resp(conn, :no_content, "")

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
      Fine:
        swagger_schema do
          title("Fine")
          description("A fine entity in the library system")

          properties do
            id(:string, "Unique identifier (UUID)", required: true, format: "uuid")
            fine_type(:string, "Fine type")
            amount(:number, "Amount", format: "decimal")
            paid_amount(:number, "Paid amount", format: "decimal", default: 0)
            balance(:number, "Balance", format: "decimal")
            fine_date(:string, "Fine date", format: "date-time")
            payment_date(:string, "Payment date", format: "date-time")
            fine_status(:string, "Fine status")
            description(:string, "Description")
            waived(:boolean, "Waived", default: false)
            waived_date(:string, "Waived date", format: "date-time")
            waived_reason(:string, "Waived reason")
            payment_method(:string, "Payment method")
            receipt_number(:string, "Receipt number")
            member_id(:string, "Member ID", format: "uuid")
            item_id(:string, "Item ID", format: "uuid")
            transaction_id(:string, "Transaction ID", format: "uuid")
            processed_by_id(:string, "Processed by user ID", format: "uuid")
            waived_by_id(:string, "Waived by user ID", format: "uuid")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end
        end,
      FineInput:
        swagger_schema do
          title("FineInput")
          description("Input schema for creating or updating a fine")

          properties do
            fine_type(:string, "Fine type")
            amount(:number, "Amount", format: "decimal")
            paid_amount(:number, "Paid amount", format: "decimal")
            balance(:number, "Balance", format: "decimal")
            fine_date(:string, "Fine date", format: "date-time")
            payment_date(:string, "Payment date", format: "date-time")
            fine_status(:string, "Fine status")
            description(:string, "Description")
            waived(:boolean, "Waived")
            waived_date(:string, "Waived date", format: "date-time")
            waived_reason(:string, "Waived reason")
            payment_method(:string, "Payment method")
            receipt_number(:string, "Receipt number")
            member_id(:string, "Member ID", format: "uuid")
            item_id(:string, "Item ID", format: "uuid")
            transaction_id(:string, "Transaction ID", format: "uuid")
            processed_by_id(:string, "Processed by user ID", format: "uuid")
            waived_by_id(:string, "Waived by user ID", format: "uuid")
          end
        end,
      FineResponse:
        swagger_schema do
          title("FineResponse")
          description("Response containing a single fine")

          properties do
            data(Schema.ref(:Fine), "Fine data", required: true)
          end
        end,
      FinesResponse:
        swagger_schema do
          title("FinesResponse")
          description("Response containing a paginated list of fines")

          properties do
            data(:array, "List of fines", items: Schema.ref(:Fine), required: true)
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
