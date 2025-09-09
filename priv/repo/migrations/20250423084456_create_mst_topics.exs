defmodule Voile.Repo.Migrations.CreateMstTopics do
  use Ecto.Migration

  def change do
    create table(:mst_topics) do
      add :name, :string
      add :type, :string
      add :description, :text

      timestamps(type: :utc_datetime)
    end
  end
end
