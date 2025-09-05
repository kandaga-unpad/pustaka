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
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Master.Creator

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

    case File.stream!(file_path, [:trim_bom]) do
      stream ->
        final_stats =
          stream
          |> CSVParser.parse_stream(skip_headers: false)
          |> Stream.drop(1)
          |> Stream.with_index(1)
          |> Stream.chunk_every(batch_size)
          |> Enum.reduce(stats, fn chunk, acc_stats ->
            process_loan_batch(chunk, node_id, acc_stats)
          end)

        final_stats
    end
  rescue
    e ->
      IO.puts("❌ Error processing loan file: #{inspect(e)}")
      %{inserted: 0, skipped: 0, errors: 1}
  end

  defp process_loan_batch(chunk, node_id, stats) do
    # Parse rows and collect valid loan attributes
    loan_attrs =
      chunk
      |> Enum.reduce([], fn {row, line_num}, acc_attrs ->
        case parse_loan_row(row, line_num, node_id) do
          {:ok, attrs} ->
            [attrs | acc_attrs]

          {:error, msg} ->
            IO.puts("❌ #{msg}")
            acc_attrs
        end
      end)

    # Count parsing errors
    error_count = length(chunk) - length(loan_attrs)

    case loan_attrs do
      [] ->
        %{stats | errors: stats.errors + error_count}

      valid_loans ->
        try do
          # Insert valid loans
          {inserted_count, _} =
            Repo.insert_all(Transaction, valid_loans,
              on_conflict: :nothing,
              returning: false
            )

          skipped_count = length(valid_loans) - inserted_count

          %{
            inserted: stats.inserted + inserted_count,
            skipped: stats.skipped + skipped_count,
            errors: stats.errors + error_count
          }
        rescue
          e ->
            IO.puts("❌ Error inserting loan batch: #{inspect(e)}")

            %{
              stats
              | errors: stats.errors + length(valid_loans) + error_count
            }
        end
    end
  end

  defp parse_loan_row(row, line_num, node_id) do
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
        # Find item by item_code (barcode) - use fallback if not found
        item = find_item_by_code(item_code) || get_or_create_default_item()
        # Find member by ID - use fallback admin user if not found
        member = find_member_by_id(member_id) || get_default_admin_user()

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
          notes: build_notes(loan_id, loan_rules_id, actual, node_id, item_code, member_id),
          status: status,
          fine_amount: Decimal.new("0.0"),
          is_overdue: is_overdue?(due_date, return_date),
          item_id: item.id,
          member_id: member.id,
          # Using the same member as librarian for historical data
          librarian_id: member.id,
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }

        {:ok, attrs}
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

      # Default case - ensure we always return valid values
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

  defp build_notes(loan_id, loan_rules_id, actual, node_id, item_code, member_id) do
    parts = []
    parts = if loan_id not in ["", nil], do: parts ++ ["Legacy Loan ID: #{loan_id}"], else: parts

    parts =
      if loan_rules_id not in ["", nil],
        do: parts ++ ["Loan Rules ID: #{loan_rules_id}"],
        else: parts

    parts = if actual not in ["", nil], do: parts ++ ["Actual: #{actual}"], else: parts
    parts = if node_id, do: parts ++ ["Source Node: #{node_id}"], else: parts
    parts = if item_code not in ["", nil], do: parts ++ ["Item Code: #{item_code}"], else: parts
    parts = if member_id not in ["", nil], do: parts ++ ["Member ID: #{member_id}"], else: parts

    case parts do
      [] -> nil
      _ -> Enum.join(parts, "; ")
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

  defp get_default_admin_user do
    # Return the default admin user ID provided
    %{id: "8a35f4b2-833d-4979-a285-0f0fdd52a42d"}
  end

  defp get_or_create_default_creator do
    # Try to find existing default creator first
    case Repo.get_by(Creator, creator_name: "System Import") do
      nil ->
        # Create default creator
        {:ok, creator} =
          %Creator{}
          |> Creator.changeset(%{
            creator_name: "System Import",
            creator_contact: "system@voile.app",
            affiliation: "Voile Library System",
            type: "Organization"
          })
          |> Repo.insert()

        creator

      creator ->
        creator
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
        # Get or create default creator first
        creator = get_or_create_default_creator()

        # Create default collection
        {:ok, collection} =
          %Collection{}
          |> Collection.changeset(%{
            title: "Missing Items Collection",
            description: "Default collection for items that could not be found during import",
            status: "published",
            access_level: "public",
            thumbnail: "/images/logo.svg",
            creator_id: creator.id
          })
          |> Repo.insert()

        collection

      collection ->
        collection
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

  defp parse_return_date(nil), do: nil
  defp parse_return_date(""), do: nil
  defp parse_return_date("0000-00-00 00:00:00"), do: nil
  defp parse_return_date(date), do: parse_datetime_with_default(date)

  defp parse_datetime_with_default(nil), do: nil
  defp parse_datetime_with_default(""), do: nil
  defp parse_datetime_with_default("0000-00-00 00:00:00"), do: nil

  defp parse_datetime_with_default(date_str) do
    case parse_datetime(date_str) do
      nil -> nil
      datetime -> datetime
    end
  end
end
