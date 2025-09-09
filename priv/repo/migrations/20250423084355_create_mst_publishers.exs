defmodule Voile.Repo.Migrations.CreateMstPublishers do
  use Ecto.Migration

  def change do
    create table(:mst_publishers) do
      add :name, :string
      add :city, :string
      add :address, :string
      add :contact, :string

      timestamps(type: :utc_datetime)
    end
  end
end
