defmodule Voile.Schema.Catalog.AttachmentRoleAccess do
  @moduledoc """
  Schema for role-based access control on attachments.
  Links attachments to roles that can access them when access_level is "limited".
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "attachment_role_access" do
    belongs_to :attachment, Voile.Schema.Catalog.Attachment, type: :binary_id
    belongs_to :role, Voile.Schema.Accounts.Role

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(attachment_role_access, attrs) do
    attachment_role_access
    |> cast(attrs, [:attachment_id, :role_id])
    |> validate_required([:attachment_id, :role_id])
    |> foreign_key_constraint(:attachment_id)
    |> foreign_key_constraint(:role_id)
    |> unique_constraint([:attachment_id, :role_id], name: :attachment_role_access_unique)
  end
end
