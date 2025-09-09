defmodule Voile.Repo.Migrations.CreateMstCreator do
  use Ecto.Migration

  def change do
    create table(:mst_creator) do
      add :creator_name, :string
      add :creator_contact, :string
      add :affiliation, :string
      add :type, :string

      timestamps(type: :utc_datetime)
    end
  end
end
