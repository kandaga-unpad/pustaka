defmodule Voile.Repo.Migrations.CreateUserProfile do
  use Ecto.Migration

  def change do
    create table(:user_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :full_name, :string, null: false
      add :address, :text
      add :phone_number, :string
      add :birth_date, :date
      add :birth_place, :string
      add :gender, :string
      add :address, :text
      add :registration_date, :date
      add :expiry_date, :date
      add :photo, :string
      add :organization, :string
      add :department, :string
      add :position, :string

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_profiles, [:user_id])
    create index(:user_profiles, [:organization])
    create index(:user_profiles, [:department])
    create index(:user_profiles, [:expiry_date])
  end
end
