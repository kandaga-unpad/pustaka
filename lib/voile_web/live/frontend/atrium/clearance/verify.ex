defmodule VoileWeb.Frontend.Atrium.Clearance.Verify do
  use VoileWeb, :live_view
  use Gettext, backend: VoileWeb.Gettext

  alias Voile.Clearance
  alias VoileWeb.Utils.FormatIndonesiaTime

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:uuid_input, "")
      |> assign(:letter, nil)
      |> assign(:not_found, false)
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("update_uuid", %{"uuid" => value}, socket) do
    {:noreply, assign(socket, uuid_input: value, letter: nil, not_found: false)}
  end

  @impl true
  def handle_event("verify", _params, socket) do
    uuid = String.trim(socket.assigns.uuid_input)

    if uuid == "" do
      {:noreply, socket}
    else
      socket = assign(socket, :loading, true)
      letter = Clearance.get_letter(uuid)

      socket =
        if letter do
          socket |> assign(:letter, letter) |> assign(:not_found, false)
        else
          socket |> assign(:letter, nil) |> assign(:not_found, true)
        end

      {:noreply, assign(socket, :loading, false)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-7xl mx-auto px-4 py-10 sm:px-6 lg:px-8">
        <div class="grid gap-8 lg:grid-cols-[minmax(0,1fr)_340px]">
          <%!-- Main column --%>
          <div class="space-y-6">
            <%!-- Hero header --%>
            <section class="rounded-3xl border border-slate-800/80 bg-slate-950/95 p-8 shadow-xl shadow-slate-900/20 text-white">
              <div class="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-xs uppercase tracking-[0.24em] text-slate-200">
                <.icon name="hero-shield-check" class="w-4 h-4" /> {gettext("Verify Letter")}
              </div>
              <div class="mt-4 space-y-3">
                <h1 class="text-3xl font-semibold tracking-tight">
                  {gettext("Verify Library Clearance Letter")}
                </h1>
                <p class="max-w-2xl text-slate-300 leading-7">
                  {gettext(
                    "Enter the letter ID (UUID) to check the authenticity and status of the library clearance letter."
                  )}
                </p>
              </div>
            </section>

            <%!-- Search form --%>
            <div class="rounded-3xl border border-slate-200/70 bg-white shadow-sm dark:border-slate-700 dark:bg-slate-950/80">
              <div class="px-6 py-5 sm:px-8 sm:py-6">
                <p class="text-sm font-semibold uppercase tracking-[0.2em] text-indigo-600 dark:text-indigo-300">
                  {gettext("Search Letter")}
                </p>
                <h2 class="mt-3 text-xl font-semibold text-slate-900 dark:text-white">
                  {gettext("Enter Letter ID")}
                </h2>
                <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                  {gettext("The letter ID is a UUID, for example:")}
                  <span class="font-mono text-xs">a1b2c3d4-…</span>
                </p>
              </div>
              <div class="border-t border-slate-200/80 dark:border-slate-700 px-6 py-5 sm:px-8">
                <form phx-submit="verify" id="verify-form" class="flex flex-col gap-3 sm:flex-row">
                  <input
                    id="uuid-input"
                    name="uuid"
                    type="text"
                    value={@uuid_input}
                    phx-change="update_uuid"
                    placeholder={gettext("Enter letter ID…")}
                    class="flex-1 rounded-xl border border-slate-300 bg-white px-4 py-2.5 text-sm text-slate-900 placeholder-slate-400 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 dark:border-slate-700 dark:bg-slate-900 dark:text-white dark:placeholder-slate-500"
                  />
                  <button
                    type="submit"
                    id="verify-submit-btn"
                    class="inline-flex items-center justify-center gap-2 rounded-xl bg-indigo-600 px-5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-700 disabled:opacity-60"
                  >
                    <.icon name="hero-magnifying-glass" class="w-4 h-4" /> {gettext("Check")}
                  </button>
                </form>
              </div>
            </div>

            <%!-- Not found --%>
            <%= if @not_found do %>
              <div class="rounded-3xl border border-red-200 bg-red-50 p-6 dark:border-red-700/30 dark:bg-red-950/20">
                <div class="flex items-start gap-3">
                  <.icon name="hero-x-circle" class="w-5 h-5 shrink-0 text-red-600 dark:text-red-400" />
                  <div>
                    <p class="font-semibold text-red-800 dark:text-red-200">
                      {gettext("Letter not found")}
                    </p>
                    <p class="mt-1 text-sm text-red-700 dark:text-red-300">
                      {gettext("The letter ID is invalid or not registered in the system.")}
                    </p>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Letter result --%>
            <%= if @letter do %>
              <div class={[
                "rounded-3xl border p-6 sm:p-8",
                if(@letter.is_revoked,
                  do: "border-red-200 bg-red-50 dark:border-red-700/40 dark:bg-red-950/20",
                  else:
                    "border-emerald-200 bg-emerald-50 dark:border-emerald-700/40 dark:bg-emerald-950/20"
                )
              ]}>
                <%!-- Status header --%>
                <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-6">
                  <h2 class={[
                    "text-lg font-semibold",
                    if(@letter.is_revoked,
                      do: "text-red-900 dark:text-red-100",
                      else: "text-emerald-900 dark:text-emerald-100"
                    )
                  ]}>
                    {gettext("Letter details")}
                  </h2>
                  <%= if @letter.is_revoked do %>
                    <span class="inline-flex items-center gap-1.5 self-start rounded-full bg-red-100 px-3 py-1 text-sm font-bold text-red-700 border border-red-300 dark:bg-red-900/30 dark:text-red-300 dark:border-red-700/50">
                      <.icon name="hero-x-circle" class="w-4 h-4" /> {gettext("REVOKED")}
                    </span>
                  <% else %>
                    <span class="inline-flex items-center gap-1.5 self-start rounded-full bg-emerald-100 px-3 py-1 text-sm font-bold text-emerald-700 border border-emerald-300 dark:bg-emerald-900/30 dark:text-emerald-300 dark:border-emerald-700/50">
                      <.icon name="hero-check-circle" class="w-4 h-4" /> {gettext("VALID")}
                    </span>
                  <% end %>
                </div>

                <%!-- Fields --%>
                <dl class="grid gap-3 sm:grid-cols-2">
                  <div class="rounded-2xl border border-slate-200/70 bg-white/80 px-4 py-3 dark:border-slate-700 dark:bg-slate-900/60">
                    <dt class="text-xs uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400">
                      {gettext("Letter number")}
                    </dt>
                    <dd class="mt-1 font-semibold text-slate-900 dark:text-white">
                      {@letter.letter_number}
                    </dd>
                  </div>
                  <div class="rounded-2xl border border-slate-200/70 bg-white/80 px-4 py-3 dark:border-slate-700 dark:bg-slate-900/60">
                    <dt class="text-xs uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400">
                      {gettext("Issued date")}
                    </dt>
                    <dd class="mt-1 font-semibold text-slate-900 dark:text-white">
                      {format_datetime(@letter.generated_at)}
                    </dd>
                  </div>
                  <div class="rounded-2xl border border-slate-200/70 bg-white/80 px-4 py-3 dark:border-slate-700 dark:bg-slate-900/60">
                    <dt class="text-xs uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400">
                      {gettext("Name")}
                    </dt>
                    <dd class="mt-1 font-semibold text-slate-900 dark:text-white">
                      {@letter.member_snapshot["fullname"]}
                    </dd>
                  </div>
                  <div class="rounded-2xl border border-slate-200/70 bg-white/80 px-4 py-3 dark:border-slate-700 dark:bg-slate-900/60">
                    <dt class="text-xs uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400">
                      {gettext("Student / Employee ID")}
                    </dt>
                    <dd class="mt-1 font-semibold text-slate-900 dark:text-white">
                      {@letter.member_snapshot["identifier"]}
                    </dd>
                  </div>
                  <div class="rounded-2xl border border-slate-200/70 bg-white/80 px-4 py-3 dark:border-slate-700 dark:bg-slate-900/60">
                    <dt class="text-xs uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400">
                      {gettext("Faculty / Unit")}
                    </dt>
                    <dd class="mt-1 font-semibold text-slate-900 dark:text-white">
                      {@letter.member_snapshot["node_name"]}
                    </dd>
                  </div>
                  <div class="rounded-2xl border border-slate-200/70 bg-white/80 px-4 py-3 dark:border-slate-700 dark:bg-slate-900/60">
                    <dt class="text-xs uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400">
                      {gettext("Study program")}
                    </dt>
                    <dd class="mt-1 font-semibold text-slate-900 dark:text-white">
                      {@letter.member_snapshot["department"] || "—"}
                    </dd>
                  </div>
                </dl>

                <%!-- Revocation info --%>
                <%= if @letter.is_revoked do %>
                  <div class="mt-5 rounded-2xl border border-red-200 bg-red-50/80 px-4 py-4 dark:border-red-700/40 dark:bg-red-950/30 space-y-2">
                    <div class="flex gap-3">
                      <span class="text-xs uppercase tracking-[0.18em] text-red-500 w-28 shrink-0 dark:text-red-400">
                        {gettext("Revoked on")}
                      </span>
                      <span class="text-sm font-medium text-red-700 dark:text-red-200">
                        {format_datetime(@letter.revoked_at)}
                      </span>
                    </div>
                    <%= if @letter.revoke_reason do %>
                      <div class="flex gap-3">
                        <span class="text-xs uppercase tracking-[0.18em] text-red-500 w-28 shrink-0 dark:text-red-400">
                          {gettext("Reason")}
                        </span>
                        <span class="text-sm font-medium text-red-700 dark:text-red-200">
                          {@letter.revoke_reason}
                        </span>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <%!-- View public letter --%>
                <div class="mt-5 flex justify-end">
                  <.link
                    navigate={~p"/clearance/surat/#{@letter.id}"}
                    class="inline-flex items-center gap-1.5 text-sm font-medium text-indigo-600 hover:text-indigo-800 dark:text-indigo-400 dark:hover:text-indigo-200"
                    target="_blank"
                  >
                    <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" /> {gettext(
                      "View letter"
                    )}
                  </.link>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Sidebar --%>
          <aside class="space-y-6">
            <div class="rounded-3xl border border-slate-200 bg-white shadow-sm p-6 dark:border-slate-700 dark:bg-slate-950/80">
              <div class="flex items-start gap-3">
                <div class="rounded-2xl bg-indigo-500/10 p-3 text-indigo-700 dark:bg-indigo-500/15 dark:text-indigo-200">
                  <.icon name="hero-information-circle" class="w-5 h-5" />
                </div>
                <div>
                  <p class="text-sm font-semibold text-slate-900 dark:text-white">
                    {gettext("How to verify")}
                  </p>
                  <p class="mt-2 text-sm text-slate-600 dark:text-slate-400">
                    {gettext(
                      "Enter the letter ID (UUID) shown on the clearance letter. The ID can be found at the bottom of the letter or in the QR code link."
                    )}
                  </p>
                </div>
              </div>

              <div class="mt-5 space-y-3">
                <div class="rounded-3xl border border-slate-200 bg-slate-50 p-4 dark:border-slate-700 dark:bg-slate-900/80">
                  <p class="text-xs uppercase tracking-[0.2em] text-slate-500 dark:text-slate-400">
                    {gettext("Status VALID")}
                  </p>
                  <p class="mt-2 text-sm text-slate-700 dark:text-slate-300">
                    {gettext("The letter is still active and has not been revoked by the library.")}
                  </p>
                </div>
                <div class="rounded-3xl border border-slate-200 bg-slate-50 p-4 dark:border-slate-700 dark:bg-slate-900/80">
                  <p class="text-xs uppercase tracking-[0.2em] text-slate-500 dark:text-slate-400">
                    {gettext("Status REVOKED")}
                  </p>
                  <p class="mt-2 text-sm text-slate-700 dark:text-slate-300">
                    {gettext(
                      "The letter has been revoked and is no longer valid. Contact the library for more information."
                    )}
                  </p>
                </div>
              </div>
            </div>
          </aside>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_datetime(nil), do: "-"

  defp format_datetime(%DateTime{} = dt) do
    FormatIndonesiaTime.format_utc_to_jakarta(dt)
  end

  defp format_datetime(_), do: "-"
end
