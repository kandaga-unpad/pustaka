defmodule Voile.Clearance do
  @moduledoc """
  Context for managing clearance letters (Surat Keterangan Bebas Perpustakaan).

  Handles eligibility checks, letter generation, verification, and revocation.
  """

  import Ecto.Query

  alias Voile.Repo
  alias Voile.Schema.Library.ClearanceLetter
  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.System
  alias Client.Storage
  alias VoileWeb.Utils.UnpadNodeList

  # Settings keys
  @setting_sequence "clearance_letter_sequence"
  @setting_number_format "clearance_number_format"
  @setting_institution_name "clearance_institution_name"
  @setting_institution_subtitle "clearance_institution_subtitle"
  @setting_institution_address "clearance_institution_address"
  @setting_institution_phone "clearance_institution_phone"
  @setting_institution_email "clearance_institution_email"
  @setting_city "clearance_city"
  @setting_signer_name "clearance_signer_name"
  @setting_signer_nip "clearance_signer_nip"
  @setting_signer_title "clearance_signer_title"
  @setting_signature_image "clearance_signature_image"
  @setting_eligible_member_types "clearance_eligible_member_types"
  @setting_body_text "clearance_body_text"
  @setting_closing_text "clearance_closing_text"

  @default_body_text "adalah benar telah <strong>bebas dari kewajiban kepada perpustakaan</strong>, meliputi tidak ada peminjaman buku yang belum dikembalikan dan tidak ada denda yang belum dibayarkan, sehingga yang bersangkutan dinyatakan <strong>BEBAS PERPUSTAKAAN</strong>."
  @default_closing_text "Surat keterangan ini dibuat untuk dipergunakan sebagaimana mestinya."

  # ---------------------------------------------------------------------------
  # Eligibility
  # ---------------------------------------------------------------------------

  @doc """
  Checks whether a user is eligible to receive a clearance letter.

  Returns a map with `:eligible` (bool) and `:checks` (list of check results).
  Each check is a map with `:key`, `:label`, `:passed`, and `:detail`.

  The user must be preloaded with `:user_type` for the member type check.
  The locker check is only included when `VoileLockerLuggage.Lockers` is loaded.
  """
  def check_eligibility(user) do
    identifier = to_string(user.identifier)
    checks = []

    # 1. Unpaid fines
    unpaid_count = Circulation.count_member_unpaid_fines(user.id)

    checks =
      checks ++
        [
          %{
            key: :unpaid_fines,
            label: "Tidak ada denda yang belum dibayar",
            passed: unpaid_count == 0,
            detail:
              if unpaid_count > 0 do
                "Terdapat #{unpaid_count} tagihan denda yang belum dibayar"
              else
                nil
              end
          }
        ]

    # 2. Active loans
    active_loans = Circulation.count_list_active_transactions(user.id)

    checks =
      checks ++
        [
          %{
            key: :active_loans,
            label: "Tidak ada peminjaman aktif",
            passed: active_loans == 0,
            detail:
              if active_loans > 0 do
                "Terdapat #{active_loans} item yang masih dipinjam"
              else
                nil
              end
          }
        ]

    # 3. Active locker (only if plugin is loaded)
    checks =
      if Code.ensure_loaded?(VoileLockerLuggage.Lockers) do
        has_locker = has_active_locker?(identifier)

        checks ++
          [
            %{
              key: :active_locker,
              label: "Tidak ada loker aktif",
              passed: not has_locker,
              detail:
                if has_locker do
                  "Terdapat sesi loker yang masih aktif"
                else
                  nil
                end
            }
          ]
      else
        checks
      end

    eligible = Enum.all?(checks, & &1.passed)
    %{eligible: eligible, checks: checks}
  end

  defp has_active_locker?(identifier) do
    nodes = System.list_nodes()

    Enum.any?(nodes, fn node ->
      case VoileLockerLuggage.Lockers.get_active_session_for_visitor(node.id, identifier) do
        nil -> false
        _session -> true
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Letter generation
  # ---------------------------------------------------------------------------

  @doc """
  Builds a member snapshot map from a user struct.

  The user may be loaded without `:node` preloaded.
  Optionally accepts a custom `identifier` (for next-degree letters).
  When `VOILE_UNPAD_VISITOR_SOURCE` is configured, fetches student data
  from the external API using the effective identifier.
  """
  def build_member_snapshot(user, identifier \\ nil) do
    identifier = stringify_identifier(identifier || user.identifier)
    external_student = fetch_external_student_data(identifier)

    %{
      "identifier" => identifier,
      "fullname" => external_student["MhsNama"] || user.fullname || "",
      "department" =>
        external_student["MhsProdi"] || external_student["study_program"] ||
          external_student["prodi"] || user.department || "",
      "node_name" => node_name(user, identifier)
    }
  end

  defp node_name(user, identifier) do
    cond do
      Map.has_key?(user, :node) and Ecto.assoc_loaded?(user.node) ->
        (user.node && user.node.name) || ""

      true ->
        identifier
        |> String.slice(0, 3)
        |> parse_node_prefix()
        |> get_unpad_node_name()
    end
  end

  defp parse_node_prefix("") do
    nil
  end

  defp parse_node_prefix(prefix) when is_binary(prefix) do
    case Integer.parse(prefix) do
      {int_prefix, ""} -> int_prefix
      _ -> nil
    end
  end

  defp get_unpad_node_name(nil), do: ""

  defp get_unpad_node_name(prefix) do
    case UnpadNodeList.get_node_by_id(prefix) do
      %{namaFakultas: name} when is_binary(name) -> name
      %{singkatan: abbr} when is_binary(abbr) -> abbr
      _ -> ""
    end
  end

  defp fetch_external_student_data(nil), do: %{}

  defp fetch_external_student_data(identifier) do
    base_url =
      :os.getenv(~c"VOILE_UNPAD_VISITOR_SOURCE", false)
      |> then(fn
        false -> nil
        v -> List.to_string(v)
      end) ||
        Application.get_env(:voile, :external_user_api_url)

    base_url =
      case base_url do
        nil -> nil
        "" -> nil
        url -> String.trim_trailing(url, "/")
      end

    if base_url do
      url =
        if String.ends_with?(base_url, "/"),
          do: base_url <> to_string(identifier),
          else: base_url <> "/" <> to_string(identifier)

      case Req.get(url, receive_timeout: 5_000) do
        {:ok, %{status: 200, body: body}} ->
          body_map =
            cond do
              is_map(body) ->
                body

              is_binary(body) ->
                case Jason.decode(body) do
                  {:ok, m} when is_map(m) -> m
                  _ -> %{}
                end

              true ->
                %{}
            end

          body_map

        _ ->
          %{}
      end
    else
      %{}
    end
  end

  @doc """
  Generates a clearance letter for a user inside a DB transaction.

  The user may be loaded without `:node` preloaded.

  Returns `{:ok, letter}` or `{:error, reason}`.
  """
  def generate_letter(user) do
    case get_member_latest_letter(user.id) do
      nil -> create_letter(user, user.identifier)
      letter -> {:error, :already_exists, letter}
    end
  end

  @doc """
  Generates a clearance letter for a user with a custom identifier.

  This is intended for super-admin dashboard usage, where the member may have
  already requested clearance under a previous identifier.
  """
  def generate_letter_for_member(user, identifier) do
    identifier = stringify_identifier(identifier)

    case get_member_active_letter_by_identifier(user.id, identifier) do
      nil -> create_letter(user, identifier)
      letter -> {:error, :already_exists, letter}
    end
  end

  defp create_letter(user, identifier) do
    identifier = stringify_identifier(identifier)

    if is_nil(identifier) or identifier == "" do
      {:error,
       Ecto.Changeset.add_error(
         ClearanceLetter.changeset(%ClearanceLetter{}, %{}),
         :identifier,
         "is required and must not be empty"
       )}
    else
      Repo.transaction(fn ->
        sequence = next_sequence()
        year = Date.utc_today().year
        format = System.get_setting_value(@setting_number_format, "{N}/{YEAR}")
        letter_number = format_letter_number(sequence, format, year)
        snapshot = build_member_snapshot(user, identifier)
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        changeset =
          ClearanceLetter.changeset(%ClearanceLetter{}, %{
            letter_number: letter_number,
            sequence_number: sequence,
            identifier: identifier,
            member_id: user.id,
            member_snapshot: snapshot,
            generated_at: now
          })

        case Repo.insert(changeset) do
          {:ok, letter} -> letter
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    end
  end

  defp stringify_identifier(nil), do: nil
  defp stringify_identifier(identifier) when is_binary(identifier), do: identifier

  defp stringify_identifier(identifier) when is_integer(identifier),
    do: Integer.to_string(identifier)

  defp stringify_identifier(%Decimal{} = identifier), do: Decimal.to_string(identifier)

  @doc """
  Formats a letter number by replacing `{N}` (zero-padded) and `{YEAR}` in the format template.
  """
  def format_letter_number(sequence, format, year) do
    padded = to_string(sequence)

    format
    |> String.replace("{N}", padded)
    |> String.replace("{YEAR}", to_string(year))
  end

  # Reads current sequence, increments, saves, and returns the new value.
  # Called inside Repo.transaction so it is effectively serialised by the DB.
  defp next_sequence do
    current =
      System.get_setting_value(@setting_sequence, "0")
      |> parse_int(0)

    next = current + 1
    System.upsert_setting(@setting_sequence, to_string(next))
    next
  end

  defp parse_int(nil, default), do: default

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} -> n
      :error -> default
    end
  end

  # ---------------------------------------------------------------------------
  # Retrieval
  # ---------------------------------------------------------------------------

  @doc """
  Returns a paginated list of clearance letters with preloaded member and member's node.

  Options:
    - `:node_id`  — integer; when provided, only letters whose member belongs to this node are returned.
    - `:search`   — string; fuzzy search on letter_number, member fullname, or member identifier.

  Returns `{letters, total_count, total_pages}`.
  """
  def list_letters_paginated(page, per_page, opts \\ []) do
    alias Voile.Schema.Accounts.User

    node_id = Keyword.get(opts, :node_id)
    search = Keyword.get(opts, :search, "")

    base =
      from l in ClearanceLetter, join: u in User, on: l.member_id == u.id

    base =
      if node_id do
        from [l, u] in base, where: u.node_id == ^node_id
      else
        base
      end

    base =
      if search && search != "" do
        term = "%#{search}%"

        from [l, u] in base,
          where:
            ilike(u.fullname, ^term) or
              ilike(l.letter_number, ^term) or
              ilike(fragment("CAST(? AS TEXT)", u.identifier), ^term)
      else
        base
      end

    total =
      base
      |> select([l], count(l.id))
      |> Repo.one()
      |> Kernel.||(0)

    total_pages = max(div(total + per_page - 1, per_page), 1)
    offset = (page - 1) * per_page

    letters =
      base
      |> order_by([l], desc: l.inserted_at)
      |> limit(^per_page)
      |> offset(^offset)
      |> select([l, _u], l)
      |> Repo.all()
      |> Repo.preload(member: :node)

    {letters, total, total_pages}
  end

  @doc """
  Gets a clearance letter by UUID, preloading member and revoked_by.
  """
  def get_letter(uuid) do
    ClearanceLetter
    |> where([l], l.id == ^uuid)
    |> preload([:member, :revoked_by])
    |> Repo.one()
  end

  @doc """
  Gets the latest non-revoked clearance letter for a member.
  """
  def get_member_latest_letter(member_id) do
    ClearanceLetter
    |> where([l], l.member_id == ^member_id and l.is_revoked == false)
    |> order_by([l], desc: l.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets all non-revoked clearance letters for a member.
  """
  def get_member_letters(member_id) do
    ClearanceLetter
    |> where([l], l.member_id == ^member_id and l.is_revoked == false)
    |> order_by([l], desc: l.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a non-revoked clearance letter for a member by identifier.
  """
  def get_member_letter_by_identifier(member_id, identifier) do
    identifier = stringify_identifier(identifier)

    ClearanceLetter
    |> where(
      [l],
      l.member_id == ^member_id and l.identifier == ^identifier and l.is_revoked == false
    )
    |> order_by([l], desc: l.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp get_member_active_letter_by_identifier(member_id, identifier) do
    get_member_letter_by_identifier(member_id, identifier)
  end

  # ---------------------------------------------------------------------------
  # Revocation
  # ---------------------------------------------------------------------------

  @doc """
  Revokes a clearance letter.
  """
  def revoke_letter(%ClearanceLetter{} = letter, revoked_by_id, reason) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    letter
    |> ClearanceLetter.revoke_changeset(%{
      is_revoked: true,
      revoked_at: now,
      revoked_by_id: revoked_by_id,
      revoke_reason: reason
    })
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Settings
  # ---------------------------------------------------------------------------

  @doc """
  Returns all clearance settings as a map with string keys.
  """
  def get_settings do
    %{
      "sequence" => System.get_setting_value(@setting_sequence, "0"),
      "number_format" => System.get_setting_value(@setting_number_format, "{N}/{YEAR}"),
      "institution_name" => System.get_setting_value(@setting_institution_name, ""),
      "institution_subtitle" => System.get_setting_value(@setting_institution_subtitle, ""),
      "institution_address" => System.get_setting_value(@setting_institution_address, ""),
      "institution_phone" => System.get_setting_value(@setting_institution_phone, ""),
      "institution_email" => System.get_setting_value(@setting_institution_email, ""),
      "city" => System.get_setting_value(@setting_city, ""),
      "signer_name" => System.get_setting_value(@setting_signer_name, ""),
      "signer_nip" => System.get_setting_value(@setting_signer_nip, ""),
      "signer_title" => System.get_setting_value(@setting_signer_title, ""),
      "signature_image" => System.get_setting_value(@setting_signature_image, nil),
      "eligible_member_types" =>
        System.get_setting_value(@setting_eligible_member_types, "member_verified"),
      "body_text" => System.get_setting_value(@setting_body_text, @default_body_text),
      "closing_text" => System.get_setting_value(@setting_closing_text, @default_closing_text)
    }
  end

  @doc """
  Saves clearance settings. Accepts a map with string keys matching the fields
  returned by `get_settings/0`.
  """
  def save_settings(attrs) do
    key_map = %{
      "sequence" => @setting_sequence,
      "number_format" => @setting_number_format,
      "institution_name" => @setting_institution_name,
      "institution_subtitle" => @setting_institution_subtitle,
      "institution_address" => @setting_institution_address,
      "institution_phone" => @setting_institution_phone,
      "institution_email" => @setting_institution_email,
      "city" => @setting_city,
      "signer_name" => @setting_signer_name,
      "signer_nip" => @setting_signer_nip,
      "signer_title" => @setting_signer_title,
      "signature_image" => @setting_signature_image,
      "eligible_member_types" => @setting_eligible_member_types,
      "body_text" => @setting_body_text,
      "closing_text" => @setting_closing_text
    }

    Enum.each(attrs, fn {key, value} ->
      if setting_name = Map.get(key_map, key) do
        System.upsert_setting(setting_name, value)
      end
    end)

    :ok
  end

  @doc """
  Deletes the old signature image from storage. Safe to call with nil.
  """
  def delete_old_signature_image(nil), do: :ok

  def delete_old_signature_image(url) when is_binary(url) do
    try do
      Storage.delete(url)
    rescue
      _ -> :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  @doc """
  Returns the eligible member type slugs from settings (comma-separated string).
  """
  def eligible_member_type_slugs do
    System.get_setting_value(@setting_eligible_member_types, "member_verified")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
