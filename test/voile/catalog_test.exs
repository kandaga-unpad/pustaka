defmodule Voile.CatalogTest do
  use Voile.DataCase

  alias Voile.Schema.Catalog

  describe "collections" do
    alias Voile.Catalog.Collection

    import Voile.CatalogFixtures

    @invalid_attrs %{status: nil, description: nil, title: nil, thumbnail: nil, access_level: nil}

    test "list_collections/0 returns all collections" do
      collection = collection_fixture()
      assert Catalog.list_collections() == [collection]
    end

    test "get_collection!/1 returns the collection with given id" do
      collection = collection_fixture()
      assert Catalog.get_collection!(collection.id) == collection
    end

    test "create_collection/1 with valid data creates a collection" do
      valid_attrs = %{
        status: "some status",
        description: "some description",
        title: "some title",
        thumbnail: "some thumbnail",
        access_level: "some access_level"
      }

      assert {:ok, %Collection{} = collection} = Catalog.create_collection(valid_attrs)
      assert collection.status == "some status"
      assert collection.description == "some description"
      assert collection.title == "some title"
      assert collection.thumbnail == "some thumbnail"
      assert collection.access_level == "some access_level"
    end

    test "create_collection/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_collection(@invalid_attrs)
    end

    test "update_collection/2 with valid data updates the collection" do
      collection = collection_fixture()

      update_attrs = %{
        status: "some updated status",
        description: "some updated description",
        title: "some updated title",
        thumbnail: "some updated thumbnail",
        access_level: "some updated access_level"
      }

      assert {:ok, %Collection{} = collection} =
               Catalog.update_collection(collection, update_attrs)

      assert collection.status == "some updated status"
      assert collection.description == "some updated description"
      assert collection.title == "some updated title"
      assert collection.thumbnail == "some updated thumbnail"
      assert collection.access_level == "some updated access_level"
    end

    test "update_collection/2 with invalid data returns error changeset" do
      collection = collection_fixture()
      assert {:error, %Ecto.Changeset{}} = Catalog.update_collection(collection, @invalid_attrs)
      assert collection == Catalog.get_collection!(collection.id)
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
      # insert two pending collections sequentially
      c1 = collection_fixture(%{status: "pending"})
      # ensure the second has a later timestamp
      Process.sleep(1)
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
    alias Voile.Catalog.Item

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
      assert Catalog.list_items() == [item]
    end

    test "get_item!/1 returns the item with given id" do
      item = item_fixture()
      assert Catalog.get_item!(item.id) == item
    end

    test "create_item/1 with valid data creates a item" do
      valid_attrs = %{
        status: "some status",
        location: "some location",
        item_code: "some item_code",
        inventory_code: "some inventory_code",
        barcode: "some barcode",
        condition: "some condition",
        availability: "some availability"
      }

      assert {:ok, %Item{} = item} = Catalog.create_item(valid_attrs)
      assert item.status == "some status"
      assert item.location == "some location"
      assert item.item_code == "some item_code"
      assert item.inventory_code == "some inventory_code"
      assert item.barcode == "some barcode"
      assert item.condition == "some condition"
      assert item.availability == "some availability"
    end

    test "create_item/1 without availability defaults to in_processing" do
      attrs = %{
        status: "ok status",
        location: "ok location",
        item_code: "ok code",
        inventory_code: "ok inv",
        barcode: "ok barcode",
        condition: "good"
        # note: availability omitted
      }

      assert {:ok, %Item{} = item} = Catalog.create_item(attrs)
      assert item.availability == "in_processing"

      # blank string should also be converted
      attrs2 = Map.put(attrs, :availability, "")
      assert {:ok, %Item{} = item2} = Catalog.create_item(attrs2)
      assert item2.availability == "in_processing"
    end

    test "create_item/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_item(@invalid_attrs)
    end

    test "update_item/2 with valid data updates the item" do
      item = item_fixture()

      update_attrs = %{
        status: "some updated status",
        location: "some updated location",
        item_code: "some updated item_code",
        inventory_code: "some updated inventory_code",
        barcode: "some updated barcode",
        condition: "some updated condition",
        availability: "some updated availability"
      }

      assert {:ok, %Item{} = item} = Catalog.update_item(item, update_attrs)
      assert item.status == "some updated status"
      assert item.location == "some updated location"
      assert item.item_code == "some updated item_code"
      assert item.inventory_code == "some updated inventory_code"
      assert item.barcode == "some updated barcode"
      assert item.condition == "some updated condition"
      assert item.availability == "some updated availability"
    end

    test "update_item/2 with invalid data returns error changeset" do
      item = item_fixture()
      assert {:error, %Ecto.Changeset{}} = Catalog.update_item(item, @invalid_attrs)
      assert item == Catalog.get_item!(item.id)
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
    alias Voile.Catalog.CollectionField

    import Voile.CatalogFixtures

    @invalid_attrs %{label: nil, name: nil, field_type: nil, required: nil, sort_order: nil}

    test "list_collection_fields/0 returns all collection_fields" do
      collection_field = collection_field_fixture()
      assert Catalog.list_collection_fields() == [collection_field]
    end

    test "get_collection_field!/1 returns the collection_field with given id" do
      collection_field = collection_field_fixture()
      assert Catalog.get_collection_field!(collection_field.id) == collection_field
    end

    test "create_collection_field/1 with valid data creates a collection_field" do
      valid_attrs = %{
        label: "some label",
        name: "some name",
        field_type: "some field_type",
        required: true,
        sort_order: 42
      }

      assert {:ok, %CollectionField{} = collection_field} =
               Catalog.create_collection_field(valid_attrs)

      assert collection_field.label == "some label"
      assert collection_field.name == "some name"
      assert collection_field.field_type == "some field_type"
      assert collection_field.required == true
      assert collection_field.sort_order == 42
    end

    test "create_collection_field/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_collection_field(@invalid_attrs)
    end

    test "update_collection_field/2 with valid data updates the collection_field" do
      collection_field = collection_field_fixture()

      update_attrs = %{
        label: "some updated label",
        name: "some updated name",
        field_type: "some updated field_type",
        required: false,
        sort_order: 43
      }

      assert {:ok, %CollectionField{} = collection_field} =
               Catalog.update_collection_field(collection_field, update_attrs)

      assert collection_field.label == "some updated label"
      assert collection_field.name == "some updated name"
      assert collection_field.field_type == "some updated field_type"
      assert collection_field.required == false
      assert collection_field.sort_order == 43
    end

    test "update_collection_field/2 with invalid data returns error changeset" do
      collection_field = collection_field_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Catalog.update_collection_field(collection_field, @invalid_attrs)

      assert collection_field == Catalog.get_collection_field!(collection_field.id)
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

  describe "collection_field_values" do
    alias Voile.Catalog.CollectionFieldValue

    import Voile.CatalogFixtures

    @invalid_attrs %{value: nil, locale: nil}

    test "list_collection_field_values/0 returns all collection_field_values" do
      collection_field_value = collection_field_value_fixture()
      assert Catalog.list_collection_field_values() == [collection_field_value]
    end

    test "get_collection_field_value!/1 returns the collection_field_value with given id" do
      collection_field_value = collection_field_value_fixture()

      assert Catalog.get_collection_field_value!(collection_field_value.id) ==
               collection_field_value
    end

    test "create_collection_field_value/1 with valid data creates a collection_field_value" do
      valid_attrs = %{value: "some value", locale: "some locale"}

      assert {:ok, %CollectionFieldValue{} = collection_field_value} =
               Catalog.create_collection_field_value(valid_attrs)

      assert collection_field_value.value == "some value"
      assert collection_field_value.locale == "some locale"
    end

    test "create_collection_field_value/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_collection_field_value(@invalid_attrs)
    end

    test "update_collection_field_value/2 with valid data updates the collection_field_value" do
      collection_field_value = collection_field_value_fixture()
      update_attrs = %{value: "some updated value", locale: "some updated locale"}

      assert {:ok, %CollectionFieldValue{} = collection_field_value} =
               Catalog.update_collection_field_value(collection_field_value, update_attrs)

      assert collection_field_value.value == "some updated value"
      assert collection_field_value.locale == "some updated locale"
    end

    test "update_collection_field_value/2 with invalid data returns error changeset" do
      collection_field_value = collection_field_value_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Catalog.update_collection_field_value(collection_field_value, @invalid_attrs)

      assert collection_field_value ==
               Catalog.get_collection_field_value!(collection_field_value.id)
    end

    test "delete_collection_field_value/1 deletes the collection_field_value" do
      collection_field_value = collection_field_value_fixture()

      assert {:ok, %CollectionFieldValue{}} =
               Catalog.delete_collection_field_value(collection_field_value)

      assert_raise Ecto.NoResultsError, fn ->
        Catalog.get_collection_field_value!(collection_field_value.id)
      end
    end

    test "change_collection_field_value/1 returns a collection_field_value changeset" do
      collection_field_value = collection_field_value_fixture()
      assert %Ecto.Changeset{} = Catalog.change_collection_field_value(collection_field_value)
    end
  end

  describe "item_field_values" do
    alias Voile.Catalog.ItemFieldValue

    import Voile.CatalogFixtures

    @invalid_attrs %{value: nil, locale: nil}

    test "list_item_field_values/0 returns all item_field_values" do
      item_field_value = item_field_value_fixture()
      assert Catalog.list_item_field_values() == [item_field_value]
    end

    test "get_item_field_value!/1 returns the item_field_value with given id" do
      item_field_value = item_field_value_fixture()
      assert Catalog.get_item_field_value!(item_field_value.id) == item_field_value
    end

    test "create_item_field_value/1 with valid data creates a item_field_value" do
      valid_attrs = %{value: "some value", locale: "some locale"}

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

      assert item_field_value == Catalog.get_item_field_value!(item_field_value.id)
    end

    test "delete_item_field_value/1 deletes the item_field_value" do
      item_field_value = item_field_value_fixture()
      assert {:ok, %ItemFieldValue{}} = Catalog.delete_item_field_value(item_field_value)

      assert_raise Ecto.NoResultsError, fn ->
        Catalog.get_item_field_value!(item_field_value.id)
      end
    end

    test "change_item_field_value/1 returns a item_field_value changeset" do
      item_field_value = item_field_value_fixture()
      assert %Ecto.Changeset{} = Catalog.change_item_field_value(item_field_value)
    end
  end
end
