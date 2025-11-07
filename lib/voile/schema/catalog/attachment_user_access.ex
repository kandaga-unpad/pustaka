defmodule Voile.Schema.Catalog.AttachmentUserAccess do
  @moduledoc """
  Schema for user-specific access control on attachments.
  Links attachments to specific users that can access them when access_level is "limited".
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "attachment_user_access" do
    belongs_to :attachment, Voile.Schema.Catalog.Attachment, type: :binary_id
    belongs_to :user, Voile.Schema.Accounts.User, type: :binary_id
    belongs_to :granted_by, Voile.Schema.Accounts.User, type: :binary_id
    field :granted_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(attachment_user_access, attrs) do
    attachment_user_access
    |> cast(attrs, [:attachment_id, :user_id, :granted_by_id, :granted_at])
    |> validate_required([:attachment_id, :user_id, :granted_at])
    |> foreign_key_constraint(:attachment_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:granted_by_id)
    |> unique_constraint([:attachment_id, :user_id], name: :attachment_user_access_unique)
  end

  @doc false
  def create_changeset(attachment_user_access, attrs) do
    attrs = Map.put_new(attrs, :granted_at, DateTime.utc_now() |> DateTime.truncate(:second))
    changeset(attachment_user_access, attrs)
  end
end
