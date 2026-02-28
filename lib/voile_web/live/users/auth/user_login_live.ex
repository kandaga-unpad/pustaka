defmodule VoileWeb.UserLoginLive do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts

  def render(assigns) do
    ~H"""
    <.modal id="magic-link-modal">
      <div class="animate-fade-in p-8 max-w-md mx-auto">
        <h3 class="text-2xl font-bold voile-text-gradient mb-2 flex items-center gap-2">
          <.icon name="hero-link" class="size-6 text-voile-primary" />
          {gettext("Login with Email Link")}
        </h3>
        <p class="text-sm text-voile-muted mb-4">
          {gettext("Enter your email and we'll send a secure login link. No password required.")}
        </p>
        <.form for={@magic_link_form} phx-submit="send_magic_link">
          <.input
            field={@magic_link_form[:email]}
            type="email"
            label={gettext("Email Address")}
            placeholder="you@example.com"
            required
            class="default-input"
          />
          <div class="flex gap-3 justify-end mt-6">
            <.button
              type="button"
              phx-click={hide_modal("magic-link-modal")}
              class="cancel-btn"
            >
              <.icon name="hero-x-mark" class="w-5 h-5 mr-1" />
              {gettext("Cancel")}
            </.button>
            <.button
              type="submit"
              phx-disable-with="Sending..."
              class="gradient-btn"
            >
              <.icon name="hero-paper-airplane" class="w-5 h-5 mr-1" />
              {gettext("Send Login Link")}
            </.button>
          </div>
        </.form>
      </div>
    </.modal>

    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen h-full flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8 bg-gradient-voile">
        <div class="w-full max-w-5xl">
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 items-center">
            <!-- Left: Brand / Illustration -->
            <div class="hidden lg:flex flex-col justify-center items-start px-6 py-8 glass-card animate-fade-in rounded-xl text-voile-surface">
              <h1 class="text-4xl font-extrabold mb-2 voile-text-gradient animate-fade-in text-center">
                <.icon name="hero-lock-closed" class="w-8 h-8 mr-2 inline-block text-voile-primary" />
                <br />
                {gettext("Welcome back to")} {@app_name}
              </h1>
              <p class="text-voile-dark/90 dark:text-voile-light max-w-prose mb-6">
                {gettext(
                  "Sign in to access your dashboard, manage content, and explore features built for creators and teams."
                )}
              </p>
              <ul class="space-y-3">
                <li class="flex items-center gap-3">
                  <.icon name="hero-bolt" class="w-5 h-5 text-voile-accent" />
                  <span class="text-voile-dark/90 dark:text-voile-light">
                    {gettext("Fast, secure login")}
                  </span>
                </li>
                <li class="flex items-center gap-3">
                  <.icon name="hero-user-group" class="w-5 h-5 text-voile-accent" />
                  <span class="text-voile-dark/90 dark:text-voile-light">
                    {gettext("Passwordless and social auth")}
                  </span>
                </li>
                <li class="flex items-center gap-3">
                  <.icon name="hero-device-phone-mobile" class="w-5 h-5 text-voile-accent" />
                  <span class="text-voile-dark/90 dark:text-voile-light">
                    {gettext("Accessible & responsive")}
                  </span>
                </li>
              </ul>
            </div>
            <!-- Right: Form Card -->
            <div class="glass-card animate-fade-in rounded-xl shadow-lg p-8">
              <div class="flex items-center justify-between mb-6">
                <div class="w-full">
                  <h2 class="text-3xl font-bold voile-text-gradient mb-2 flex items-center gap-2">
                    <.icon name="hero-user-circle" class="w-7 h-7 text-voile-primary" />
                    {gettext("Sign in to your account")}
                  </h2>
                  <div class="flex flex-col w-full">
                    <p class="text-sm italic">{gettext("Don't have an account?")}</p>
                    <.link
                      navigate={~p"/register"}
                      class="gradient-btn-outline bg-gray-300 mt-2 text-sm text-center w-full"
                    >
                      <.icon name="hero-user-plus" class="w-5 h-5 mr-1" />
                      {gettext("Register")}
                    </.link>
                  </div>
                </div>
              </div>
              <.form for={@form} id="login_form" action={~p"/users/log_in"} class="space-y-4">
                <.input
                  field={@form[:email]}
                  type="text"
                  label={gettext("Email, Username, or Identifier")}
                  placeholder={gettext("Enter your email, username, or identifier")}
                  required
                  class="default-input"
                />
                <div id="login-password-wrapper" phx-hook="PasswordToggle">
                  <.input
                    field={@form[:password]}
                    type="password"
                    label={gettext("Password")}
                    required
                    class="default-input"
                  />
                </div>
                <div class="flex items-center justify-between gap-4">
                  <.input
                    field={@form[:remember_me]}
                    type="checkbox"
                    label={gettext("Keep me logged in")}
                  />
                  <.link
                    href={~p"/users/reset_password"}
                    class="text-sm font-semibold hover:underline"
                  >
                    {gettext("Forgot your password?")}
                  </.link>
                </div>
                <.button type="submit" phx-disable-with="Logging in..." class="gradient-btn w-full">
                  <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5 mr-1" />
                  {gettext("Log in")}
                </.button>
              </.form>
              <div class="my-6 flex items-center gap-3">
                <hr class="flex-1 border-voile-muted animate-fade-in" />
                <span class="text-sm text-voile-muted animate-fade-in">
                  {gettext("or continue with")}
                </span>
                <hr class="flex-1 border-voile-muted animate-fade-in" />
              </div>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <.button
                  phx-click="google_auth"
                  class="gradient-btn-outline flex items-center justify-center gap-2 text-xs bg-white text-voile-primary hover:shadow-md"
                >
                  <img
                    src={~p"/images/google_img.png"}
                    class="inline h-5 w-5"
                    alt="Google logo"
                  />
                  <span>Google</span>
                </.button>
                <.button
                  type="button"
                  phx-click={show_modal("magic-link-modal")}
                  class="gradient-btn flex items-center gap-2 text-xs text-white"
                >
                  <.icon name="hero-link" class="size-4 opacity-75 hover:opacity-100" />
                  <span>{gettext("Login passwordless")}</span>
                </.button>
              </div>
              <div class="mt-4 text-center w-full">
                <.button
                  phx-click="paus_auth"
                  class="disabled-btn bg-gray-400 w-full flex items-center justify-center gap-2 text-sm"
                  disabled
                >
                  <img src={~p"/images/unpad_img.svg"} class="inline h-5 w-5" alt="PAuS logo" />
                  <span class="text-gray-300">{gettext("PAuS ID")}</span>
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

      # Get app name for display
      app_name = Voile.Schema.System.get_setting_value("app_name", "Voile")

      form = to_form(%{"email" => email}, as: "user")
      magic_link_form = to_form(%{"email" => ""}, as: "magic_link")

      {:ok,
       socket
       |> assign(form: form)
       |> assign(magic_link_form: magic_link_form)
       |> assign(app_name: app_name),
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
                 gettext("We've sent a login link to %{email}. Please check your email.",
                   email: email
                 )
               )
               |> redirect(to: ~p"/login")}

            {:error, _} ->
              {:noreply,
               put_flash(socket, :error, gettext("Unable to send email. Please try again."))}
          end

        nil ->
          # User doesn't exist
          {:noreply,
           put_flash(socket, :error, gettext("No account found with that email address."))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("Please enter your email address."))}
    end
  end

  def handle_event("google_auth", _params, socket) do
    {:noreply, redirect(socket, to: "/auth/google")}
  end

  def handle_event("paus_auth", _params, socket) do
    {:noreply, redirect(socket, to: "/auth/paus")}
  end
end
