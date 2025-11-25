defmodule Voile.Repo.Migrations.CreateUserApiToken do
  use Ecto.Migration

  def change do
    create table(:user_api_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token, :string
      add :hashed_token, :string, null: false

      add :name, :string, null: false
      add :description, :text

      add :scopes, {:array, :string}, default: []

      add :last_used_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :ip_whitelist, {:array, :string}

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :user_agent, :string
      add :last_used_ip, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_api_tokens, [:hashed_token])
    create index(:user_api_tokens, [:user_id])
    create index(:user_api_tokens, [:expires_at])
    create index(:user_api_tokens, [:revoked_at])
  end
end
