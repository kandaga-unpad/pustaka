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
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Accounts.User

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

    # Get default system user for processed_by (created during user import)
    system_user = get_or_create_system_user()

    # Track seen member_ids to prevent duplicates within the same file
    seen_member_ids = MapSet.new()

    case File.stream!(file_path, [:trim_bom]) do
      stream ->
        {final_stats, _} =
          stream
          |> CSVParser.parse_stream(skip_headers: false)
          # Skip header row
          |> Stream.drop(1)
          # Start from line 2 (after header)
          |> Stream.with_index(2)
          |> Stream.chunk_every(batch_size)
          |> Enum.reduce({stats, seen_member_ids}, fn chunk, {acc_stats, acc_seen} ->
            process_fines_batch(chunk, system_user.id, node_id, acc_stats, acc_seen)
          end)

        final_stats
    end
  rescue
    e ->
      IO.puts("❌ Error processing fines file: #{inspect(e)}")
      %{inserted: 0, skipped: 0, errors: 1}
  end

  defp process_fines_batch(chunk, processed_by_id, node_id, stats, seen_member_ids) do
    # First, filter and parse rows, checking for duplicate member_ids
    {fines_attrs, updated_seen, duplicate_count} =
      chunk
      |> Enum.reduce({[], seen_member_ids, 0}, fn {row, line_num},
                                                  {acc_attrs, acc_seen, dup_count} ->
        case parse_fine_row(row, line_num, processed_by_id, node_id) do
          {:ok, attrs} ->
            member_id = attrs.member_id

            if MapSet.member?(acc_seen, member_id) do
              IO.puts("⚠️ Skipping duplicate member_id #{member_id} at line #{line_num}")
              {acc_attrs, acc_seen, dup_count + 1}
            else
              {[attrs | acc_attrs], MapSet.put(acc_seen, member_id), dup_count}
            end

          {:error, _msg} ->
            {acc_attrs, acc_seen, dup_count}
        end
      end)

    # Count total errors including duplicates and parse errors
    error_count = length(chunk) - length(fines_attrs) - duplicate_count

    case fines_attrs do
      [] ->
        {%{stats | errors: stats.errors + error_count, skipped: stats.skipped + duplicate_count},
         updated_seen}

      valid_fines ->
        try do
          # Insert valid fines
          {inserted_count, _} =
            Repo.insert_all(Fine, valid_fines,
              on_conflict: :nothing,
              returning: false
            )

          skipped_count = length(valid_fines) - inserted_count

          {%{
             inserted: stats.inserted + inserted_count,
             skipped: stats.skipped + skipped_count + duplicate_count,
             errors: stats.errors + error_count
           }, updated_seen}
        rescue
          e ->
            IO.puts("❌ Error inserting fines batch: #{inspect(e)}")

            {%{
               stats
               | errors: stats.errors + length(valid_fines) + error_count + duplicate_count
             }, updated_seen}
        end
    end
  end

  defp parse_fine_row(row, line_num, processed_by_id, node_id) do
    try do
      [fines_id, fines_date, member_id, debet, credit, description] = row

      # Skip if essential data is missing
      if member_id in ["", nil] or fines_date in ["", nil] do
        {:error, "Missing essential data at line #{line_num}"}
      else
        # Find member by ID
        member = find_member_by_id(member_id)

        if is_nil(member) do
          {:error, "Member not found for ID: #{member_id} at line #{line_num}"}
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
            # Extract item code from description if available
            item = extract_and_find_item_from_description(description)

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
              processed_by_id: processed_by_id,
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

  defp parse_amount(amount_str) when amount_str in ["", nil], do: Decimal.new("0")

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

  defp extract_and_find_item_from_description(description) when description in ["", nil], do: nil

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
    from(i in Item, where: i.barcode == ^item_code)
    |> Repo.one()
  end

  defp find_member_by_id(member_id) do
    # Try to find by legacy member ID first, then by actual ID
    user =
      from(u in User,
        join: up in assoc(u, :user_profile),
        where: up.legacy_member_id == ^member_id
      )
      |> Repo.one()

    case user do
      nil ->
        # Try to find by actual user ID if it's a valid UUID
        case Ecto.UUID.cast(member_id) do
          {:ok, uuid} -> Repo.get(User, uuid)
          :error -> nil
        end

      user ->
        user
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

  defp parse_datetime_with_default(date_str) when date_str in ["", nil, "0000-00-00 00:00:00"],
    do: nil

  defp parse_datetime_with_default(date_str) do
    case parse_datetime(date_str) do
      nil -> nil
      datetime -> datetime
    end
  end

  defp get_or_create_system_user do
    case Repo.get_by(User, email: "system@library.local") do
      nil ->
        # Create system user if it doesn't exist
        {:ok, system_user} =
          %User{}
          |> User.registration_changeset(%{
            email: "system@library.local",
            password: "system-generated-#{:rand.uniform(999_999)}"
          })
          |> Repo.insert()

        system_user

      user ->
        user
    end
  end
end
