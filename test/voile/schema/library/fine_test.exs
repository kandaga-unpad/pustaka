defmodule Voile.Schema.Library.FineTest do
  use Voile.DataCase

  alias Voile.Schema.Library.Fine
  import Voile.LibraryFixtures
  import Voile.AccountsFixtures

  @valid_attrs %{
    fine_type: "overdue",
    amount: "10000",
    fine_date: DateTime.utc_now(),
    fine_status: "pending",
    description: "Test fine"
  }

  @invalid_attrs %{
    fine_type: nil,
    amount: nil,
    fine_date: nil,
    fine_status: nil,
    member_id: nil
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
          processed_by_id: librarian.id
        })

      changeset = Fine.changeset(%Fine{}, attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Fine.changeset(%Fine{}, @invalid_attrs)
      refute changeset.valid?

      assert "can't be blank" in errors_on(changeset).fine_type
      assert "can't be blank" in errors_on(changeset).amount
      assert "can't be blank" in errors_on(changeset).fine_date
      assert "can't be blank" in errors_on(changeset).fine_status
      assert "can't be blank" in errors_on(changeset).member_id
    end

    test "changeset validates fine_type inclusion" do
      attrs = Map.merge(@valid_attrs, %{fine_type: "invalid_type"})
      changeset = Fine.changeset(%Fine{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).fine_type
    end

    test "changeset validates fine_status inclusion" do
      attrs = Map.merge(@valid_attrs, %{fine_status: "invalid_status"})
      changeset = Fine.changeset(%Fine{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).fine_status
    end

    test "changeset validates payment_method inclusion when provided" do
      attrs = Map.merge(@valid_attrs, %{payment_method: "invalid_method"})
      changeset = Fine.changeset(%Fine{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).payment_method
    end

    test "changeset accepts all valid fine types" do
      valid_types = ~w(overdue lost_item damaged_item processing)

      Enum.each(valid_types, fn fine_type ->
        member = user_fixture()

        attrs =
          Map.merge(@valid_attrs, %{
            fine_type: fine_type,
            member_id: member.id
          })

        changeset = Fine.changeset(%Fine{}, attrs)
        assert changeset.valid?, "#{fine_type} should be valid"
      end)
    end

    test "changeset accepts all valid statuses" do
      valid_statuses = ~w(pending partial_paid paid waived)

      Enum.each(valid_statuses, fn status ->
        member = user_fixture()

        attrs =
          Map.merge(@valid_attrs, %{
            fine_status: status,
            member_id: member.id
          })

        changeset = Fine.changeset(%Fine{}, attrs)
        assert changeset.valid?, "#{status} should be valid"
      end)
    end

    test "changeset accepts all valid payment methods" do
      valid_methods = ~w(cash credit_card debit_card bank_transfer online)

      Enum.each(valid_methods, fn method ->
        member = user_fixture()

        attrs =
          Map.merge(@valid_attrs, %{
            payment_method: method,
            member_id: member.id
          })

        changeset = Fine.changeset(%Fine{}, attrs)
        assert changeset.valid?, "#{method} should be valid"
      end)
    end

    test "changeset validates amount is greater than 0" do
      attrs = Map.merge(@valid_attrs, %{amount: "0"})
      changeset = Fine.changeset(%Fine{}, attrs)

      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).amount
    end

    test "changeset validates paid_amount is greater than or equal to 0" do
      attrs = Map.merge(@valid_attrs, %{paid_amount: "-100"})
      changeset = Fine.changeset(%Fine{}, attrs)

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).paid_amount
    end

    test "changeset calculates balance automatically" do
      member = user_fixture()

      attrs =
        Map.merge(@valid_attrs, %{
          amount: "20000",
          paid_amount: "5000",
          member_id: member.id
        })

      changeset = Fine.changeset(%Fine{}, attrs)
      assert changeset.valid?

      balance = Ecto.Changeset.get_field(changeset, :balance)
      expected_balance = Decimal.sub(Decimal.new("20000"), Decimal.new("5000"))
      assert Decimal.equal?(balance, expected_balance)
    end

    test "changeset sets default values" do
      member = user_fixture()

      # Test minimal valid attributes
      minimal_attrs = %{
        fine_type: "overdue",
        amount: "15000",
        member_id: member.id
      }

      changeset = Fine.changeset(%Fine{}, minimal_attrs)
      assert changeset.valid?

      # Check defaults are set
      assert Ecto.Changeset.get_field(changeset, :fine_status) == "pending"
      assert Ecto.Changeset.get_field(changeset, :fine_date) != nil
      assert Ecto.Changeset.get_field(changeset, :paid_amount) == Decimal.new("0")
    end
  end

  describe "fully_paid?/1" do
    test "returns true when balance is zero" do
      fine = %Fine{balance: Decimal.new("0")}
      assert Fine.fully_paid?(fine) == true
    end

    test "returns false when balance is greater than zero" do
      fine = %Fine{balance: Decimal.new("5000")}
      assert Fine.fully_paid?(fine) == false
    end
  end

  describe "struct" do
    test "has correct fields" do
      fine = %Fine{}

      assert Map.has_key?(fine, :id)
      assert Map.has_key?(fine, :fine_type)
      assert Map.has_key?(fine, :amount)
      assert Map.has_key?(fine, :paid_amount)
      assert Map.has_key?(fine, :balance)
      assert Map.has_key?(fine, :fine_date)
      assert Map.has_key?(fine, :payment_date)
      assert Map.has_key?(fine, :fine_status)
      assert Map.has_key?(fine, :description)
      assert Map.has_key?(fine, :waived)
      assert Map.has_key?(fine, :waived_date)
      assert Map.has_key?(fine, :waived_reason)
      assert Map.has_key?(fine, :payment_method)
      assert Map.has_key?(fine, :receipt_number)
      assert Map.has_key?(fine, :member_id)
      assert Map.has_key?(fine, :item_id)
      assert Map.has_key?(fine, :transaction_id)
      assert Map.has_key?(fine, :processed_by_id)
      assert Map.has_key?(fine, :waived_by_id)
    end

    test "has correct associations" do
      fine = fine_fixture()
      fine = Repo.preload(fine, [:member, :item, :processed_by])

      assert fine.member != nil
      assert fine.item != nil
      assert fine.processed_by != nil
    end

    test "has correct default values" do
      fine = %Fine{}

      assert fine.paid_amount == Decimal.new("0.0")
      assert fine.waived == false
    end
  end

  describe "default amount calculation" do
    test "sets default amount for overdue fines" do
      member = user_fixture()

      attrs = %{
        fine_type: "overdue",
        member_id: member.id,
        fine_date: DateTime.utc_now(),
        fine_status: "pending"
      }

      changeset = Fine.changeset(%Fine{}, attrs)
      assert changeset.valid?

      amount = Ecto.Changeset.get_field(changeset, :amount)
      assert amount != nil
    end

    test "sets default amount for lost_item fines" do
      member = user_fixture()

      attrs = %{
        fine_type: "lost_item",
        member_id: member.id,
        fine_date: DateTime.utc_now(),
        fine_status: "pending"
      }

      changeset = Fine.changeset(%Fine{}, attrs)
      assert changeset.valid?

      amount = Ecto.Changeset.get_field(changeset, :amount)
      expected_amount = Decimal.new("50000")
      assert Decimal.equal?(amount, expected_amount)
    end

    test "sets default amount for damaged_item fines" do
      member = user_fixture()

      attrs = %{
        fine_type: "damaged_item",
        member_id: member.id,
        fine_date: DateTime.utc_now(),
        fine_status: "pending"
      }

      changeset = Fine.changeset(%Fine{}, attrs)
      assert changeset.valid?

      amount = Ecto.Changeset.get_field(changeset, :amount)
      expected_amount = Decimal.new("25000")
      assert Decimal.equal?(amount, expected_amount)
    end

    test "sets default amount for processing fines" do
      member = user_fixture()

      attrs = %{
        fine_type: "processing",
        member_id: member.id,
        fine_date: DateTime.utc_now(),
        fine_status: "pending"
      }

      changeset = Fine.changeset(%Fine{}, attrs)
      assert changeset.valid?

      amount = Ecto.Changeset.get_field(changeset, :amount)
      expected_amount = Decimal.new("10000")
      assert Decimal.equal?(amount, expected_amount)
    end

    test "does not override explicit amount" do
      member = user_fixture()
      custom_amount = "25000"

      attrs = %{
        fine_type: "overdue",
        amount: custom_amount,
        member_id: member.id,
        fine_date: DateTime.utc_now(),
        fine_status: "pending"
      }

      changeset = Fine.changeset(%Fine{}, attrs)
      assert changeset.valid?

      amount = Ecto.Changeset.get_field(changeset, :amount)
      expected_amount = Decimal.new(custom_amount)
      assert Decimal.equal?(amount, expected_amount)
    end
  end

  describe "database constraints" do
    test "enforces foreign key constraints" do
      invalid_attrs =
        Map.merge(@valid_attrs, %{
          member_id: Ecto.UUID.generate(),
          item_id: Ecto.UUID.generate(),
          processed_by_id: Ecto.UUID.generate()
        })

      changeset = Fine.changeset(%Fine{}, invalid_attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).member_id
    end
  end
end
