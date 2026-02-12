defmodule VoileWeb.UserForgotPasswordLive do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-10">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8 items-center">
          <!-- Decorative side -->
          <div class="hidden md:flex items-center justify-center">
            <div class="w-full max-w-sm text-center">
              <!-- Simple SVG illustration placeholder -->
              <img src={~p"/images/v.png"} class="mx-auto h-36 w-36 object-contain" alt="Voile logo" />
              <h3 class="mt-6 text-lg font-semibold">{gettext("Reset your password")}</h3>

              <p class="mt-2 text-sm">
                {gettext(
                  "Enter the email associated with your account and we'll send a secure link to reset your password."
                )}
              </p>
            </div>
          </div>
          <!-- Form card -->
          <div class="bg-voile-light dark:bg-voile-dark shadow rounded-lg border border-gray-100 p-6">
            <.header>
              {gettext("Forgot your password?")}
              <:subtitle>
                <span class="text-sm text-gray-500">
                  {gettext("We'll send a password reset link to your inbox")}
                </span>
              </:subtitle>
            </.header>

            <.form for={@form} id="reset_password_form" phx-submit="send_email">
              <div class="space-y-4">
                <.input field={@form[:email]} type="email" placeholder={gettext("Email")} required />
                <.button phx-disable-with="Sending..." class="primary-btn w-full text-sm">
                  {gettext("Send password reset instructions")}
                </.button>
              </div>
            </.form>

            <div class="mt-6 flex items-center justify-between text-sm text-gray-600">
              <.link href={~p"/register"} class="w-24 text-center primary-btn hover:underline">
                {gettext("Register")}
              </.link>
              <.link href={~p"/login"} class="w-24 text-center success-btn hover:underline">
                {gettext("Log in")}
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    # Redirect already authenticated users to appropriate page
    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      user = socket.assigns.current_scope.user

      redirect_path = determine_redirect_path(user)
      {:ok, push_navigate(socket, to: redirect_path)}
    else
      {:ok, assign(socket, form: to_form(%{}, as: "user"))}
    end
  end

  defp determine_redirect_path(user) do
    case user.user_type do
      %{slug: slug} when slug in ["administrator", "staff"] -> "/manage"
      _ -> "/"
    end
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    info =
      gettext(
        "If your email is in our system, you will receive instructions to reset your password shortly."
      )

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
