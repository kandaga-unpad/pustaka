defmodule Voile.Schema.System.CollectionLog do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "collection_logs" do
    field :message, :string
    field :title, :string
    field :action, :string
    field :action_type, :string
    field :entity_type, :string, default: "collection"
    field :severity, :string, default: "info"

    # Audit context
    field :ip_address, :string
    field :user_agent, :string
    field :session_id, :string
    field :request_id, :string

    # Change tracking
    field :old_values, :map
    field :new_values, :map

    # Performance and status
    field :duration_ms, :integer
    field :success, :boolean, default: true
    field :metadata, :map

    belongs_to :collection, Collection, type: :binary_id
    belongs_to :user, User, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @action_types ~w(create update delete publish unpublish archive restore import export)
  @severities ~w(info warning error)

  def changeset(collection_log, attrs) do
    collection_log
    |> cast(attrs, [
      :title,
      :message,
      :action,
      :action_type,
      :entity_type,
      :severity,
      :ip_address,
      :user_agent,
      :session_id,
      :request_id,
      :old_values,
      :new_values,
      :duration_ms,
      :success,
      :metadata,
      :collection_id,
      :user_id
    ])
    |> validate_required([:title, :message, :action])
    |> (fn changeset ->
          # Only validate action_type if present
          if get_field(changeset, :action_type) do
            validate_inclusion(changeset, :action_type, @action_types)
          else
            changeset
          end
        end).()
    |> (fn changeset ->
          # Only validate severity if present
          if get_field(changeset, :severity) do
            validate_inclusion(changeset, :severity, @severities)
          else
            changeset
          end
        end).()
    |> (fn changeset ->
          # Only validate duration when present
          if get_field(changeset, :duration_ms) do
            validate_number(changeset, :duration_ms, greater_than_or_equal_to: 0)
          else
            changeset
          end
        end).()
    |> foreign_key_constraint(:collection_id)
    |> foreign_key_constraint(:user_id)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_change(:entity_type, "collection")
    |> put_change(:severity, "info")
    |> put_change(:success, true)
  end

  def error_changeset(attrs) do
    create_changeset(attrs)
    |> put_change(:severity, "error")
    |> put_change(:success, false)
  end
end
