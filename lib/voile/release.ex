defmodule Voile.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :voile

  def create_database do
    load_app()

    for repo <- repos() do
      cfg = db_config(repo)

      if Keyword.has_key?(cfg, :database) do
        # Try to create the DB with retries/backoff to tolerate DB startup races
        attempts = 6
        backoff_ms = 2000

        result =
          Enum.reduce_while(1..attempts, {:error, :not_tried}, fn attempt, _acc ->
            case safe_storage_up(repo, cfg) do
              :ok ->
                {:halt, :ok}

              {:error, :already_up} ->
                {:halt, {:ok, :already_up}}

              {:error, {:conn, reason}} ->
                IO.puts(
                  "DB not ready (attempt #{attempt}/#{attempts}): #{inspect(reason)} — retrying in #{backoff_ms}ms"
                )

                :timer.sleep(backoff_ms)
                {:cont, {:retry, reason}}

              {:error, term} ->
                {:halt, {:error, term}}
            end
          end)

        case result do
          :ok -> IO.puts("Database created for #{inspect(repo)}")
          {:ok, :already_up} -> IO.puts("Database already exists for #{inspect(repo)}")
          {:error, term} when is_binary(term) -> IO.puts("Error creating database: #{term}")
          {:error, term} -> IO.puts("Error creating database: #{inspect(term)}")
        end
      else
        IO.puts(
          "Skipping create_database for #{inspect(repo)}: no database info found in repo config or DATABASE_URL environment variable."
        )

        IO.puts(
          "Set DATABASE_URL or ensure repo config includes :database or :url so the release can create the database."
        )
      end
    end
  end

  # Build a DB config map suitable for storage_up/1. When the app uses a
  # DATABASE_URL (or :url in repo config) the Repo.config() may not include
  # a :database key, which Postgres.storage_up/1 expects. Parse the URL and
  # merge the values so storage_up works in releases.
  defp db_config(repo) do
    cfg = repo.config() || []

    cond do
      Keyword.has_key?(cfg, :database) ->
        cfg

      url =
          Keyword.get(cfg, :url) || System.get_env("DATABASE_URL") ||
            System.get_env("VOILE_DATABASE_URL") ->
        parsed = parse_database_url(url)
        # merge parsed values but keep existing keys in cfg
        Keyword.merge(parsed, cfg)

      true ->
        # If repo is using a :prefix (schema), that's not a database name and
        # storage_up can't create a DB from it. Inform the operator so they can
        # set DATABASE_URL/VOILE_DATABASE_URL or :url in runtime config.
        if Keyword.has_key?(cfg, :prefix) do
          IO.puts(
            "Note: repo config contains :prefix (schema). This does not provide a database name for storage_up. Ensure DATABASE_URL or VOILE_DATABASE_URL is set with the target database name."
          )
        end

        cfg
    end
  end

  defp parse_database_url(nil), do: []

  defp parse_database_url(url) when is_binary(url) do
    uri = URI.parse(url)

    db = uri.path && String.trim_leading(uri.path, "/")

    # URI.userinfo contains "user:pass" or just "user". Split it safely.
    {user, pass} =
      case uri.userinfo do
        nil ->
          {nil, nil}

        ui ->
          case String.split(ui, ":", parts: 2) do
            [u, p] -> {u, p}
            [u] -> {u, nil}
          end
      end

    []
    |> maybe_put(:database, db)
    |> maybe_put(:username, user)
    |> maybe_put(:password, pass)
    |> maybe_put(:hostname, uri.host)
    |> maybe_put(:port, uri.port)
  end

  defp maybe_put(acc, _key, nil), do: acc
  defp maybe_put(acc, key, value), do: Keyword.put(acc, key, value)

  def migrate do
    load_app()

    for repo <- repos() do
      # Retry migrations in case DB is not yet accepting connections
      attempts = 6
      backoff_ms = 2000

      # Retry migrations in case DB is not yet accepting connections. Use
      # reduce_while so we can stop early without using throw/raise which
      # bubbles out unexpectedly when uncaught.
      result =
        Enum.reduce_while(1..attempts, :retry, fn attempt, _acc ->
          case try_migrate(repo) do
            :ok ->
              {:halt, :ok}

            {:error, {:conn, reason}} ->
              IO.puts(
                "Migrations: DB not ready (attempt #{attempt}/#{attempts}): #{inspect(reason)} — retrying in #{backoff_ms}ms"
              )

              :timer.sleep(backoff_ms)
              {:cont, :retry}

            {:error, term} ->
              IO.puts("Migrations failed: #{inspect(term)}")
              {:halt, {:error, term}}
          end
        end)

      # If we didn't succeed in the retry loop, do a final attempt and log
      # any failure (mirrors previous behavior but without throws).
      case result do
        :ok ->
          :ok

        _ ->
          case try_migrate(repo) do
            :ok -> :ok
            {:error, term} -> IO.puts("Final migration attempt failed: #{inspect(term)}")
          end
      end
    end
  end

  defp try_migrate(repo) do
    try do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
      :ok
    rescue
      e in DBConnection.ConnectionError -> {:error, {:conn, e}}
      e in RuntimeError -> {:error, e}
      e -> {:error, e}
    end
  end

  defp safe_storage_up(repo, cfg) do
    try do
      case repo.__adapter__().storage_up(cfg) do
        :ok -> :ok
        {:error, :already_up} -> {:error, :already_up}
        {:error, term} -> {:error, term}
      end
    rescue
      e in DBConnection.ConnectionError -> {:error, {:conn, e}}
      e -> {:error, e}
    end
  end

  def seed do
    load_app()

    # Check if the application is already running
    app_already_started =
      Application.started_applications()
      |> Enum.any?(fn {app, _, _} -> app == @app end)

    # Only start applications if they're not already running
    unless app_already_started do
      {:ok, _} = Application.ensure_all_started(:finch)
      {:ok, _} = Application.ensure_all_started(:req)
    end

    # Load S3 configuration from environment variables if not already loaded
    load_s3_config()

    seed_files = [
      "seeds/seeds.exs",
      "seeds/metadata_resource_class.exs",
      "seeds/authorization_seeds_runner.exs",
      "seeds/metadata_properties.exs",
      "seeds/master.exs",
      "seeds/glams.exs"
    ]

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          # Run all seed files in order
          Enum.each(seed_files, fn seed_file ->
            seed_path = Path.join(["#{:code.priv_dir(:voile)}", "repo", seed_file])

            if File.exists?(seed_path) do
              IO.puts("Running seed: #{seed_file}")
              Code.eval_file(seed_path)
            else
              IO.puts("Seed file not found: #{seed_path}")
            end
          end)
        end)
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def import_data(opts \\ []) do
    load_app()

    # Check if the application is already running
    app_already_started =
      Application.started_applications()
      |> Enum.any?(fn {app, _, _} -> app == @app end)

    # Only start applications if they're not already running
    unless app_already_started do
      {:ok, _} = Application.ensure_all_started(@app)
      {:ok, _} = Application.ensure_all_started(:finch)
      {:ok, _} = Application.ensure_all_started(:req)
    end

    # Load S3 configuration from environment variables if not already loaded
    load_s3_config()

    alias Voile.Migration.{
      BiblioImporter,
      ItemImporter,
      MasterImporter,
      MemberImporter,
      UserImporter,
      LoanImporter,
      LoanHistoryImporter,
      FineImporter,
      DataSource
    }

    batch_size = Keyword.get(opts, :batch_size, 500)
    skip_images = Keyword.get(opts, :skip_images, false)
    source_type = Keyword.get(opts, :source, :csv)
    with_loans = Keyword.get(opts, :with_loans, false)
    with_loan_history = Keyword.get(opts, :with_loan_history, false)
    with_fines = Keyword.get(opts, :with_fines, false)
    with_all = Keyword.get(opts, :with_all, false)

    IO.puts("=" |> String.duplicate(60))
    IO.puts("VOILE DATA MIGRATION (Release Mode)")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Data source: #{String.upcase(to_string(source_type))}")
    IO.puts("Batch size: #{batch_size}")
    IO.puts("Skip images: #{skip_images}")
    IO.puts("=" |> String.duplicate(60))

    case DataSource.init_source(source_type) do
      {:ok, source} ->
        try do
          Process.put(:migration_source, source)
          Process.put(:migration_source_type, source_type)
          Process.put(:with_loans, with_loans || with_all)
          Process.put(:with_loan_history, with_loan_history || with_all)
          Process.put(:with_fines, with_fines || with_all)

          IO.puts("\n🚀 Starting data migration from #{String.upcase(to_string(source_type))}...")

          # Default imports
          default_steps = [
            {"Master Data (Authors & Publishers)",
             fn -> MasterImporter.import_all(batch_size) end},
            {"Bibliography Data", fn -> BiblioImporter.import_all(batch_size, skip_images) end},
            {"Item Data", fn -> ItemImporter.import_all(batch_size) end},
            {"Member Data", fn -> MemberImporter.import_all(batch_size) end},
            {"User Data", fn -> UserImporter.import_all(batch_size) end}
          ]

          # Optional imports
          optional_steps =
            []
            |> maybe_add_step(
              with_loans || with_all,
              {"Loan Data", fn -> LoanImporter.import_all(batch_size) end}
            )
            |> maybe_add_step(
              with_loan_history || with_all,
              {"Loan History Data", fn -> LoanHistoryImporter.import_all(batch_size) end}
            )
            |> maybe_add_step(
              with_fines || with_all,
              {"Fines Data", fn -> FineImporter.import_all(batch_size) end}
            )

          all_steps = default_steps ++ optional_steps

          IO.puts("\n📋 Import plan:")
          IO.puts("  Default: masters, biblio, items, members, users")

          if length(optional_steps) > 0 do
            optional_names = Enum.map(optional_steps, fn {name, _} -> name end) |> Enum.join(", ")
            IO.puts("  Optional: #{optional_names}")
          else
            IO.puts("  Optional: none")
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

          IO.puts("\n✅ Data migration completed!")
        after
          DataSource.close_source(source)
        end

      {:error, reason} ->
        IO.puts("❌ Failed to initialize data source: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Run all bootstrap tasks in order: create database, migrate, seed, import_data.
  This runs in-process and ensures strict sequential execution.
  """
  def bootstrap(opts \\ []) do
    # Ensure runtime apps are started for imports
    {:ok, _} = Application.ensure_all_started(@app)
    {:ok, _} = Application.ensure_all_started(:finch)
    {:ok, _} = Application.ensure_all_started(:req)

    create_database()
    migrate()
    seed()
    import_data(opts)

    :ok
  end

  defp maybe_add_step(steps, true, step), do: steps ++ [step]
  defp maybe_add_step(steps, false, _step), do: steps

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end

  # Load S3 configuration from environment variables into application config
  # This is needed for the import process to work with S3 storage
  defp load_s3_config do
    if System.get_env("VOILE_S3_ACCESS_KEY_ID") do
      Application.put_env(:voile, :storage_adapter, Client.Storage.S3)
      Application.put_env(:voile, :s3_access_key_id, System.get_env("VOILE_S3_ACCESS_KEY_ID"))

      Application.put_env(
        :voile,
        :s3_secret_key_access,
        System.get_env("VOILE_S3_SECRET_ACCESS_KEY")
      )

      Application.put_env(
        :voile,
        :s3_bucket_name,
        System.get_env("VOILE_S3_BUCKET_NAME") || "glam-storage"
      )

      Application.put_env(:voile, :s3_region, System.get_env("VOILE_S3_REGION") || "us-east-1")

      Application.put_env(
        :voile,
        :s3_public_url,
        System.get_env("VOILE_S3_PUBLIC_URL") || "https://library.unpad.ac.id"
      )

      Application.put_env(
        :voile,
        :s3_public_url_format,
        System.get_env("VOILE_S3_PUBLIC_URL_FORMAT") || "{endpoint}/{bucket}/{key}"
      )

      IO.puts("✅ S3 configuration loaded for import process")
    else
      Application.put_env(:voile, :storage_adapter, Client.Storage.Local)
      IO.puts("ℹ️ No S3 credentials found, using local storage for import")
    end
  end
end
