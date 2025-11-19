defmodule Voile.Utils.ItemHelper do
  alias Ecto.UUID

  def generate_item_code(unit, type, collection, time_identifier, index) do
    unit = String.downcase(unit)
    type = String.downcase(type)
    collection = String.downcase(to_string(collection))
    index = String.pad_leading(index, 3, "0")

    "#{unit}-#{type}-#{collection}-#{time_identifier}-#{index}"
  end

  def generate_inventory_code(unit, type, collection, sequential_number) do
    padded_number = String.pad_leading("#{sequential_number}", 3, "0")
    # Normalize collection part: downcase, replace spaces with hyphens so it
    # matches the seed-generated format which used UUIDs (lowercase) or
    # slugified titles.
    collection = collection |> to_string() |> String.downcase() |> String.replace(" ", "-")

    "INV/#{unit}/#{type}/#{collection}/#{padded_number}"
  end

  def default_item_params(collection_id, location_id, index) do
    item_code =
      generate_item_code(
        "Kandaga",
        "Book",
        "77f6cd57-4d36-43f3-bb2c-7dd475accbcf",
        collection_id,
        index
      )

    inventory_code =
      generate_inventory_code("Kandaga", "Book", "77f6cd57-4d36-43f3-bb2c-7dd475accbcf", index)

    %{
      "item_code" => item_code,
      "inventory_code" => inventory_code,
      "barcode" => UUID.generate(),
      "location" => Integer.to_string(location_id),
      "status" => "active",
      # Use "good" as this schema expects one of the @conditions values
      # (excellent, good, fair, poor, damaged).
      "condition" => "good",
      "availability" => "available"
    }
  end

  @doc """
  Generate a compact barcode string from an item_code.

  Behavior mirrors the importer helper: it extracts the third-to-last
  segment (expected to be the last UUID segment) concatenated with the
  sequence number to produce a short scannable barcode.
  """
  def generate_barcode_from_item_code(item_code) when is_binary(item_code) do
    parts = String.split(item_code, "-")

    if length(parts) >= 3 do
      uuid_segment = Enum.at(parts, -3)
      sequence = List.last(parts)
      "#{uuid_segment}#{sequence}"
    else
      String.replace(item_code, "-", "") |> String.slice(0, 15)
    end
  end

  def generate_barcode_from_item_code(_), do: ""
end
