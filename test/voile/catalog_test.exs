defmodule Voile.CatalogTest do
  use Voile.DataCase

  alias Voile.Schema.Catalog

  describe "collections" do
    alias Voile.Schema.Catalog.Collection

    import Voile.CatalogFixtures

    @invalid_attrs %{status: nil, description: nil, title: nil, thumbnail: nil, access_level: nil}

    test "list_collections/0 returns all collections" do
      collection = collection_fixture()
      assert Enum.any?(Catalog.list_collections(), &(&1.id == collection.id))
    end

    test "get_collection!/1 returns the collection with given id" do
      collection = collection_fixture()
      assert Catalog.get_collection!(collection.id).id == collection.id
    end

    test "create_collection/1 with valid data creates a collection" do
      creator = Voile.MasterFixtures.creator_fixture()
      resource_class = Voile.MetadataFixtures.resource_class_fixture()
      node = Voile.SystemFixtures.node_fixture()

      valid_attrs = %{
        collection_code: "some_collection_code",
        status: "draft",
        description: "some description",
        title: "some title",
        thumbnail: "some thumbnail",
        access_level: "public",
        creator_id: creator.id,
        type_id: resource_class.id,
        unit_id: node.id
      }

      assert {:ok, %Collection{} = collection} = Catalog.create_collection(valid_attrs)
      assert collection.collection_code == "some_collection_code"
      assert collection.status == "draft"
      assert collection.description == "some description"
      assert collection.title == "some title"
      assert collection.thumbnail == "some thumbnail"
      assert collection.access_level == "public"
      assert collection.creator_id == creator.id
      assert collection.type_id == resource_class.id
    end

    test "create_collection/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_collection(@invalid_attrs)
    end

    test "update_collection/2 with valid data updates the collection" do
      collection = collection_fixture()

      update_attrs = %{
        status: "published",
        description: "some updated description",
        title: "some updated title",
        thumbnail: "some updated thumbnail",
        access_level: "private"
      }

      assert {:ok, %Collection{} = collection} =
               Catalog.update_collection(collection, update_attrs)

      assert collection.status == "published"
      assert collection.description == "some updated description"
      assert collection.title == "some updated title"
      assert collection.thumbnail == "some updated thumbnail"
      assert collection.access_level == "private"
    end

    test "update_collection/2 with invalid data returns error changeset" do
      collection = collection_fixture()
      assert {:error, %Ecto.Changeset{}} = Catalog.update_collection(collection, @invalid_attrs)
      assert Catalog.get_collection!(collection.id).id == collection.id
    end

    test "delete_collection/1 deletes the collection" do
      collection = collection_fixture()
      assert {:ok, %Collection{}} = Catalog.delete_collection(collection)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_collection!(collection.id) end
    end

    test "change_collection/1 returns a collection changeset" do
      collection = collection_fixture()
      assert %Ecto.Changeset{} = Catalog.change_collection(collection)
    end

    test "approve_collection/3 publishes collection and makes items available" do
      # create a pending collection
      collection = collection_fixture(%{status: "pending"})
      # create reviewer user via accounts fixtures
      reviewer = Voile.AccountsFixtures.user_fixture()

      # add an item with nil availability and link to collection
      item = item_fixture(%{collection_id: collection.id, availability: nil})

      assert {:ok, _updated} = Catalog.approve_collection(collection, reviewer, "Looks good")
      # reload item and verify availability
      updated_item = Catalog.get_item!(item.id)
      assert updated_item.availability == "available"
    end

    test "list_pending_collections_paginated/7 honors sort_order parameter" do
      c1 = collection_fixture(%{status: "pending"})

      c1 =
        c1
        |> Ecto.Changeset.change(inserted_at: DateTime.add(c1.inserted_at, -3600, :second))
        |> Voile.Repo.update!()

      c2 = collection_fixture(%{status: "pending"})

      {asc_list, _, _} =
        Catalog.list_pending_collections_paginated(1, 10, nil, nil, nil, nil, "asc")

      assert Enum.map(asc_list, & &1.id) == [c1.id, c2.id]

      {desc_list, _, _} =
        Catalog.list_pending_collections_paginated(1, 10, nil, nil, nil, nil, "desc")

      assert Enum.map(desc_list, & &1.id) == [c2.id, c1.id]
    end
  end

  describe "items" do
    alias Voile.Schema.Catalog.Item

    import Voile.CatalogFixtures

    @invalid_attrs %{
      status: nil,
      location: nil,
      item_code: nil,
      inventory_code: nil,
      barcode: nil,
      condition: nil,
      availability: nil
    }

    test "list_items/0 returns all items" do
      item = item_fixture()
      assert Enum.any?(Catalog.list_items(), &(&1.id == item.id))
    end

    test "get_item!/1 returns the item with given id" do
      item = item_fixture()
      assert Catalog.get_item!(item.id).id == item.id
    end

    test "create_item/1 with valid data creates a item" do
      node = Voile.SystemFixtures.node_fixture()
      collection = collection_fixture()

      valid_attrs = %{
        status: "active",
        location: "some location",
        item_code: "some item_code",
        inventory_code: "some inventory_code",
        barcode: "some barcode",
        condition: "excellent",
        availability: "in_processing",
        unit_id: node.id,
        collection_id: collection.id
      }

      assert {:ok, %Item{} = item} = Catalog.create_item(valid_attrs)
      assert item.status == "active"
      assert item.location == "some location"
      assert item.item_code == "some item_code"
      assert item.inventory_code == "some inventory_code"
      assert item.barcode == "some barcode"
      assert item.condition == "excellent"
      assert item.availability == "in_processing"
      assert item.unit_id == node.id
      assert item.collection_id == collection.id
    end

    test "create_item/1 without availability defaults to in_processing" do
      node = Voile.SystemFixtures.node_fixture()
      collection = collection_fixture()

      attrs = %{
        status: "active",
        location: "ok location",
        item_code: "ok code",
        inventory_code: "ok inv",
        barcode: "ok barcode",
        condition: "excellent",
        unit_id: node.id,
        collection_id: collection.id
        # note: availability omitted
      }

      assert {:ok, %Item{} = item} = Catalog.create_item(attrs)
      assert item.availability == "in_processing"

      # blank string should also be converted
      attrs2 =
        attrs
        |> Map.put(:availability, "")
        |> Map.put(:item_code, "ok code 2")
        |> Map.put(:inventory_code, "ok inv 2")
        |> Map.put(:barcode, "ok barcode 2")

      assert {:ok, %Item{} = item2} = Catalog.create_item(attrs2)
      assert item2.availability == "in_processing"
    end

    test "create_item/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_item(@invalid_attrs)
    end

    test "update_item/2 with valid data updates the item" do
      item = item_fixture()

      update_attrs = %{
        status: "inactive",
        location: "some updated location",
        item_code: "some updated item_code",
        inventory_code: "some updated inventory_code",
        barcode: "some updated barcode",
        condition: "good",
        availability: "available"
      }

      assert {:ok, %Item{} = item} = Catalog.update_item(item, update_attrs)
      assert item.status == "inactive"
      assert item.location == "some updated location"
      assert item.item_code == "some updated item_code"
      assert item.inventory_code == "some updated inventory_code"
      assert item.barcode == "some updated barcode"
      assert item.condition == "good"
      assert item.availability == "available"
    end

    test "update_item/2 with invalid data returns error changeset" do
      item = item_fixture()
      assert {:error, %Ecto.Changeset{}} = Catalog.update_item(item, @invalid_attrs)
      assert Catalog.get_item!(item.id).id == item.id
    end

    test "delete_item/1 deletes the item" do
      item = item_fixture()
      assert {:ok, %Item{}} = Catalog.delete_item(item)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_item!(item.id) end
    end

    test "change_item/1 returns a item changeset" do
      item = item_fixture()
      assert %Ecto.Changeset{} = Catalog.change_item(item)
    end
  end

  describe "collection_fields" do
    alias Voile.Schema.Catalog.CollectionField

    import Voile.CatalogFixtures

    @invalid_attrs %{label: nil, name: nil, value: nil, value_lang: nil, sort_order: nil}

    test "list_collection_fields/0 returns all collection_fields" do
      collection_field = collection_field_fixture()
      assert Enum.any?(Catalog.list_collection_fields(), &(&1.id == collection_field.id))
    end

    test "get_collection_field!/1 returns the collection_field with given id" do
      collection_field = collection_field_fixture()
      assert Catalog.get_collection_field!(collection_field.id) == collection_field
    end

    test "create_collection_field/1 with valid data creates a collection_field" do
      collection = collection_fixture()
      property = Voile.SchemaMetadataFixtures.property_fixture()

      valid_attrs = %{
        collection_id: collection.id,
        property_id: property.id,
        label: "some label",
        name: "some name",
        value: "some value",
        value_lang: "en",
        sort_order: 42,
        type_value: "text"
      }

      assert {:ok, %CollectionField{} = collection_field} =
               Catalog.create_collection_field(valid_attrs)

      assert collection_field.label == "some label"
      assert collection_field.name == "some name"
      assert collection_field.value == "some value"
      assert collection_field.value_lang == "en"
      assert collection_field.sort_order == 42
      assert collection_field.type_value == "text"
    end

    test "create_collection_field/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_collection_field(@invalid_attrs)
    end

    test "update_collection_field/2 with valid data updates the collection_field" do
      collection_field = collection_field_fixture()

      update_attrs = %{
        label: "some updated label",
        name: "some updated name",
        value: "some updated value",
        value_lang: "fr",
        sort_order: 43,
        type_value: "text"
      }

      assert {:ok, %CollectionField{} = collection_field} =
               Catalog.update_collection_field(collection_field, update_attrs)

      assert collection_field.label == "some updated label"
      assert collection_field.name == "some updated name"
      assert collection_field.value == "some updated value"
      assert collection_field.value_lang == "fr"
      assert collection_field.sort_order == 43
      assert collection_field.type_value == "text"
    end

    test "update_collection_field/2 with invalid data returns error changeset" do
      collection_field = collection_field_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Catalog.update_collection_field(collection_field, @invalid_attrs)

      assert Catalog.get_collection_field!(collection_field.id).id == collection_field.id
    end

    test "delete_collection_field/1 deletes the collection_field" do
      collection_field = collection_field_fixture()
      assert {:ok, %CollectionField{}} = Catalog.delete_collection_field(collection_field)

      assert_raise Ecto.NoResultsError, fn ->
        Catalog.get_collection_field!(collection_field.id)
      end
    end

    test "change_collection_field/1 returns a collection_field changeset" do
      collection_field = collection_field_fixture()
      assert %Ecto.Changeset{} = Catalog.change_collection_field(collection_field)
    end
  end

  describe "item_field_values" do
    alias Voile.Schema.Catalog.ItemFieldValue

    import Voile.CatalogFixtures

    @invalid_attrs %{value: nil, locale: nil}

    test "list_item_field_values/0 returns all item_field_values" do
      item_field_value = item_field_value_fixture()
      assert Enum.any?(Catalog.list_item_field_values(), &(&1.id == item_field_value.id))
    end

    test "get_item_field_value!/1 returns the item_field_value with given id" do
      item_field_value = item_field_value_fixture()

      fetched = Catalog.get_item_field_value!(item_field_value.id)
      assert fetched.id == item_field_value.id
    end

    test "create_item_field_value/1 with valid data creates an item_field_value" do
      item = item_fixture()
      collection_field = collection_field_fixture()

      valid_attrs = %{
        value: "some value",
        locale: "some locale",
        item_id: item.id,
        collection_field_id: collection_field.id
      }

      assert {:ok, %ItemFieldValue{} = item_field_value} =
               Catalog.create_item_field_value(valid_attrs)

      assert item_field_value.value == "some value"
      assert item_field_value.locale == "some locale"
    end

    test "create_item_field_value/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_item_field_value(@invalid_attrs)
    end

    test "update_item_field_value/2 with valid data updates the item_field_value" do
      item_field_value = item_field_value_fixture()
      update_attrs = %{value: "some updated value", locale: "some updated locale"}

      assert {:ok, %ItemFieldValue{} = item_field_value} =
               Catalog.update_item_field_value(item_field_value, update_attrs)

      assert item_field_value.value == "some updated value"
      assert item_field_value.locale == "some updated locale"
    end

    test "update_item_field_value/2 with invalid data returns error changeset" do
      item_field_value = item_field_value_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Catalog.update_item_field_value(item_field_value, @invalid_attrs)

      fetched = Catalog.get_item_field_value!(item_field_value.id)
      assert fetched.id == item_field_value.id
    end

    test "delete_item_field_value/1 deletes the item_field_value" do
      item_field_value = item_field_value_fixture()

      assert {:ok, %ItemFieldValue{}} =
               Catalog.delete_item_field_value(item_field_value)

      assert_raise Ecto.NoResultsError, fn ->
        Catalog.get_item_field_value!(item_field_value.id)
      end
    end

    test "change_item_field_value/1 returns an item_field_value changeset" do
      item_field_value = item_field_value_fixture()
      assert %Ecto.Changeset{} = Catalog.change_item_field_value(item_field_value)
    end
  end
end
