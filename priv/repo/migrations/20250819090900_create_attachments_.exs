defmodule Voile.Repo.Migrations.CreateAttachments do
  use Ecto.Migration

  def change do
    create table(:attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :file_name, :string
      add :original_name, :string
      add :file_path, :string
      add :file_size, :integer
      add :mime_type, :string
      add :file_type, :string
      add :description, :text
      add :sort_order, :integer, default: 0
      add :is_primary, :boolean, default: false
      add :metadata, :map, default: %{}

      # Polymorphic associations
      add :attachable_id, :binary_id, null: false
      add :attachable_type, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:attachments, [:attachable_id, :attachable_type])
    create index(:attachments, [:file_type])
    create index(:attachments, [:is_primary])
    create index(:attachments, [:sort_order])

    create unique_index(
             :attachments,
             [:attachable_id, :attachable_type, :file_name],
             name: :attachments_unique_file_per_entity
           )

    # Add check constraint for attachable_type
    create constraint(:attachments, :attachable_type_must_be_valid,
             check: "attachable_type IN ('collection', 'item')"
           )

    # Add check constraint for file_type
    create constraint(:attachments, :file_type_must_be_valid,
             check:
               "file_type IN ('document', 'image', 'video', 'audio', 'software', 'archive', 'other')"
           )

    # Add check constraint for file_size
    create constraint(:attachments, :file_size_must_be_positive, check: "file_size > 0")

    # Add check constraint for sort_order
    create constraint(:attachments, :sort_order_must_be_non_negative, check: "sort_order >= 0")
  end
end
