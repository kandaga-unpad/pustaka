defmodule Voile.Schema.Library.ClearanceLetter do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Phoenix.Param, key: :id}
  schema "clearance_letters" do
    field :letter_number, :string
    field :sequence_number, :integer
    field :member_snapshot, :map
    field :generated_at, :utc_datetime
    field :is_revoked, :boolean, default: false
    field :revoked_at, :utc_datetime
    field :revoke_reason, :string

    belongs_to :member, User, type: :binary_id
    belongs_to :revoked_by, User, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(letter, attrs) do
    letter
    |> cast(attrs, [
      :letter_number,
      :sequence_number,
      :member_id,
      :member_snapshot,
      :generated_at,
      :is_revoked,
      :revoked_at,
      :revoked_by_id,
      :revoke_reason
    ])
    |> validate_required([
      :letter_number,
      :sequence_number,
      :member_id,
      :member_snapshot,
      :generated_at
    ])
    |> validate_snapshot_fields()
    |> unique_constraint(:letter_number)
    |> unique_constraint(:sequence_number)
  end

  def revoke_changeset(letter, attrs) do
    letter
    |> cast(attrs, [:is_revoked, :revoked_at, :revoked_by_id, :revoke_reason])
    |> validate_required([:is_revoked, :revoked_at, :revoke_reason])
  end

  defp validate_snapshot_fields(changeset) do
    case get_field(changeset, :member_snapshot) do
      nil ->
        changeset

      snapshot ->
        required_keys = ["identifier", "fullname", "department", "node_name"]
        missing = Enum.filter(required_keys, &(not Map.has_key?(snapshot, &1)))

        if missing == [] do
          changeset
        else
          add_error(
            changeset,
            :member_snapshot,
            "missing required fields: #{Enum.join(missing, ", ")}"
          )
        end
    end
  end
end
