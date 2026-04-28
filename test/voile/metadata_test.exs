defmodule Voile.MetadataTest do
  use Voile.DataCase

  alias Voile.Schema.Metadata

  describe "metadata_vocabularies" do
    alias Voile.Schema.Metadata.Vocabulary

    import Voile.MetadataFixtures

    @invalid_attrs %{label: nil, prefix: nil, namespace_url: nil, information: nil}

    test "list_metadata_vocabularies/0 returns all metadata_vocabularies" do
      vocabulary = vocabulary_fixture()
      assert Enum.any?(Metadata.list_metadata_vocabularies(), &(&1.id == vocabulary.id))
    end

    test "get_vocabulary!/1 returns the vocabulary with given id" do
      vocabulary = vocabulary_fixture()
      assert Metadata.get_vocabulary!(vocabulary.id) == vocabulary
    end

    test "create_vocabulary/1 with valid data creates a vocabulary" do
      valid_attrs = %{
        label: "some label",
        prefix: "some prefix",
        namespace_url: "some namespace_url",
        information: "some information"
      }

      assert {:ok, %Vocabulary{} = vocabulary} = Metadata.create_vocabulary(valid_attrs)
      assert vocabulary.label == "some label"
      assert vocabulary.prefix == "some prefix"
      assert vocabulary.namespace_url == "some namespace_url"
      assert vocabulary.information == "some information"
    end

    test "create_vocabulary/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Metadata.create_vocabulary(@invalid_attrs)
    end

    test "update_vocabulary/2 with valid data updates the vocabulary" do
      vocabulary = vocabulary_fixture()

      update_attrs = %{
        label: "some updated label",
        prefix: "some updated prefix",
        namespace_url: "some updated namespace_url",
        information: "some updated information"
      }

      assert {:ok, %Vocabulary{} = vocabulary} =
               Metadata.update_vocabulary(vocabulary, update_attrs)

      assert vocabulary.label == "some updated label"
      assert vocabulary.prefix == "some updated prefix"
      assert vocabulary.namespace_url == "some updated namespace_url"
      assert vocabulary.information == "some updated information"
    end

    test "update_vocabulary/2 with invalid data returns error changeset" do
      vocabulary = vocabulary_fixture()
      assert {:error, %Ecto.Changeset{}} = Metadata.update_vocabulary(vocabulary, @invalid_attrs)
      assert vocabulary == Metadata.get_vocabulary!(vocabulary.id)
    end

    test "delete_vocabulary/1 deletes the vocabulary" do
      vocabulary = vocabulary_fixture()
      assert {:ok, %Vocabulary{}} = Metadata.delete_vocabulary(vocabulary)
      assert_raise Ecto.NoResultsError, fn -> Metadata.get_vocabulary!(vocabulary.id) end
    end

    test "change_vocabulary/1 returns a vocabulary changeset" do
      vocabulary = vocabulary_fixture()
      assert %Ecto.Changeset{} = Metadata.change_vocabulary(vocabulary)
    end
  end

  describe "resource_class" do
    alias Voile.Schema.Metadata.ResourceClass

    import Voile.MetadataFixtures

    @invalid_attrs %{label: nil, local_name: nil, information: nil, glam_type: nil}

    test "list_resource_class/0 returns all resource_class" do
      resource_class = resource_class_fixture()
      assert Enum.any?(Metadata.list_resource_class(), &(&1.id == resource_class.id))
    end

    test "get_resource_class!/1 returns the resource_class with given id" do
      resource_class = resource_class_fixture()
      assert Metadata.get_resource_class!(resource_class.id) == resource_class
    end

    test "create_resource_class/1 with valid data creates a resource_class" do
      valid_attrs = %{
        label: "some label",
        local_name: "some local_name",
        information: "some information",
        glam_type: "Library"
      }

      assert {:ok, %ResourceClass{} = resource_class} =
               Metadata.create_resource_class(valid_attrs)

      assert resource_class.label == "some label"
      assert resource_class.local_name == "some local_name"
      assert resource_class.information == "some information"
    end

    test "create_resource_class/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Metadata.create_resource_class(@invalid_attrs)
    end

    test "update_resource_class/2 with valid data updates the resource_class" do
      resource_class = resource_class_fixture()

      update_attrs = %{
        label: "some updated label",
        local_name: "some updated local_name",
        information: "some updated information"
      }

      assert {:ok, %ResourceClass{} = resource_class} =
               Metadata.update_resource_class(resource_class, update_attrs)

      assert resource_class.label == "some updated label"
      assert resource_class.local_name == "some updated local_name"
      assert resource_class.information == "some updated information"
    end

    test "update_resource_class/2 with invalid data returns error changeset" do
      resource_class = resource_class_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Metadata.update_resource_class(resource_class, @invalid_attrs)

      assert resource_class == Metadata.get_resource_class!(resource_class.id)
    end

    test "delete_resource_class/1 deletes the resource_class" do
      resource_class = resource_class_fixture()
      assert {:ok, %ResourceClass{}} = Metadata.delete_resource_class(resource_class)
      assert_raise Ecto.NoResultsError, fn -> Metadata.get_resource_class!(resource_class.id) end
    end

    test "change_resource_class/1 returns a resource_class changeset" do
      resource_class = resource_class_fixture()
      assert %Ecto.Changeset{} = Metadata.change_resource_class(resource_class)
    end
  end

  describe "resource_template" do
    alias Voile.Schema.Metadata.ResourceTemplate

    import Voile.MetadataFixtures

    @invalid_attrs %{label: nil}

    test "list_resource_template/0 returns all resource_template" do
      resource_template = resource_template_fixture()
      assert Metadata.list_resource_template() == [resource_template]
    end

    test "get_resource_template!/1 returns the resource_template with given id" do
      resource_template = resource_template_fixture()
      assert Metadata.get_resource_template!(resource_template.id) == resource_template
    end

    test "create_resource_template/1 with valid data creates a resource_template" do
      user = Voile.AccountsFixtures.user_fixture()
      resource_class = resource_class_fixture()

      valid_attrs = %{
        label: "some label",
        owner_id: user.id,
        resource_class_id: resource_class.id
      }

      assert {:ok, %ResourceTemplate{} = resource_template} =
               Metadata.create_resource_template(valid_attrs)

      assert resource_template.label == "some label"
    end

    test "create_resource_template/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Metadata.create_resource_template(@invalid_attrs)
    end

    test "update_resource_template/2 with valid data updates the resource_template" do
      resource_template = resource_template_fixture()
      update_attrs = %{label: "some updated label"}

      assert {:ok, %ResourceTemplate{} = resource_template} =
               Metadata.update_resource_template(resource_template, update_attrs)

      assert resource_template.label == "some updated label"
    end

    test "update_resource_template/2 with invalid data returns error changeset" do
      resource_template = resource_template_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Metadata.update_resource_template(resource_template, @invalid_attrs)

      assert resource_template == Metadata.get_resource_template!(resource_template.id)
    end

    test "delete_resource_template/1 deletes the resource_template" do
      resource_template = resource_template_fixture()
      assert {:ok, %ResourceTemplate{}} = Metadata.delete_resource_template(resource_template)

      assert_raise Ecto.NoResultsError, fn ->
        Metadata.get_resource_template!(resource_template.id)
      end
    end

    test "change_resource_template/1 returns a resource_template changeset" do
      resource_template = resource_template_fixture()
      assert %Ecto.Changeset{} = Metadata.change_resource_template(resource_template)
    end
  end

  describe "resource_template_property" do
    alias Voile.Schema.Metadata.ResourceTemplateProperty

    import Voile.MetadataFixtures
    import Voile.SchemaMetadataFixtures

    @invalid_attrs %{
      position: nil,
      property_id: nil,
      template_id: nil
    }

    test "list_resource_template_property/0 returns all resource_template_property" do
      resource_template_property = resource_template_property_fixture()

      assert Enum.any?(
               Metadata.list_resource_template_property(),
               &(&1.id == resource_template_property.id)
             )
    end

    test "get_resource_template_property!/1 returns the resource_template_property with given id" do
      resource_template_property = resource_template_property_fixture()

      assert Metadata.get_resource_template_property!(resource_template_property.id) ==
               resource_template_property
    end

    test "create_resource_template_property/1 with valid data creates a resource_template_property" do
      property = property_fixture()
      resource_template = resource_template_fixture()

      valid_attrs = %{
        position: 42,
        property_id: property.id,
        template_id: resource_template.id,
        override_label: "some alternate_label"
      }

      assert {:ok, %ResourceTemplateProperty{} = resource_template_property} =
               Metadata.create_resource_template_property(valid_attrs)

      assert resource_template_property.position == 42
      assert resource_template_property.override_label == "some alternate_label"
      assert resource_template_property.property_id == property.id
    end

    test "create_resource_template_property/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Metadata.create_resource_template_property(@invalid_attrs)
    end

    test "update_resource_template_property/2 with valid data updates the resource_template_property" do
      resource_template_property = resource_template_property_fixture()

      update_attrs = %{
        position: 43,
        override_label: "some updated alternate_label"
      }

      assert {:ok, %ResourceTemplateProperty{} = resource_template_property} =
               Metadata.update_resource_template_property(
                 resource_template_property,
                 update_attrs
               )

      assert resource_template_property.position == 43
      assert resource_template_property.override_label == "some updated alternate_label"
    end

    test "update_resource_template_property/2 with invalid data returns error changeset" do
      resource_template_property = resource_template_property_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Metadata.update_resource_template_property(
                 resource_template_property,
                 @invalid_attrs
               )

      assert resource_template_property ==
               Metadata.get_resource_template_property!(resource_template_property.id)
    end

    test "delete_resource_template_property/1 deletes the resource_template_property" do
      resource_template_property = resource_template_property_fixture()

      assert {:ok, %ResourceTemplateProperty{}} =
               Metadata.delete_resource_template_property(resource_template_property)

      assert_raise Ecto.NoResultsError, fn ->
        Metadata.get_resource_template_property!(resource_template_property.id)
      end
    end

    test "change_resource_template_property/1 returns a resource_template_property changeset" do
      resource_template_property = resource_template_property_fixture()

      assert %Ecto.Changeset{} =
               Metadata.change_resource_template_property(resource_template_property)
    end
  end
end
