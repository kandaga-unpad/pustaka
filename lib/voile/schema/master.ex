defmodule Voile.Schema.Master do
  @moduledoc """
  The Master context.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo

  alias Voile.Schema.Master.Creator

  @doc """
  Returns the list of mst_creator.

  ## Examples

      iex> list_mst_creator()
      [%Creator{}, ...]

  """
  def list_mst_creator do
    Repo.all(Creator)
  end

  @doc """
  Return the list of mst_creator with the given filter.

  ## Examples

      iex> list_mst_creator(%{field: value})
      [%Creator{}, ...]
  """
  def list_mst_creator(filter) do
    Creator
    |> where([c], c.creator_name == ^filter.creator_name)
    |> Repo.all()
  end

  @doc """
  Return the list of mst_creator with pagination.
  """
  def list_mst_creator_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from c in Creator,
        order_by: [desc: c.id],
        limit: ^per_page,
        offset: ^offset

    creators = Repo.all(query)

    total_count = Repo.aggregate(Creator, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {creators, total_pages, total_count}
  end

  @doc """
  Search creators by name using a case-insensitive partial match.

  Returns a list limited by `limit`.
  """
  def search_mst_creator(query, limit \\ 10) when is_binary(query) do
    q = "%" <> String.replace(query, "%", "\\%") <> "%"

    Creator
    |> where([c], ilike(c.creator_name, ^q))
    |> order_by([c], asc: c.creator_name)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Search creators but return only minimal fields (id, creator_name, affiliation) to reduce data transfer.
  """
  def search_mst_creator_names(query, limit \\ 10, offset \\ 0) when is_binary(query) do
    q = "%" <> String.replace(query, "%", "\\%") <> "%"

    Creator
    |> where([c], ilike(c.creator_name, ^q))
    |> order_by([c], asc: c.creator_name)
    |> limit(^limit)
    |> offset(^offset)
    |> select([c], %{id: c.id, creator_name: c.creator_name, affiliation: c.affiliation})
    |> Repo.all()
  end

  @doc """
  Gets a single creator.

  Raises `Ecto.NoResultsError` if the Creator does not exist.

  ## Examples

      iex> get_creator!(123)
      %Creator{}

      iex> get_creator!(456)
      ** (Ecto.NoResultsError)

  """
  def get_creator!(id), do: Repo.get!(Creator, id)

  @doc """
  Gets or creates a creator by attributes (typically creator_name).
  Uses upsert with on_conflict to handle race conditions.

  ## Examples

      iex> get_or_create_creator(%{creator_name: "John Doe"})
      {:ok, %Creator{}}

  """
  def get_or_create_creator(attrs \\ %{}) do
    changeset = Creator.changeset(%Creator{}, attrs)

    Repo.insert(changeset,
      on_conflict: {:replace, [:updated_at]},
      conflict_target: :creator_name,
      returning: true
    )
  end

  @doc """
  Creates a creator.

  ## Examples

      iex> create_creator(%{creator_name: "John Doe"})
      {:ok, %Creator{}}

  """
  def create_creator(attrs \\ %{}) do
    %Creator{}
    |> Creator.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a creator.

  ## Examples

      iex> update_creator(creator, %{field: new_value})
      {:ok, %Creator{}}

      iex> update_creator(creator, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_creator(%Creator{} = creator, attrs) do
    creator
    |> Creator.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a creator.

  ## Examples

      iex> delete_creator(creator)
      {:ok, %Creator{}}

      iex> delete_creator(creator)
      {:error, %Ecto.Changeset{}}

  """
  def delete_creator(%Creator{} = creator) do
    Repo.delete(creator)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking creator changes.

  ## Examples

      iex> change_creator(creator)
      %Ecto.Changeset{data: %Creator{}}

  """
  def change_creator(%Creator{} = creator, attrs \\ %{}) do
    Creator.changeset(creator, attrs)
  end

  alias Voile.Schema.Master.Frequency

  @doc """
  Returns the list of mst_frequency.

  ## Examples

      iex> list_mst_frequency()
      [%Frequency{}, ...]

  """
  def list_mst_frequency do
    Repo.all(Frequency)
  end

  @doc """
  Returns the list of mst_frequency with pagination.

  ## Examples

      iex> list_mst_frequency_paginated(1, 10)
      {[%Frequency{}], 3}

  """
  def list_mst_frequency_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from f in Frequency,
        order_by: [desc: f.id],
        limit: ^per_page,
        offset: ^offset

    frequencies = Repo.all(query)

    total_count = Repo.aggregate(Frequency, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {frequencies, total_pages, total_count}
  end

  @doc """
  Gets a single frequency.

  Raises `Ecto.NoResultsError` if the Frequency does not exist.

  ## Examples

      iex> get_frequency!(123)
      %Frequency{}

      iex> get_frequency!(456)
      ** (Ecto.NoResultsError)

  """
  def get_frequency!(id), do: Repo.get!(Frequency, id)

  @doc """
  Creates a frequency.

  ## Examples

      iex> create_frequency(%{field: value})
      {:ok, %Frequency{}}

      iex> create_frequency(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_frequency(attrs \\ %{}) do
    %Frequency{}
    |> Frequency.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a frequency.

  ## Examples

      iex> update_frequency(frequency, %{field: new_value})
      {:ok, %Frequency{}}

      iex> update_frequency(frequency, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_frequency(%Frequency{} = frequency, attrs) do
    frequency
    |> Frequency.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a frequency.

  ## Examples

      iex> delete_frequency(frequency)
      {:ok, %Frequency{}}

      iex> delete_frequency(frequency)
      {:error, %Ecto.Changeset{}}

  """
  def delete_frequency(%Frequency{} = frequency) do
    Repo.delete(frequency)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking frequency changes.

  ## Examples

      iex> change_frequency(frequency)
      %Ecto.Changeset{data: %Frequency{}}

  """
  def change_frequency(%Frequency{} = frequency, attrs \\ %{}) do
    Frequency.changeset(frequency, attrs)
  end

  alias Voile.Schema.Master.MemberType

  @doc """
  Returns the list of mst_member_types.

  ## Examples

      iex> list_mst_member_types()
      [%MemberType{}, ...]

  """
  def list_mst_member_types do
    Repo.all(MemberType)
  end

  def list_mst_member_types_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from mt in MemberType,
        order_by: [desc: mt.id],
        limit: ^per_page,
        offset: ^offset

    member_types = Repo.all(query)

    total_count = Repo.aggregate(MemberType, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {member_types, total_pages, total_count}
  end

  @doc """
  Gets a single member_type.

  Raises `Ecto.NoResultsError` if the Member type does not exist.

  ## Examples

      iex> get_member_type!(123)
      %MemberType{}

      iex> get_member_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_member_type!(id), do: Repo.get!(MemberType, id)

  @doc """
  Gets a single member_type by slug.

  Returns nil if the Member type does not exist.

  ## Examples

      iex> get_member_type_by_slug("verified_member")
      %MemberType{}

      iex> get_member_type_by_slug("nonexistent")
      nil

  """
  def get_member_type_by_slug(slug) when is_binary(slug) do
    Repo.get_by(MemberType, slug: slug)
  end

  @doc """
  Creates a member_type.

  ## Examples

      iex> create_member_type(%{field: value})
      {:ok, %MemberType{}}

      iex> create_member_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_member_type(attrs \\ %{}) do
    %MemberType{}
    |> MemberType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a member_type.

  ## Examples

      iex> update_member_type(member_type, %{field: new_value})
      {:ok, %MemberType{}}

      iex> update_member_type(member_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_member_type(%MemberType{} = member_type, attrs) do
    member_type
    |> MemberType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a member_type.

  ## Examples

      iex> delete_member_type(member_type)
      {:ok, %MemberType{}}

      iex> delete_member_type(member_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_member_type(%MemberType{} = member_type) do
    Repo.delete(member_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking member_type changes.

  ## Examples

      iex> change_member_type(member_type)
      %Ecto.Changeset{data: %MemberType{}}

  """
  def change_member_type(%MemberType{} = member_type, attrs \\ %{}) do
    MemberType.changeset(member_type, attrs)
  end

  alias Voile.Schema.Master.Location

  @doc """
  Returns the list of mst_locations.

  ## Examples

      iex> list_mst_locations()
      [%Locations{}, ...]

  """
  def list_mst_locations do
    Repo.all(Location)
  end

  @doc """
  Returns the list of locations with filtering options.

  ## Options

    * `:node_id` - Filter by node_id
    * `:is_active` - Filter by active status
    * `:preload` - List of associations to preload

  ## Examples

      iex> list_locations(node_id: 1)
      [%Location{}, ...]

      iex> list_locations(node_id: 1, is_active: true)
      [%Location{}, ...]

  """
  def list_locations(opts \\ []) do
    query = from l in Location, order_by: [asc: l.location_name]

    query =
      if opts[:node_id] do
        where(query, [l], l.node_id == ^opts[:node_id])
      else
        query
      end

    query =
      if opts[:is_active] != nil do
        where(query, [l], l.is_active == ^opts[:is_active])
      else
        query
      end

    query =
      if opts[:preload] do
        preload(query, ^opts[:preload])
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Returns the list of mst_locations with pagination.
  """
  def list_mst_locations_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from l in Location,
        order_by: [desc: l.id],
        limit: ^per_page,
        offset: ^offset

    locations = Repo.all(query)

    total_count = Repo.aggregate(Location, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {locations, total_pages, total_count}
  end

  @doc """
  Gets a single locations.

  Raises `Ecto.NoResultsError` if the Locations does not exist.

  ## Examples

      iex> get_locations!(123)
      %Locations{}

      iex> get_locations!(456)
      ** (Ecto.NoResultsError)

  """
  def get_locations!(id), do: Repo.get!(Location, id)

  @doc """
  Creates a locations.

  ## Examples

      iex> create_locations(%{field: value})
      {:ok, %Locations{}}

      iex> create_locations(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_locations(attrs \\ %{}) do
    %Location{}
    |> Location.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a locations.

  ## Examples

      iex> update_locations(locations, %{field: new_value})
      {:ok, %Locations{}}

      iex> update_locations(locations, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_locations(%Location{} = location, attrs) do
    location
    |> Location.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a locations.

  ## Examples

      iex> delete_locations(locations)
      {:ok, %Locations{}}

      iex> delete_locations(locations)
      {:error, %Ecto.Changeset{}}

  """
  def delete_locations(%Location{} = location) do
    Repo.delete(location)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking locations changes.

  ## Examples

      iex> change_locations(locations)
      %Ecto.Changeset{data: %Locations{}}

  """
  def change_locations(%Location{} = location, attrs \\ %{}) do
    Location.changeset(location, attrs)
  end

  alias Voile.Schema.Master.Places

  @doc """
  Returns the list of mst_places.

  ## Examples

      iex> list_mst_places()
      [%Places{}, ...]

  """
  def list_mst_places do
    Repo.all(Places)
  end

  @doc """
  Returns the list of mst_places with pagination.
  """
  def list_mst_places_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from p in Places,
        order_by: [desc: p.id],
        limit: ^per_page,
        offset: ^offset

    places = Repo.all(query)

    total_count = Repo.aggregate(Places, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {places, total_pages, total_count}
  end

  @doc """
  Gets a single places.

  Raises `Ecto.NoResultsError` if the Places does not exist.

  ## Examples

      iex> get_places!(123)
      %Places{}

      iex> get_places!(456)
      ** (Ecto.NoResultsError)

  """
  def get_places!(id), do: Repo.get!(Places, id)

  @doc """
  Creates a places.

  ## Examples

      iex> create_places(%{field: value})
      {:ok, %Places{}}

      iex> create_places(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_places(attrs \\ %{}) do
    %Places{}
    |> Places.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a places.

  ## Examples

      iex> update_places(places, %{field: new_value})
      {:ok, %Places{}}

      iex> update_places(places, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_places(%Places{} = places, attrs) do
    places
    |> Places.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a places.

  ## Examples

      iex> delete_places(places)
      {:ok, %Places{}}

      iex> delete_places(places)
      {:error, %Ecto.Changeset{}}

  """
  def delete_places(%Places{} = places) do
    Repo.delete(places)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking places changes.

  ## Examples

      iex> change_places(places)
      %Ecto.Changeset{data: %Places{}}

  """
  def change_places(%Places{} = places, attrs \\ %{}) do
    Places.changeset(places, attrs)
  end

  alias Voile.Schema.Master.Publishers

  @doc """
  Returns the list of mst_publishers.

  ## Examples

      iex> list_mst_publishers()
      [%Publishers{}, ...]

  """
  def list_mst_publishers do
    Repo.all(Publishers)
  end

  @doc """
  Returns the list of mst_publisher with pagination
  """
  def list_mst_publishers_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from p in Publishers,
        order_by: [desc: p.id],
        limit: ^per_page,
        offset: ^offset

    publishers = Repo.all(query)

    total_count = Repo.aggregate(Publishers, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {publishers, total_pages, total_count}
  end

  @doc """
  Gets a single publishers.

  Raises `Ecto.NoResultsError` if the Publishers does not exist.

  ## Examples

      iex> get_publishers!(123)
      %Publishers{}

      iex> get_publishers!(456)
      ** (Ecto.NoResultsError)

  """
  def get_publishers!(id), do: Repo.get!(Publishers, id)

  @doc """
  Creates a publishers.

  ## Examples

      iex> create_publishers(%{field: value})
      {:ok, %Publishers{}}

      iex> create_publishers(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_publishers(attrs \\ %{}) do
    %Publishers{}
    |> Publishers.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a publishers.

  ## Examples

      iex> update_publishers(publishers, %{field: new_value})
      {:ok, %Publishers{}}

      iex> update_publishers(publishers, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_publishers(%Publishers{} = publishers, attrs) do
    publishers
    |> Publishers.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a publishers.

  ## Examples

      iex> delete_publishers(publishers)
      {:ok, %Publishers{}}

      iex> delete_publishers(publishers)
      {:error, %Ecto.Changeset{}}

  """
  def delete_publishers(%Publishers{} = publishers) do
    Repo.delete(publishers)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking publishers changes.

  ## Examples

      iex> change_publishers(publishers)
      %Ecto.Changeset{data: %Publishers{}}

  """
  def change_publishers(%Publishers{} = publishers, attrs \\ %{}) do
    Publishers.changeset(publishers, attrs)
  end

  alias Voile.Schema.Master.Topic

  @doc """
  Returns the list of mst_topics.

  ## Examples

      iex> list_mst_topics()
      [%Topic{}, ...]

  """
  def list_mst_topics do
    Repo.all(Topic)
  end

  @doc """
  Returns the list of mst_topics with pagination.
  """
  def list_mst_topics_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from t in Topic,
        order_by: [desc: t.id],
        limit: ^per_page,
        offset: ^offset

    topics = Repo.all(query)

    total_count = Repo.aggregate(Topic, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {topics, total_pages, total_count}
  end

  @doc """
  Gets a single topic.

  Raises `Ecto.NoResultsError` if the Topic does not exist.

  ## Examples

      iex> get_topic!(123)
      %Topic{}

      iex> get_topic!(456)
      ** (Ecto.NoResultsError)

  """
  def get_topic!(id), do: Repo.get!(Topic, id)

  @doc """
  Creates a topic.

  ## Examples

      iex> create_topic(%{field: value})
      {:ok, %Topic{}}

      iex> create_topic(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_topic(attrs \\ %{}) do
    %Topic{}
    |> Topic.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a topic.

  ## Examples

      iex> update_topic(topic, %{field: new_value})
      {:ok, %Topic{}}

      iex> update_topic(topic, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_topic(%Topic{} = topic, attrs) do
    topic
    |> Topic.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a topic.

  ## Examples

      iex> delete_topic(topic)
      {:ok, %Topic{}}

      iex> delete_topic(topic)
      {:error, %Ecto.Changeset{}}

  """
  def delete_topic(%Topic{} = topic) do
    Repo.delete(topic)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking topic changes.

  ## Examples

      iex> change_topic(topic)
      %Ecto.Changeset{data: %Topic{}}

  """
  def change_topic(%Topic{} = topic, attrs \\ %{}) do
    Topic.changeset(topic, attrs)
  end
end
