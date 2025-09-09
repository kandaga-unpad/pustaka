defmodule Voile.Schema.Accounts.UserProfile do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Phoenix.Param, key: :id}
  schema "user_profiles" do
    field :full_name, :string
    field :address, :string
    field :phone_number, :string
    field :birth_date, :date
    field :birth_place, :string
    field :gender, :string
    field :registration_date, :date
    field :expiry_date, :date
    field :photo, :string
    field :organization, :string
    field :department, :string
    field :position, :string

    belongs_to :user, User, type: :binary_id

    timestamps(type: :naive_datetime)
  end

  def changeset(user_profile, attrs) do
    user_profile
    |> cast(attrs, [
      :full_name,
      :address,
      :phone_number,
      :birth_date,
      :birth_place,
      :gender,
      :registration_date,
      :expiry_date,
      :photo,
      :organization,
      :department,
      :position,
      :user_id
    ])
    |> validate_required([:full_name, :address, :phone_number])
  end
end
