defmodule VoileWeb.Dashboard.Members.Clearance.Verify do
  use VoileWeb, :live_view_dashboard
  use Gettext, backend: VoileWeb.Gettext

  alias Voile.Clearance

  @impl true
  def mount(_params, _session, socket) do
    handle_mount_errors do
      authorize!(socket, "system.settings")

      socket =
        socket
        |> assign(:uuid_input, "")
        |> assign(:letter, nil)
        |> assign(:not_found, false)
        |> assign(:revoke_reason, "")
        |> assign(:show_revoke_form, false)

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("update_uuid", %{"uuid" => value}, socket) do
    {:noreply,
     assign(socket, uuid_input: value, letter: nil, not_found: false, show_revoke_form: false)}
  end

  @impl true
  def handle_event("verify", _params, socket) do
    uuid = String.trim(socket.assigns.uuid_input)

    if uuid == "" do
      {:noreply, socket}
    else
      letter = Clearance.get_letter(uuid)

      socket =
        if letter do
          socket
          |> assign(:letter, letter)
          |> assign(:not_found, false)
          |> assign(:show_revoke_form, false)
        else
          socket |> assign(:letter, nil) |> assign(:not_found, true)
        end

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_revoke_form", _params, socket) do
    {:noreply,
     assign(socket, show_revoke_form: not socket.assigns.show_revoke_form, revoke_reason: "")}
  end

  @impl true
  def handle_event("update_revoke_reason", %{"reason" => value}, socket) do
    {:noreply, assign(socket, :revoke_reason, value)}
  end

  @impl true
  def handle_event("revoke_letter", _params, socket) do
    reason = String.trim(socket.assigns.revoke_reason)

    if reason == "" do
      {:noreply, put_flash(socket, :error, gettext("Revocation reason is required."))}
    else
      admin_id = socket.assigns.current_scope.user.id

      case Clearance.revoke_letter(socket.assigns.letter, admin_id, reason) do
        {:ok, updated_letter} ->
          socket =
            socket
            |> assign(:letter, %{updated_letter | revoked_by: socket.assigns.letter.revoked_by})
            |> assign(:show_revoke_form, false)
            |> assign(:revoke_reason, "")
            |> put_flash(:info, gettext("Letter successfully revoked."))

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to revoke the letter."))}
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
  def render(assigns) do
    ~H"""
    <div class="space-y-6 bg-gray-100 dark:bg-gray-800 min-h-screen p-6 rounded-lg">
      <%!-- Breadcrumb --%>
      <.breadcrumb items={[
        %{label: gettext("Manage"), path: ~p"/manage"},
        %{label: gettext("Members"), path: ~p"/manage/members"},
        %{label: gettext("Clearance Letters"), path: ~p"/manage/members/clearance"},
        %{label: gettext("Verify"), path: nil}
      ]} />

      <%!-- Clearance sub-navigation --%>
      <.clearance_nav active={:verify} />

      <%!-- Page header --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
          {gettext("Verify & Revoke Clearance Letters")}
        </h1>
        <p class="text-gray-500 dark:text-gray-400 mt-1 text-sm">
          {gettext("Search a letter by its unique ID, then revoke it if necessary.")}
        </p>
      </div>

      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6 max-w-xl">
        <%!-- Search form --%>
        <form phx-submit="verify" id="verify-form" class="flex gap-2">
          <input
            id="uuid-input"
            name="uuid"
            type="text"
            value={@uuid_input}
            phx-change="update_uuid"
            placeholder={gettext("Paste letter ID (UUID)…")}
            class="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
          />
          <button
            type="submit"
            id="verify-submit-btn"
            class="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700"
          >
            {gettext("Search")}
          </button>
        </form>

        <%!-- Not found --%>
        <%= if @not_found do %>
          <div class="mt-5 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
            {gettext("No letter with that ID was found in the system.")}
          </div>
        <% end %>

        <%!-- Letter found --%>
        <%= if @letter do %>
          <div class="mt-5 rounded-lg border border-gray-200 bg-white shadow-sm divide-y divide-gray-100">
            <%!-- Header with status --%>
            <div class="flex items-center justify-between px-5 py-4">
              <h2 class="font-semibold text-gray-800">{gettext("Letter Detail")}</h2>
              <%= if @letter.is_revoked do %>
                <span class="inline-flex items-center gap-1.5 rounded-full bg-red-100 px-3 py-1 text-xs font-bold text-red-700">
                  <.icon name="hero-x-circle" class="w-3.5 h-3.5" /> {gettext("REVOKED")}
                </span>
              <% else %>
                <span class="inline-flex items-center gap-1.5 rounded-full bg-green-100 px-3 py-1 text-xs font-bold text-green-700">
                  <.icon name="hero-check-circle" class="w-3.5 h-3.5" /> {gettext("VALID")}
                </span>
              <% end %>
            </div>

            <%!-- Fields --%>
            <dl class="px-5 py-4 text-sm space-y-2">
              <div class="flex gap-2">
                <dt class="w-36 shrink-0 text-gray-500">{gettext("Letter Number")}</dt>
                <dd class="font-medium">{@letter.letter_number}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="w-36 shrink-0 text-gray-500">{gettext("Name")}</dt>
                <dd>{@letter.member_snapshot["fullname"]}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="w-36 shrink-0 text-gray-500">{gettext("Identifier")}</dt>
                <dd>{@letter.member_snapshot["identifier"]}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="w-36 shrink-0 text-gray-500">{gettext("Faculty / Unit")}</dt>
                <dd>{@letter.member_snapshot["node_name"]}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="w-36 shrink-0 text-gray-500">{gettext("Department")}</dt>
                <dd>{@letter.member_snapshot["department"]}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="w-36 shrink-0 text-gray-500">{gettext("Issued At")}</dt>
                <dd>{format_datetime(@letter.generated_at)}</dd>
              </div>
              <%= if @letter.is_revoked do %>
                <div class="flex gap-2 pt-2 border-t border-gray-100">
                  <dt class="w-36 shrink-0 text-red-500">{gettext("Revoked At")}</dt>
                  <dd class="text-red-700">{format_datetime(@letter.revoked_at)}</dd>
                </div>
                <%= if @letter.revoke_reason do %>
                  <div class="flex gap-2">
                    <dt class="w-36 shrink-0 text-red-500">{gettext("Reason")}</dt>
                    <dd class="text-red-700">{@letter.revoke_reason}</dd>
                  </div>
                <% end %>
              <% end %>
            </dl>

            <%!-- Actions --%>
            <div class="px-5 py-4 flex items-center gap-3">
              <.link
                href={~p"/clearance/surat/#{@letter.id}"}
                target="_blank"
                class="inline-flex items-center gap-1.5 text-sm text-indigo-600 hover:text-indigo-800 font-medium"
              >
                <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" /> {gettext(
                  "View Letter"
                )}
              </.link>

              <%= if not @letter.is_revoked do %>
                <button
                  id="toggle-revoke-btn"
                  phx-click="toggle_revoke_form"
                  class="inline-flex items-center gap-1.5 text-sm text-red-600 hover:text-red-800 font-medium ml-auto"
                >
                  <.icon name="hero-x-circle" class="w-4 h-4" /> {gettext("Revoke Letter")}
                </button>
              <% end %>
            </div>

            <%!-- Revoke form --%>
            <%= if @show_revoke_form and not @letter.is_revoked do %>
              <div class="px-5 py-4 bg-red-50 space-y-3">
                <p class="text-sm font-semibold text-red-800">{gettext("Confirm Revocation")}</p>
                <p class="text-xs text-red-600">
                  {gettext("Revocation is permanent and cannot be undone. Provide a clear reason.")}
                </p>
                <form phx-submit="revoke_letter" id="revoke-form" class="space-y-3">
                  <div>
                    <label for="revoke-reason" class="block text-xs font-medium text-red-800 mb-1">
                      {gettext("Revocation Reason *")}
                    </label>
                    <textarea
                      id="revoke-reason"
                      name="reason"
                      rows="3"
                      value={@revoke_reason}
                      phx-change="update_revoke_reason"
                      placeholder={gettext("Enter revocation reason…")}
                      class="w-full rounded border border-red-300 px-3 py-2 text-sm focus:border-red-500 focus:outline-none focus:ring-1 focus:ring-red-400"
                    ></textarea>
                  </div>
                  <div class="flex gap-2">
                    <button
                      type="submit"
                      id="confirm-revoke-btn"
                      class="rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white hover:bg-red-700"
                    >
                      {gettext("Revoke Letter")}
                    </button>
                    <button
                      type="button"
                      phx-click="toggle_revoke_form"
                      class="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                    >
                      {gettext("Cancel")}
                    </button>
                  </div>
                </form>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_datetime(nil), do: "-"

  defp format_datetime(%DateTime{} = dt) do
    months = ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
    month = Enum.at(months, dt.month - 1)
    "#{dt.day} #{month} #{dt.year}, #{pad2(dt.hour)}:#{pad2(dt.minute)}"
  end

  defp format_datetime(_), do: "-"

  defp pad2(n), do: String.pad_leading(to_string(n), 2, "0")
end
