defmodule VoileWeb.UserLoginLive do
  use VoileWeb, :live_view

  def render(assigns) do
    ~H"""
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
        
        <div class="flex flex-col gap-8 items-center lg:flex-row lg:gap-36">
          <.form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore">
            <.input field={@form[:email]} type="email" label="Email" required />
            <.input field={@form[:password]} type="password" label="Password" required />
            <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
            <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
              Forgot your password?
            </.link>
            <.button phx-disable-with="Logging in..." class="default-btn w-full">
              Log in <span aria-hidden="true">→</span>
            </.button>
          </.form>
          
          <div>
            <%= if @current_scope === nil do %>
              <.button phx-click="google_auth" class="default-btn">Login with Google</.button>
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
      {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
    end
  end

  defp determine_redirect_path(user) do
    case user.user_type do
      %{slug: slug} when slug in ["administrator", "staff"] -> "/manage"
      _ -> "/"
    end
  end

  def handle_event("google_auth", _params, socket) do
    {:noreply, redirect(socket, to: "/auth/google")}
  end
end
