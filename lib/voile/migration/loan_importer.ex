defmodule Voile.Migration.LoanImporter do
  @moduledoc """
  Imports loan data from CSV files to lib_transactions table.

  Expected CSV structure:
  - scripts/csv_data/loan/loan_*.csv

  CSV Headers:
  loan_id,item_code,member_id,loan_date,due_date,renewed,loan_rules_id,actual,is_lent,is_return,return_date
  """

  import Ecto.Query
  import Voile.Migration.Common

  alias Voile.Repo
  alias Voile.Schema.Library.Transaction
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Accounts.User

  def import_all(batch_size \\ 500) do
    IO.puts("📚 Starting loan data import...")

    # Get loan files
    files = get_csv_files("loan")

    if Enum.empty?(files) do
      IO.puts("⚠️ No loan files found")
      %{inserted: 0, skipped: 0, errors: 0}
    else
      stats =
        files
        |> Enum.with_index(1)
        |> Enum.reduce(%{inserted: 0, skipped: 0, errors: 0}, fn {file, index}, acc ->
          IO.puts("\n🔄 Processing loan file #{index}/#{length(files)}: #{Path.basename(file)}")

          # Extract node info from filename for loan_N.csv files
          node_id = extract_node_from_filename(file)

          file_stats = process_loan_file(file, batch_size, node_id)

          %{
            inserted: acc.inserted + file_stats.inserted,
            skipped: acc.skipped + file_stats.skipped,
            errors: acc.errors + file_stats.errors
          }
        end)

      print_summary("LOAN IMPORT", %{
        "Total Loans Inserted" => stats.inserted,
        "Total Loans Skipped" => stats.skipped,
        "Total Errors" => stats.errors
      })

      stats
    end
  end

  defp process_loan_file(file_path, batch_size, node_id) do
    stats = %{inserted: 0, skipped: 0, errors: 0}

    # Get default system user for librarian (created during user import)
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
            process_loan_batch(chunk, system_user.id, node_id, acc_stats, acc_seen)
          end)

        final_stats
    end
  rescue
    e ->
      IO.puts("❌ Error processing loan file: #{inspect(e)}")
      %{inserted: 0, skipped: 0, errors: 1}
  end

  defp process_loan_batch(chunk, librarian_id, node_id, stats, seen_member_ids) do
    # First, filter and parse rows, checking for duplicate member_ids
    {loan_attrs, updated_seen, duplicate_count} =
      chunk
      |> Enum.reduce({[], seen_member_ids, 0}, fn {row, line_num},
                                                  {acc_attrs, acc_seen, dup_count} ->
        case parse_loan_row(row, line_num, librarian_id, node_id) do
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
    error_count = length(chunk) - length(loan_attrs) - duplicate_count

    case loan_attrs do
      [] ->
        {%{stats | errors: stats.errors + error_count, skipped: stats.skipped + duplicate_count},
         updated_seen}

      valid_loans ->
        try do
          # Insert valid loans
          {inserted_count, _} =
            Repo.insert_all(Transaction, valid_loans,
              on_conflict: :nothing,
              returning: false
            )

          skipped_count = length(valid_loans) - inserted_count

          {%{
             inserted: stats.inserted + inserted_count,
             skipped: stats.skipped + skipped_count + duplicate_count,
             errors: stats.errors + error_count
           }, updated_seen}
        rescue
          e ->
            IO.puts("❌ Error inserting loan batch: #{inspect(e)}")

            {%{
               stats
               | errors: stats.errors + length(valid_loans) + error_count + duplicate_count
             }, updated_seen}
        end
    end
  end

  defp parse_loan_row(row, line_num, librarian_id, node_id) do
    try do
      [
        loan_id,
        item_code,
        member_id,
        loan_date,
        due_date,
        renewed,
        loan_rules_id,
        actual,
        is_lent,
        is_return,
        return_date
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
            # Determine transaction type and status
            {transaction_type, status} =
              determine_transaction_type_and_status(is_lent, is_return, return_date)

            attrs = %{
              id: generate_transaction_id(loan_id, node_id),
              transaction_type: transaction_type,
              transaction_date: parse_datetime_with_default(loan_date),
              due_date: parse_datetime_with_default(due_date),
              return_date: parse_return_date(return_date),
              renewal_count: parse_int(renewed) || 0,
              notes: build_notes(loan_id, loan_rules_id, actual, node_id),
              status: status,
              fine_amount: Decimal.new("0.0"),
              is_overdue: is_overdue?(due_date, return_date),
              item_id: item.id,
              member_id: member.id,
              librarian_id: librarian_id,
              inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
              updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
            }

            {:ok, attrs}
          end
        end
      end
    rescue
      e ->
        {:error, "Error parsing loan row at line #{line_num}: #{inspect(e)}"}
    end
  end

  defp determine_transaction_type_and_status(is_lent, is_return, return_date) do
    cond do
      # If there's a return date, it's a completed loan
      return_date not in ["", nil, "0000-00-00 00:00:00"] ->
        {"loan", "returned"}

      # If is_return is "1", it's returned
      is_return == "1" ->
        {"loan", "returned"}

      # If is_lent is "1" and no return, it's active
      is_lent == "1" ->
        {"loan", "active"}

      # Default case
      true ->
        {"loan", "active"}
    end
  end

  defp is_overdue?(due_date, return_date) do
    cond do
      # If already returned, not overdue
      return_date not in ["", nil, "0000-00-00 00:00:00"] ->
        false

      # If no due date, can't determine
      due_date in ["", nil, "0000-00-00 00:00:00"] ->
        false

      # Check if current date is past due date
      true ->
        case parse_datetime_with_default(due_date) do
          nil ->
            false

          parsed_due_date ->
            DateTime.compare(parsed_due_date, DateTime.utc_now()) == :lt
        end
    end
  end

  defp build_notes(loan_id, loan_rules_id, actual, node_id) do
    parts = []
    parts = if loan_id not in ["", nil], do: parts ++ ["Legacy Loan ID: #{loan_id}"], else: parts

    parts =
      if loan_rules_id not in ["", nil],
        do: parts ++ ["Loan Rules ID: #{loan_rules_id}"],
        else: parts

    parts = if actual not in ["", nil], do: parts ++ ["Actual: #{actual}"], else: parts
    parts = if node_id, do: parts ++ ["Source Node: #{node_id}"], else: parts

    case parts do
      [] -> nil
      _ -> Enum.join(parts, "; ")
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

  defp extract_node_from_filename(filename) do
    extract_unit_id_from_filename(filename)
  end

  defp generate_transaction_id(loan_id, node_id) do
    # Create a deterministic UUID based on loan_id and node_id
    seed = "loan-#{loan_id}-node-#{node_id || 0}"
    hash = :crypto.hash(:md5, seed) |> Base.encode16(case: :lower)

    # Format as UUID v4
    <<p1::binary-size(8), p2::binary-size(4), p3::binary-size(4), p4::binary-size(4),
      p5::binary-size(12)>> = hash

    "#{p1}-#{p2}-4#{String.slice(p3, 1, 3)}-a#{String.slice(p4, 1, 3)}-#{p5}"
  end

  defp parse_return_date(date) when date in ["", nil, "0000-00-00 00:00:00"], do: nil
  defp parse_return_date(date), do: parse_datetime_with_default(date)

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
