defmodule VoileWeb.UserConfirmationInstructionsLive do
  use VoileWeb, :live_view

  on_mount {VoileWeb.UserAuth, :require_sudo_mode}

  alias Voile.Schema.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            No confirmation instructions received?
            <:subtitle>We'll send a new confirmation link to your inbox</:subtitle>
          </.header>
        </div>
        
        <.form for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
          <.input field={@form[:email]} type="email" placeholder="Email" required />
          <.button phx-disable-with="Sending..." class="w-full">
            Resend confirmation instructions
          </.button>
        </.form>
        
        <p class="text-center mt-4">
          <.link href={~p"/register"}>Register</.link>
          | <.link href={~p"/users/log_in"}>Log in</.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    info =
      "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
