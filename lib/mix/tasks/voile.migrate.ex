defmodule Mix.Tasks.Voile.Migrate do
  @moduledoc """
  Migration task for importing data from SLiMS to Voile.

  This task imports various data types from either CSV files or directly from a MySQL/MariaDB SLiMS database.

  CSV Mode (default):
  - scripts/csv_data/biblio/ - Contains biblio_master.csv, biblio_1.csv, biblio_2.csv, etc.
  - scripts/csv_data/items/ - Contains item_master.csv, item_1.csv, item_2.csv, etc.
  - scripts/csv_data/member/ - Contains member_master.csv, member_1.csv, member_2.csv, etc.
  - scripts/csv_data/mst/ - Contains mst_author_master.csv, mst_publisher_master.csv, etc.
  - scripts/csv_data/user/ - Contains user_master.csv, user.csv, etc.
  - scripts/csv_data/loan/ - Contains loan_master.csv, loan_1.csv, loan_2.csv, etc.
  - scripts/csv_data/loan_history/ - Contains loan_history_master.csv, loan_history_1.csv, etc.
  - scripts/csv_data/fines/ - Contains fines_master.csv, fines_1.csv, fines_2.csv, etc.

  File Processing Priority: _master files → _1, _2, _3... → regular files

  MySQL/MariaDB Mode:
  Reads data directly from SLiMS MySQL or MariaDB database. Configure in config/dev.exs:
    config :voile, :mysql_source,
      hostname: "localhost",
      port: 3306,                        # Standard port for both MySQL and MariaDB
      username: "slims_user",
      password: "slims_password",
      database: "slims_database"

  Default Import: masters, biblio, items, members, and users
  Optional Import (use flags): loans, loan_history, fines

  Usage:
    mix voile.migrate                    # Import default: masters, biblio, items, members, users
    mix voile.migrate --source mysql     # Import defaults from MySQL/MariaDB
    mix voile.migrate --only masters     # Import only master data from CSV
    mix voile.migrate --only biblio      # Import only bibliography data from CSV
    mix voile.migrate --only items --source mysql  # Import only items from MySQL/MariaDB
    mix voile.migrate --only members    # Import only member data from CSV
    mix voile.migrate --only users       # Import only user data from CSV
    mix voile.migrate --with-loans       # Import defaults + loans
    mix voile.migrate --with-loan-history # Import defaults + loan history
    mix voile.migrate --with-fines       # Import defaults + fines
    mix voile.migrate --with-all         # Import everything including loans, loan_history, fines
    mix voile.migrate --validate         # Validate migration results
    mix voile.migrate --help             # Show this help

  Options:
    --source TYPE       Data source: 'csv' (default) or 'mysql' (works with both MySQL and MariaDB)
    --only TYPE         Import only the specified data type
    --with-loans        Include loans in default import
    --with-loan-history Include loan history in default import
    --with-fines        Include fines in default import
    --with-all          Import everything (defaults + loans + loan_history + fines)
    --validate          Run validation checks after migration
    --skip-images       Skip image downloads (for biblio import)
    --batch-size N      Set batch size for bulk inserts (default: 500)
    --help              Show this help message
  """

  use Mix.Task

  alias Voile.Migration.{
    BiblioImporter,
    ItemImporter,
    MasterImporter,
    MemberImporter,
    UserImporter,
    LoanImporter,
    LoanHistoryImporter,
    FineImporter,
    Validator,
    DataSource
  }

  alias Voile.Repo
  alias Voile.Schema.Catalog.Attachment
  import Ecto.Query, only: [from: 2]

  @shortdoc "Import data from SLiMS CSV files or MySQL/MariaDB database to Voile"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _args, _invalid} =
      OptionParser.parse(args,
        switches: [
          source: :string,
          storage: :string,
          migrate_thumbnails: :boolean,
          dry_run: :boolean,
          delete_old: :boolean,
          only: :string,
          validate: :boolean,
          skip_images: :boolean,
          batch_size: :integer,
          with_loans: :boolean,
          with_loan_history: :boolean,
          with_fines: :boolean,
          with_all: :boolean,
          help: :boolean
        ],
        aliases: [h: :help, s: :source, m: :migrate_thumbnails, S: :storage]
      )

    if opts[:help] do
      show_help()
    else
      run_migration(opts)
    end
  end

  defp show_help do
    IO.puts(@moduledoc)
  end

  defp run_migration(opts) do
    batch_size = opts[:batch_size] || 500
    skip_images = opts[:skip_images] || false
    source_type = parse_source_type(opts[:source])

    # Store optional import flags in process dictionary
    Process.put(:with_loans, opts[:with_loans] || opts[:with_all] || false)
    Process.put(:with_loan_history, opts[:with_loan_history] || opts[:with_all] || false)
    Process.put(:with_fines, opts[:with_fines] || opts[:with_all] || false)

    IO.puts("=" |> String.duplicate(60))
    IO.puts("VOILE DATA MIGRATION")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Data source: #{String.upcase(to_string(source_type))}")
    IO.puts("Storage adapter override: #{opts[:storage] || "(none)"}")
    IO.puts("Batch size: #{batch_size}")
    IO.puts("Skip images: #{skip_images}")
    IO.puts("=" |> String.duplicate(60))

    # Initialize data source
    case DataSource.init_source(source_type) do
      {:ok, source} ->
        try do
          case opts[:only] do
            nil ->
              run_full_migration(source, source_type, batch_size, skip_images)

            "validate" ->
              Validator.run_all_checks()

            data_type ->
              run_partial_migration(source, source_type, data_type, batch_size, skip_images)
          end

          if opts[:validate] do
            IO.puts(("\n" <> "=") |> String.duplicate(60))
            IO.puts("RUNNING VALIDATION CHECKS")
            IO.puts("=" |> String.duplicate(60))
            Validator.run_all_checks()
          end

          IO.puts("\n✅ Migration completed!")

          # Apply storage override now (so migration of old thumbnails uses correct adapter)
          case opts[:storage] do
            "s3" -> System.put_env("VOILE_STORAGE_ADAPTER", "s3")
            "local" -> System.put_env("VOILE_STORAGE_ADAPTER", "local")
            _ -> :noop
          end

          if opts[:migrate_thumbnails] do
            migrate_thumbnails(opts)
          end
        after
          DataSource.close_source(source)
        end

      {:error, reason} ->
        IO.puts("❌ Failed to initialize data source: #{reason}")
        System.halt(1)
    end
  end

  defp run_full_migration(source, source_type, batch_size, skip_images) do
    IO.puts("🚀 Starting data migration from #{String.upcase(to_string(source_type))}...")

    # Set source context for importers
    Process.put(:migration_source, source)
    Process.put(:migration_source_type, source_type)

    # Get optional import flags
    with_loans = Process.get(:with_loans, false)
    with_loan_history = Process.get(:with_loan_history, false)
    with_fines = Process.get(:with_fines, false)

    # Default imports (always run)
    default_steps = [
      {"Master Data (Authors & Publishers)", fn -> MasterImporter.import_all(batch_size) end},
      {"Bibliography Data", fn -> BiblioImporter.import_all(batch_size, skip_images) end},
      {"Item Data", fn -> ItemImporter.import_all(batch_size) end},
      {"Member Data", fn -> MemberImporter.import_all(batch_size) end},
      {"User Data", fn -> UserImporter.import_all(batch_size) end}
    ]

    # Optional imports (only if flags are set)
    optional_steps =
      []
      |> maybe_add_step(with_loans, {"Loan Data", fn -> LoanImporter.import_all(batch_size) end})
      |> maybe_add_step(
        with_loan_history,
        {"Loan History Data",
         fn ->
           LoanHistoryImporter.import_all(batch_size)
         end}
      )
      |> maybe_add_step(with_fines, {"Fines Data", fn -> FineImporter.import_all(batch_size) end})

    all_steps = default_steps ++ optional_steps

    IO.puts("\n📋 Import plan:")
    IO.puts("  Default: masters, biblio, items, members, users")

    if length(optional_steps) > 0 do
      optional_names = Enum.map(optional_steps, fn {name, _} -> name end) |> Enum.join(", ")
      IO.puts("  Optional: #{optional_names}")
    else
      IO.puts("  Optional: none (use --with-loans, --with-loan-history, --with-fines)")
    end

    IO.puts("")

    Enum.each(all_steps, fn {name, import_func} ->
      IO.puts("\n📦 Importing #{name}...")
      start_time = System.monotonic_time(:millisecond)

      import_func.()

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      IO.puts("✅ #{name} imported in #{duration}ms")
    end)
  end

  defp maybe_add_step(steps, true, step), do: steps ++ [step]
  defp maybe_add_step(steps, false, _step), do: steps

  defp run_partial_migration(source, source_type, data_type, batch_size, skip_images) do
    # Set source context for importers
    Process.put(:migration_source, source)
    Process.put(:migration_source_type, source_type)

    case data_type do
      "biblio" ->
        IO.puts("📚 Importing bibliography data from #{String.upcase(to_string(source_type))}...")
        BiblioImporter.import_all(batch_size, skip_images)

      "items" ->
        IO.puts("📦 Importing item data from #{String.upcase(to_string(source_type))}...")
        ItemImporter.import_all(batch_size)

      "members" ->
        IO.puts("👥 Importing member data from #{String.upcase(to_string(source_type))}...")
        MemberImporter.import_all(batch_size)

      "users" ->
        IO.puts("👤 Importing user data from #{String.upcase(to_string(source_type))}...")
        UserImporter.import_all(batch_size)

      "masters" ->
        IO.puts("📋 Importing master data from #{String.upcase(to_string(source_type))}...")
        MasterImporter.import_all(batch_size)

      "fines" ->
        IO.puts("� Importing fines data from #{String.upcase(to_string(source_type))}...")
        FineImporter.import_all(batch_size)

      "loans" ->
        IO.puts("� Importing loan data from #{String.upcase(to_string(source_type))}...")
        LoanImporter.import_all(batch_size)

      "loan_history" ->
        IO.puts("� Importing loan history data from #{String.upcase(to_string(source_type))}...")
        LoanHistoryImporter.import_all(batch_size)

      invalid_type ->
        IO.puts("❌ Invalid data type: #{invalid_type}")
        IO.puts("Valid types: biblio, items, members, users, masters, loans, loan_history, fines")

        show_help()
    end
  end

  defp parse_source_type(nil), do: :csv
  defp parse_source_type("csv"), do: :csv
  defp parse_source_type("mysql"), do: :mysql

  defp parse_source_type(invalid) do
    IO.puts("⚠️ Invalid source type: #{invalid}. Using CSV as default.")
    :csv
  end

  # Migrate local thumbnails (files served from /uploads) to the configured storage (S3)
  defp migrate_thumbnails(opts) do
    batch_size = opts[:batch_size] || 500
    dry_run = opts[:dry_run] || false
    delete_old = opts[:delete_old] || false

    IO.puts("\n🔁 Starting thumbnail migration (local -> storage)")
    IO.puts("  batch_size: #{batch_size}, dry_run: #{dry_run}, delete_old: #{delete_old}")

    # Honor storage override if provided
    case opts[:storage] do
      "s3" -> System.put_env("VOILE_STORAGE_ADAPTER", "s3")
      "local" -> System.put_env("VOILE_STORAGE_ADAPTER", "local")
      _ -> :noop
    end

    query_base =
      from(a in Attachment,
        where: like(a.file_path, ^"/uploads/%"),
        order_by: [asc: a.inserted_at]
      )

    total =
      Repo.aggregate(from(a in Attachment, where: like(a.file_path, ^"/uploads/%")), :count, :id)

    IO.puts("  Found #{total} local attachments to consider for migration")

    migrate_loop(0, batch_size, total, dry_run, delete_old, query_base)
  end

  defp migrate_loop(offset, _batch_size, total, _dry_run, _delete_old, _query)
       when offset >= total do
    IO.puts("🎉 Thumbnail migration finished")
  end

  defp migrate_loop(offset, batch_size, total, dry_run, delete_old, query_base) do
    attachments =
      Repo.all(from(a in query_base, limit: ^batch_size, offset: ^offset))

    if attachments == [] do
      IO.puts("No more attachments to process")
    else
      Enum.each(attachments, fn attachment ->
        try do
          process_attachment_for_migration(attachment, dry_run, delete_old)
        rescue
          e -> IO.puts("Error processing attachment #{attachment.id}: #{inspect(e)}")
        end
      end)

      # next page
      migrate_loop(offset + batch_size, batch_size, total, dry_run, delete_old, query_base)
    end
  end

  defp process_attachment_for_migration(%Attachment{} = attachment, dry_run, delete_old) do
    file_path = attachment.file_path || ""

    local_path =
      cond do
        String.starts_with?(file_path, "/") ->
          Path.join(["priv/static", String.trim_leading(file_path, "/")])

        true ->
          Path.join(["priv/static", file_path])
      end

    if not File.exists?(local_path) do
      IO.puts("Skipping #{attachment.id} - local file not found: #{local_path}")
      :skip
    else
      stat = File.stat!(local_path)
      size = stat.size
      mime = attachment.mime_type || MIME.from_path(local_path)

      upload_map = %{
        path: local_path,
        filename: attachment.original_name || attachment.file_name || Path.basename(local_path),
        content_type: mime
      }

      IO.puts("Uploading attachment #{attachment.id} (#{local_path}) -> storage...")

      if dry_run do
        IO.puts(
          "[dry-run] would upload and update record #{attachment.id} -> keep local file: #{not delete_old}"
        )

        :dry_run
      else
        case Client.Storage.upload(upload_map, folder: "thumbnails", adapter: Client.Storage.S3) do
          {:ok, url} ->
            IO.puts("Uploaded: #{url}")

            changes = %{
              file_path: url,
              file_name: Path.basename(url),
              file_size: size,
              mime_type: mime
            }

            case Attachment.changeset(attachment, changes) |> Repo.update() do
              {:ok, _updated} ->
                IO.puts("Updated DB for attachment #{attachment.id}")

                if delete_old do
                  case File.rm(local_path) do
                    :ok ->
                      IO.puts("Deleted old local file: #{local_path}")

                    {:error, reason} ->
                      IO.puts("Failed to delete #{local_path}: #{inspect(reason)}")
                  end
                end

                :ok

              {:error, cs} ->
                IO.puts("Failed to update DB for #{attachment.id}: #{inspect(cs.errors)}")
                {:error, :db_update}
            end

          {:error, reason} ->
            IO.puts("Failed to upload #{local_path}: #{inspect(reason)}")
            {:error, :upload}
        end
      end
    end
  end
end
