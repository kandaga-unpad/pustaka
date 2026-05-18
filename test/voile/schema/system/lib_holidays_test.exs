defmodule Voile.Schema.System.LibHolidaysTest do
  use Voile.DataCase, async: true

  alias Voile.Schema.System.LibHolidays

  describe "recurring holiday support" do
    setup do
      node = insert(:node)
      other_node = insert(:node)

      %{node: node, other_node: other_node}
    end

    test "system-wide recurring holiday is recognized in a future year", %{node: _node} do
      {:ok, _} =
        LibHolidays.create_holiday(%{
          "name" => "New Year's Day",
          "holiday_date" => ~D[2025-01-01],
          "holiday_type" => "public",
          "description" => "System-wide recurring holiday",
          "is_recurring" => true,
          "is_active" => true,
          "unit_id" => nil
        })

      assert LibHolidays.is_holiday?(~D[2026-01-01])
      assert LibHolidays.get_holiday_stats(nil).public_holidays == 1
    end

    test "unit-specific recurring holiday applies only to that unit", %{
      node: node,
      other_node: other_node
    } do
      {:ok, _} =
        LibHolidays.create_holiday(%{
          "name" => "Branch Closure",
          "holiday_date" => ~D[2025-05-15],
          "holiday_type" => "library",
          "description" => "Annual branch closure",
          "is_recurring" => true,
          "is_active" => true,
          "unit_id" => node.id
        })

      assert LibHolidays.is_holiday?(~D[2026-05-15], node.id)
      refute LibHolidays.is_holiday?(~D[2026-05-15], other_node.id)
    end

    test "exact holiday creation conflicts with same scope recurring month/day", %{node: node} do
      {:ok, _} =
        LibHolidays.create_holiday(%{
          "name" => "Annual Staff Day",
          "holiday_date" => ~D[2025-11-11],
          "holiday_type" => "custom",
          "description" => "Yearly recurring holiday",
          "is_recurring" => true,
          "is_active" => true,
          "unit_id" => node.id
        })

      assert {:error, changeset} =
               LibHolidays.create_holiday(%{
                 "name" => "Single-day closure",
                 "holiday_date" => ~D[2026-11-11],
                 "holiday_type" => "custom",
                 "description" => "One-off day off",
                 "is_recurring" => false,
                 "is_active" => true,
                 "unit_id" => node.id
               })

      assert "Recurring or duplicate holiday already exists for this date, type, and unit" in errors_on(
               changeset
             ).holiday_date
    end

    test "recurring holidays are included when querying a date range", %{node: node} do
      {:ok, _} =
        LibHolidays.create_holiday(%{
          "name" => "Annual Stocktaking",
          "holiday_date" => ~D[2024-08-10],
          "holiday_type" => "library",
          "description" => "Annual stocktaking",
          "is_recurring" => true,
          "is_active" => true,
          "unit_id" => node.id
        })

      holidays = LibHolidays.get_holidays_in_range(~D[2025-08-09], ~D[2025-08-11])

      assert Enum.any?(holidays, fn holiday -> holiday.name == "Annual Stocktaking" end)
    end
  end
end
