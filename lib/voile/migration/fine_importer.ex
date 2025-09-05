defmodule Voile.Migration.FineImporter do
  @moduledoc """
  Imports fines data from CSV files to lib_fines table.

  Expected CSV structure:
  - scripts/csv_data/fines/fines_*.csv

  CSV Headers:
  fines_id,fines_date,member_id,debet,credit,description
  """

  import Ecto.Query
  import Voile.Migration.Common

  alias Voile.Repo
  alias Voile.Schema.Library.{Fine, Transaction}
  alias Voile.Schema.Catalog.{Item, Collection}
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Master.Creator

  def import_all(batch_size \\ 500) do
    IO.puts("💰 Starting fines data import...")

    # Get fines files
    files = get_csv_files("fines")

    if Enum.empty?(files) do
      IO.puts("⚠️ No fines files found")
      %{inserted: 0, skipped: 0, errors: 0}
    else
      stats =
        files
        |> Enum.with_index(1)
        |> Enum.reduce(%{inserted: 0, skipped: 0, errors: 0}, fn {file, index}, acc ->
          IO.puts("\n🔄 Processing fines file #{index}/#{length(files)}: #{Path.basename(file)}")

          # Extract node info from filename for fines_N.csv files
          node_id = extract_node_from_filename(file)

          file_stats = process_fines_file(file, batch_size, node_id)

          %{
            inserted: acc.inserted + file_stats.inserted,
            skipped: acc.skipped + file_stats.skipped,
            errors: acc.errors + file_stats.errors
          }
        end)

      print_summary("FINES IMPORT", %{
        "Total Fines Inserted" => stats.inserted,
        "Total Fines Skipped" => stats.skipped,
        "Total Errors" => stats.errors
      })

      stats
    end
  end

  defp process_fines_file(file_path, batch_size, node_id) do
    stats = %{inserted: 0, skipped: 0, errors: 0}

    case File.stream!(file_path, [:trim_bom]) do
      stream ->
        final_stats =
          stream
          |> CSVParser.parse_stream(skip_headers: false)
          |> Stream.drop(1)
          |> Stream.with_index(1)
          |> Stream.chunk_every(batch_size)
          |> Enum.reduce(stats, fn chunk, acc_stats ->
            process_fines_batch(chunk, node_id, acc_stats)
          end)

        final_stats
    end
  rescue
    e ->
      IO.puts("❌ Error processing fines file: #{inspect(e)}")
      %{inserted: 0, skipped: 0, errors: 1}
  end

  defp process_fines_batch(chunk, node_id, stats) do
    # Parse rows and collect valid fine attributes
    fines_attrs =
      chunk
      |> Enum.reduce([], fn {row, line_num}, acc_attrs ->
        case parse_fine_row(row, line_num, node_id) do
          {:ok, attrs} ->
            [attrs | acc_attrs]

          {:error, _msg} ->
            acc_attrs
        end
      end)

    # Count parsing errors
    error_count = length(chunk) - length(fines_attrs)

    case fines_attrs do
      [] ->
        %{stats | errors: stats.errors + error_count}

      valid_fines ->
        try do
          # Insert valid fines
          {inserted_count, _} =
            Repo.insert_all(Fine, valid_fines,
              on_conflict: :nothing,
              returning: false
            )

          skipped_count = length(valid_fines) - inserted_count

          %{
            inserted: stats.inserted + inserted_count,
            skipped: stats.skipped + skipped_count,
            errors: stats.errors + error_count
          }
        rescue
          e ->
            IO.puts("❌ Error inserting fines batch: #{inspect(e)}")

            %{
              stats
              | errors: stats.errors + length(valid_fines) + error_count
            }
        end
    end
  end

  defp parse_fine_row(row, line_num, node_id) do
    try do
      [fines_id, fines_date, member_id, debet, credit, description] = row

      # Skip if essential data is missing
      if member_id in ["", nil] or fines_date in ["", nil] do
        {:error, "Missing essential data at line #{line_num}"}
      else
        # Find member by ID - skip record if member not found
        member = find_member_by_id(member_id)

        if is_nil(member) do
          {:error, "Member with ID #{member_id} not found at line #{line_num}"}
        else
          # Parse amounts
          debet_amount = parse_amount(debet)
          credit_amount = parse_amount(credit)

          # Calculate net amount (debet - credit)
          net_amount = Decimal.sub(debet_amount, credit_amount)

          # Skip if net amount is zero or negative
          if Decimal.compare(net_amount, 0) != :gt do
            {:error, "Invalid or zero fine amount at line #{line_num}"}
          else
            # Extract item code from description if available - use fallback if not found
            item =
              extract_and_find_item_from_description(description) || get_or_create_default_item()

            # Try to find related transaction
            transaction = find_related_transaction(member.id, item && item.id, fines_date)

            # Determine fine status based on credit amount
            {fine_status, paid_amount} = determine_fine_status(debet_amount, credit_amount)

            attrs = %{
              id: generate_fine_id(fines_id, node_id),
              # Most SLiMS fines are overdue fines
              fine_type: "overdue",
              amount: net_amount,
              paid_amount: paid_amount,
              balance: Decimal.sub(net_amount, paid_amount),
              fine_date: parse_datetime_with_default(fines_date),
              payment_date: determine_payment_date(fine_status, fines_date),
              fine_status: fine_status,
              description: clean_description(description, fines_id, node_id),
              waived: false,
              waived_date: nil,
              waived_reason: nil,
              payment_method: determine_payment_method(fine_status),
              receipt_number: generate_receipt_number(fines_id, node_id),
              member_id: member.id,
              item_id: item && item.id,
              transaction_id: transaction && transaction.id,
              # Using the same member as processed_by for historical data
              processed_by_id: member.id,
              waived_by_id: nil,
              inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
              updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
            }

            {:ok, attrs}
          end
        end
      end
    rescue
      e ->
        {:error, "Error parsing fine row at line #{line_num}: #{inspect(e)}"}
    end
  end

  defp parse_amount(nil), do: Decimal.new("0")
  defp parse_amount(""), do: Decimal.new("0")

  defp parse_amount(amount_str) do
    case Decimal.parse(amount_str) do
      {decimal, _} -> decimal
      :error -> Decimal.new("0")
    end
  end

  defp determine_fine_status(debet_amount, credit_amount) do
    cond do
      # If credit equals or exceeds debet, it's paid
      Decimal.compare(credit_amount, debet_amount) != :lt ->
        {"paid", debet_amount}

      # If there's some credit but less than debet, it's partially paid
      Decimal.compare(credit_amount, Decimal.new("0")) == :gt ->
        {"partial_paid", credit_amount}

      # No credit means it's pending
      true ->
        {"pending", Decimal.new("0")}
    end
  end

  defp determine_payment_date("paid", fines_date), do: parse_datetime_with_default(fines_date)

  defp determine_payment_date("partial_paid", fines_date),
    do: parse_datetime_with_default(fines_date)

  defp determine_payment_date(_, _), do: nil

  # Assume cash payment for legacy data
  defp determine_payment_method("paid"), do: "cash"
  defp determine_payment_method("partial_paid"), do: "cash"
  defp determine_payment_method(_), do: nil

  defp extract_and_find_item_from_description(nil), do: nil
  defp extract_and_find_item_from_description(""), do: nil

  defp extract_and_find_item_from_description(description) do
    # Try to extract item code from description like "Overdue fines for item 01001970500082"
    case Regex.run(~r/item\s+(\d+)/i, description) do
      [_, item_code] ->
        find_item_by_code(item_code)

      _ ->
        nil
    end
  end

  defp find_item_by_code(item_code) do
    from(i in Item, where: i.item_code == ^item_code)
    |> Repo.one()
  end

  defp find_member_by_id(member_id) do
    # Find user by identifier field which matches member_id from CSV
    # Convert string member_id to Decimal to match the schema type
    case Decimal.cast(member_id) do
      {:ok, decimal_id} ->
        Repo.get_by(User, identifier: decimal_id)

      :error ->
        nil
    end
  end

  defp find_related_transaction(member_id, item_id, fine_date) do
    fine_datetime = parse_datetime_with_default(fine_date)

    query =
      from(t in Transaction,
        where:
          t.member_id == ^member_id and
            t.transaction_type == "loan"
      )

    query =
      if item_id do
        from(t in query, where: t.item_id == ^item_id)
      else
        query
      end

    # Try to find transaction around the fine date
    query =
      if fine_datetime do
        from(t in query,
          where: t.transaction_date <= ^fine_datetime,
          order_by: [desc: t.transaction_date]
        )
      else
        from(t in query, order_by: [desc: t.transaction_date])
      end

    query
    |> limit(1)
    |> Repo.one()
  end

  defp clean_description(description, fines_id, node_id) do
    base_desc = if description not in ["", nil], do: description, else: "Legacy fine"
    additional_info = []

    additional_info =
      if fines_id not in ["", nil],
        do: additional_info ++ ["Legacy Fine ID: #{fines_id}"],
        else: additional_info

    additional_info =
      if node_id, do: additional_info ++ ["Source Node: #{node_id}"], else: additional_info

    case additional_info do
      [] -> base_desc
      _ -> "#{base_desc} (#{Enum.join(additional_info, "; ")})"
    end
  end

  defp extract_node_from_filename(filename) do
    extract_unit_id_from_filename(filename)
  end

  defp generate_fine_id(fines_id, node_id) do
    # Create a deterministic UUID based on fines_id and node_id
    seed = "fine-#{fines_id}-node-#{node_id || 0}"
    hash = :crypto.hash(:md5, seed) |> Base.encode16(case: :lower)

    # Format as UUID v4
    <<p1::binary-size(8), p2::binary-size(4), p3::binary-size(4), p4::binary-size(4),
      p5::binary-size(12)>> = hash

    "#{p1}-#{p2}-4#{String.slice(p3, 1, 3)}-c#{String.slice(p4, 1, 3)}-#{p5}"
  end

  defp generate_receipt_number(fines_id, node_id) do
    "LEGACY-#{fines_id}-N#{node_id || 0}"
  end

  defp parse_datetime_with_default(nil), do: nil
  defp parse_datetime_with_default(""), do: nil
  defp parse_datetime_with_default("0000-00-00 00:00:00"), do: nil

  defp parse_datetime_with_default(date_str) do
    case parse_datetime(date_str) do
      nil -> nil
      datetime -> datetime
    end
  end

  defp get_or_create_default_item do
    # Try to find existing default item first
    case Repo.get_by(Item, item_code: "MISSING_ITEM_DEFAULT") do
      nil ->
        # Create default collection first if it doesn't exist
        collection = get_or_create_default_collection()

        # Create default item
        {:ok, item} =
          %Item{}
          |> Item.changeset(%{
            item_code: "MISSING_ITEM_DEFAULT",
            inventory_code: "MISSING_ITEM_DEFAULT",
            location: "Unknown Location",
            status: "active",
            condition: "fair",
            availability: "available",
            collection_id: collection.id
          })
          |> Repo.insert()

        item

      item ->
        item
    end
  end

  defp get_or_create_default_collection do
    # Try to find existing default collection first
    case Repo.get_by(Collection, title: "Missing Items Collection") do
      nil ->
        # Get or create the default creator first
        creator = get_or_create_default_creator()

        # Create default collection
        {:ok, collection} =
          %Collection{}
          |> Collection.changeset(%{
            title: "Missing Items Collection",
            description: "Default collection for items that could not be found during import",
            status: "published",
            access_level: "public",
            thumbnail: "heroicons:solid:folder",
            creator_id: creator.id
          })
          |> Repo.insert()

        collection

      collection ->
        collection
    end
  end

  defp get_or_create_default_creator do
    # Try to find existing default creator first
    case Repo.get_by(Creator, creator_name: "Unknown Creator") do
      nil ->
        # Create default creator
        {:ok, creator} =
          %Creator{}
          |> Creator.changeset(%{
            creator_name: "Unknown Creator",
            creator_contact: "unknown@voile.app",
            affiliation: "Unknown",
            type: "Organization"
          })
          |> Repo.insert()

        creator

      creator ->
        creator
    end
  end
end
