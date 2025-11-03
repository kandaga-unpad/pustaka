defmodule VoileWeb.UserRegistrationLive do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts
  alias Voile.Schema.Accounts.User

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto px-4 py-12">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8 items-center">
          <div class="flex items-center justify-center">
            <div class="max-w-sm text-center">
              <img src={~p"/images/v.png"} class="mx-auto h-36 w-36 object-contain" alt="Voile logo" />
              <h3 class="mt-6 text-lg font-semibold text-gray-900">Create your account</h3>

              <p class="mt-2 text-sm text-gray-600">
                Join Voile to manage your projects and collaborate with your team.
              </p>
            </div>
          </div>

          <div class="default-card shadow rounded-lg border border-gray-100 p-6 md:p-8">
            <.header>
              Register for an account
              <:subtitle>
                <span class="text-sm text-gray-500">
                  Already registered?
                  <.link
                    navigate={~p"/login"}
                    class="font-semibold text-voile-primary hover:underline ml-1"
                  >
                    Log in
                  </.link>
                  to your account now.
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
                <.input field={@form[:email]} type="email" label="Email" required />
                <.input field={@form[:password]} type="password" label="Password" required />
                <.button phx-disable-with="Creating account..." class="default-btn w-full">
                  Create an account
                </.button>
              </div>
            </.form>

            <div class="my-6 flex items-center gap-3">
              <hr class="flex-1 border-gray-300" />
              <span class="text-sm text-gray-500">or register with</span>
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
              />
              <span>Continue with Google</span>
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
    user_params = Map.put(user_params, "username", username)

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
           "Account created successfully! Please check your email to confirm your account."
         )
         |> push_navigate(to: ~p"/users/pending_confirmation?email=#{user.email}")}

      {:error, %Ecto.Changeset{} = changeset} ->
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
