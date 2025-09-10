defmodule VoileWeb.UserLoginLive do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts

  def render(assigns) do
    ~H"""
    <.modal id="magic-link-modal">
      <div class="flex flex-col gap-4">
        <h3 class="text-lg font-semibold">Login with Email Link</h3>

        <p class="text-sm text-gray-600">
          Enter your email address and we'll send you a secure login link. No password required!
        </p>

        <.form for={@magic_link_form} phx-submit="send_magic_link">
          <.input
            field={@magic_link_form[:email]}
            type="email"
            label="Email Address"
            placeholder="Enter your email address"
            required
          />
          <div class="flex gap-2 justify-end mt-4">
            <.button
              type="button"
              phx-click={hide_modal("magic-link-modal")}
              class="px-4 py-2 text-gray-600 hover:text-gray-800"
            >
              Cancel
            </.button>
            <.button
              type="submit"
              phx-disable-with="Sending..."
              class="default-btn px-6"
            >
              Send Login Link
            </.button>
          </div>
        </.form>
      </div>
    </.modal>

    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-7xl mx-auto flex flex-col items-center">
        <.header>
          Log in to account
          <:subtitle>
            Don't have an account?
            <.link navigate={~p"/register"} class="font-semibold text-brand hover:underline">
              Sign up
            </.link>
            for an account now.
          </:subtitle>
        </.header>

        <div class="flex flex-col gap-8 items-center justify-center lg:flex-row lg:gap-2 w-full">
          <div class="w-full max-w-sm">
            <.form for={@form} id="login_form" action={~p"/users/log_in"}>
              <.input field={@form[:email]} type="email" label="Email" required />
              <.input field={@form[:password]} type="password" label="Password" required />
              <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
              <div class="flex flex-col gap-2 my-2">
                <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
                  Forgot your password?
                </.link>
              </div>

              <.button phx-disable-with="Logging in..." class="default-btn w-full">
                Log in <span aria-hidden="true">→</span>
              </.button>
            </.form>
          </div>

          <div class="w-full max-w-sm">
            <%= if @current_scope === nil do %>
              <div class="flex flex-col gap-4 items-center justify-center">
                <.button phx-click="google_auth" class="default-btn">Login with Google</.button>
                <.button phx-click="paus_auth" class="default-btn">Login with PAuS ID</.button>
                <.button
                  type="button"
                  phx-click={show_modal("magic-link-modal")}
                  class="default-btn"
                >
                  Login Passwordless
                </.button>
              </div>
            <% else %>
              <.link
                href="/users/log_out"
                method="delete"
                class="default-menu bg-red-400 hover:bg-red-500 text-white"
              >
                Log out
              </.link>
            <% end %>
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
      email =
        Phoenix.Flash.get(socket.assigns.flash, :email) ||
          get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

      form = to_form(%{"email" => email}, as: "user")
      magic_link_form = to_form(%{"email" => ""}, as: "magic_link")

      {:ok,
       socket
       |> assign(form: form)
       |> assign(magic_link_form: magic_link_form),
       temporary_assigns: [form: form, magic_link_form: magic_link_form]}
    end
  end

  defp determine_redirect_path(user) do
    case user.user_type do
      %{slug: slug} when slug in ["administrator", "staff"] -> "/manage"
      _ -> "/"
    end
  end

  def handle_event("send_magic_link", %{"magic_link" => %{"email" => email}}, socket) do
    if email && String.trim(email) != "" do
      case Accounts.get_user_by_email(email) do
        %Accounts.User{confirmed_at: nil} = user ->
          # This is likely a migrated user who needs onboarding
          case Accounts.deliver_onboarding_instructions(user, &url(~p"/users/onboarding/#{&1}")) do
            {:ok, _} ->
              {:noreply,
               socket
               |> put_flash(
                 :info,
                 "We've sent account setup instructions to #{email}. " <>
                   "Please check your email and click the link to set your password and access your account."
               )
               |> redirect(to: ~p"/login")}

            {:error, _} ->
              {:noreply,
               put_flash(
                 socket,
                 :error,
                 "Unable to send email. Please try again or contact support."
               )}
          end

        %Accounts.User{} = user ->
          # Regular confirmed user - send magic link
          case Accounts.deliver_login_instructions(user, &url(~p"/users/login/#{&1}")) do
            {:ok, _} ->
              {:noreply,
               socket
               |> put_flash(
                 :info,
                 "We've sent a login link to #{email}. Please check your email."
               )
               |> redirect(to: ~p"/login")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Unable to send email. Please try again.")}
          end

        nil ->
          # User doesn't exist
          {:noreply, put_flash(socket, :error, "No account found with that email address.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please enter your email address.")}
    end
  end

  def handle_event("google_auth", _params, socket) do
    {:noreply, redirect(socket, to: "/auth/google")}
  end

  def handle_event("paus_auth", _params, socket) do
    {:noreply, redirect(socket, to: "/auth/paus")}
  end
end
