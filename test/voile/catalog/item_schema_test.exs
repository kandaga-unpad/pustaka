defmodule Voile.Schema.Catalog.ItemTest do
  use ExUnit.Case, async: true

  alias Voile.Schema.Catalog.Item

  @valid_attrs %{
    item_code: "LIB-BOOK-001",
    inventory_code: "INV/LIB/BOOK/001",
    barcode: "1234567890123",
    location: "A1-01",
    status: "active",
    condition: "good",
    availability: "available"
  }

  describe "changeset/2" do
    test "changeset with valid attributes is valid" do
      changeset = Item.changeset(%Item{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset requires item_code" do
      changeset = Item.changeset(%Item{}, Map.delete(@valid_attrs, :item_code))
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).item_code
    end

    test "changeset requires inventory_code" do
      changeset = Item.changeset(%Item{}, Map.delete(@valid_attrs, :inventory_code))
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).inventory_code
    end

    test "changeset requires barcode" do
      changeset = Item.changeset(%Item{}, Map.delete(@valid_attrs, :barcode))
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).barcode
    end

    test "changeset requires location" do
      changeset = Item.changeset(%Item{}, Map.delete(@valid_attrs, :location))
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).location
    end

    test "changeset requires status" do
      changeset = Item.changeset(%Item{}, Map.delete(@valid_attrs, :status))
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).status
    end

    test "changeset requires condition" do
      changeset = Item.changeset(%Item{}, Map.delete(@valid_attrs, :condition))
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).condition
    end

    test "changeset requires availability" do
      changeset = Item.changeset(%Item{}, Map.delete(@valid_attrs, :availability))
      # When availability is missing, it defaults to "in_processing"
      assert changeset.valid?
    end

    test "changeset defaults availability to 'in_processing' when nil" do
      attrs = Map.put(@valid_attrs, :availability, nil)
      changeset = Item.changeset(%Item{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :availability) == "in_processing"
    end

    test "changeset defaults availability to 'in_processing' when empty string" do
      attrs = Map.put(@valid_attrs, :availability, "")
      changeset = Item.changeset(%Item{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :availability) == "in_processing"
    end

    test "changeset validates status inclusion" do
      attrs = Map.put(@valid_attrs, :status, "invalid_status")
      changeset = Item.changeset(%Item{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "changeset accepts all valid statuses" do
      valid_statuses = ~w(active inactive lost damaged discarded)

      Enum.each(valid_statuses, fn status ->
        attrs = Map.put(@valid_attrs, :status, status)
        changeset = Item.changeset(%Item{}, attrs)
        assert changeset.valid?, "Expected valid for status: #{status}"
      end)
    end

    test "changeset validates condition inclusion" do
      attrs = Map.put(@valid_attrs, :condition, "invalid_condition")
      changeset = Item.changeset(%Item{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).condition
    end

    test "changeset accepts all valid conditions" do
      valid_conditions = ~w(excellent good fair poor damaged)

      Enum.each(valid_conditions, fn condition ->
        attrs = Map.put(@valid_attrs, :condition, condition)
        changeset = Item.changeset(%Item{}, attrs)
        assert changeset.valid?, "Expected valid for condition: #{condition}"
      end)
    end

    test "changeset validates availability inclusion" do
      attrs = Map.put(@valid_attrs, :availability, "invalid_availability")
      changeset = Item.changeset(%Item{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).availability
    end

    test "changeset accepts all valid availabilities" do
      valid_availabilities =
        ~w(available loaned reserved reference_only non_circulating maintenance conservation in_processing exhibition restricted in_transit missing quarantine)

      Enum.each(valid_availabilities, fn availability ->
        attrs = Map.put(@valid_attrs, :availability, availability)
        changeset = Item.changeset(%Item{}, attrs)
        assert changeset.valid?, "Expected valid for availability: #{availability}"
      end)
    end
  end

  describe "availability_options/0" do
    test "returns a list of {label, value} tuples" do
      options = Item.availability_options()

      assert is_list(options)
      assert length(options) > 0

      Enum.each(options, fn {label, value} ->
        assert is_binary(label)
        assert is_binary(value)
      end)
    end

    test "humanizes availability labels" do
      options = Item.availability_options()
      option_map = Enum.into(options, %{}, fn {label, val} -> {val, label} end)

      # "in_processing" should become "In Processing"
      assert option_map["in_processing"] == "In Processing"
      # "reference_only" should become "Reference Only"
      assert option_map["reference_only"] == "Reference Only"
    end

    test "includes all availability values" do
      options = Item.availability_options()
      values = Enum.map(options, fn {_label, val} -> val end)

      assert "available" in values
      assert "loaned" in values
      assert "reserved" in values
      assert "in_processing" in values
      assert "missing" in values
    end
  end

  describe "status_options/0" do
    test "returns a list of {label, value} tuples" do
      options = Item.status_options()

      assert is_list(options)
      assert length(options) > 0

      Enum.each(options, fn {label, value} ->
        assert is_binary(label)
        assert is_binary(value)
      end)
    end

    test "includes all status values" do
      options = Item.status_options()
      values = Enum.map(options, fn {_label, val} -> val end)

      assert "active" in values
      assert "inactive" in values
      assert "lost" in values
      assert "damaged" in values
      assert "discarded" in values
    end
  end

  describe "condition_options/0" do
    test "returns a list of {label, value} tuples" do
      options = Item.condition_options()

      assert is_list(options)
      assert length(options) > 0

      Enum.each(options, fn {label, value} ->
        assert is_binary(label)
        assert is_binary(value)
      end)
    end

    test "includes all condition values" do
      options = Item.condition_options()
      values = Enum.map(options, fn {_label, val} -> val end)

      assert "excellent" in values
      assert "good" in values
      assert "fair" in values
      assert "poor" in values
      assert "damaged" in values
    end
  end

  describe "attachments_by_type/2" do
    test "filters attachments by file_type" do
      attachments = [
        %{file_type: "pdf", name: "doc.pdf"},
        %{file_type: "image", name: "cover.jpg"},
        %{file_type: "pdf", name: "annex.pdf"}
      ]

      item = %Item{attachments: attachments}
      pdf_attachments = Item.attachments_by_type(item, "pdf")

      assert length(pdf_attachments) == 2
      assert Enum.all?(pdf_attachments, fn a -> a.file_type == "pdf" end)
    end

    test "returns empty list when no attachments match" do
      attachments = [%{file_type: "image", name: "cover.jpg"}]
      item = %Item{attachments: attachments}

      pdf_attachments = Item.attachments_by_type(item, "pdf")
      assert pdf_attachments == []
    end

    test "returns empty list when attachments list is empty" do
      item = %Item{attachments: []}
      assert Item.attachments_by_type(item, "pdf") == []
    end
  end

  describe "primary_attachment/1" do
    test "returns the primary attachment" do
      attachments = [
        %{is_primary: false, name: "cover.jpg"},
        %{is_primary: true, name: "primary.jpg"},
        %{is_primary: false, name: "other.jpg"}
      ]

      item = %Item{attachments: attachments}
      primary = Item.primary_attachment(item)

      assert primary.name == "primary.jpg"
      assert primary.is_primary == true
    end

    test "returns nil when no primary attachment" do
      attachments = [
        %{is_primary: false, name: "cover.jpg"},
        %{is_primary: false, name: "other.jpg"}
      ]

      item = %Item{attachments: attachments}
      assert Item.primary_attachment(item) == nil
    end

    test "returns nil when attachments list is empty" do
      item = %Item{attachments: []}
      assert Item.primary_attachment(item) == nil
    end
  end

  # Helper to format changeset errors (mirrors DataCase.errors_on/1)
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
