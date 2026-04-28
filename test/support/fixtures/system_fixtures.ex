defmodule Voile.SystemFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Voile.System` context.
  """

  @doc """
  Generate a node.
  """
  def node_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    {:ok, node} =
      attrs
      |> Enum.into(%{
        abbr: "some-abbr-#{unique}",
        image: "some image",
        name: "some name #{unique}"
      })
      |> Voile.Schema.System.create_node()

    node
  end

  @doc """
  Generate a setting.
  """
  def setting_fixture(attrs \\ %{}) do
    {:ok, setting} =
      attrs
      |> Enum.into(%{
        setting_name: "some setting_name",
        setting_value: "some setting_value"
      })
      |> Voile.Schema.System.create_setting()

    setting
  end

  @doc """
  Generate a system_log.
  """
  def system_log_fixture(attrs \\ %{}) do
    {:ok, system_log} =
      attrs
      |> Enum.into(%{
        log_date: ~U[2025-04-21 08:02:00Z],
        log_location: "some log_location",
        log_msg: "some log_msg",
        log_type: "some log_type"
      })
      |> Voile.Schema.System.create_system_log()

    system_log
  end

  @doc """
  Generate a collection_log.
  """
  def collection_log_fixture(attrs \\ %{}) do
    {:ok, collection_log} =
      attrs
      |> Enum.into(%{
        action: "some action",
        message: "some message",
        title: "some title"
      })
      |> Voile.Schema.System.create_collection_log()

    collection_log
  end
end
