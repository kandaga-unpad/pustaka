defmodule Voile.Schema.System.VisitorLog do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.System.Node
  alias Voile.Schema.Master.Location
  alias Voile.Schema.System.VisitorSurvey

  schema "visitor_logs" do
    field :visitor_identifier, :string
    field :visitor_name, :string
    field :visitor_origin, :string
    field :check_in_time, :utc_datetime
    field :check_out_time, :utc_datetime
    field :ip_address, :string
    field :user_agent, :string
    field :additional_data, :map, default: %{}

    belongs_to :location, Location
    belongs_to :node, Node

    has_many :visitor_surveys, VisitorSurvey

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(visitor_log, attrs) do
    visitor_log
    |> cast(attrs, [
      :visitor_identifier,
      :visitor_name,
      :visitor_origin,
      :check_in_time,
      :check_out_time,
      :ip_address,
      :user_agent,
      :additional_data,
      :location_id,
      :node_id
    ])
    |> validate_required([:visitor_identifier, :check_in_time, :location_id, :node_id])
    |> validate_length(:visitor_identifier, min: 1, max: 255)
    |> validate_length(:visitor_name, max: 255)
    |> validate_length(:visitor_origin, max: 255)
    |> validate_check_times()
    |> foreign_key_constraint(:location_id)
    |> foreign_key_constraint(:node_id)
  end

  defp validate_check_times(changeset) do
    check_in = get_field(changeset, :check_in_time)
    check_out = get_field(changeset, :check_out_time)

    if check_in && check_out && DateTime.compare(check_out, check_in) == :lt do
      add_error(changeset, :check_out_time, "must be after check-in time")
    else
      changeset
    end
  end
end
