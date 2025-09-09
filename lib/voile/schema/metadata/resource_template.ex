defmodule Voile.Schema.Metadata.ResourceTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Metadata.ResourceClass
  alias Voile.Schema.Metadata.ResourceTemplateProperty

  schema "resource_template" do
    field :label, :string
    field :description, :string
    belongs_to :owner, User, type: :binary_id
    belongs_to :resource_class, ResourceClass

    has_many :template_properties,
             ResourceTemplateProperty,
             foreign_key: :template_id,
             on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(resource_template, attrs) do
    resource_template
    |> cast(attrs, [:label, :description, :owner_id, :resource_class_id])
    |> cast_assoc(:template_properties, with: &ResourceTemplateProperty.changeset/2)
    |> validate_required([:label, :owner_id, :resource_class_id])
  end
end
