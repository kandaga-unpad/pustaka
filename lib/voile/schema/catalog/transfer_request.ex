defmodule Voile.Schema.Catalog.TransferRequest do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.System.Node

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transfer_requests" do
    field :from_location, :string
    field :to_location, :string
    field :status, :string, default: "pending"
    field :reason, :string
    field :notes, :string
    field :reviewed_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :item, Item, type: :binary_id
    belongs_to :from_node, Node, foreign_key: :from_node_id, type: :integer
    belongs_to :to_node, Node, foreign_key: :to_node_id, type: :integer
    belongs_to :requested_by, User, foreign_key: :requested_by_id, type: :binary_id
    belongs_to :reviewed_by, User, foreign_key: :reviewed_by_id, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(pending approved denied cancelled)

  @doc """
  Returns status options for form selects as {label, value} tuples.
  """
  def status_options do
    Enum.map(@statuses, fn val ->
      label = val |> String.capitalize()
      {label, val}
    end)
  end

  @doc false
  def changeset(transfer_request, attrs) do
    transfer_request
    |> cast(attrs, [
      :item_id,
      :from_node_id,
      :to_node_id,
      :from_location,
      :to_location,
      :status,
      :reason,
      :notes,
      :requested_by_id,
      :reviewed_by_id,
      :reviewed_at,
      :completed_at
    ])
    |> validate_required([
      :item_id,
      :to_node_id,
      :to_location,
      :reason,
      :requested_by_id
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_different_nodes()
    |> foreign_key_constraint(:item_id)
    |> foreign_key_constraint(:from_node_id)
    |> foreign_key_constraint(:to_node_id)
    |> foreign_key_constraint(:requested_by_id)
    |> foreign_key_constraint(:reviewed_by_id)
  end

  @doc false
  def review_changeset(transfer_request, attrs) do
    transfer_request
    |> cast(attrs, [:status, :notes, :reviewed_by_id, :reviewed_at])
    |> validate_required([:status, :reviewed_by_id, :reviewed_at])
    |> validate_inclusion(:status, ~w(approved denied))
  end

  defp validate_different_nodes(changeset) do
    from_node_id = get_field(changeset, :from_node_id)
    to_node_id = get_field(changeset, :to_node_id)

    if from_node_id && to_node_id && from_node_id == to_node_id do
      add_error(changeset, :to_node_id, "must be different from current node")
    else
      changeset
    end
  end

  @doc """
  Check if transfer request is pending
  """
  def pending?(transfer_request) do
    transfer_request.status == "pending"
  end

  @doc """
  Check if transfer request is approved
  """
  def approved?(transfer_request) do
    transfer_request.status == "approved"
  end

  @doc """
  Check if transfer request is denied
  """
  def denied?(transfer_request) do
    transfer_request.status == "denied"
  end

  @doc """
  Check if transfer request can be reviewed
  """
  def can_review?(transfer_request) do
    transfer_request.status == "pending"
  end
end
