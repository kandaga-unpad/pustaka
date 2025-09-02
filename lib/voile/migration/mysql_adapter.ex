defmodule Voile.Migration.MySQLAdapter do
  @moduledoc """
  MySQL/MariaDB database adapter for reading SLiMS data directly from MySQL or MariaDB database.

  This module provides functionality to connect to a MySQL or MariaDB database and read
  SLiMS data directly instead of using CSV files. Both database systems are fully supported
  using the same configuration and connection methods.

  Configuration example in config/dev.exs:
  ```elixir
  config :voile, :mysql_source,
    hostname: "localhost",
    port: 3306,                    # Default port for both MySQL and MariaDB
    username: "slims_user",
    password: "slims_password",
    database: "slims_database"
  ```
  """

  require Logger

  @doc """
  Establishes connection to MySQL database for SLiMS data.
  Returns the connection process or error.
  """
  def connect do
    config = mysql_config()

    case MyXQL.start_link(config) do
      {:ok, conn} ->
        Logger.info("✅ Connected to SLiMS MySQL/MariaDB database: #{config[:database]}")
        {:ok, conn}

      {:error, reason} ->
        Logger.error("❌ Failed to connect to MySQL/MariaDB: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Fetches bibliography data from MySQL biblio table.
  Returns stream of data similar to CSV format.
  """
  def fetch_biblio_data(conn, opts \\ []) do
    limit = Keyword.get(opts, :limit, nil)
    offset = Keyword.get(opts, :offset, 0)

    base_query = """
    SELECT
      biblio_id, title, sor, edition, isbn_issn, publisher_id,
      publish_year, collation, series_title, call_number, source,
      publish_place, classification, notes, image, file_att,
      opac_hide, promoted, labels, frequency_id, spec_detail_info,
      content_type, gmd_id, media_type, carrier_type, input_date,
      last_update, uid
    FROM biblio
    ORDER BY biblio_id
    """

    query = add_limit_offset(base_query, limit, offset)

    case MyXQL.query(conn, query) do
      {:ok, %{rows: rows, columns: columns}} ->
        Logger.info("📚 Fetched #{length(rows)} bibliography records from MySQL")
        {:ok, format_mysql_rows(rows, columns)}

      {:error, reason} ->
        Logger.error("❌ Failed to fetch biblio data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Fetches item data from MySQL item table.
  """
  def fetch_item_data(conn, opts \\ []) do
    limit = Keyword.get(opts, :limit, nil)
    offset = Keyword.get(opts, :offset, 0)

    base_query = """
    SELECT
      item_id, biblio_id, call_number, coll_type_id, item_code,
      inventory_code, received_date, supplier_id, order_no, location_id,
      order_date, item_status_id, site_id, source, invoice, price,
      price_currency, invoice_date, input_date, last_update
    FROM item
    ORDER BY item_id
    """

    query = add_limit_offset(base_query, limit, offset)

    case MyXQL.query(conn, query) do
      {:ok, %{rows: rows, columns: columns}} ->
        Logger.info("📦 Fetched #{length(rows)} item records from MySQL")
        {:ok, format_mysql_rows(rows, columns)}

      {:error, reason} ->
        Logger.error("❌ Failed to fetch item data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Fetches member data from MySQL member table.
  """
  def fetch_member_data(conn, opts \\ []) do
    limit = Keyword.get(opts, :limit, nil)
    offset = Keyword.get(opts, :offset, 0)

    base_query = """
    SELECT
      member_id, member_name, gender, birth_date, member_type_id,
      member_address, member_mail_address, member_email, postal_code,
      inst_name, is_new, member_image, pin, member_phone, member_fax,
      member_since_date, register_date, expire_date, member_notes, is_pending
    FROM member
    ORDER BY member_id
    """

    query = add_limit_offset(base_query, limit, offset)

    case MyXQL.query(conn, query) do
      {:ok, %{rows: rows, columns: columns}} ->
        Logger.info("👥 Fetched #{length(rows)} member records from MySQL")
        {:ok, format_mysql_rows(rows, columns)}

      {:error, reason} ->
        Logger.error("❌ Failed to fetch member data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Fetches user data from MySQL user table.
  """
  def fetch_user_data(conn, opts \\ []) do
    limit = Keyword.get(opts, :limit, nil)
    offset = Keyword.get(opts, :offset, 0)

    base_query = """
    SELECT
      user_id, username, realname, user_type, passwd, last_login,
      last_login_ip, groups, email, social_media, user_image,
      input_date, last_update
    FROM user
    ORDER BY user_id
    """

    query = add_limit_offset(base_query, limit, offset)

    case MyXQL.query(conn, query) do
      {:ok, %{rows: rows, columns: columns}} ->
        Logger.info("👤 Fetched #{length(rows)} user records from MySQL")
        {:ok, format_mysql_rows(rows, columns)}

      {:error, reason} ->
        Logger.error("❌ Failed to fetch user data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Fetches author data from MySQL mst_author table.
  """
  def fetch_author_data(conn, opts \\ []) do
    limit = Keyword.get(opts, :limit, nil)
    offset = Keyword.get(opts, :offset, 0)

    base_query = """
    SELECT
      author_id, author_name, author_year, author_type, authority_type,
      auth_list, input_date, last_update
    FROM mst_author
    ORDER BY author_id
    """

    query = add_limit_offset(base_query, limit, offset)

    case MyXQL.query(conn, query) do
      {:ok, %{rows: rows, columns: columns}} ->
        Logger.info("✍️ Fetched #{length(rows)} author records from MySQL")
        {:ok, format_mysql_rows(rows, columns)}

      {:error, reason} ->
        Logger.error("❌ Failed to fetch author data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Fetches publisher data from MySQL mst_publisher table.
  """
  def fetch_publisher_data(conn, opts \\ []) do
    limit = Keyword.get(opts, :limit, nil)
    offset = Keyword.get(opts, :offset, 0)

    base_query = """
    SELECT
      publisher_id, publisher_name, input_date, last_update
    FROM mst_publisher
    ORDER BY publisher_id
    """

    query = add_limit_offset(base_query, limit, offset)

    case MyXQL.query(conn, query) do
      {:ok, %{rows: rows, columns: columns}} ->
        Logger.info("🏢 Fetched #{length(rows)} publisher records from MySQL")
        {:ok, format_mysql_rows(rows, columns)}

      {:error, reason} ->
        Logger.error("❌ Failed to fetch publisher data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Fetches biblio-author relationship data from MySQL biblio_author table.
  """
  def fetch_biblio_author_data(conn, opts \\ []) do
    limit = Keyword.get(opts, :limit, nil)
    offset = Keyword.get(opts, :offset, 0)

    base_query = """
    SELECT
      biblio_id, author_id, level
    FROM biblio_author
    ORDER BY biblio_id, level
    """

    query = add_limit_offset(base_query, limit, offset)

    case MyXQL.query(conn, query) do
      {:ok, %{rows: rows, columns: columns}} ->
        Logger.info("🔗 Fetched #{length(rows)} biblio-author relationships from MySQL")
        {:ok, format_mysql_rows(rows, columns)}

      {:error, reason} ->
        Logger.error("❌ Failed to fetch biblio-author data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Gets the count of records in a table.
  """
  def get_table_count(conn, table_name) do
    query = "SELECT COUNT(*) as total FROM #{table_name}"

    case MyXQL.query(conn, query) do
      {:ok, %{rows: [[count]]}} ->
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Closes the MySQL connection.
  """
  def close(conn) do
    GenServer.stop(conn)
    Logger.info("🔌 Closed MySQL connection")
  end

  # Private helper functions

  defp mysql_config do
    config = Application.get_env(:voile, :mysql_source, [])

    default_config = [
      hostname: "localhost",
      port: 3306,
      username: "root",
      password: "",
      database: "slims"
    ]

    Keyword.merge(default_config, config)
  end

  defp add_limit_offset(query, nil, 0), do: query
  defp add_limit_offset(query, nil, offset), do: "#{query} OFFSET #{offset}"
  defp add_limit_offset(query, limit, 0), do: "#{query} LIMIT #{limit}"
  defp add_limit_offset(query, limit, offset), do: "#{query} LIMIT #{limit} OFFSET #{offset}"

  defp format_mysql_rows(rows, _columns) do
    # Convert MySQL results to list of lists (similar to CSV format)
    Enum.map(rows, fn row ->
      Enum.map(row, fn
        nil -> ""
        %DateTime{} = dt -> DateTime.to_string(dt)
        %NaiveDateTime{} = ndt -> NaiveDateTime.to_string(ndt)
        %Date{} = date -> Date.to_string(date)
        value when is_binary(value) -> value
        value -> to_string(value)
      end)
    end)
  end
end
