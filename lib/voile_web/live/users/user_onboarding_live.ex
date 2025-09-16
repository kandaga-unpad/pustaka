defmodule VoileWeb.UserOnboardingLive do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto px-4 py-12">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8 items-center">
          <div class="flex items-center justify-center">
            <div class="max-w-sm text-center">
              <img src={~p"/images/v.png"} class="mx-auto h-36 w-36 object-contain" alt="Voile logo" />
              <h3 class="mt-6 text-lg font-semibold text-gray-900">You're almost done</h3>
              
              <p class="mt-2 text-sm text-gray-600">
                Set a new password to finalize your account migration and access all of your data.
              </p>
            </div>
          </div>
          
          <div class="bg-white shadow rounded-lg border border-gray-100 p-6">
            <.header>
              Welcome to Voile!
              <:subtitle>
                <span class="text-sm text-gray-500">
                  Complete your account setup by setting a new password
                </span>
              </:subtitle>
            </.header>
            
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
              <div class="flex items-start">
                <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400 mt-1" />
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-blue-800">Account Migration Complete</h3>
                  
                  <p class="mt-2 text-sm text-blue-700">
                    Your account has been successfully migrated from the previous system.
                    Please set a new password to access your account and all your previous data.
                  </p>
                </div>
              </div>
            </div>
            
            <.form
              for={@form}
              id="onboarding_form"
              phx-submit="complete_onboarding"
              phx-change="validate"
            >
              <div class="space-y-4">
                <.input
                  field={@form[:password]}
                  type="password"
                  label="New password"
                  required
                  autocomplete="new-password"
                />
                <.input
                  field={@form[:password_confirmation]}
                  type="password"
                  label="Confirm new password"
                  required
                  autocomplete="new-password"
                />
                <.button phx-disable-with="Setting up your account..." class="w-full">
                  Complete Account Setup
                </.button>
              </div>
            </.form>
            
            <div class="mt-6 p-4 bg-gray-50 rounded-lg">
              <h4 class="text-sm font-medium text-gray-900 mb-2">What happens next?</h4>
              
              <ul class="text-sm text-gray-600 space-y-1">
                <li>• Your password will be securely updated</li>
                
                <li>• Your account will be confirmed and activated</li>
                
                <li>• You'll be logged in automatically</li>
                
                <li>• All your previous data will be available</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket = assign_user_and_token(socket, token)

    form_source =
      case socket.assigns do
        %{user: user} ->
          Accounts.change_user_password(user)

        _ ->
          %{}
      end

    {:ok, assign_form(socket, form_source), temporary_assigns: [form: nil]}
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> put_flash(:error, "Onboarding link is missing or invalid.")
     |> redirect(to: ~p"/login")}
  end

  def handle_event("complete_onboarding", %{"user" => user_params}, socket) do
    case Accounts.complete_user_onboarding(socket.assigns.user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Welcome! Your account has been set up successfully.")
         |> redirect(to: ~p"/users/log_in?email=#{user.email}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_password(socket.assigns.user, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_user_and_token(socket, token) do
    if user = Accounts.get_user_by_onboarding_token(token) do
      assign(socket, user: user, token: token)
    else
      socket
      |> put_flash(:error, "Onboarding link is invalid or has expired.")
      |> redirect(to: ~p"/login")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "user"))
  end
end
