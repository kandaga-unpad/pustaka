defmodule VoileWeb.API.V1.Unit.UnitApiController do
  use VoileWeb, :controller
  use PhoenixSwagger

  alias Voile.Schema.System

  action_fallback VoileWeb.API.FallbackController

  swagger_path :index do
    get("/v1/units")
    summary("List all units")
    description("Returns a list of all unit / faculty / node")
    produces("application/json")
    tag("Units")
    security([%{Bearer: []}])

    response(200, "OK", Schema.ref(:UnitsResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  def index(conn, _params) do
    unit_list = System.list_nodes()

    conn
    |> put_status(:ok)
    |> render(:index, units: unit_list)
  end

  def swagger_definitions do
    %{
      Unit:
        swagger_schema do
          title("Unit")
          description("A unit/faculty/node entity in the system")

          properties do
            id(:string, "Unique identifier", required: true, format: "uuid")
            name(:string, "Full name of the unit", required: true)
            image(:string, "Image URL for the unit")
            abbr(:string, "Abbreviation of the unit name", required: true)
            description(:string, "Description of the unit")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "Faculty of Computer Science",
            image: "/images/units/cs.jpg",
            abbr: "FCS",
            description: "Faculty of Computer Science at University",
            inserted_at: "2024-01-01T00:00:00Z",
            updated_at: "2024-01-01T00:00:00Z"
          })
        end,
      UnitsResponse:
        swagger_schema do
          title("UnitsResponse")
          description("Response containing a list of units")

          properties do
            data(:array, "List of units", items: Schema.ref(:Unit), required: true)
          end

          example(%{
            data: [
              %{
                id: "550e8400-e29b-41d4-a716-446655440000",
                name: "Faculty of Computer Science",
                image: "/images/units/cs.jpg",
                abbr: "FCS",
                description: "Faculty of Computer Science at University",
                inserted_at: "2024-01-01T00:00:00Z",
                updated_at: "2024-01-01T00:00:00Z"
              }
            ]
          })
        end
    }
  end
end
