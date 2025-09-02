defmodule Voile.Schema.Library.RequisitionTest do
  use Voile.DataCase

  alias Voile.Schema.Library.Requisition
  import Voile.LibraryFixtures
  import Voile.AccountsFixtures

  @valid_attrs %{
    request_date: DateTime.utc_now(),
    request_type: "purchase_request",
    status: "submitted",
    title: "Test Book Title",
    requested_by_id: nil
  }

  @invalid_attrs %{
    request_date: nil,
    request_type: nil,
    status: nil,
    title: nil,
    requested_by_id: nil
  }

  describe "changeset/2" do
    test "changeset with valid attributes" do
      user = user_fixture()

      attrs =
        Map.merge(@valid_attrs, %{
          requested_by_id: user.id
        })

      changeset = Requisition.changeset(%Requisition{}, attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Requisition.changeset(%Requisition{}, @invalid_attrs)
      refute changeset.valid?

      assert "can't be blank" in errors_on(changeset).request_date
      assert "can't be blank" in errors_on(changeset).request_type
      assert "can't be blank" in errors_on(changeset).status
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).requested_by_id
    end

    test "changeset validates request_type inclusion" do
      attrs = Map.merge(@valid_attrs, %{request_type: "invalid_type"})
      changeset = Requisition.changeset(%Requisition{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).request_type
    end

    test "changeset validates status inclusion" do
      attrs = Map.merge(@valid_attrs, %{status: "invalid_status"})
      changeset = Requisition.changeset(%Requisition{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "changeset validates priority inclusion" do
      attrs = Map.merge(@valid_attrs, %{priority: "invalid_priority"})
      changeset = Requisition.changeset(%Requisition{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).priority
    end

    test "changeset accepts all valid request types" do
      valid_types = ~w(purchase_request interlibrary_loan digitization_request reference_question)

      Enum.each(valid_types, fn request_type ->
        user = user_fixture()

        attrs =
          Map.merge(@valid_attrs, %{
            request_type: request_type,
            requested_by_id: user.id
          })

        changeset = Requisition.changeset(%Requisition{}, attrs)
        assert changeset.valid?, "#{request_type} should be valid"
      end)
    end

    test "changeset accepts all valid statuses" do
      valid_statuses = ~w(submitted reviewing approved rejected fulfilled cancelled)

      Enum.each(valid_statuses, fn status ->
        user = user_fixture()

        attrs =
          Map.merge(@valid_attrs, %{
            status: status,
            requested_by_id: user.id
          })

        changeset = Requisition.changeset(%Requisition{}, attrs)
        assert changeset.valid?, "#{status} should be valid"
      end)
    end

    test "changeset accepts all valid priorities" do
      valid_priorities = ~w(low normal high urgent)

      Enum.each(valid_priorities, fn priority ->
        user = user_fixture()

        attrs =
          Map.merge(@valid_attrs, %{
            priority: priority,
            requested_by_id: user.id
          })

        changeset = Requisition.changeset(%Requisition{}, attrs)
        assert changeset.valid?, "#{priority} should be valid"
      end)
    end

    test "changeset validates ISBN format" do
      user = user_fixture()

      # Invalid ISBN
      invalid_attrs =
        Map.merge(@valid_attrs, %{
          isbn: "invalid-isbn",
          requested_by_id: user.id
        })

      changeset = Requisition.changeset(%Requisition{}, invalid_attrs)
      refute changeset.valid?
      assert "must be a valid 10 or 13 digit ISBN" in errors_on(changeset).isbn

      # Valid 10-digit ISBN
      valid_10_attrs =
        Map.merge(@valid_attrs, %{
          isbn: "1234567890",
          requested_by_id: user.id
        })

      changeset = Requisition.changeset(%Requisition{}, valid_10_attrs)
      assert changeset.valid?

      # Valid 13-digit ISBN
      valid_13_attrs =
        Map.merge(@valid_attrs, %{
          isbn: "1234567890123",
          requested_by_id: user.id
        })

      changeset = Requisition.changeset(%Requisition{}, valid_13_attrs)
      assert changeset.valid?
    end

    test "changeset validates estimated cost is positive" do
      user = user_fixture()

      invalid_attrs =
        Map.merge(@valid_attrs, %{
          estimated_cost: Decimal.new("-100"),
          requested_by_id: user.id
        })

      changeset = Requisition.changeset(%Requisition{}, invalid_attrs)
      refute changeset.valid?
      assert "must be positive" in errors_on(changeset).estimated_cost

      # Valid positive cost
      valid_attrs =
        Map.merge(@valid_attrs, %{
          estimated_cost: Decimal.new("150000"),
          requested_by_id: user.id
        })

      changeset = Requisition.changeset(%Requisition{}, valid_attrs)
      assert changeset.valid?
    end

    test "changeset validates due date is not before request date" do
      user = user_fixture()
      request_date = DateTime.utc_now()
      past_due_date = Date.add(DateTime.to_date(request_date), -1)

      invalid_attrs =
        Map.merge(@valid_attrs, %{
          request_date: request_date,
          due_date: past_due_date,
          requested_by_id: user.id
        })

      changeset = Requisition.changeset(%Requisition{}, invalid_attrs)
      refute changeset.valid?
      assert "cannot be before request date" in errors_on(changeset).due_date

      # Valid future due date
      future_due_date = Date.add(DateTime.to_date(request_date), 30)

      valid_attrs =
        Map.merge(@valid_attrs, %{
          request_date: request_date,
          due_date: future_due_date,
          requested_by_id: user.id
        })

      changeset = Requisition.changeset(%Requisition{}, valid_attrs)
      assert changeset.valid?
    end
  end

  describe "struct" do
    test "has correct fields" do
      requisition = %Requisition{}

      assert Map.has_key?(requisition, :id)
      assert Map.has_key?(requisition, :request_date)
      assert Map.has_key?(requisition, :request_type)
      assert Map.has_key?(requisition, :status)
      assert Map.has_key?(requisition, :title)
      assert Map.has_key?(requisition, :author)
      assert Map.has_key?(requisition, :publisher)
      assert Map.has_key?(requisition, :isbn)
      assert Map.has_key?(requisition, :publication_year)
      assert Map.has_key?(requisition, :description)
      assert Map.has_key?(requisition, :justification)
      assert Map.has_key?(requisition, :priority)
      assert Map.has_key?(requisition, :estimated_cost)
      assert Map.has_key?(requisition, :notes)
      assert Map.has_key?(requisition, :staff_notes)
      assert Map.has_key?(requisition, :due_date)
      assert Map.has_key?(requisition, :fulfilled_date)
      assert Map.has_key?(requisition, :requested_by_id)
      assert Map.has_key?(requisition, :assigned_to_id)
      assert Map.has_key?(requisition, :unit_id)
    end

    test "has correct associations" do
      requisition = requisition_fixture()
      requisition = Repo.preload(requisition, [:requested_by, :assigned_to, :unit])

      assert requisition.requested_by != nil
      # assigned_to and unit may be nil
    end

    test "has correct default values" do
      requisition = %Requisition{}

      assert requisition.priority == "normal"
    end
  end

  describe "database constraints" do
    test "enforces foreign key constraints" do
      invalid_attrs =
        Map.merge(@valid_attrs, %{
          requested_by_id: Ecto.UUID.generate(),
          assigned_to_id: Ecto.UUID.generate()
        })

      changeset = Requisition.changeset(%Requisition{}, invalid_attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).requested_by_id
    end

    test "enforces unique title constraint" do
      user = user_fixture()
      title = "Unique Test Book"

      attrs =
        Map.merge(@valid_attrs, %{
          title: title,
          requested_by_id: user.id
        })

      # First requisition should succeed
      changeset1 = Requisition.changeset(%Requisition{}, attrs)
      assert {:ok, _requisition1} = Repo.insert(changeset1)

      # Second requisition with same title should fail
      changeset2 = Requisition.changeset(%Requisition{}, attrs)
      assert {:error, changeset} = Repo.insert(changeset2)
      assert "has already been taken" in errors_on(changeset).title
    end
  end

  describe "integration tests" do
    test "creates purchase request with full details" do
      user = user_fixture()
      now = DateTime.utc_now()

      attrs = %{
        request_date: now,
        request_type: "purchase_request",
        status: "submitted",
        title: "Advanced Elixir Programming",
        author: "Dave Thomas",
        publisher: "Pragmatic Bookshelf",
        isbn: "9781680502992",
        publication_year: 2018,
        description: "Comprehensive guide to advanced Elixir concepts",
        justification: "Required for library programming collection",
        priority: "high",
        estimated_cost: Decimal.new("450000"),
        notes: "Latest edition preferred",
        requested_by_id: user.id
      }

      changeset = Requisition.changeset(%Requisition{}, attrs)
      assert changeset.valid?

      assert {:ok, requisition} = Repo.insert(changeset)
      assert requisition.title == "Advanced Elixir Programming"
      assert requisition.author == "Dave Thomas"
      assert requisition.isbn == "9781680502992"
      assert requisition.priority == "high"
      assert Decimal.equal?(requisition.estimated_cost, Decimal.new("450000"))
    end

    test "creates interlibrary loan request" do
      user = user_fixture()

      attrs =
        Map.merge(@valid_attrs, %{
          request_type: "interlibrary_loan",
          title: "Rare Historical Document",
          description: "Primary source for research project",
          justification: "Not available in our collection",
          requested_by_id: user.id
        })

      changeset = Requisition.changeset(%Requisition{}, attrs)
      assert changeset.valid?

      assert {:ok, requisition} = Repo.insert(changeset)
      assert requisition.request_type == "interlibrary_loan"
    end

    test "assigns requisition to staff member" do
      requisition = requisition_fixture(%{status: "submitted"})
      staff = user_fixture()

      update_attrs = %{
        assigned_to_id: staff.id,
        status: "reviewing"
      }

      changeset = Requisition.changeset(requisition, update_attrs)
      assert changeset.valid?

      assert {:ok, updated_requisition} = Repo.update(changeset)
      assert updated_requisition.assigned_to_id == staff.id
      assert updated_requisition.status == "reviewing"
    end

    test "approves requisition with staff notes" do
      requisition = requisition_fixture(%{status: "reviewing"})

      update_attrs = %{
        status: "approved",
        staff_notes: "Approved for immediate purchase within budget"
      }

      changeset = Requisition.changeset(requisition, update_attrs)
      assert changeset.valid?

      assert {:ok, approved_requisition} = Repo.update(changeset)
      assert approved_requisition.status == "approved"
      assert approved_requisition.staff_notes == "Approved for immediate purchase within budget"
    end

    test "rejects requisition with reason" do
      requisition = requisition_fixture(%{status: "reviewing"})

      update_attrs = %{
        status: "rejected",
        staff_notes: "Outside collection scope"
      }

      changeset = Requisition.changeset(requisition, update_attrs)
      assert changeset.valid?

      assert {:ok, rejected_requisition} = Repo.update(changeset)
      assert rejected_requisition.status == "rejected"
      assert rejected_requisition.staff_notes == "Outside collection scope"
    end

    test "fulfills approved requisition" do
      requisition = requisition_fixture(%{status: "approved"})
      fulfill_time = DateTime.utc_now()

      update_attrs = %{
        status: "fulfilled",
        fulfilled_date: fulfill_time
      }

      changeset = Requisition.changeset(requisition, update_attrs)
      assert changeset.valid?

      assert {:ok, fulfilled_requisition} = Repo.update(changeset)
      assert fulfilled_requisition.status == "fulfilled"
      assert fulfilled_requisition.fulfilled_date == fulfill_time
    end

    test "manages requisition workflow" do
      user = user_fixture()
      staff = user_fixture()

      # 1. Create initial request
      initial_attrs =
        Map.merge(@valid_attrs, %{
          requested_by_id: user.id,
          priority: "urgent"
        })

      changeset = Requisition.changeset(%Requisition{}, initial_attrs)
      {:ok, requisition} = Repo.insert(changeset)
      assert requisition.status == "submitted"

      # 2. Assign to staff
      assign_changeset =
        Requisition.changeset(requisition, %{
          assigned_to_id: staff.id,
          status: "reviewing"
        })

      {:ok, requisition} = Repo.update(assign_changeset)
      assert requisition.status == "reviewing"

      # 3. Approve with notes
      approve_changeset =
        Requisition.changeset(requisition, %{
          status: "approved",
          staff_notes: "High priority item, proceed with purchase"
        })

      {:ok, requisition} = Repo.update(approve_changeset)
      assert requisition.status == "approved"

      # 4. Fulfill
      fulfill_changeset =
        Requisition.changeset(requisition, %{
          status: "fulfilled",
          fulfilled_date: DateTime.utc_now()
        })

      {:ok, final_requisition} = Repo.update(fulfill_changeset)
      assert final_requisition.status == "fulfilled"
      assert final_requisition.fulfilled_date != nil
    end
  end
end
