defmodule VoileWeb.API.V1.Users.UserApiController do
  use VoileWeb, :controller
  use PhoenixSwagger

  alias Voile.Schema.Accounts
  alias Voile.Schema.Accounts.User

  action_fallback VoileWeb.API.FallbackController

  swagger_path :index do
    get("/v1/users")
    summary("List all users")
    description("Returns a paginated list of users")
    produces("application/json")
    tag("Users")
    security([%{Bearer: []}])

    parameters do
      page(:query, :integer, "Page number", required: false, default: 1)
    end

    response(200, "OK", Schema.ref(:UsersResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()

    {users, total_pages} = Accounts.list_users_paginated(page, 10)

    pagination = %{
      page_number: page,
      page_size: 10,
      total_pages: total_pages
    }

    conn
    |> put_status(:ok)
    |> render(:index, users: users, pagination: pagination)
  end

  swagger_path :show do
    get("/v1/users/{identifier}")
    summary("Get a user by identifier")
    description("Returns a single user by their identifier")
    produces("application/json")
    tag("Users")
    security([%{Bearer: []}])

    parameters do
      identifier(:path, :string, "User identifier", required: true)
    end

    response(200, "OK", Schema.ref(:UserResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(500, "Internal Server Error")
  end

  def show(conn, %{"id" => identifier}) do
    case Accounts.get_user_with_associations_by_identifier(identifier) do
      nil ->
        {:error, :not_found}

      %User{} = user ->
        conn
        |> put_status(:ok)
        |> render(:show, user: user)
    end
  end

  def swagger_definitions do
    %{
      User:
        swagger_schema do
          title("User")
          description("A user entity in the system")

          properties do
            id(:string, "Unique identifier (UUID)", required: true, format: "uuid")
            username(:string, "Username")
            identifier(:number, "User identifier number")
            email(:string, "Email address", format: "email")
            fullname(:string, "Full name")
            user_image(:string, "User image URL")
            social_media(:object, "Social media links")
            groups(:array, "User groups", items: %{type: :string})
            last_login(:string, "Last login timestamp", format: "date-time")
            last_login_ip(:string, "Last login IP address")
            manually_suspended(:boolean, "Manual suspension status", default: false)
            suspension_reason(:string, "Suspension reason")
            suspended_at(:string, "Suspension timestamp", format: "date-time")
            suspension_ends_at(:string, "Suspension end timestamp", format: "date-time")
            suspended_by_id(:string, "Suspended by user ID", format: "uuid")
            address(:string, "Address")
            phone_number(:string, "Phone number")
            birth_date(:string, "Birth date", format: "date")
            birth_place(:string, "Birth place")
            gender(:string, "Gender")
            registration_date(:string, "Registration date", format: "date")
            expiry_date(:string, "Expiry date", format: "date")
            organization(:string, "Organization")
            department(:string, "Department")
            position(:string, "Position")
            user_type_id(:string, "User type ID", format: "uuid")
            node_id(:string, "Node ID", format: "uuid")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end
        end,
      UserResponse:
        swagger_schema do
          title("UserResponse")
          description("Response containing a single user")

          properties do
            data(Schema.ref(:User), "User data", required: true)
          end
        end,
      UsersResponse:
        swagger_schema do
          title("UsersResponse")
          description("Response containing a paginated list of users")

          properties do
            data(:array, "List of users", items: Schema.ref(:User), required: true)
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
