defmodule VoileWeb.UserRegistrationLive do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.System

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto px-4 py-12">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8 items-center">
          <div class="flex items-center justify-center">
            <div class="max-w-sm text-center">
              <img
                src={System.get_setting_by_name("app_logo_url").setting_value || "/images/v.png"}
                class="mx-auto h-36 w-36 object-contain"
                alt="Voile logo"
              />
              <h3 class="mt-6 text-lg font-semibold">{gettext("Create your account")}</h3>

              <p class="mt-2 text-sm">
                {gettext(
                  "Join %{app_name} today and start explore collection, manage your favorite items, and connect with us.",
                  app_name: @app_name
                )}
              </p>
            </div>
          </div>

          <div class="default-card shadow rounded-lg border border-gray-100 p-6 md:p-8">
            <.header>
              {gettext("Register for an account")}
              <:subtitle>
                <span class="text-sm">
                  {gettext("Already registered?")}
                  <.link
                    navigate={~p"/login"}
                    class="font-semibold text-voile-primary hover:underline ml-1"
                  >
                    {gettext("Log in")}
                  </.link>
                  {gettext("to your account now.")}
                </span>
              </:subtitle>
            </.header>

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
                <.input field={@form[:email]} type="email" label={gettext("Email")} required />
                <.input field={@form[:password]} type="password" label={gettext("Password")} required />
                <.button phx-disable-with="Creating account..." class="default-btn w-full">
                  {gettext("Create an account")}
                </.button>
              </div>
            </.form>

            <div class="my-6 flex items-center gap-3">
              <hr class="flex-1 border-gray-300" />
              <span class="text-sm">{gettext("or register with")}</span>
              <hr class="flex-1 border-gray-300" />
            </div>

            <.button
              phx-click="google_auth"
              class="w-full btn border-2 border-blue-600 bg-white text-blue-600 hover:bg-blue-50"
            >
              <img
                src={~p"/images/google_img.png"}
                class="inline h-5 w-5 mr-2"
                alt="Google logo"
              /> <span>{gettext("Continue with Google")}</span>
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
