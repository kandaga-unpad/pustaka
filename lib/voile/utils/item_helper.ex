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
    collection = String.replace(collection, " ", "-")
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
      "condition" => "new",
      "availability" => "available"
    }
  end
end
