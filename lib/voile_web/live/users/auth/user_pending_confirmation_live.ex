defmodule VoileWeb.UserPendingConfirmationLive do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl px-4 py-12">
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8">
          <div class="text-center mb-8">
            <div class="inline-flex items-center justify-center w-20 h-20 bg-yellow-100 dark:bg-yellow-900 rounded-full mb-4">
              <.icon name="hero-envelope" class="w-10 h-10 text-yellow-600 dark:text-yellow-400" />
            </div>

            <div class="text-center">
              <.header>
                {gettext("Verify Your Email Address")}
                <:subtitle>
                  {gettext("We've sent a confirmation email to verify your account")}
                </:subtitle>
              </.header>
            </div>
          </div>

          <%= if @email do %>
            <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-6 mb-6">
              <div class="flex items-start gap-3">
                <div class="flex-shrink-0">
                  <.icon name="hero-envelope-open" class="w-8 h-8 text-blue-600 dark:text-blue-400" />
                </div>
                <div class="flex-1">
                  <p class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    {gettext("Confirmation email sent to:")}
                  </p>
                  <p class="text-lg font-semibold text-gray-900 dark:text-white mb-3">
                    {@email}
                  </p>
                  <p class="text-sm text-gray-600 dark:text-gray-400">
                    {gettext(
                      "Please check your inbox and click the confirmation link to activate your account."
                    )}
                  </p>
                </div>
              </div>
            </div>

            <div class="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-6 mb-6">
              <h3 class="font-semibold text-gray-900 dark:text-white mb-3">
                {gettext("What to do next:")}
              </h3>
              <ol class="space-y-3 text-sm text-gray-700 dark:text-gray-300">
                <li class="flex items-start gap-3">
                  <span class="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center text-xs font-semibold">
                    1
                  </span>
                  <span>{gettext("Check your email inbox (and spam folder)")}</span>
                </li>
                <li class="flex items-start gap-3">
                  <span class="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center text-xs font-semibold">
                    2
                  </span>
                  <span>{gettext("Click the confirmation link in the email")}</span>
                </li>
                <li class="flex items-start gap-3">
                  <span class="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center text-xs font-semibold">
                    3
                  </span>
                  <span>{gettext("Return to login and access your account")}</span>
                </li>
              </ol>
            </div>

            <div class="space-y-4">
              <.form for={%{}} id="resend_form" phx-submit="resend_confirmation">
                <input type="hidden" name="email" value={@email} />
                <.button
                  type="submit"
                  phx-disable-with="Sending..."
                  class="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-lg transition-colors"
                >
                  <.icon name="hero-paper-airplane" class="w-5 h-5 inline-block mr-2" />
                  {gettext("Resend Confirmation Email")}
                </.button>
              </.form>

              <.link
                href={~p"/login"}
                class="block w-full text-center bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 font-semibold py-3 rounded-lg transition-colors"
              >
                {gettext("Return to Login")}
              </.link>
            </div>
          <% else %>
            <div class="text-center">
              <p class="text-gray-600 dark:text-gray-400 mb-6">
                {gettext("No email address found. Please register or log in.")}
              </p>
              <.link
                href={~p"/register"}
                class="inline-block bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 px-6 rounded-lg transition-colors"
              >
                {gettext("Go to Registration")}
              </.link>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(params, _session, socket) do
    email = params["email"]

    # `socket.assigns.current_scope` may be nil when this LiveView is mounted
    # outside of the expected live_session. Use a safe check instead of
    # calling Map.has_key?/2 directly on a potentially nil value.
    is_user_logged_in = not is_nil(get_in(socket.assigns, [:current_scope, :user]))

    if is_user_logged_in do
      {:ok,
       socket
       |> put_flash(:info, gettext("You are already logged in."))
       |> push_navigate(to: ~p"/")}
    else
      {:ok,
       socket
       |> assign(:email, email)}
    end
  end

  def handle_event("resend_confirmation", %{"email" => email}, socket) do
    case Accounts.get_user_by_email(email) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("No account found with that email address."))
         |> push_navigate(to: ~p"/register")}

      user ->
        if user.confirmed_at do
          {:noreply,
           socket
           |> put_flash(:info, gettext("This account is already confirmed. You can log in now."))
           |> push_navigate(to: ~p"/login")}
        else
          Accounts.deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))

          {:noreply,
           socket
           |> put_flash(:info, gettext("Confirmation email sent! Please check your inbox."))}
        end
    end
  end
end
