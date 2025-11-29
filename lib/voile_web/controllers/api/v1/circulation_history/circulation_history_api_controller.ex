defmodule VoileWeb.API.V1.CirculationHistory.CirculationHistoryApiController do
  use VoileWeb, :controller
  use PhoenixSwagger

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Library.CirculationHistory

  action_fallback VoileWeb.API.FallbackController

  swagger_path :index do
    get("/v1/circulation_history")
    summary("List all circulation history")
    description("Returns a paginated list of circulation history entries")
    produces("application/json")
    tag("CirculationHistory")
    security([%{Bearer: []}])

    parameters do
      page(:query, :integer, "Page number", required: false, default: 1)
    end

    response(200, "OK", Schema.ref(:CirculationHistoriesResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()

    {circulation_history, total_pages} =
      Circulation.list_circulation_history_paginated(page, 10)

    pagination = %{
      page_number: page,
      page_size: 10,
      total_pages: total_pages
    }

    conn
    |> put_status(:ok)
    |> render(:index, circulation_history: circulation_history, pagination: pagination)
  end

  swagger_path :show do
    get("/v1/circulation_history/{id}")
    summary("Get a circulation history entry by ID")
    description("Returns a single circulation history entry by its ID")
    produces("application/json")
    tag("CirculationHistory")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Circulation history ID (UUID)",
        required: true,
        example: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9"
      )
    end

    response(200, "OK", Schema.ref(:CirculationHistoryResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(500, "Internal Server Error")
  end

  def show(conn, %{"id" => id}) do
    case Circulation.get_circulation_history(id) do
      nil ->
        {:error, :not_found}

      %CirculationHistory{} = history ->
        conn
        |> put_status(:ok)
        |> render(:show, circulation_history: history)
    end
  end

  swagger_path :create do
    post("/v1/circulation_history")
    summary("Create a new circulation history entry")
    description("Creates a new circulation history entry with the provided parameters")
    produces("application/json")
    consumes("application/json")
    tag("CirculationHistory")
    security([%{Bearer: []}])

    parameters do
      circulation_history(
        :body,
        Schema.ref(:CirculationHistoryInput),
        "Circulation history parameters", required: true)
    end

    response(201, "Created", Schema.ref(:CirculationHistoryResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResponse))
    response(500, "Internal Server Error")
  end

  def create(conn, %{"circulation_history" => history_params}) do
    case Circulation.create_circulation_history(history_params) do
      {:ok, %CirculationHistory{} = history} ->
        conn
        |> put_status(:created)
        |> render(:show, circulation_history: history)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(VoileWeb.API.FallbackController)
        |> render(:error, changeset: changeset)
    end
  end

  swagger_path :update do
    put("/v1/circulation_history/{id}")
    summary("Update a circulation history entry")
    description("Updates an existing circulation history entry with the provided parameters")
    produces("application/json")
    consumes("application/json")
    tag("CirculationHistory")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Circulation history ID (UUID)",
        required: true,
        example: "ea3f5b2c-7d1b-4d2a-9f3e-5b27d1b4d2a9"
      )

      circulation_history(
        :body,
        Schema.ref(:CirculationHistoryInput),
        "Circulation history parameters", required: true)
    end

    response(200, "OK", Schema.ref(:CirculationHistoryResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResponse))
    response(500, "Internal Server Error")
  end

  def update(conn, %{"id" => id, "circulation_history" => history_params}) do
    case Circulation.get_circulation_history(id) do
      nil ->
        {:error, :not_found}

      %CirculationHistory{} = history ->
        case Circulation.update_circulation_history(history, history_params) do
          {:ok, %CirculationHistory{} = updated_history} ->
            conn
            |> put_status(:ok)
            |> render(:show, circulation_history: updated_history)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(VoileWeb.API.FallbackController)
            |> render(:error, changeset: changeset)
        end
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/v1/circulation_history/{id}")
    summary("Delete a circulation history entry")
    description("Deletes an existing circulation history entry by its ID")
    produces("application/json")
    tag("CirculationHistory")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Circulation history ID (UUID)",
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
    case Circulation.get_circulation_history(id) do
      nil ->
        {:error, :not_found}

      %CirculationHistory{} = history ->
        case Circulation.delete_circulation_history(history) do
          {:ok, %CirculationHistory{}} ->
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
      CirculationHistory:
        swagger_schema do
          title("CirculationHistory")
          description("A circulation history entry in the library system")

          properties do
            id(:string, "Unique identifier (UUID)", required: true, format: "uuid")
            event_type(:string, "Event type")
            event_date(:string, "Event date", format: "date-time")
            description(:string, "Description")
            old_value(:object, "Old value")
            new_value(:object, "New value")
            ip_address(:string, "IP address")
            user_agent(:string, "User agent")
            member_id(:string, "Member ID", format: "uuid")
            item_id(:string, "Item ID", format: "uuid")
            transaction_id(:string, "Transaction ID", format: "uuid")
            reservation_id(:string, "Reservation ID", format: "uuid")
            fine_id(:string, "Fine ID", format: "uuid")
            processed_by_id(:string, "Processed by user ID", format: "uuid")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end
        end,
      CirculationHistoryInput:
        swagger_schema do
          title("CirculationHistoryInput")
          description("Input schema for creating or updating a circulation history entry")

          properties do
            event_type(:string, "Event type")
            event_date(:string, "Event date", format: "date-time")
            description(:string, "Description")
            old_value(:object, "Old value")
            new_value(:object, "New value")
            ip_address(:string, "IP address")
            user_agent(:string, "User agent")
            member_id(:string, "Member ID", format: "uuid")
            item_id(:string, "Item ID", format: "uuid")
            transaction_id(:string, "Transaction ID", format: "uuid")
            reservation_id(:string, "Reservation ID", format: "uuid")
            fine_id(:string, "Fine ID", format: "uuid")
            processed_by_id(:string, "Processed by user ID", format: "uuid")
          end
        end,
      CirculationHistoryResponse:
        swagger_schema do
          title("CirculationHistoryResponse")
          description("Response containing a single circulation history entry")

          properties do
            data(Schema.ref(:CirculationHistory), "Circulation history data", required: true)
          end
        end,
      CirculationHistoriesResponse:
        swagger_schema do
          title("CirculationHistoriesResponse")
          description("Response containing a paginated list of circulation history entries")

          properties do
            data(:array, "List of circulation history entries",
              items: Schema.ref(:CirculationHistory),
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
