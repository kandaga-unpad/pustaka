defmodule VoileWeb.UserLoginLive do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts

  def render(assigns) do
    ~H"""
    <.modal id="magic-link-modal">
      <div class="p-6 sm:p-8 rounded-lg max-w-md mx-auto">
        <h3 class="text-xl sm:text-2xl font-semibold mb-2">Login with Email Link</h3>

        <p class="text-sm text-voile-muted mb-4">
          Enter your email and we'll send a secure login link. No password required.
        </p>

        <.form for={@magic_link_form} phx-submit="send_magic_link">
          <.input
            field={@magic_link_form[:email]}
            type="email"
            label="Email Address"
            placeholder="you@example.com"
            required
            class="default-input"
          />
          <div class="flex gap-3 justify-end mt-6">
            <.button
              type="button"
              phx-click={hide_modal("magic-link-modal")}
              class="px-4 py-2 hover:text-voile-primary bg-voile-neutral rounded-md"
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
      <div class="min-h-[70vh] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
        <div class="w-full max-w-5xl bg-transparent">
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 items-center">
            <!-- Left: Brand / Illustration -->
            <div class="hidden lg:flex flex-col justify-center items-start px-6 py-8 bg-gradient-to-br from-voile-gradient to-library-gradient rounded-xl text-voile-surface">
              <h1 class="text-3xl font-extrabold mb-2 voile-text-gradient">Welcome back to Voile</h1>

              <p class="text-voile-dark/90 dark:text-voile-light max-w-prose mb-6">
                Sign in to access your dashboard, manage content, and explore features built for creators and teams.
              </p>

              <ul class="space-y-3">
                <li class="flex items-center gap-3">
                  <span class="inline-block w-3 h-3 rounded-full bg-voile-accent dark:bg-white/80" />
                  <span class="text-voile-dark/90 dark:text-voile-light">Fast, secure login</span>
                </li>

                <li class="flex items-center gap-3">
                  <span class="inline-block w-3 h-3 rounded-full bg-voile-accent dark:bg-white/80" />
                  <span class="text-voile-dark/90 dark:text-voile-light">
                    Passwordless and social auth
                  </span>
                </li>

                <li class="flex items-center gap-3">
                  <span class="inline-block w-3 h-3 rounded-full bg-voile-accent dark:bg-white/80" />
                  <span class="text-voile-dark/90 dark:text-voile-light">
                    Accessible & responsive
                  </span>
                </li>
              </ul>
            </div>
            <!-- Right: Form Card -->
            <div class="default-card rounded-xl shadow-md p-6 sm:p-8">
              <div class="flex items-center justify-between mb-6">
                <div>
                  <h2 class="text-2xl font-bold">Sign in to your account</h2>

                  <p class="text-sm italic">
                    Don't have an account?
                    <.link
                      navigate={~p"/register"}
                      class="font-semibold hover:underline"
                    >
                      Create one
                    </.link>
                  </p>
                </div>
              </div>

              <.form for={@form} id="login_form" action={~p"/users/log_in"} class="space-y-4">
                <.input
                  field={@form[:email]}
                  type="text"
                  label="Email, Username, or Identifier"
                  placeholder="Enter your email, username, or identifier"
                  required
                  class="default-input"
                />
                <.input
                  field={@form[:password]}
                  type="password"
                  label="Password"
                  required
                  class="default-input"
                />
                <div class="flex items-center justify-between gap-4">
                  <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
                  <.link
                    href={~p"/users/reset_password"}
                    class="text-sm font-semibold hover:underline"
                  >
                    Forgot your password?
                  </.link>
                </div>

                <.button phx-disable-with="Logging in..." class="default-btn w-full">
                  Log in <span aria-hidden="true">→</span>
                </.button>
              </.form>

              <div class="my-4 flex items-center gap-3">
                <hr class="flex-1 border-voile-muted" />
                <span class="text-sm text-voile-muted">or</span>
                <hr class="flex-1 border-voile-muted" />
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <.button
                  phx-click="google_auth"
                  class="btn border-voile-primary bg-white text-voile-primary hover:shadow-md"
                >
                  <span class="hidden sm:inline">Login with </span>
                  <span>
                    <img
                      src={~p"/images/google_img.png"}
                      class="inline h-5 w-5"
                      alt="Google logo"
                    />
                  </span>
                   <span>Google</span>
                </.button>
                <.button
                  type="button"
                  phx-click={show_modal("magic-link-modal")}
                  class="btn bg-voile-primary text-sm text-white"
                >
                  <span>
                    <.icon
                      name="hero-link"
                      class="size-4 opacity-75 hover:opacity-100"
                    />
                  </span>
                   <span>Login passwordless</span>
                </.button>
              </div>

              <div class="mt-4 text-center w-full">
                <.button
                  phx-click="paus_auth"
                  class="btn w-full hover:brightness-95 cursor-not-allowed"
                  disabled
                >
                  <span>
                    <img src={~p"/images/unpad_img.svg"} class="inline h-5 w-5" alt="PAuS logo" />
                  </span>
                   <span>PAuS ID</span>
                </.button>
              </div>
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
        %Accounts.User{} = user ->
          # Send magic link or confirmation instructions
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
