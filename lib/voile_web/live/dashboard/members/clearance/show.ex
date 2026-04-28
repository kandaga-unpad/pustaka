defmodule VoileWeb.Dashboard.Members.Clearance.Show do
  use VoileWeb, :live_view_dashboard
  use Gettext, backend: VoileWeb.Gettext

  alias Voile.Clearance
  alias VoileWeb.Auth.Authorization
  alias VoileWeb.Utils.FormatIndonesiaTime

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    handle_mount_errors do
      authorize!(socket, "system.settings")

      user = socket.assigns.current_scope.user
      is_super_admin = Authorization.is_super_admin?(socket)

      letter =
        case Ecto.UUID.cast(id) do
          {:ok, uuid} -> Clearance.get_letter(uuid)
          :error -> nil
        end

      cond do
        is_nil(letter) ->
          {:ok,
           socket
           |> put_flash(:error, gettext("Clearance letter not found."))
           |> push_navigate(to: ~p"/manage/members/clearance")}

        (not is_super_admin and
           letter.member) && letter.member.node_id != user.node_id ->
          {:ok,
           socket
           |> put_flash(:error, gettext("You do not have access to this clearance letter."))
           |> push_navigate(to: ~p"/manage/members/clearance")}

        true ->
          socket =
            socket
            |> assign(:page_title, gettext("Clearance Letter Detail"))
            |> assign(:letter, letter)
            |> assign(:is_super_admin, is_super_admin)
            |> assign(:show_revoke_form, false)
            |> assign(:revoke_reason, "")

          {:ok, socket}
      end
    end
  end

  defp clearance_nav(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg">
      <nav
        class="flex gap-1 px-4 border-b border-gray-200 dark:border-gray-600"
        aria-label={gettext("Clearance navigation")}
      >
        <.link
          navigate={~p"/manage/members/clearance"}
          class={[
            "px-4 py-3 text-sm font-medium border-b-2 -mb-px transition-colors",
            if @active == :letters do
              "border-voile-primary text-voile-primary"
            else
              "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
            end
          ]}
        >
          <.icon name="hero-document-text" class="w-4 h-4 inline-block mr-1" />
          {gettext("Letters")}
        </.link>
        <.link
          navigate={~p"/manage/members/clearance/verify"}
          class={[
            "px-4 py-3 text-sm font-medium border-b-2 -mb-px transition-colors",
            if @active == :verify do
              "border-voile-primary text-voile-primary"
            else
              "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
            end
          ]}
        >
          <.icon name="hero-shield-check" class="w-4 h-4 inline-block mr-1" />
          {gettext("Verify")}
        </.link>
        <.link
          navigate={~p"/manage/members/clearance/settings"}
          class={[
            "px-4 py-3 text-sm font-medium border-b-2 -mb-px transition-colors",
            if @active == :settings do
              "border-voile-primary text-voile-primary"
            else
              "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
            end
          ]}
        >
          <.icon name="hero-cog-6-tooth" class="w-4 h-4 inline-block mr-1" />
          {gettext("Settings")}
        </.link>
      </nav>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_revoke_form", _params, socket) do
    {:noreply,
     assign(socket, show_revoke_form: not socket.assigns.show_revoke_form, revoke_reason: "")}
  end

  @impl true
  def handle_event("update_revoke_reason", %{"reason" => value}, socket) do
    {:noreply, assign(socket, revoke_reason: value)}
  end

  @impl true
  def handle_event("revoke", _params, socket) do
    reason = String.trim(socket.assigns.revoke_reason)
    letter = socket.assigns.letter
    user_id = socket.assigns.current_scope.user.id

    if reason == "" do
      {:noreply, put_flash(socket, :error, gettext("Please provide a revocation reason."))}
    else
      case Clearance.revoke_letter(letter, user_id, reason) do
        {:ok, updated_letter} ->
          {:noreply,
           socket
           |> assign(:letter, %{
             updated_letter
             | member: letter.member,
               revoked_by: socket.assigns.current_scope.user
           })
           |> assign(:show_revoke_form, false)
           |> assign(:revoke_reason, "")
           |> put_flash(:info, gettext("Letter successfully revoked."))}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to revoke the letter."))}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6 bg-gray-100 dark:bg-gray-800 min-h-screen p-6 rounded-lg">
      <%!-- Breadcrumb --%>
      <.breadcrumb items={[
        %{label: gettext("Manage"), path: ~p"/manage"},
        %{label: gettext("Members"), path: ~p"/manage/members"},
        %{label: gettext("Clearance Letters"), path: ~p"/manage/members/clearance"},
        %{label: @letter.letter_number, path: nil}
      ]} />

      <%!-- Clearance sub-navigation --%>
      <.clearance_nav active={:letters} />

      <%!-- Header --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
        <div class="flex items-start justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
              {@letter.letter_number}
            </h1>
            <p class="text-gray-500 dark:text-gray-400 mt-1 text-sm">
              {gettext("Generated on %{date}",
                date: FormatIndonesiaTime.format_utc_to_jakarta(@letter.generated_at)
              )}
            </p>
          </div>

          <div class="flex items-center gap-3">
            <%= if @letter.is_revoked do %>
              <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400">
                <.icon name="hero-x-circle" class="w-4 h-4 mr-1" />
                {gettext("Revoked")}
              </span>
            <% else %>
              <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400">
                <.icon name="hero-check-circle" class="w-4 h-4 mr-1" />
                {gettext("Active")}
              </span>
            <% end %>

            <%!-- Public letter link --%>
            <.link
              href={~p"/clearance/surat/#{@letter.id}"}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-1 px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 dark:bg-gray-600 dark:border-gray-500 dark:text-gray-200 dark:hover:bg-gray-500 transition-colors"
            >
              <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
              {gettext("View Public Letter")}
            </.link>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Member Information --%>
        <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
          <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
            {gettext("Member Information")}
          </h2>

          <dl class="space-y-3">
            <div class="flex flex-col sm:flex-row sm:justify-between">
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                {gettext("Full Name")}
              </dt>
              <dd class="mt-1 sm:mt-0 text-sm text-gray-900 dark:text-white font-medium">
                {@letter.member_snapshot["fullname"]}
              </dd>
            </div>

            <div class="flex flex-col sm:flex-row sm:justify-between">
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                {gettext("Identifier")}
              </dt>
              <dd class="mt-1 sm:mt-0 text-sm text-gray-900 dark:text-white">
                {@letter.member_snapshot["identifier"]}
              </dd>
            </div>

            <div class="flex flex-col sm:flex-row sm:justify-between">
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                {gettext("Department")}
              </dt>
              <dd class="mt-1 sm:mt-0 text-sm text-gray-900 dark:text-white">
                {@letter.member_snapshot["department"] || gettext("—")}
              </dd>
            </div>

            <div class="flex flex-col sm:flex-row sm:justify-between">
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                {gettext("Node")}
              </dt>
              <dd class="mt-1 sm:mt-0 text-sm text-gray-900 dark:text-white">
                {@letter.member_snapshot["node_name"] || gettext("—")}
              </dd>
            </div>

            <%= if @letter.member do %>
              <div class="flex flex-col sm:flex-row sm:justify-between">
                <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                  {gettext("Current Member")}
                </dt>
                <dd class="mt-1 sm:mt-0 text-sm text-voile-primary">
                  <.link
                    navigate={~p"/manage/members/management/#{@letter.member.id}"}
                    class="hover:underline"
                  >
                    {gettext("View Profile")}
                  </.link>
                </dd>
              </div>
            <% end %>
          </dl>
        </div>

        <%!-- Letter Details --%>
        <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
          <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
            {gettext("Letter Details")}
          </h2>

          <dl class="space-y-3">
            <div class="flex flex-col sm:flex-row sm:justify-between">
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                {gettext("Letter Number")}
              </dt>
              <dd class="mt-1 sm:mt-0 text-sm text-gray-900 dark:text-white font-mono">
                {@letter.letter_number}
              </dd>
            </div>

            <div class="flex flex-col sm:flex-row sm:justify-between">
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                {gettext("Sequence Number")}
              </dt>
              <dd class="mt-1 sm:mt-0 text-sm text-gray-900 dark:text-white">
                {@letter.sequence_number}
              </dd>
            </div>

            <div class="flex flex-col sm:flex-row sm:justify-between">
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                {gettext("Generated At")}
              </dt>
              <dd class="mt-1 sm:mt-0 text-sm text-gray-900 dark:text-white">
                {FormatIndonesiaTime.format_utc_to_jakarta(@letter.generated_at)}
              </dd>
            </div>

            <div class="flex flex-col sm:flex-row sm:justify-between">
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                {gettext("Letter UUID")}
              </dt>
              <dd class="mt-1 sm:mt-0 text-xs text-gray-500 dark:text-gray-400 font-mono break-all">
                {@letter.id}
              </dd>
            </div>
          </dl>
        </div>
      </div>

      <%!-- Revocation Info --%>
      <%= if @letter.is_revoked do %>
        <div class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-6">
          <h2 class="text-lg font-semibold text-red-800 dark:text-red-400 mb-4 flex items-center gap-2">
            <.icon name="hero-x-circle" class="w-5 h-5" />
            {gettext("Revocation Details")}
          </h2>

          <dl class="space-y-3">
            <div class="flex flex-col sm:flex-row sm:justify-between">
              <dt class="text-sm font-medium text-red-700 dark:text-red-400">
                {gettext("Revoked At")}
              </dt>
              <dd class="mt-1 sm:mt-0 text-sm text-red-900 dark:text-red-300">
                {FormatIndonesiaTime.format_utc_to_jakarta(@letter.revoked_at)}
              </dd>
            </div>

            <div class="flex flex-col sm:flex-row sm:justify-between">
              <dt class="text-sm font-medium text-red-700 dark:text-red-400">
                {gettext("Revoked By")}
              </dt>
              <dd class="mt-1 sm:mt-0 text-sm text-red-900 dark:text-red-300">
                {if @letter.revoked_by, do: @letter.revoked_by.fullname, else: gettext("—")}
              </dd>
            </div>

            <div class="flex flex-col">
              <dt class="text-sm font-medium text-red-700 dark:text-red-400">
                {gettext("Reason")}
              </dt>
              <dd class="mt-1 text-sm text-red-900 dark:text-red-300">
                {@letter.revoke_reason}
              </dd>
            </div>
          </dl>
        </div>
      <% else %>
        <%!-- Revoke action --%>
        <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
          <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
            {gettext("Revoke Letter")}
          </h2>
          <p class="text-sm text-gray-500 dark:text-gray-400 mb-4">
            {gettext("Revoking this letter will invalidate it. This action cannot be undone.")}
          </p>

          <%= if @show_revoke_form do %>
            <div class="space-y-3">
              <textarea
                id="revoke-reason-input"
                phx-keyup="update_revoke_reason"
                phx-value-reason={@revoke_reason}
                placeholder={gettext("Enter reason for revocation...")}
                rows="3"
                class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm dark:bg-gray-800 dark:border-gray-600 dark:text-white focus:outline-none focus:ring-2 focus:ring-red-500 focus:border-transparent"
              >{@revoke_reason}</textarea>

              <div class="flex items-center gap-3">
                <button
                  phx-click="revoke"
                  data-confirm={gettext("Are you sure you want to revoke this letter?")}
                  class="inline-flex items-center gap-1 px-4 py-2 text-sm font-semibold text-white bg-red-600 rounded-md hover:bg-red-700 transition-colors"
                >
                  <.icon name="hero-x-circle" class="w-4 h-4" />
                  {gettext("Confirm Revoke")}
                </button>

                <button
                  phx-click="toggle_revoke_form"
                  class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 dark:bg-gray-600 dark:border-gray-500 dark:text-gray-200 dark:hover:bg-gray-500 transition-colors"
                >
                  {gettext("Cancel")}
                </button>
              </div>
            </div>
          <% else %>
            <button
              phx-click="toggle_revoke_form"
              class="inline-flex items-center gap-1 px-4 py-2 text-sm font-semibold text-white bg-red-600 rounded-md hover:bg-red-700 transition-colors"
            >
              <.icon name="hero-x-circle" class="w-4 h-4" />
              {gettext("Revoke Letter")}
            </button>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
