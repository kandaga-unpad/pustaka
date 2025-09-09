defmodule Voile.Schema.Library.Reservation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.{Item, Collection}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "lib_reservations" do
    field :reservation_date, :naive_datetime
    field :expiry_date, :naive_datetime
    field :notification_sent, :boolean, default: false
    field :status, :string
    field :priority, :integer, default: 1
    field :notes, :string
    field :pickup_date, :naive_datetime
    field :cancelled_date, :naive_datetime
    field :cancellation_reason, :string

    belongs_to :item, Item, type: :binary_id
    belongs_to :member, User, foreign_key: :member_id, type: :binary_id
    belongs_to :collection, Collection, type: :binary_id
    belongs_to :processed_by, User, foreign_key: :processed_by_id, type: :binary_id

    timestamps(type: :naive_datetime)
  end

  @statuses ~w(pending available picked_up expired cancelled)

  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [
      :reservation_date,
      :expiry_date,
      :notification_sent,
      :status,
      :priority,
      :notes,
      :pickup_date,
      :cancelled_date,
      :cancellation_reason,
      :member_id,
      :item_id,
      :collection_id,
      :processed_by_id
    ])
    |> validate_required([:reservation_date, :status, :member_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:priority, greater_than: 0)
    |> check_constraint(:item_or_collection, name: :item_or_collection_check)
    |> foreign_key_constraint(:member_id)
    |> foreign_key_constraint(:item_id)
    |> foreign_key_constraint(:collection_id)
  end

  def expired?(%__MODULE__{expiry_date: expiry_date, status: status})
      when status in ["pending", "available"] do
    DateTime.compare(expiry_date, DateTime.utc_now()) == :lt
  end

  def expired?(_), do: false
end
