defmodule Voile.Utils.ItemHelperTest do
  use ExUnit.Case, async: true

  alias Voile.Utils.ItemHelper

  describe "extract_barcode_prefix/1" do
    test "extracts the last 12-char block from a valid UUID" do
      assert ItemHelper.extract_barcode_prefix("b371e6aa-3fb1-48cf-8439-90373dfcd91a") ==
               "90373dfcd91a"
    end

    test "normalises to lowercase" do
      assert ItemHelper.extract_barcode_prefix("B371E6AA-3FB1-48CF-8439-90373DFCd91a") ==
               "90373dfcd91a"
    end

    test "returns nil for an invalid UUID string" do
      assert ItemHelper.extract_barcode_prefix("invalid") == nil
    end

    test "returns nil for nil input" do
      assert ItemHelper.extract_barcode_prefix(nil) == nil
    end

    test "returns nil for an integer input" do
      assert ItemHelper.extract_barcode_prefix(42) == nil
    end
  end

  describe "generate_item_code/5" do
    test "produces lowercased unit-type-collection-time-index format (index padded to 3 digits)" do
      code =
        ItemHelper.generate_item_code(
          "LIB",
          "Book",
          "fa000001-0000-0000-0000-000000000001",
          12345,
          "1"
        )

      assert code == "lib-book-fa000001-0000-0000-0000-000000000001-12345-001"
    end

    test "lowercases unit and type" do
      code = ItemHelper.generate_item_code("LIBNODE", "MONOGRAPH", "coll-id", 1, "01")
      assert String.starts_with?(code, "libnode-monograph-")
    end

    test "includes the index as the final segment" do
      code = ItemHelper.generate_item_code("a", "b", "c", 0, "007")
      assert String.ends_with?(code, "-007")
    end
  end

  describe "generate_inventory_code/4" do
    test "produces INV/unit/type/collection/padded_seq format" do
      code = ItemHelper.generate_inventory_code("LIB", "Book", "some-collection", "5")
      assert code == "INV/LIB/Book/some-collection/005"
    end

    test "pads single-digit sequence to 3 digits" do
      code = ItemHelper.generate_inventory_code("A", "B", "C", "1")
      assert String.ends_with?(code, "/001")
    end

    test "pads two-digit sequence to 3 digits" do
      code = ItemHelper.generate_inventory_code("A", "B", "C", "12")
      assert String.ends_with?(code, "/012")
    end

    test "leaves three-digit sequence unchanged" do
      code = ItemHelper.generate_inventory_code("A", "B", "C", "123")
      assert String.ends_with?(code, "/123")
    end

    test "slugifies collection part (spaces become hyphens, downcased)" do
      code = ItemHelper.generate_inventory_code("LIB", "Book", "My Collection", "1")
      assert code == "INV/LIB/Book/my-collection/001"
    end
  end

  describe "generate_barcode_from_item_code/1" do
    test "generates barcode using timestamp + last UUID block + zero-padded seq for UUID-bearing code" do
      # item_code ends with ...90373dfcd91a...-1773899097433-001
      collection_uuid = "b371e6aa-3fb1-48cf-8439-90373dfcd91a"
      item_code = "lib-book-#{collection_uuid}-1773899097433-001"

      barcode = ItemHelper.generate_barcode_from_item_code(item_code)

      assert barcode == "177389909743390373dfcd91a001"
    end

    test "barcode is at most 30 characters" do
      item_code = "lib-book-b371e6aa-3fb1-48cf-8439-90373dfcd91a-9999999999-999"
      barcode = ItemHelper.generate_barcode_from_item_code(item_code)
      assert String.length(barcode) <= 30
    end

    test "returns empty string for nil input" do
      assert ItemHelper.generate_barcode_from_item_code(nil) == ""
    end

    test "returns empty string for non-binary input" do
      assert ItemHelper.generate_barcode_from_item_code(123) == ""
    end
  end

  describe "generate_unique_collection_uuid/2" do
    test "returns {:ok, uuid} when the first candidate does not collide" do
      no_collision = fn _prefix -> false end

      assert {:ok, uuid} = ItemHelper.generate_unique_collection_uuid(no_collision)
      assert {:ok, _} = Ecto.UUID.cast(uuid)
    end

    test "retries until a non-colliding candidate is found" do
      # The first two candidates will collide; the third will succeed.
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      check_fn = fn _prefix ->
        count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)
        count < 2
      end

      assert {:ok, _uuid} = ItemHelper.generate_unique_collection_uuid(check_fn)
    end

    test "returns {:error, :max_attempts_reached} when all candidates collide" do
      always_collision = fn _prefix -> true end

      assert {:error, :max_attempts_reached} =
               ItemHelper.generate_unique_collection_uuid(always_collision, 5)
    end
  end
end
