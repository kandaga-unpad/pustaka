defmodule Voile.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :username, :citext, null: false
      add :identifier, :numeric
      add :email, :citext, null: false
      add :fullname, :string
      add :hashed_password, :string, null: false
      add :confirmed_at, :utc_datetime
      add :user_image, :string
      add :social_media, :map, type: :jsonb
      add :groups, {:array, :string}
      add :last_login, :utc_datetime
      add :last_login_ip, :string

      # Profile fields
      add :address, :string
      add :phone_number, :string
      add :birth_date, :date
      add :birth_place, :string
      add :gender, :string
      add :registration_date, :date
      add :expiry_date, :date
      add :organization, :string
      add :department, :string
      add :position, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
    create unique_index(:users, [:identifier])

    # Performance indexes
    create index(:users, [:confirmed_at])
    create index(:users, [:last_login])
    create index(:users, [:user_type_id])
    create index(:users, [:node_id])

    create table(:users_tokens) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
