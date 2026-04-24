defmodule VoileWeb.Frontend.Atrium.Clearance.Index do
  use VoileWeb, :live_view
  use Gettext, backend: VoileWeb.Gettext

  alias Voile.Clearance
  alias Voile.Schema.Accounts
  alias Voile.Repo

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    # get_user already preloads user_type; additionally preload node for snapshot
    user = Accounts.get_user(user.id) |> Repo.preload(:node)

    eligible_slugs = Clearance.eligible_member_type_slugs()
    member_type_slug = user.user_type && user.user_type.slug

    socket =
      if member_type_slug not in eligible_slugs do
        socket
        |> assign(:not_eligible_type, true)
        |> assign(:user, user)
        |> assign(:eligibility, nil)
        |> assign(:existing_letter, nil)
        |> assign(:generating, false)
        |> assign(:error, nil)
      else
        eligibility = Clearance.check_eligibility(user)
        existing_letter = Clearance.get_member_latest_letter(user.id)

        socket
        |> assign(:not_eligible_type, false)
        |> assign(:user, user)
        |> assign(:eligibility, eligibility)
        |> assign(:existing_letter, existing_letter)
        |> assign(:generating, false)
        |> assign(:error, nil)
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("generate_letter", _params, socket) do
    if socket.assigns.not_eligible_type or not socket.assigns.eligibility.eligible do
      {:noreply, socket}
    else
      socket = assign(socket, :generating, true)

      case Clearance.generate_letter(socket.assigns.user) do
        {:ok, letter} ->
          {:noreply, push_navigate(socket, to: ~p"/clearance/surat/#{letter.id}")}

        {:error, changeset} ->
          error =
            changeset.errors
            |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
            |> Enum.join(", ")

          {:noreply, assign(socket, generating: false, error: "Gagal membuat surat: #{error}")}
      end
    end
  end

  @impl true
  def handle_event("refresh_eligibility", _params, socket) do
    user = socket.assigns.user
    eligibility = Clearance.check_eligibility(user)
    existing_letter = Clearance.get_member_latest_letter(user.id)
    {:noreply, assign(socket, eligibility: eligibility, existing_letter: existing_letter)}
  end
end
