defmodule Voile.CatalogFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Voile.Catalog` context.
  """

  @doc """
  Generate a collection.
  """
  def collection_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])
    creator = Voile.MasterFixtures.creator_fixture()
    resource_class = Voile.MetadataFixtures.resource_class_fixture()
    node = Voile.SystemFixtures.node_fixture()

    {:ok, collection} =
      attrs
      |> Enum.into(%{
        access_level: "public",
        collection_code: "some_collection_code_#{unique}",
        creator_id: creator.id,
        description: "some description",
        status: "draft",
        thumbnail: "some thumbnail",
        title: "some title",
        type_id: resource_class.id,
        unit_id: node.id
      })
      |> Voile.Schema.Catalog.create_collection()

    collection
  end

  @doc """
  Generate a item.
  """
  def item_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])
    node = Voile.SystemFixtures.node_fixture()
    collection = collection_fixture()

    {:ok, item} =
      attrs
      |> Enum.into(%{
        item_code: "some item_code_#{unique}",
        inventory_code: "some inventory_code_#{unique}",
        barcode: "some barcode_#{unique}",
        location: "some location",
        status: "active",
        condition: "excellent",
        unit_id: node.id,
        collection_id: collection.id
      })
      |> Voile.Schema.Catalog.create_item()

    item
  end

  @doc """
  Generate a collection_field.
  """
  def collection_field_fixture(attrs \\ %{}) do
    collection = collection_fixture()
    property = Voile.SchemaMetadataFixtures.property_fixture()

    {:ok, collection_field} =
      attrs
      |> Enum.into(%{
        collection_id: collection.id,
        property_id: property.id,
        name: "some_name",
        label: "some label",
        value: "some value",
        value_lang: "en",
        sort_order: 1,
        type_value: "text"
      })
      |> Voile.Schema.Catalog.create_collection_field()

    collection_field
  end

  @doc """
  Generate a item_field_value.
  """
  def item_field_value_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{locale: "some locale", value: "some value"})

    attrs =
      attrs
      |> put_default(:item_id, fn -> item_fixture().id end)
      |> put_default(:collection_field_id, fn -> collection_field_fixture().id end)

    {:ok, item_field_value} = Voile.Schema.Catalog.create_item_field_value(attrs)
    item_field_value
  end

  defp put_default(attrs, key, default_fun) do
    if Map.has_key?(attrs, key) or Map.has_key?(attrs, to_string(key)) do
      attrs
    else
      Map.put(attrs, key, default_fun.())
    end
  end
end
