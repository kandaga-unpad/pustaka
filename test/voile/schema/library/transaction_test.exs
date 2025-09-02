defmodule Voile.Schema.Library.TransactionTest do
  use Voile.DataCase

  alias Voile.Schema.Library.Transaction
  import Voile.LibraryFixtures
  import Voile.AccountsFixtures

  @valid_attrs %{
    transaction_type: "loan",
    transaction_date: DateTime.utc_now(),
    due_date: DateTime.add(DateTime.utc_now(), 14 * 24 * 60 * 60, :second),
    status: "active"
  }

  @invalid_attrs %{
    transaction_type: nil,
    transaction_date: nil,
    member_id: nil,
    item_id: nil,
    librarian_id: nil
  }

  describe "changeset/2" do
    test "changeset with valid attributes" do
      member = user_fixture()
      item = fine_fixture().item
      librarian = user_fixture()

      attrs =
        Map.merge(@valid_attrs, %{
          member_id: member.id,
          item_id: item.id,
          librarian_id: librarian.id
        })

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Transaction.changeset(%Transaction{}, @invalid_attrs)
      refute changeset.valid?

      assert "can't be blank" in errors_on(changeset).transaction_type
      assert "can't be blank" in errors_on(changeset).transaction_date
      assert "can't be blank" in errors_on(changeset).member_id
      assert "can't be blank" in errors_on(changeset).item_id
      assert "can't be blank" in errors_on(changeset).librarian_id
    end

    test "changeset validates transaction_type inclusion" do
      attrs = Map.merge(@valid_attrs, %{transaction_type: "invalid_type"})
      changeset = Transaction.changeset(%Transaction{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).transaction_type
    end

    test "changeset validates status inclusion" do
      attrs = Map.merge(@valid_attrs, %{status: "invalid_status"})
      changeset = Transaction.changeset(%Transaction{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "changeset accepts all valid transaction types" do
      valid_types = ~w(loan return renewal lost_item damaged_item cancel)

      Enum.each(valid_types, fn transaction_type ->
        member = user_fixture()
        item = fine_fixture().item
        librarian = user_fixture()

        attrs =
          Map.merge(@valid_attrs, %{
            transaction_type: transaction_type,
            member_id: member.id,
            item_id: item.id,
            librarian_id: librarian.id
          })

        changeset = Transaction.changeset(%Transaction{}, attrs)
        assert changeset.valid?, "#{transaction_type} should be valid"
      end)
    end

    test "changeset accepts all valid statuses" do
      valid_statuses = ~w(active returned overdue lost damaged canceled)

      Enum.each(valid_statuses, fn status ->
        member = user_fixture()
        item = fine_fixture().item
        librarian = user_fixture()

        attrs =
          Map.merge(@valid_attrs, %{
            status: status,
            member_id: member.id,
            item_id: item.id,
            librarian_id: librarian.id
          })

        changeset = Transaction.changeset(%Transaction{}, attrs)
        assert changeset.valid?, "#{status} should be valid"
      end)
    end

    test "changeset validates renewal_count is non-negative" do
      attrs = Map.merge(@valid_attrs, %{renewal_count: -1})
      changeset = Transaction.changeset(%Transaction{}, attrs)

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).renewal_count
    end

    test "changeset validates fine_amount is non-negative" do
      attrs = Map.merge(@valid_attrs, %{fine_amount: "-100"})
      changeset = Transaction.changeset(%Transaction{}, attrs)

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).fine_amount
    end
  end

  describe "overdue?/1" do
    test "returns true for active transaction past due date" do
      past_due_date = DateTime.add(DateTime.utc_now(), -1 * 24 * 60 * 60, :second)

      transaction = %Transaction{
        due_date: past_due_date,
        return_date: nil
      }

      assert Transaction.overdue?(transaction) == true
    end

    test "returns false for active transaction not past due date" do
      future_due_date = DateTime.add(DateTime.utc_now(), 1 * 24 * 60 * 60, :second)

      transaction = %Transaction{
        due_date: future_due_date,
        return_date: nil
      }

      assert Transaction.overdue?(transaction) == false
    end

    test "returns false for returned transaction" do
      past_due_date = DateTime.add(DateTime.utc_now(), -1 * 24 * 60 * 60, :second)

      transaction = %Transaction{
        due_date: past_due_date,
        return_date: DateTime.utc_now()
      }

      assert Transaction.overdue?(transaction) == false
    end
  end

  describe "days_overdue/1" do
    test "calculates days overdue for active overdue transaction" do
      # 5 days ago
      past_due_date = DateTime.add(DateTime.utc_now(), -5 * 24 * 60 * 60, :second)

      transaction = %Transaction{
        due_date: past_due_date,
        return_date: nil
      }

      days = Transaction.days_overdue(transaction)
      # Allow for some time variance
      assert days >= 4 and days <= 5
    end

    test "returns 0 for active transaction not overdue" do
      future_due_date = DateTime.add(DateTime.utc_now(), 1 * 24 * 60 * 60, :second)

      transaction = %Transaction{
        due_date: future_due_date,
        return_date: nil
      }

      assert Transaction.days_overdue(transaction) == 0
    end

    test "returns 0 for returned transaction" do
      past_due_date = DateTime.add(DateTime.utc_now(), -5 * 24 * 60 * 60, :second)

      transaction = %Transaction{
        due_date: past_due_date,
        return_date: DateTime.utc_now()
      }

      assert Transaction.days_overdue(transaction) == 0
    end
  end

  describe "struct" do
    test "has correct fields" do
      transaction = %Transaction{}

      assert Map.has_key?(transaction, :id)
      assert Map.has_key?(transaction, :transaction_type)
      assert Map.has_key?(transaction, :transaction_date)
      assert Map.has_key?(transaction, :due_date)
      assert Map.has_key?(transaction, :return_date)
      assert Map.has_key?(transaction, :renewal_count)
      assert Map.has_key?(transaction, :notes)
      assert Map.has_key?(transaction, :status)
      assert Map.has_key?(transaction, :fine_amount)
      assert Map.has_key?(transaction, :is_overdue)
      assert Map.has_key?(transaction, :item_id)
      assert Map.has_key?(transaction, :member_id)
      assert Map.has_key?(transaction, :librarian_id)
    end

    test "has correct associations" do
      transaction = transaction_fixture()
      transaction = Repo.preload(transaction, [:item, :member, :librarian])

      assert transaction.item != nil
      assert transaction.member != nil
      assert transaction.librarian != nil
    end

    test "has correct default values" do
      transaction = %Transaction{}

      assert transaction.renewal_count == 0
      assert transaction.fine_amount == Decimal.new("0.0")
      assert transaction.is_overdue == false
    end
  end

  describe "database constraints" do
    test "enforces foreign key constraints" do
      invalid_attrs =
        Map.merge(@valid_attrs, %{
          member_id: Ecto.UUID.generate(),
          item_id: Ecto.UUID.generate(),
          librarian_id: Ecto.UUID.generate()
        })

      changeset = Transaction.changeset(%Transaction{}, invalid_attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).member_id
    end
  end

  describe "integration tests" do
    test "creates transaction with all fields" do
      member = user_fixture()
      item = fine_fixture().item
      librarian = user_fixture()
      now = DateTime.utc_now()
      due_date = DateTime.add(now, 14 * 24 * 60 * 60, :second)

      attrs = %{
        transaction_type: "loan",
        transaction_date: now,
        due_date: due_date,
        status: "active",
        renewal_count: 0,
        notes: "Test transaction",
        fine_amount: Decimal.new("0"),
        is_overdue: false,
        member_id: member.id,
        item_id: item.id,
        librarian_id: librarian.id
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?

      assert {:ok, transaction} = Repo.insert(changeset)
      assert transaction.transaction_type == "loan"
      assert transaction.status == "active"
      assert transaction.renewal_count == 0
      assert transaction.is_overdue == false
    end

    test "updates transaction on return" do
      transaction = transaction_fixture()
      return_date = DateTime.utc_now()

      update_attrs = %{
        status: "returned",
        return_date: return_date
      }

      changeset = Transaction.changeset(transaction, update_attrs)
      assert changeset.valid?

      assert {:ok, updated_transaction} = Repo.update(changeset)
      assert updated_transaction.status == "returned"
      assert updated_transaction.return_date == return_date
    end

    test "tracks renewals correctly" do
      transaction = transaction_fixture(%{renewal_count: 0})
      new_due_date = DateTime.add(DateTime.utc_now(), 14 * 24 * 60 * 60, :second)

      update_attrs = %{
        renewal_count: 1,
        due_date: new_due_date
      }

      changeset = Transaction.changeset(transaction, update_attrs)
      assert changeset.valid?

      assert {:ok, renewed_transaction} = Repo.update(changeset)
      assert renewed_transaction.renewal_count == 1
      assert renewed_transaction.due_date == new_due_date
    end
  end
end
