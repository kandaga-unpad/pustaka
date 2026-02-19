defmodule VoileWeb.UserRegistrationLive do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.System

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="w-full min-h-screen mx-auto px-4 py-12 bg-gradient-voile flex items-center justify-center">
        <div class="max-w-5xl grid grid-cols-1 md:grid-cols-2 gap-4 items-center justify-center">
          <div class="flex items-center justify-center">
            <div class="max-w-sm text-center glass-card animate-fade-in p-8 rounded-xl shadow-lg border border-gray-100">
              <img
                src={System.get_setting_by_name("app_logo_url").setting_value || "/images/v.png"}
                class="mx-auto h-36 w-36 object-contain animate-fade-in"
                alt="Voile logo"
              />
              <h3 class="mt-6 text-2xl font-bold voile-text-gradient animate-fade-in flex items-center justify-center gap-2">
                <.icon name="hero-user-plus" class="w-7 h-7 text-voile-primary" />
                {gettext("Create your account")}
              </h3>
              <p class="mt-2 text-sm">
                {gettext(
                  "Join %{app_name} today and start explore collection, manage your favorite items, and connect with us.",
                  app_name: @app_name
                )}
              </p>
            </div>
          </div>
          <div class="glass-card animate-fade-in rounded-xl shadow-lg border border-gray-100 p-8">
            <.header>
              <span class="text-2xl font-bold voile-text-gradient flex items-center gap-2 mb-4">
                <.icon name="hero-user-circle" class="w-7 h-7 text-voile-primary" />
                {gettext("Register for an account")}
              </span>
              <:subtitle>
                <span class="text-sm">
                  {gettext("Already registered?")}
                </span>
              </:subtitle>
            </.header>
            <div class="flex mb-5 -mt-5 w-full">
              <.link
                navigate={~p"/login"}
                class="gradient-btn-outline font-semibold w-full text-sm text-center"
              >
                <.icon name="hero-arrow-left-on-rectangle" class="w-5 h-5 mr-1" />
                {gettext("Log in")}
              </.link>
            </div>
            <.form
              for={@form}
              id="registration_form"
              phx-submit="save"
              phx-change="validate"
              phx-trigger-action={@trigger_submit}
              action={~p"/users/log_in?_action=registered"}
              method="post"
            >
              <div class="space-y-4">
                <.input
                  field={@form[:email]}
                  type="email"
                  label={gettext("Email")}
                  required
                  class="default-input"
                />
                <div id="reg-password-wrapper" phx-hook="PasswordToggle">
                  <.input
                    field={@form[:password]}
                    type="password"
                    label={gettext("Password")}
                    required
                    class="default-input"
                  />
                </div>
                <.button phx-disable-with="Creating account..." class="gradient-btn w-full">
                  <.icon name="hero-user-plus" class="w-5 h-5 mr-1" />
                  {gettext("Create an account")}
                </.button>
              </div>
            </.form>
            <div class="my-6 flex items-center gap-3">
              <hr class="flex-1 border-voile-muted animate-fade-in" />
              <span class="text-sm text-voile-muted animate-fade-in">
                {gettext("or register with")}
              </span>
              <hr class="flex-1 border-voile-muted animate-fade-in" />
            </div>
            <.button
              phx-click="google_auth"
              class="gradient-btn-outline w-full flex items-center justify-center gap-2 bg-white text-voile-primary hover:shadow-md"
            >
              <img
                src={~p"/images/google_img.png"}
                class="inline h-5 w-5 mr-2"
                alt="Google logo"
              />
              <span>{gettext("Continue with Google")}</span>
            </.button>
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
      changeset = Accounts.change_user_registration(%User{})

      socket =
        socket
        |> assign(trigger_submit: false, check_errors: false)
        |> assign(app_name: Voile.Schema.System.get_setting_value("app_name", "Voile"))
        |> assign_form(changeset)

      {:ok, socket, temporary_assigns: [form: nil]}
    end
  end

  defp determine_redirect_path(user) do
    case user.user_type do
      %{slug: slug} when slug in ["administrator", "staff"] -> "/manage"
      _ -> "/"
    end
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    # add username to the user_params
    username = String.split(user_params["email"], "@") |> hd

    registration_date_value =
      case User.__schema__(:type, :registration_date) do
        :date -> Date.utc_today()
        _ -> Date.to_iso8601(Date.utc_today())
      end

    user_params =
      user_params
      |> Map.put("username", username)
      |> Map.put("registration_date", registration_date_value)

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        # Redirect to pending confirmation page instead of auto-login
        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext(
             "Account created successfully! Please check your email to confirm your account."
           )
         )
         |> push_navigate(to: ~p"/users/pending_confirmation?email=#{user.email}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Check if there's a username error and add a flash message
        socket =
          if Keyword.has_key?(changeset.errors, :username) do
            put_flash(
              socket,
              :error,
              gettext(
                "The username generated from your email is already taken. Please try a different email address."
              )
            )
          else
            socket
          end

        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("google_auth", _params, socket) do
    {:noreply, redirect(socket, to: "/auth/google")}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
