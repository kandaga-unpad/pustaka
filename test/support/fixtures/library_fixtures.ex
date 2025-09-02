defmodule Voile.LibraryFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Voile.Schema.Library` context.
  """

  import Ecto.Query
  alias Voile.Repo
  alias Voile.Schema.Library.{CirculationHistory, Fine, Requisition, Reservation, Transaction}
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Master.{MemberType, Creator}

  def valid_circulation_history_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      event_type: "loan",
      event_date: DateTime.utc_now(),
      description: "Test circulation event"
    })
  end

  def circulation_history_fixture(attrs \\ %{}) do
    member = ensure_user()
    item = ensure_item()
    librarian = ensure_user()

    attrs =
      attrs
      |> valid_circulation_history_attributes()
      |> Map.put_new(:member_id, member.id)
      |> Map.put_new(:item_id, item.id)
      |> Map.put_new(:processed_by_id, librarian.id)

    {:ok, circulation_history} =
      %CirculationHistory{}
      |> CirculationHistory.changeset(attrs)
      |> Repo.insert()

    circulation_history
  end

  def valid_fine_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      fine_type: "overdue",
      amount: Decimal.new("10000"),
      balance: Decimal.new("10000"),
      fine_date: DateTime.utc_now(),
      fine_status: "pending",
      description: "Late return fine"
    })
  end

  def fine_fixture(attrs \\ %{}) do
    member = ensure_user()
    item = ensure_item()
    librarian = ensure_user()

    attrs =
      attrs
      |> valid_fine_attributes()
      |> Map.put_new(:member_id, member.id)
      |> Map.put_new(:item_id, item.id)
      |> Map.put_new(:processed_by_id, librarian.id)

    {:ok, fine} =
      %Fine{}
      |> Fine.changeset(attrs)
      |> Repo.insert()

    fine
  end

  def valid_requisition_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      request_date: DateTime.utc_now(),
      request_type: "purchase_request",
      status: "submitted",
      title: "Test Book Title",
      author: "Test Author",
      description: "Test book description"
    })
  end

  def requisition_fixture(attrs \\ %{}) do
    user = ensure_user()

    attrs =
      attrs
      |> valid_requisition_attributes()
      |> Map.put_new(:requested_by_id, user.id)

    {:ok, requisition} =
      %Requisition{}
      |> Requisition.changeset(attrs)
      |> Repo.insert()

    requisition
  end

  def valid_reservation_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      reservation_date: DateTime.utc_now(),
      expiry_date: DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60, :second),
      status: "pending",
      priority: 1
    })
  end

  def reservation_fixture(attrs \\ %{}) do
    member = ensure_user()
    item = ensure_item()

    attrs =
      attrs
      |> valid_reservation_attributes()
      |> Map.put_new(:member_id, member.id)
      |> Map.put_new(:item_id, item.id)

    {:ok, reservation} =
      %Reservation{}
      |> Reservation.changeset(attrs)
      |> Repo.insert()

    reservation
  end

  def valid_transaction_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      transaction_type: "loan",
      transaction_date: DateTime.utc_now(),
      due_date: DateTime.add(DateTime.utc_now(), 14 * 24 * 60 * 60, :second),
      status: "active",
      renewal_count: 0
    })
  end

  def transaction_fixture(attrs \\ %{}) do
    member = ensure_user()
    item = ensure_item()
    librarian = ensure_user()

    attrs =
      attrs
      |> valid_transaction_attributes()
      |> Map.put_new(:member_id, member.id)
      |> Map.put_new(:item_id, item.id)
      |> Map.put_new(:librarian_id, librarian.id)

    {:ok, transaction} =
      %Transaction{}
      |> Transaction.changeset(attrs)
      |> Repo.insert()

    transaction
  end

  def overdue_transaction_fixture(attrs \\ %{}) do
    # Create a transaction that's already overdue
    past_due_date = DateTime.add(DateTime.utc_now(), -5 * 24 * 60 * 60, :second)

    attrs =
      attrs
      |> valid_transaction_attributes()
      |> Map.put(:due_date, past_due_date)
      |> Map.put(:is_overdue, true)

    transaction_fixture(attrs)
  end

  def expired_reservation_fixture(attrs \\ %{}) do
    # Create a reservation that's already expired
    past_expiry = DateTime.add(DateTime.utc_now(), -2 * 24 * 60 * 60, :second)

    attrs =
      attrs
      |> valid_reservation_attributes()
      |> Map.put(:expiry_date, past_expiry)
      |> Map.put(:status, "pending")

    reservation_fixture(attrs)
  end

  # Helper functions to ensure required entities exist
  defp ensure_user do
    case Repo.all(from u in User, limit: 1) do
      [user | _] ->
        user

      [] ->
        # Create a basic user with member type
        member_type = ensure_member_type()
        email = "test#{System.unique_integer()}@example.com"
        username = String.split(email, "@") |> hd()

        {:ok, user} =
          %User{}
          |> User.registration_changeset(%{
            email: email,
            username: username,
            password: "testpassword123",
            user_type_id: member_type.id
          })
          |> Repo.insert()

        user
    end
  end

  defp ensure_item do
    case Repo.all(from i in Item, limit: 1) do
      [item | _] ->
        item

      [] ->
        collection = ensure_collection()

        {:ok, item} =
          %Item{}
          |> Item.changeset(%{
            item_code: "TEST-#{System.unique_integer()}",
            inventory_code: "INV-#{System.unique_integer()}",
            location: "Test Library - Shelf A1",
            status: "active",
            availability: "available",
            condition: "good",
            collection_id: collection.id
          })
          |> Repo.insert()

        item
    end
  end

  defp ensure_collection do
    alias Voile.Schema.Catalog.Collection

    case Repo.all(from c in Collection, limit: 1) do
      [collection | _] ->
        collection

      [] ->
        creator = ensure_creator()

        {:ok, collection} =
          %Collection{}
          |> Collection.changeset(%{
            title: "Test Collection",
            description: "Test collection description",
            status: "published",
            access_level: "public",
            thumbnail: "test-thumbnail.jpg",
            creator_id: creator.id
          })
          |> Repo.insert()

        collection
    end
  end

  defp ensure_creator do
    alias Voile.Schema.Master.Creator

    case Repo.all(from c in Creator, limit: 1) do
      [creator | _] ->
        creator

      [] ->
        {:ok, creator} =
          %Creator{}
          |> Creator.changeset(%{
            creator_name: "Test Creator",
            type: "Person",
            creator_contact: "test@example.com",
            affiliation: "Test Institution"
          })
          |> Repo.insert()

        creator
    end
  end

  defp ensure_member_type do
    case Repo.all(from mt in MemberType, limit: 1) do
      [member_type | _] ->
        member_type

      [] ->
        {:ok, member_type} =
          %MemberType{}
          |> MemberType.changeset(%{
            name: "Regular Member",
            slug: "regular",
            description: "Regular library member",
            max_concurrent_loans: 5,
            max_days: 14,
            can_renew: true,
            max_renewals: 2,
            can_reserve: true,
            max_reserves: 3,
            fine_per_day: Decimal.new("5000"),
            max_fine: Decimal.new("100000"),
            is_active: true,
            priority_level: 1
          })
          |> Repo.insert()

        member_type
    end
  end
end
