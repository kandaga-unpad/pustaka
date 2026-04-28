defmodule VoileWeb.Frontend.Atrium.Clearance.Index do
  use VoileWeb, :live_view
  use Gettext, backend: VoileWeb.Gettext

  alias Voile.Clearance
  alias Voile.Schema.Accounts
  alias Voile.Repo

  @impl true
  def mount(_params, _session, socket) do
    clearance_enabled = Clearance.feature_enabled?()
    user = socket.assigns.current_scope.user
    # get_user already preloads user_type; additionally preload node for snapshot
    user = Accounts.get_user(user.id) |> Repo.preload(:node)

    eligible_slugs = Clearance.eligible_member_type_slugs()
    member_type_slug = user.user_type && user.user_type.slug

    get_phone_info = Voile.Schema.System.get_setting_by_name("app_contact_number")
    get_email_info = Voile.Schema.System.get_setting_by_name("app_contact_email")

    institution_phone = get_phone_info && get_phone_info.setting_value
    institution_email = get_email_info && get_email_info.setting_value

    dbg(institution_phone: institution_phone, institution_email: institution_email)

    socket =
      cond do
        not clearance_enabled ->
          socket
          |> assign(:clearance_enabled, false)
          |> assign(:not_eligible_type, false)
          |> assign(:user, user)
          |> assign(:eligibility, nil)
          |> assign(:existing_letters, [])
          |> assign(:existing_letter, nil)
          |> assign(:generating, false)
          |> assign(:error, nil)
          |> assign(:institution_phone, institution_phone || "-")
          |> assign(:institution_email, institution_email || "-")
          |> assign(:support_needed, false)

        member_type_slug not in eligible_slugs ->
          settings = Clearance.get_settings()

          socket
          |> assign(:clearance_enabled, true)
          |> assign(:not_eligible_type, true)
          |> assign(:user, user)
          |> assign(:eligibility, nil)
          |> assign(:existing_letters, [])
          |> assign(:existing_letter, nil)
          |> assign(:generating, false)
          |> assign(:error, nil)
          |> assign(:institution_phone, institution_phone || settings["institution_phone"] || "-")
          |> assign(:institution_email, institution_email || settings["institution_email"] || "-")
          |> assign(:support_needed, false)

        true ->
          eligibility = Clearance.check_eligibility(user)
          existing_letters = Clearance.get_member_letters(user.id)
          existing_letter = Clearance.get_member_letter_by_identifier(user.id, user.identifier)
          settings = Clearance.get_settings()

          support_needed =
            Enum.any?(eligibility.checks, fn check ->
              check.key in [:unpaid_fines, :active_loans] and not check.passed
            end)

          socket
          |> assign(:clearance_enabled, true)
          |> assign(:not_eligible_type, false)
          |> assign(:user, user)
          |> assign(:eligibility, eligibility)
          |> assign(:existing_letters, existing_letters)
          |> assign(:existing_letter, existing_letter)
          |> assign(:generating, false)
          |> assign(:error, nil)
          |> assign(:institution_phone, institution_phone || settings["institution_phone"] || "-")
          |> assign(:institution_email, institution_email || settings["institution_email"] || "-")
          |> assign(:support_needed, support_needed)
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("generate_letter", _params, socket) do
    cond do
      not socket.assigns.clearance_enabled ->
        {:noreply, put_flash(socket, :error, gettext("Bebas Pustaka is not available yet."))}

      socket.assigns.not_eligible_type or not socket.assigns.eligibility.eligible ->
        {:noreply, socket}

      socket.assigns.existing_letter ->
        {:noreply,
         push_navigate(socket, to: ~p"/clearance/surat/#{socket.assigns.existing_letter.id}")}

      true ->
        socket = assign(socket, :generating, true)

        case Clearance.generate_letter(socket.assigns.user) do
          {:ok, letter} ->
            {:noreply, push_navigate(socket, to: ~p"/clearance/surat/#{letter.id}")}

          {:error, :already_exists, letter} ->
            {:noreply, push_navigate(socket, to: ~p"/clearance/surat/#{letter.id}")}

          {:error, changeset} ->
            error =
              changeset.errors
              |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
              |> Enum.join(", ")

            {:noreply,
             assign(socket,
               generating: false,
               error: gettext("Failed to generate letter: %{reason}", reason: error)
             )}
        end
    end
  end

  @impl true
  def handle_event("refresh_eligibility", _params, socket) do
    user = socket.assigns.user
    eligibility = Clearance.check_eligibility(user)
    existing_letters = Clearance.get_member_letters(user.id)
    existing_letter = Clearance.get_member_letter_by_identifier(user.id, user.identifier)

    support_needed =
      Enum.any?(eligibility.checks, fn check ->
        check.key in [:unpaid_fines, :active_loans] and not check.passed
      end)

    {:noreply,
     assign(socket,
       eligibility: eligibility,
       existing_letters: existing_letters,
       existing_letter: existing_letter,
       support_needed: support_needed
     )}
  end
end
