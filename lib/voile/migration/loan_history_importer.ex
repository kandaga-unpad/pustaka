defmodule Voile.Migration.LoanHistoryImporter do
  @moduledoc """
  Imports loan history data from CSV files to lib_circulation_history table.

  Expected CSV structure:
  - scripts/csv_data/loan_history/loan_history_*.csv

  CSV Headers:
  loan_id,item_code,biblio_id,title,call_number,classification,gmd_name,language_name,location_name,collection_type_name,member_id,member_name,member_type_name,loan_date,due_date,renewed,is_lent,is_return,return_date,input_date,last_update
  """

  import Ecto.Query
  import Voile.Migration.Common

  alias Voile.Repo
  alias Voile.Schema.Library.{CirculationHistory, Transaction}
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Accounts.User

  def import_all(batch_size \\ 500) do
    IO.puts("📜 Starting loan history data import...")

    # Get loan history files
    files = get_csv_files("loan_history")

    if Enum.empty?(files) do
      IO.puts("⚠️ No loan history files found")
      %{inserted: 0, skipped: 0, errors: 0}
    else
      stats =
        files
        |> Enum.with_index(1)
        |> Enum.reduce(%{inserted: 0, skipped: 0, errors: 0}, fn {file, index}, acc ->
          IO.puts(
            "\n🔄 Processing loan history file #{index}/#{length(files)}: #{Path.basename(file)}"
          )

          # Extract node info from filename for loan_history_N.csv files
          node_id = extract_node_from_filename(file)

          file_stats = process_loan_history_file(file, batch_size, node_id)

          %{
            inserted: acc.inserted + file_stats.inserted,
            skipped: acc.skipped + file_stats.skipped,
            errors: acc.errors + file_stats.errors
          }
        end)

      print_summary("LOAN HISTORY IMPORT", %{
        "Total History Records Inserted" => stats.inserted,
        "Total History Records Skipped" => stats.skipped,
        "Total Errors" => stats.errors
      })

      stats
    end
  end

  defp process_loan_history_file(file_path, batch_size, node_id) do
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
            process_loan_history_batch(chunk, system_user.id, node_id, acc_stats, acc_seen)
          end)

        final_stats
    end
  rescue
    e ->
      IO.puts("❌ Error processing loan history file: #{inspect(e)}")
      %{inserted: 0, skipped: 0, errors: 1}
  end

  defp process_loan_history_batch(chunk, processed_by_id, node_id, stats, seen_member_ids) do
    # First, filter and parse rows, checking for duplicate member_ids
    {history_attrs, updated_seen, duplicate_count} =
      chunk
      |> Enum.reduce({[], seen_member_ids, 0}, fn {row, line_num},
                                                  {acc_attrs, acc_seen, dup_count} ->
        case parse_loan_history_row(row, line_num, processed_by_id, node_id) do
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
    error_count = length(chunk) - length(history_attrs) - duplicate_count

    case history_attrs do
      [] ->
        {%{stats | errors: stats.errors + error_count, skipped: stats.skipped + duplicate_count},
         updated_seen}

      valid_histories ->
        try do
          # Insert valid history records
          {inserted_count, _} =
            Repo.insert_all(CirculationHistory, valid_histories,
              on_conflict: :nothing,
              returning: false
            )

          skipped_count = length(valid_histories) - inserted_count

          {%{
             inserted: stats.inserted + inserted_count,
             skipped: stats.skipped + skipped_count + duplicate_count,
             errors: stats.errors + error_count
           }, updated_seen}
        rescue
          e ->
            IO.puts("❌ Error inserting loan history batch: #{inspect(e)}")

            {%{
               stats
               | errors: stats.errors + length(valid_histories) + error_count + duplicate_count
             }, updated_seen}
        end
    end
  end

  defp parse_loan_history_row(row, line_num, processed_by_id, node_id) do
    try do
      [
        loan_id,
        item_code,
        biblio_id,
        title,
        call_number,
        _classification,
        _gmd_name,
        _language_name,
        _location_name,
        _collection_type_name,
        member_id,
        member_name,
        _member_type_name,
        loan_date,
        due_date,
        renewed,
        is_lent,
        is_return,
        return_date,
        _input_date,
        _last_update
      ] = row

      # Skip if essential data is missing
      if item_code in ["", nil] or member_id in ["", nil] or loan_date in ["", nil] do
        {:error, "Missing essential data at line #{line_num}"}
      else
        # Find item by item_code (barcode)
        item = find_item_by_code(item_code)
        member = find_member_by_id(member_id)

        if is_nil(item) do
          {:error, "Item not found for code: #{item_code} at line #{line_num}"}
        else
          if is_nil(member) do
            {:error, "Member not found for ID: #{member_id} at line #{line_num}"}
          else
            # Try to find related transaction
            transaction = find_related_transaction(loan_id, item.id, member.id, node_id)

            # Determine event type based on loan actions
            event_type = determine_event_type(is_lent, is_return, return_date)
            event_date = determine_event_date(loan_date, return_date, event_type)

            attrs = %{
              id: generate_history_id(loan_id, event_type, node_id),
              event_type: event_type,
              event_date: event_date,
              description: build_description(event_type, title, item_code, member_name),
              old_value: build_old_value(loan_date, due_date),
              new_value:
                build_new_value(event_type, return_date, renewed, biblio_id, title, call_number),
              # Not available in legacy data
              ip_address: nil,
              user_agent: "SLiMS Legacy Import",
              member_id: member.id,
              item_id: item.id,
              transaction_id: transaction && transaction.id,
              # Not applicable for loan history
              reservation_id: nil,
              # Will be linked later if fines exist
              fine_id: nil,
              processed_by_id: processed_by_id,
              inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
              updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
            }

            {:ok, attrs}
          end
        end
      end
    rescue
      e ->
        {:error, "Error parsing loan history row at line #{line_num}: #{inspect(e)}"}
    end
  end

  defp determine_event_type(is_lent, is_return, return_date) do
    cond do
      # If there's a return date or is_return is "1", it's a return event
      return_date not in ["", nil, "0000-00-00 00:00:00"] or is_return == "1" ->
        "return"

      # If is_lent is "1", it's a loan event
      is_lent == "1" ->
        "loan"

      # Default to loan
      true ->
        "loan"
    end
  end

  defp determine_event_date(loan_date, return_date, event_type) do
    case event_type do
      "return" ->
        case parse_datetime_with_default(return_date) do
          nil -> parse_datetime_with_default(loan_date)
          date -> date
        end

      _ ->
        parse_datetime_with_default(loan_date)
    end
  end

  defp build_description(event_type, title, item_code, member_name) do
    title_part = if title not in ["", nil], do: " \"#{String.slice(title, 0, 50)}\"", else: ""
    member_part = if member_name not in ["", nil], do: " by #{member_name}", else: ""

    case event_type do
      "loan" -> "Item #{item_code}#{title_part} loaned#{member_part}"
      "return" -> "Item #{item_code}#{title_part} returned#{member_part}"
      _ -> "Transaction for item #{item_code}#{title_part}#{member_part}"
    end
  end

  defp build_old_value(loan_date, due_date) do
    %{
      "loan_date" => loan_date,
      "due_date" => due_date,
      "status" => "pending"
    }
  end

  defp build_new_value(event_type, return_date, renewed, biblio_id, title, call_number) do
    base = %{
      "event_type" => event_type,
      "biblio_id" => biblio_id,
      "title" => title,
      "call_number" => call_number
    }

    case event_type do
      "return" ->
        Map.merge(base, %{
          "return_date" => return_date,
          "status" => "returned"
        })

      "loan" ->
        Map.merge(base, %{
          "renewed" => renewed,
          "status" => "active"
        })

      _ ->
        base
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

  defp find_related_transaction(loan_id, item_id, member_id, node_id) do
    # Try to find transaction by generated ID pattern
    transaction_id = generate_transaction_id(loan_id, node_id)

    from(t in Transaction,
      where:
        t.id == ^transaction_id or
          (t.item_id == ^item_id and t.member_id == ^member_id)
    )
    |> limit(1)
    |> Repo.one()
  end

  defp generate_transaction_id(loan_id, node_id) do
    # Use same pattern as LoanImporter
    seed = "loan-#{loan_id}-node-#{node_id || 0}"
    hash = :crypto.hash(:md5, seed) |> Base.encode16(case: :lower)

    # Format as UUID v4
    <<p1::binary-size(8), p2::binary-size(4), p3::binary-size(4), p4::binary-size(4),
      p5::binary-size(12)>> = hash

    "#{p1}-#{p2}-4#{String.slice(p3, 1, 3)}-a#{String.slice(p4, 1, 3)}-#{p5}"
  end

  defp extract_node_from_filename(filename) do
    extract_unit_id_from_filename(filename)
  end

  defp generate_history_id(loan_id, event_type, node_id) do
    # Create a deterministic UUID based on loan_id, event_type and node_id
    seed = "loan-history-#{loan_id}-#{event_type}-node-#{node_id || 0}"
    hash = :crypto.hash(:md5, seed) |> Base.encode16(case: :lower)

    # Format as UUID v4
    <<p1::binary-size(8), p2::binary-size(4), p3::binary-size(4), p4::binary-size(4),
      p5::binary-size(12)>> = hash

    "#{p1}-#{p2}-4#{String.slice(p3, 1, 3)}-b#{String.slice(p4, 1, 3)}-#{p5}"
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
