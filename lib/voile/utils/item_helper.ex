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
    # Preferred strategy:
    # 1. Find the last UUID in the string (if present). Use the UUID's final block (12 hex chars).
    # 2. Use the trailing sequence (last hyphen-separated segment) zero-padded to 3 digits.
    # 3. Fallbacks: try to parse inventory-like codes, then fall back to earlier heuristics.

    # prefer trailing numeric sequence (handles both `-001` and `/002` cases)
    seq =
      case Regex.run(~r/(\d+)\s*$/, item_code) do
        [_, s] -> s
        _ -> List.last(String.split(item_code, "-")) || "1"
      end

    # look for UUID anywhere in the string and take the last match
    uuid_regex = ~r/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i

    case Regex.scan(uuid_regex, item_code) do
      [] ->
        # attempt inventory-style `.../<collection_uuid>/<seq>` by looking for UUID in slashes
        case Regex.scan(uuid_regex, item_code |> String.replace("/", "-")) do
          [] ->
            # no UUID found; fallback to previous heuristic: use third-to-last part if available
            parts = String.split(item_code, "-")

            if length(parts) >= 3 do
              uuid_segment = Enum.at(parts, -3)
              sequence = seq

              "#{String.replace(uuid_segment, "-", "")}#{String.pad_leading(sequence, 3, "0")}"
              |> String.slice(0, 20)
            else
              String.replace(item_code, "-", "") |> String.slice(0, 15)
            end

          matches ->
            last_uuid = matches |> List.last() |> List.first()
            last_block = last_uuid |> String.split("-") |> List.last()

            "#{String.downcase(last_block)}#{String.pad_leading(seq, 3, "0")}"
            |> String.slice(0, 20)
        end

      matches ->
        last_uuid = matches |> List.last() |> List.first()
        last_block = last_uuid |> String.split("-") |> List.last()

        "#{String.downcase(last_block)}#{String.pad_leading(seq, 3, "0")}"
        |> String.slice(0, 20)
    end
  end

  def generate_barcode_from_item_code(_), do: ""
end
