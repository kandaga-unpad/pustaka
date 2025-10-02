defmodule Voile.Schema.Accounts.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "audit_logs" do
    belongs_to :user, Voile.Schema.Accounts.User, type: :binary_id

    field :action, :string
    field :resource_type, :string
    field :resource_id, :binary_id

    field :ip_address, :string
    field :user_agent, :string
    field :metadata, :map

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [
      :user_id,
      :action,
      :resource_type,
      :resource_id,
      :ip_address,
      :user_agent,
      :metadata
    ])
    |> validate_required([:action])
    |> foreign_key_constraint(:user_id)
  end
end
