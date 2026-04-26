defmodule Voile.MasterFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Voile.Master` context.
  """

  @doc """
  Generate a creator.
  """
  def creator_fixture(attrs \\ %{}) do
    {:ok, creator} =
      attrs
      |> Enum.into(%{
        affiliation: "some affiliation",
        creator_contact: "some creator_contact",
        creator_name: "some creator_name_#{System.unique_integer([:positive])}",
        type: "Person"
      })
      |> Voile.Schema.Master.create_creator()

    creator
  end

  @doc """
  Generate a frequency.
  """
  def frequency_fixture(attrs \\ %{}) do
    {:ok, frequency} =
      attrs
      |> Enum.into(%{
        frequency: "some frequency",
        time_increment: 42,
        time_unit: "some time_unit"
      })
      |> Voile.Schema.Master.create_frequency()

    frequency
  end

  @doc """
  Generate a member_type.
  """
  def member_type_fixture(attrs \\ %{}) do
    {:ok, member_type} =
      attrs
      |> Enum.into(%{
        can_reserve: true,
        fine_per_day: 42,
        max_items: 42,
        max_days: 42,
        membership_period_days: 42,
        name: "some name_#{System.unique_integer([:positive])}",
        slug: "some-slug-#{System.unique_integer([:positive])}",
        max_renewals: 42
      })
      |> Voile.Schema.Master.create_member_type()

    member_type
  end

  @doc """
  Generate a locations.
  """
  def locations_fixture(attrs \\ %{}) do
    node = Voile.SystemFixtures.node_fixture()

    {:ok, locations} =
      attrs
      |> Enum.into(%{
        location_code: "some location_code_#{System.unique_integer([:positive])}",
        location_name: "some location_name",
        location_place: "some location_place",
        node_id: node.id
      })
      |> Voile.Schema.Master.create_locations()

    locations
  end

  @doc """
  Generate a places.
  """
  def places_fixture(attrs \\ %{}) do
    {:ok, places} =
      attrs
      |> Enum.into(%{
        name: "some name"
      })
      |> Voile.Schema.Master.create_places()

    places
  end

  @doc """
  Generate a publishers.
  """
  def publishers_fixture(attrs \\ %{}) do
    {:ok, publishers} =
      attrs
      |> Enum.into(%{
        address: "some address",
        city: "some city",
        contact: "some contact",
        name: "some name"
      })
      |> Voile.Schema.Master.create_publishers()

    publishers
  end

  @doc """
  Generate a topic.
  """
  def topic_fixture(attrs \\ %{}) do
    {:ok, topic} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: "some name",
        type: "some type"
      })
      |> Voile.Schema.Master.create_topic()

    topic
  end
end
