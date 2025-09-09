defmodule Voile.Schema.Library.CirculationHistory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Library.{Transaction, Reservation, Fine}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "lib_circulation_history" do
    field :event_type, :string
    field :event_date, :naive_datetime
    field :description, :string
    field :old_value, :map
    field :new_value, :map
    field :ip_address, :string
    field :user_agent, :string

    belongs_to :member, User, foreign_key: :member_id, type: :binary_id
    belongs_to :item, Item, type: :binary_id
    belongs_to :transaction, Transaction, foreign_key: :transaction_id, type: :binary_id
    belongs_to :reservation, Reservation, foreign_key: :reservation_id, type: :binary_id
    belongs_to :fine, Fine, foreign_key: :fine_id, type: :binary_id
    belongs_to :processed_by, User, foreign_key: :processed_by_id, type: :binary_id

    timestamps(type: :naive_datetime)
  end

  @circulation_event_types ~w(loan return renewal reserve cancel_reserve fine_paid fine_waived member_created member_updated item_status_change)

  def changeset(circulation_history, attrs) do
    circulation_history
    |> cast(attrs, [
      :event_type,
      :event_date,
      :description,
      :old_value,
      :new_value,
      :ip_address,
      :user_agent,
      :member_id,
      :item_id,
      :transaction_id,
      :reservation_id,
      :fine_id,
      :processed_by_id
    ])
    |> validate_required([:event_type, :event_date, :member_id, :item_id, :processed_by_id])
    |> validate_inclusion(:event_type, @circulation_event_types)
    |> foreign_key_constraint(:member_id, name: :lib_circulation_history_member_id_fkey)
    |> foreign_key_constraint(:item_id, name: :lib_circulation_history_item_id_fkey)
    |> foreign_key_constraint(:transaction_id, name: :lib_circulation_history_transaction_id_fkey)
    |> foreign_key_constraint(:reservation_id, name: :lib_circulation_history_reservation_id_fkey)
    |> foreign_key_constraint(:fine_id, name: :lib_circulation_history_fine_id_fkey)
    |> foreign_key_constraint(:processed_by_id,
      name: :lib_circulation_history_processed_by_id_fkey
    )
  end
end
