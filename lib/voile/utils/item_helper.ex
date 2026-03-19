defmodule Voile.Utils.ItemHelper do
  alias Ecto.UUID

  @doc """
  Extracts the barcode prefix from a collection UUID.
  The barcode prefix is the last 12 characters of the UUID (the final block).

  ## Examples

      iex> extract_barcode_prefix("b371e6aa-3fb1-48cf-8439-90373dfcd91a")
      "90373dfcd91a"

      iex> extract_barcode_prefix("invalid")
      nil
  """
  def extract_barcode_prefix(collection_id) when is_binary(collection_id) do
    case UUID.cast(collection_id) do
      {:ok, _} ->
        # UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        # We want the last 12 characters (the final block)
        collection_id
        |> String.split("-")
        |> List.last()
        |> String.downcase()

      :error ->
        nil
    end
  end

  def extract_barcode_prefix(_), do: nil

  @doc """
  Generates a unique collection UUID that doesn't collide with existing barcode prefixes.
  Takes a function that checks if a barcode prefix exists and generates new UUIDs until
  a unique one is found.

  ## Parameters

    - check_exists_fn: A function that takes a barcode prefix and returns true if it exists
    - max_attempts: Maximum number of attempts (default: 100)

  ## Returns

    - {:ok, uuid} - A unique UUID
    - {:error, :max_attempts_reached} - If unable to find unique UUID after max attempts
  """
  def generate_unique_collection_uuid(check_exists_fn, max_attempts \\ 100) do
    do_generate_unique_uuid(check_exists_fn, max_attempts, 0)
  end

  defp do_generate_unique_uuid(_check_exists_fn, max_attempts, attempts)
       when attempts >= max_attempts do
    {:error, :max_attempts_reached}
  end

  defp do_generate_unique_uuid(check_exists_fn, max_attempts, attempts) do
    uuid = UUID.generate()
    barcode_prefix = extract_barcode_prefix(uuid)

    if check_exists_fn.(barcode_prefix) do
      do_generate_unique_uuid(check_exists_fn, max_attempts, attempts + 1)
    else
      {:ok, uuid}
    end
  end

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

  ## New Format (preferred for new items)
  Combines unix timestamp (milliseconds) + collection UUID segment + item index.
  Example: `17738990974338c87c8d23358001`
    - `1773899097433` = unix timestamp in milliseconds
    - `8c87c8d23358` = last 12 chars of collection UUID
    - `001` = item index (padded to 3 digits)

  ## Old Format (backward compatibility)
  Falls back to extracting UUID last block + sequence for older item_codes.
  Example: `8c87c8d23358001`

  ## Item Code Format
  Expected: `unit-type-collection_uuid-timestamp-index`
  Example: `curatorian-book-c1fcfbee-8674-4ee1-bc30-8c87c8d23358-1773899097433-000`
  """
  def generate_barcode_from_item_code(item_code) when is_binary(item_code) do
    parts = String.split(item_code, "-")

    # Check if we have enough parts for new format (at least 5 parts: unit-type-uuid-timestamp-index)
    cond do
      length(parts) >= 5 ->
        # New format: unit-type-collection_uuid-timestamp-index
        timestamp = Enum.at(parts, -2) || ""
        collection_uuid = Enum.at(parts, -3) || ""
        index = List.last(parts) || "001"

        # Get last 12 characters of collection UUID
        collection_segment =
          if String.length(collection_uuid) >= 12 do
            String.slice(collection_uuid, -12, 12)
          else
            # Pad with zeros if UUID is shorter
            String.pad_leading(collection_uuid, 12, "0")
          end

        # Combine: timestamp + collection_segment + padded_index
        "#{timestamp}#{collection_segment}#{String.pad_leading(index, 3, "0")}"

      # Try to find UUID and sequence for old format
      true ->
        generate_barcode_legacy(item_code)
    end
  end

  def generate_barcode_from_item_code(_), do: ""

  # Legacy barcode generation for backward compatibility
  defp generate_barcode_legacy(item_code) when is_binary(item_code) do
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
end
