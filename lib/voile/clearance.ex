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

  The user must be preloaded with `:node`.
  """
  def build_member_snapshot(user) do
    %{
      "identifier" => to_string(user.identifier),
      "fullname" => user.fullname || "",
      "department" => user.department || "",
      "node_name" => (user.node && user.node.name) || ""
    }
  end

  @doc """
  Generates a clearance letter for a user inside a DB transaction.

  The user must be preloaded with `:node`.

  Returns `{:ok, letter}` or `{:error, reason}`.
  """
  def generate_letter(user) do
    Repo.transaction(fn ->
      sequence = next_sequence()
      year = Date.utc_today().year
      format = System.get_setting_value(@setting_number_format, "{N}/{YEAR}")
      letter_number = format_letter_number(sequence, format, year)
      snapshot = build_member_snapshot(user)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      changeset =
        ClearanceLetter.changeset(%ClearanceLetter{}, %{
          letter_number: letter_number,
          sequence_number: sequence,
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

  @doc """
  Formats a letter number by replacing `{N}` (zero-padded) and `{YEAR}` in the format template.
  """
  def format_letter_number(sequence, format, year) do
    padded = String.pad_leading(to_string(sequence), 4, "0")

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
        System.get_setting_value(@setting_eligible_member_types, "member_verified")
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
      "eligible_member_types" => @setting_eligible_member_types
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
