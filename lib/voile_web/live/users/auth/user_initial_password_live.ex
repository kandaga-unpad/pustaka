defmodule VoileWeb.UserInitialPasswordLive do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center justify-center min-h-[60vh]">
        <div class="w-full max-w-md bg-white/80 dark:bg-gray-800/70 backdrop-blur rounded-lg shadow-md p-6">
          <div class="mb-4 text-center">
            <.header>Set your initial password</.header>
            
            <p class="text-sm text-gray-600 dark:text-gray-300 mt-1">
              This account was imported with a default password. Choose a new secure password below to finish setting up your account.
            </p>
          </div>
          
          <.form
            for={@form}
            id="initial_password_form"
            phx-submit="set_password"
            phx-change="validate"
            class="space-y-4"
          >
            <.input
              field={@form[:password]}
              type="password"
              label="New password"
              required
            />
            <.input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              required
            />
            <div class="pt-2">
              <.button phx-disable-with="Setting..." class="w-full primary-btn">Set password</.button>
            </div>
          </.form>
          
          <div class="mt-5 text-center text-sm text-gray-600 dark:text-gray-300">
            <.link href={~p"/register"} class="underline mr-2">Register</.link>
            <span class="mx-1">·</span>
            <.link href={~p"/users/log_in"} class="underline ml-2">Log in</.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(params, _session, socket) do
    socket = assign_user_and_token(socket, params)

    form_source =
      case socket.assigns do
        %{user: user} ->
          Accounts.change_user_password(user)

        _ ->
          %{}
      end

    {:ok, assign_form(socket, form_source), temporary_assigns: [form: nil]}
  end

  def handle_event("set_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password set successfully. Please log in.")
         |> redirect(to: ~p"/login")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_password(socket.assigns.user, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_user_and_token(socket, %{"token" => token}) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      assign(socket, user: user, token: token)
    else
      socket
      |> put_flash(:error, "Set password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "user"))
  end
end
