defmodule Voile.Utils.PaginationTest do
  use ExUnit.Case, async: true

  alias Voile.Utils.Pagination

  describe "parse_page/2 (M5: safe pagination)" do
    @tag :pagination_security
    test "returns default for nil" do
      assert Pagination.parse_page(nil) == 1
    end

    @tag :pagination_security
    test "returns default for empty string" do
      assert Pagination.parse_page("") == 1
    end

    @tag :pagination_security
    test "returns default for non-numeric input (no crash)" do
      assert Pagination.parse_page("abc") == 1
      assert Pagination.parse_page("1abc") == 1
    end

    @tag :pagination_security
    test "returns default for partial numeric input" do
      assert Pagination.parse_page("12.5") == 1
    end

    @tag :pagination_security
    test "clamps zero and negative to 1" do
      assert Pagination.parse_page("0") == 1
      assert Pagination.parse_page("-5") == 1
    end

    @tag :pagination_security
    test "returns valid positive integers" do
      assert Pagination.parse_page("1") == 1
      assert Pagination.parse_page("5") == 5
      assert Pagination.parse_page("100") == 100
    end

    @tag :pagination_security
    test "respects custom default" do
      assert Pagination.parse_page("bad", 3) == 3
    end
  end

  describe "parse_per_page/2 (M5: capped pagination)" do
    @tag :pagination_security
    test "returns default for nil" do
      assert Pagination.parse_per_page(nil) == 20
    end

    @tag :pagination_security
    test "returns default for non-numeric input (no crash)" do
      assert Pagination.parse_per_page("not-a-number") == 20
    end

    @tag :pagination_security
    test "clamps zero and negative to 1" do
      assert Pagination.parse_per_page("0") == 1
      assert Pagination.parse_per_page("-10") == 1
    end

    @tag :pagination_security
    test "caps at maximum (100) to prevent resource exhaustion" do
      assert Pagination.parse_per_page("999999999") == 100
      assert Pagination.parse_per_page("101") == 100
    end

    @tag :pagination_security
    test "returns valid values within range" do
      assert Pagination.parse_per_page("10") == 10
      assert Pagination.parse_per_page("50") == 50
      assert Pagination.parse_per_page("100") == 100
    end

    @tag :pagination_security
    test "respects custom default" do
      assert Pagination.parse_per_page("bad", 15) == 15
    end
  end
end
