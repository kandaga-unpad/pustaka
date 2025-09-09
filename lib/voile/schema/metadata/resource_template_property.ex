defmodule Voile.Schema.Metadata.ResourceTemplateProperty do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Metadata.ResourceTemplate
  alias Voile.Schema.Metadata.Property

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "resource_template_properties" do
    field :position, :integer
    field :override_label, :string
    belongs_to :resource_template, ResourceTemplate, foreign_key: :template_id
    belongs_to :property, Property

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(resource_template_properties, attrs) do
    resource_template_properties
    |> cast(attrs, [:position, :property_id, :override_label, :template_id])
    |> validate_required([:position, :property_id])
  end
end
