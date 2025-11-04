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

  Usage:
    mix voile.migrate                    # Import all data types from CSV
    mix voile.migrate --source mysql     # Import all data types from MySQL/MariaDB
    mix voile.migrate --only masters     # Import only master data from CSV
    mix voile.migrate --only biblio      # Import only bibliography data from CSV
    mix voile.migrate --only items --source mysql  # Import only items from MySQL/MariaDB
    mix voile.migrate --only members    # Import only member data from CSV
    mix voile.migrate --only loans       # Import only loan data from CSV
    mix voile.migrate --only loan_history # Import only loan history from CSV
    mix voile.migrate --only fines       # Import only fines data from CSV
    mix voile.migrate --validate         # Validate migration results
    mix voile.migrate --help             # Show this help

  Options:
    --source TYPE     Data source: 'csv' (default) or 'mysql' (works with both MySQL and MariaDB)
    --only TYPE       Import only the specified data type
    --validate        Run validation checks after migration
    --skip-images     Skip image downloads (for biblio import)
    --batch-size N    Set batch size for bulk inserts (default: 500)
    --help            Show this help message
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

  @shortdoc "Import data from SLiMS CSV files or MySQL/MariaDB database to Voile"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _args, _invalid} =
      OptionParser.parse(args,
        switches: [
          source: :string,
          only: :string,
          validate: :boolean,
          skip_images: :boolean,
          batch_size: :integer,
          help: :boolean
        ],
        aliases: [h: :help, s: :source]
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

    IO.puts("=" |> String.duplicate(60))
    IO.puts("VOILE DATA MIGRATION")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Data source: #{String.upcase(to_string(source_type))}")
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
        after
          DataSource.close_source(source)
        end

      {:error, reason} ->
        IO.puts("❌ Failed to initialize data source: #{reason}")
        System.halt(1)
    end
  end

  defp run_full_migration(source, source_type, batch_size, skip_images) do
    IO.puts("🚀 Starting full data migration from #{String.upcase(to_string(source_type))}...")

    # Set source context for importers
    Process.put(:migration_source, source)
    Process.put(:migration_source_type, source_type)

    # Import in dependency order
    steps = [
      {"Master Data (Authors & Publishers)", fn -> MasterImporter.import_all(batch_size) end},
      {"Bibliography Data", fn -> BiblioImporter.import_all(batch_size, skip_images) end},
      {"Item Data", fn -> ItemImporter.import_all(batch_size) end},
      {"User Data", fn -> UserImporter.import_all(batch_size) end},
      {"Member Data", fn -> MemberImporter.import_all(batch_size) end},
      {"Loan Data", fn -> LoanImporter.import_all(batch_size) end},
      {"Loan History Data", fn -> LoanHistoryImporter.import_all(batch_size) end},
      {"Fines Data", fn -> FineImporter.import_all(batch_size) end}
    ]

    Enum.each(steps, fn {name, import_func} ->
      IO.puts("\n📦 Importing #{name}...")
      start_time = System.monotonic_time(:millisecond)

      import_func.()

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      IO.puts("✅ #{name} imported in #{duration}ms")
    end)
  end

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

      "loans" ->
        IO.puts("📚 Importing loan data from #{String.upcase(to_string(source_type))}...")
        LoanImporter.import_all(batch_size)

      "loan_history" ->
        IO.puts("📜 Importing loan history data from #{String.upcase(to_string(source_type))}...")
        LoanHistoryImporter.import_all(batch_size)

      "fines" ->
        IO.puts("💰 Importing fines data from #{String.upcase(to_string(source_type))}...")
        FineImporter.import_all(batch_size)

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
end
