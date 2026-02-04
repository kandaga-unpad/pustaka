defmodule Voile.Schema.System.VisitorSurvey do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.System.Node
  alias Voile.Schema.Master.Location
  alias Voile.Schema.System.VisitorLog

  schema "visitor_surveys" do
    field :rating, :integer
    field :comment, :string
    field :survey_type, :string, default: "general"
    field :ip_address, :string
    field :user_agent, :string
    field :additional_data, :map, default: %{}

    belongs_to :location, Location
    belongs_to :node, Node
    belongs_to :visitor_log, VisitorLog

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(visitor_survey, attrs) do
    visitor_survey
    |> cast(attrs, [
      :rating,
      :comment,
      :survey_type,
      :ip_address,
      :user_agent,
      :additional_data,
      :location_id,
      :node_id,
      :visitor_log_id
    ])
    |> validate_required([:rating, :location_id, :node_id])
    |> validate_number(:rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_length(:comment, max: 2000)
    |> validate_inclusion(:survey_type, ["general", "service", "facility", "staff"])
    |> foreign_key_constraint(:location_id)
    |> foreign_key_constraint(:node_id)
    |> foreign_key_constraint(:visitor_log_id)
  end
end
