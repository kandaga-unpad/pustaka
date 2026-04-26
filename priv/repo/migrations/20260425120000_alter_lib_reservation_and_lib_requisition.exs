defmodule Voile.Repo.Migrations.AlterLibReservationAndLibRequisition do
  use Ecto.Migration

  def change do
    alter table(:lib_reservations) do
      modify :item_id, :binary_id, null: true
    end

    create unique_index(:lib_requisitions, [:title], name: :lib_requisitions_title_index)
  end
end
