defmodule Voile.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :username, :citext, null: false
      add :identifier, :integer
      add :email, :citext, null: false
      add :fullname, :string
      add :hashed_password, :string, null: false
      add :confirmed_at, :utc_datetime
      add :user_type, :string
      add :user_image, :string
      add :social_media, :map, type: :jsonb
      add :groups, {:array, :string}
      add :node_id, :integer
      add :last_login, :utc_datetime
      add :last_login_ip, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email, :username, :identifier])

    create table(:user_roles) do
      add :name, :string, null: false
      add :description, :text
      add :permissions, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_roles, [:name])

    alter table(:users) do
      add :user_role_id, references(:user_roles), null: false
    end

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
