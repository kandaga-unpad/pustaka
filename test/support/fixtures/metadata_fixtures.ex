defmodule Voile.MetadataFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Voile.Metadata` context.
  """

  @doc """
  Generate a vocabulary.
  """
  def vocabulary_fixture(attrs \\ %{}) do
    {:ok, vocabulary} =
      attrs
      |> Enum.into(%{
        information: "some information",
        label: "some label",
        namespace_url: "some namespace_url",
        prefix: "some prefix"
      })
      |> Voile.Schema.Metadata.create_vocabulary()

    vocabulary
  end

  @doc """
  Generate a resource_class.
  """
  def resource_class_fixture(attrs \\ %{}) do
    {:ok, resource_class} =
      attrs
      |> Enum.into(%{
        information: "some information",
        label: "some label",
        local_name: "some local_name",
        glam_type: "Library"
      })
      |> Voile.Schema.Metadata.create_resource_class()

    resource_class
  end

  @doc """
  Generate a resource_template.
  """
  def resource_template_fixture(attrs \\ %{}) do
    user = Voile.AccountsFixtures.user_fixture()
    resource_class = resource_class_fixture()

    {:ok, resource_template} =
      attrs
      |> Enum.into(%{
        label: "some label",
        owner_id: user.id,
        resource_class_id: resource_class.id
      })
      |> Voile.Schema.Metadata.create_resource_template()

    resource_template
  end

  @doc """
  Generate a resource_template_property.
  """
  def resource_template_property_fixture(attrs \\ %{}) do
    property = Voile.SchemaMetadataFixtures.property_fixture()
    resource_template = resource_template_fixture()

    {:ok, resource_template_property} =
      attrs
      |> Enum.into(%{
        position: 42,
        property_id: property.id,
        template_id: resource_template.id,
        override_label: "some override_label"
      })
      |> Voile.Schema.Metadata.create_resource_template_property()

    resource_template_property
  end
end
