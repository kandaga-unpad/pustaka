defmodule Voile.Repo.Migrations.AlterThumbnailTypeValue do
  use Ecto.Migration

  def change do
    alter table(:collections) do
      modify :thumbnail, :text
    end
  end
end
