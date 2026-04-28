defmodule Voile.SchemaMetadataFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Voile.SchemaMetadata` context.
  """

  @doc """
  Generate a property.
  """
  def property_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])
    vocabulary = Voile.MetadataFixtures.vocabulary_fixture()
    owner = Voile.AccountsFixtures.user_fixture()

    {:ok, property} =
      attrs
      |> Enum.into(%{
        information: "some information",
        label: "some label",
        local_name: "some local_name_#{unique}",
        type_value: "text",
        vocabulary_id: vocabulary.id,
        owner_id: owner.id
      })
      |> Voile.Schema.Metadata.create_property()

    property
  end
end
