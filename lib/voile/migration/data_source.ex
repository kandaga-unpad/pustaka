defmodule Voile.Migration.DataSource do
  @moduledoc """
  Abstraction layer for data sources (CSV files or MySQL database).

  This module provides a unified interface for reading data from either
  CSV files in the scripts/csv_data directory or directly from a MySQL
  SLiMS database.
  """

  alias Voile.Migration.{MySQLAdapter, Common}
  require Logger

  @type source_type :: :csv | :mysql
  @type data_type ::
          :biblio | :items | :members | :users | :authors | :publishers | :biblio_authors

  @doc """
  Initialize data source connection.
  For CSV: validates directory structure
  For MySQL: establishes database connection
  """
  def init_source(source_type) do
    case source_type do
      :csv ->
        # Use absolute path for containerized environment
        csv_dir = Path.join(["/", "app", "scripts", "csv_data"])

        if File.dir?(csv_dir) do
          Logger.info("📁 Using CSV data source from #{csv_dir}")
          {:ok, :csv}
        else
          # Fallback to relative path for development
          csv_dir_relative = Path.join("scripts", "csv_data")

          if File.dir?(csv_dir_relative) do
            Logger.info("📁 Using CSV data source from #{csv_dir_relative} (development mode)")
            {:ok, :csv}
          else
            {:error, "CSV data directory not found: #{csv_dir} or #{csv_dir_relative}"}
          end
        end

      :mysql ->
        case MySQLAdapter.connect() do
          {:ok, conn} ->
            Logger.info("🗄️ Using MySQL data source")
            {:ok, conn}

          {:error, reason} ->
            {:error, "Failed to connect to MySQL: #{inspect(reason)}"}
        end

      _ ->
        {:error, "Unsupported source type: #{source_type}"}
    end
  end

  @doc """
  Fetch data of specified type from the configured source.
  Returns a stream of data rows.
  """
  def fetch_data(source, data_type, opts \\ [])

  # CSV Source implementations
  def fetch_data(:csv, :biblio, opts) do
    files = Common.get_csv_files("biblio")
    batch_size = Keyword.get(opts, :batch_size, 500)

    if Enum.empty?(files) do
      {:error, "No bibliography CSV files found"}
    else
      {:ok, stream_csv_files(files, batch_size)}
    end
  end

  def fetch_data(:csv, :items, opts) do
    files = Common.get_csv_files("items")
    batch_size = Keyword.get(opts, :batch_size, 500)

    if Enum.empty?(files) do
      {:error, "No item CSV files found"}
    else
      {:ok, stream_csv_files(files, batch_size)}
    end
  end

  def fetch_data(:csv, :members, opts) do
    files = Common.get_csv_files("member")
    batch_size = Keyword.get(opts, :batch_size, 500)

    if Enum.empty?(files) do
      {:error, "No member CSV files found"}
    else
      {:ok, stream_csv_files(files, batch_size)}
    end
  end

  def fetch_data(:csv, :users, opts) do
    files = Common.get_csv_files("user")
    batch_size = Keyword.get(opts, :batch_size, 500)

    if Enum.empty?(files) do
      {:error, "No user CSV files found"}
    else
      {:ok, stream_csv_files(files, batch_size)}
    end
  end

  def fetch_data(:csv, :authors, opts) do
    files = Common.get_specific_files("mst", "mst_author_*.csv")
    batch_size = Keyword.get(opts, :batch_size, 500)

    if Enum.empty?(files) do
      {:error, "No author CSV files found"}
    else
      {:ok, stream_csv_files(files, batch_size)}
    end
  end

  def fetch_data(:csv, :publishers, opts) do
    files = Common.get_specific_files("mst", "mst_publisher_*.csv")
    batch_size = Keyword.get(opts, :batch_size, 500)

    if Enum.empty?(files) do
      {:error, "No publisher CSV files found"}
    else
      {:ok, stream_csv_files(files, batch_size)}
    end
  end

  def fetch_data(:csv, :biblio_authors, opts) do
    files = Common.get_specific_files("mst", "biblio_author_*.csv")
    batch_size = Keyword.get(opts, :batch_size, 500)

    if Enum.empty?(files) do
      {:error, "No biblio-author CSV files found"}
    else
      {:ok, stream_csv_files(files, batch_size)}
    end
  end

  # MySQL Source implementations
  def fetch_data(mysql_conn, :biblio, opts) when is_pid(mysql_conn) do
    MySQLAdapter.fetch_biblio_data(mysql_conn, opts)
  end

  def fetch_data(mysql_conn, :items, opts) when is_pid(mysql_conn) do
    MySQLAdapter.fetch_item_data(mysql_conn, opts)
  end

  def fetch_data(mysql_conn, :members, opts) when is_pid(mysql_conn) do
    MySQLAdapter.fetch_member_data(mysql_conn, opts)
  end

  def fetch_data(mysql_conn, :users, opts) when is_pid(mysql_conn) do
    MySQLAdapter.fetch_user_data(mysql_conn, opts)
  end

  def fetch_data(mysql_conn, :authors, opts) when is_pid(mysql_conn) do
    MySQLAdapter.fetch_author_data(mysql_conn, opts)
  end

  def fetch_data(mysql_conn, :publishers, opts) when is_pid(mysql_conn) do
    MySQLAdapter.fetch_publisher_data(mysql_conn, opts)
  end

  def fetch_data(mysql_conn, :biblio_authors, opts) when is_pid(mysql_conn) do
    MySQLAdapter.fetch_biblio_author_data(mysql_conn, opts)
  end

  @doc """
  Get data count for specified type.
  """
  def get_data_count(source, data_type)

  def get_data_count(:csv, data_type) do
    case fetch_data(:csv, data_type) do
      {:ok, stream} ->
        count = Enum.count(stream)
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_data_count(mysql_conn, data_type) when is_pid(mysql_conn) do
    table_name = data_type_to_table_name(data_type)
    MySQLAdapter.get_table_count(mysql_conn, table_name)
  end

  @doc """
  Close data source connection.
  """
  def close_source(source) do
    case source do
      :csv ->
        # CSV doesn't need explicit cleanup
        :ok

      mysql_conn when is_pid(mysql_conn) ->
        MySQLAdapter.close(mysql_conn)
        :ok

      _ ->
        :ok
    end
  end

  # Private helper functions

  defp stream_csv_files(files, _batch_size) do
    files
    |> Enum.flat_map(fn file ->
      File.stream!(file)
      |> CSVParser.parse_stream()
      # Skip header
      |> Stream.drop(1)
      |> Enum.to_list()
    end)
  end

  defp data_type_to_table_name(:biblio), do: "biblio"
  defp data_type_to_table_name(:items), do: "item"
  defp data_type_to_table_name(:members), do: "member"
  defp data_type_to_table_name(:users), do: "user"
  defp data_type_to_table_name(:authors), do: "mst_author"
  defp data_type_to_table_name(:publishers), do: "mst_publisher"
  defp data_type_to_table_name(:biblio_authors), do: "biblio_author"
end
