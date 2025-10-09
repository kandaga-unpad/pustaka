defmodule Voile.Schema.Library.CirculationFineCalculationTest do
  use Voile.DataCase

  alias Voile.Schema.Library.{Circulation, Transaction}
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.Item

  describe "fine calculation with skip_holidays option" do
    setup do
      # Create member type with known fine rate
      {:ok, member_type} =
        %MemberType{}
        |> MemberType.changeset(%{
          name: "Regular Member",
          slug: "regular-test",
          description: "Test member type",
          max_concurrent_loans: 5,
          max_days: 14,
          can_renew: true,
          max_renewals: 2,
          can_reserve: true,
          max_reserves: 3,
          fine_per_day: Decimal.new("5000"),
          # Rp 100,000
          max_fine: Decimal.new("100000"),
          is_active: true,
          priority_level: 1
        })
        |> Repo.insert()

      # Create test member
      {:ok, member} =
        %User{}
        |> User.changeset(%{
          identifier: "TEST001",
          fullname: "Test Member",
          email: "test@example.com",
          user_role_id: 2,
          user_type_id: member_type.id,
          status: "active"
        })
        |> Repo.insert()

      # Create test item
      {:ok, collection} =
        Voile.Schema.Catalog.create_collection(%{
          title: "Test Book",
          material_type: "book",
          status: "active"
        })

      {:ok, item} =
        %Item{}
        |> Item.changeset(%{
          item_code: "ITEM001",
          collection_id: collection.id,
          availability: "available",
          status: "active"
        })
        |> Repo.insert()

      # Create librarian
      {:ok, librarian} =
        %User{}
        |> User.changeset(%{
          identifier: "LIB001",
          fullname: "Test Librarian",
          email: "librarian@example.com",
          user_role_id: 1,
          status: "active"
        })
        |> Repo.insert()

      # Create an overdue transaction
      # Due 10 days ago
      due_date = DateTime.utc_now() |> DateTime.add(-10, :day)

      {:ok, transaction} =
        %Transaction{}
        |> Transaction.changeset(%{
          transaction_type: "loan",
          transaction_date: DateTime.utc_now() |> DateTime.add(-24, :day),
          due_date: due_date,
          status: "active",
          member_id: member.id,
          item_id: item.id,
          librarian_id: librarian.id,
          renewal_count: 0
        })
        |> Repo.insert()

      %{
        transaction: transaction,
        member: member,
        member_type: member_type,
        librarian: librarian,
        item: item
      }
    end

    test "calculate_days_for_fine with skip_holidays: false (business days)", %{
      transaction: transaction
    } do
      # Should use business days (excluding weekends/holidays)
      days = Circulation.calculate_days_for_fine(transaction, skip_holidays: false)

      # The actual number will depend on weekends/holidays in the 10-day period
      assert is_integer(days)
      assert days > 0
      # Should be less than or equal to 10 (some days might be excluded)
      assert days <= 10
    end

    test "calculate_days_for_fine with skip_holidays: true (all days)", %{
      transaction: transaction
    } do
      # Should use all calendar days
      days = Circulation.calculate_days_for_fine(transaction, skip_holidays: true)

      assert is_integer(days)
      # Should be exactly 10 days (all calendar days)
      assert days == 10
    end

    test "calculate_fine_amount with skip_holidays: false", %{
      transaction: transaction,
      member_type: member_type
    } do
      amount = Circulation.calculate_fine_amount(transaction, member_type, skip_holidays: false)

      # Amount should be positive
      assert Decimal.gt?(amount, Decimal.new("0"))
      # Amount should respect max_fine
      assert Decimal.compare(amount, member_type.max_fine) != :gt
    end

    test "calculate_fine_amount with skip_holidays: true (higher fine)", %{
      transaction: transaction,
      member_type: member_type
    } do
      all_days_amount =
        Circulation.calculate_fine_amount(transaction, member_type, skip_holidays: true)

      business_days_amount =
        Circulation.calculate_fine_amount(transaction, member_type, skip_holidays: false)

      # All days amount should be greater than or equal to business days amount
      # (because it includes weekends/holidays)
      assert Decimal.compare(all_days_amount, business_days_amount) in [:gt, :eq]

      # For 10 calendar days at Rp 5,000/day = Rp 50,000
      expected = Decimal.mult(Decimal.new("10"), Decimal.new("5000"))
      assert Decimal.equal?(all_days_amount, expected)
    end

    test "Transaction.calculate_days_overdue with skip_holidays flag", %{transaction: transaction} do
      # With skip_holidays: true (all days)
      all_days = Transaction.calculate_days_overdue(transaction, true)
      assert all_days == 10

      # With skip_holidays: false (business days)
      business_days = Transaction.calculate_days_overdue(transaction, false)
      assert business_days <= 10
      assert business_days > 0
    end

    test "Transaction.calendar_days_overdue returns all days", %{transaction: transaction} do
      days = Transaction.calendar_days_overdue(transaction)
      assert days == 10
    end

    test "Transaction.days_overdue uses business days by default", %{transaction: transaction} do
      days = Transaction.days_overdue(transaction)
      # Should be less than or equal to 10
      assert days <= 10
      assert days > 0
    end
  end
end
