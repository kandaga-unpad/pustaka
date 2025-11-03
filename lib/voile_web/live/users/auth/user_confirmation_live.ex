defmodule VoileWeb.UserConfirmationLive do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl px-4 py-8">
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8">
          <div class="text-center mb-8">
            <div class="inline-flex items-center justify-center w-16 h-16 bg-blue-100 dark:bg-blue-900 rounded-full mb-4">
              <.icon name="hero-envelope" class="w-8 h-8 text-blue-600 dark:text-blue-400" />
            </div>
            <div class="text-center">
              <.header>
                Confirm Your Account
                <:subtitle>
                  Please verify your email address to activate your account
                </:subtitle>
              </.header>
            </div>
          </div>

          <%= if @user do %>
            <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-6 mb-6">
              <div class="flex items-start gap-3">
                <div class="flex-shrink-0">
                  <.icon name="hero-user-circle" class="w-10 h-10 text-blue-600 dark:text-blue-400" />
                </div>
                <div class="flex-1">
                  <p class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Confirming account for:
                  </p>
                  <p class="text-lg font-semibold text-gray-900 dark:text-white">
                    {@user.email}
                  </p>
                  <%= if @user.fullname do %>
                    <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
                      {@user.fullname}
                    </p>
                  <% end %>
                </div>
              </div>
            </div>

            <.form for={@form} id="confirmation_form" phx-submit="confirm_account">
              <input type="hidden" name={@form[:token].name} value={@form[:token].value} />

              <div class="space-y-4">
                <div class="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-4">
                  <ul class="space-y-2 text-sm text-gray-700 dark:text-gray-300">
                    <li class="flex items-start gap-2">
                      <.icon
                        name="hero-check-circle"
                        class="w-5 h-5 text-green-600 dark:text-green-400 flex-shrink-0 mt-0.5"
                      />
                      <span>Access to all platform features</span>
                    </li>
                    <li class="flex items-start gap-2">
                      <.icon
                        name="hero-check-circle"
                        class="w-5 h-5 text-green-600 dark:text-green-400 flex-shrink-0 mt-0.5"
                      />
                      <span>Secure your account with email verification</span>
                    </li>
                    <li class="flex items-start gap-2">
                      <.icon
                        name="hero-check-circle"
                        class="w-5 h-5 text-green-600 dark:text-green-400 flex-shrink-0 mt-0.5"
                      />
                      <span>Receive important notifications and updates</span>
                    </li>
                  </ul>
                </div>

                <.button
                  phx-disable-with="Confirming..."
                  class="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-lg transition-colors"
                >
                  <.icon name="hero-check-badge" class="w-5 h-5 inline-block mr-2" />
                  Confirm My Account
                </.button>
              </div>
            </.form>
          <% else %>
            <div class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-6 mb-6">
              <div class="flex items-start gap-3">
                <div class="flex-shrink-0">
                  <.icon
                    name="hero-exclamation-triangle"
                    class="w-6 h-6 text-red-600 dark:text-red-400"
                  />
                </div>
                <div class="flex-1">
                  <p class="font-medium text-red-800 dark:text-red-300 mb-1">
                    Invalid Confirmation Link
                  </p>
                  <p class="text-sm text-red-700 dark:text-red-400">
                    This confirmation link is invalid or has expired. Please request a new confirmation email.
                  </p>
                </div>
              </div>
            </div>

            <.link
              href={~p"/users/confirm"}
              class="block w-full text-center bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-lg transition-colors"
            >
              Request New Confirmation Email
            </.link>
          <% end %>

          <div class="mt-8 pt-6 border-t border-gray-200 dark:border-gray-700">
            <p class="text-center text-sm text-gray-600 dark:text-gray-400">
              Already confirmed your account?
              <.link
                href={~p"/login"}
                class="text-blue-600 dark:text-blue-400 hover:underline font-medium"
              >
                Sign in
              </.link>
            </p>
            <p class="text-center text-sm text-gray-600 dark:text-gray-400 mt-2">
              Don't have an account?
              <.link
                href={~p"/register"}
                class="text-blue-600 dark:text-blue-400 hover:underline font-medium"
              >
                Register
              </.link>
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    # Try to get user information from the token
    user = Accounts.get_user_by_confirmation_token(token)

    form = to_form(%{"token" => token}, as: "user")

    {:ok,
     socket
     |> assign(form: form, user: user), temporary_assigns: [form: nil]}
  end

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  def handle_event("confirm_account", %{"user" => %{"token" => token}}, socket) do
    case Accounts.confirm_user(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "User confirmed successfully.")
         |> redirect(to: ~p"/")}

      :error ->
        # If there is a current user and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the user themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_user: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "User confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/")}
        end
    end
  end
end
