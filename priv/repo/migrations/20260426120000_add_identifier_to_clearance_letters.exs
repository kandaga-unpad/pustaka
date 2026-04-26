defmodule Voile.Repo.Migrations.AddIdentifierToClearanceLetters do
  use Ecto.Migration

  def change do
    alter table(:clearance_letters) do
      add :identifier, :string
    end

    create index(:clearance_letters, [:member_id, :identifier])
  end
end
