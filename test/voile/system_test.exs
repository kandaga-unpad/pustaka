defmodule Voile.SystemTest do
  use Voile.DataCase

  alias Voile.System

  describe "nodes" do
    alias Voile.System.Node

    import Voile.SystemFixtures

    @invalid_attrs %{name: nil, image: nil, abbr: nil}

    test "list_nodes/0 returns all nodes" do
      node = node_fixture()
      assert System.list_nodes() == [node]
    end

    test "get_node!/1 returns the node with given id" do
      node = node_fixture()
      assert System.get_node!(node.id) == node
    end

    test "create_node/1 with valid data creates a node" do
      valid_attrs = %{name: "some name", image: "some image", abbr: "some abbr"}

      assert {:ok, %Node{} = node} = System.create_node(valid_attrs)
      assert node.name == "some name"
      assert node.image == "some image"
      assert node.abbr == "some abbr"
    end

    test "create_node/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = System.create_node(@invalid_attrs)
    end

    test "update_node/2 with valid data updates the node" do
      node = node_fixture()
      update_attrs = %{name: "some updated name", image: "some updated image", abbr: "some updated abbr"}

      assert {:ok, %Node{} = node} = System.update_node(node, update_attrs)
      assert node.name == "some updated name"
      assert node.image == "some updated image"
      assert node.abbr == "some updated abbr"
    end

    test "update_node/2 with invalid data returns error changeset" do
      node = node_fixture()
      assert {:error, %Ecto.Changeset{}} = System.update_node(node, @invalid_attrs)
      assert node == System.get_node!(node.id)
    end

    test "delete_node/1 deletes the node" do
      node = node_fixture()
      assert {:ok, %Node{}} = System.delete_node(node)
      assert_raise Ecto.NoResultsError, fn -> System.get_node!(node.id) end
    end

    test "change_node/1 returns a node changeset" do
      node = node_fixture()
      assert %Ecto.Changeset{} = System.change_node(node)
    end
  end

  describe "settings" do
    alias Voile.System.Setting

    import Voile.SystemFixtures

    @invalid_attrs %{setting_name: nil, setting_value: nil}

    test "list_settings/0 returns all settings" do
      setting = setting_fixture()
      assert System.list_settings() == [setting]
    end

    test "get_setting!/1 returns the setting with given id" do
      setting = setting_fixture()
      assert System.get_setting!(setting.id) == setting
    end

    test "create_setting/1 with valid data creates a setting" do
      valid_attrs = %{setting_name: "some setting_name", setting_value: "some setting_value"}

      assert {:ok, %Setting{} = setting} = System.create_setting(valid_attrs)
      assert setting.setting_name == "some setting_name"
      assert setting.setting_value == "some setting_value"
    end

    test "create_setting/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = System.create_setting(@invalid_attrs)
    end

    test "update_setting/2 with valid data updates the setting" do
      setting = setting_fixture()
      update_attrs = %{setting_name: "some updated setting_name", setting_value: "some updated setting_value"}

      assert {:ok, %Setting{} = setting} = System.update_setting(setting, update_attrs)
      assert setting.setting_name == "some updated setting_name"
      assert setting.setting_value == "some updated setting_value"
    end

    test "update_setting/2 with invalid data returns error changeset" do
      setting = setting_fixture()
      assert {:error, %Ecto.Changeset{}} = System.update_setting(setting, @invalid_attrs)
      assert setting == System.get_setting!(setting.id)
    end

    test "delete_setting/1 deletes the setting" do
      setting = setting_fixture()
      assert {:ok, %Setting{}} = System.delete_setting(setting)
      assert_raise Ecto.NoResultsError, fn -> System.get_setting!(setting.id) end
    end

    test "change_setting/1 returns a setting changeset" do
      setting = setting_fixture()
      assert %Ecto.Changeset{} = System.change_setting(setting)
    end
  end

  describe "system_logs" do
    alias Voile.System.SystemLog

    import Voile.SystemFixtures

    @invalid_attrs %{log_msg: nil, log_type: nil, log_location: nil, log_date: nil}

    test "list_system_logs/0 returns all system_logs" do
      system_log = system_log_fixture()
      assert System.list_system_logs() == [system_log]
    end

    test "get_system_log!/1 returns the system_log with given id" do
      system_log = system_log_fixture()
      assert System.get_system_log!(system_log.id) == system_log
    end

    test "create_system_log/1 with valid data creates a system_log" do
      valid_attrs = %{log_msg: "some log_msg", log_type: "some log_type", log_location: "some log_location", log_date: ~U[2025-04-21 08:02:00Z]}

      assert {:ok, %SystemLog{} = system_log} = System.create_system_log(valid_attrs)
      assert system_log.log_msg == "some log_msg"
      assert system_log.log_type == "some log_type"
      assert system_log.log_location == "some log_location"
      assert system_log.log_date == ~U[2025-04-21 08:02:00Z]
    end

    test "create_system_log/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = System.create_system_log(@invalid_attrs)
    end

    test "update_system_log/2 with valid data updates the system_log" do
      system_log = system_log_fixture()
      update_attrs = %{log_msg: "some updated log_msg", log_type: "some updated log_type", log_location: "some updated log_location", log_date: ~U[2025-04-22 08:02:00Z]}

      assert {:ok, %SystemLog{} = system_log} = System.update_system_log(system_log, update_attrs)
      assert system_log.log_msg == "some updated log_msg"
      assert system_log.log_type == "some updated log_type"
      assert system_log.log_location == "some updated log_location"
      assert system_log.log_date == ~U[2025-04-22 08:02:00Z]
    end

    test "update_system_log/2 with invalid data returns error changeset" do
      system_log = system_log_fixture()
      assert {:error, %Ecto.Changeset{}} = System.update_system_log(system_log, @invalid_attrs)
      assert system_log == System.get_system_log!(system_log.id)
    end

    test "delete_system_log/1 deletes the system_log" do
      system_log = system_log_fixture()
      assert {:ok, %SystemLog{}} = System.delete_system_log(system_log)
      assert_raise Ecto.NoResultsError, fn -> System.get_system_log!(system_log.id) end
    end

    test "change_system_log/1 returns a system_log changeset" do
      system_log = system_log_fixture()
      assert %Ecto.Changeset{} = System.change_system_log(system_log)
    end
  end

  describe "collection_logs" do
    alias Voile.System.CollectionLog

    import Voile.SystemFixtures

    @invalid_attrs %{message: nil, title: nil, action: nil}

    test "list_collection_logs/0 returns all collection_logs" do
      collection_log = collection_log_fixture()
      assert System.list_collection_logs() == [collection_log]
    end

    test "get_collection_log!/1 returns the collection_log with given id" do
      collection_log = collection_log_fixture()
      assert System.get_collection_log!(collection_log.id) == collection_log
    end

    test "create_collection_log/1 with valid data creates a collection_log" do
      valid_attrs = %{message: "some message", title: "some title", action: "some action"}

      assert {:ok, %CollectionLog{} = collection_log} = System.create_collection_log(valid_attrs)
      assert collection_log.message == "some message"
      assert collection_log.title == "some title"
      assert collection_log.action == "some action"
    end

    test "create_collection_log/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = System.create_collection_log(@invalid_attrs)
    end

    test "update_collection_log/2 with valid data updates the collection_log" do
      collection_log = collection_log_fixture()
      update_attrs = %{message: "some updated message", title: "some updated title", action: "some updated action"}

      assert {:ok, %CollectionLog{} = collection_log} = System.update_collection_log(collection_log, update_attrs)
      assert collection_log.message == "some updated message"
      assert collection_log.title == "some updated title"
      assert collection_log.action == "some updated action"
    end

    test "update_collection_log/2 with invalid data returns error changeset" do
      collection_log = collection_log_fixture()
      assert {:error, %Ecto.Changeset{}} = System.update_collection_log(collection_log, @invalid_attrs)
      assert collection_log == System.get_collection_log!(collection_log.id)
    end

    test "delete_collection_log/1 deletes the collection_log" do
      collection_log = collection_log_fixture()
      assert {:ok, %CollectionLog{}} = System.delete_collection_log(collection_log)
      assert_raise Ecto.NoResultsError, fn -> System.get_collection_log!(collection_log.id) end
    end

    test "change_collection_log/1 returns a collection_log changeset" do
      collection_log = collection_log_fixture()
      assert %Ecto.Changeset{} = System.change_collection_log(collection_log)
    end
  end
end
