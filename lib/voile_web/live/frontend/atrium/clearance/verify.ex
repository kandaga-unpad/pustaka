defmodule VoileWeb.Frontend.Atrium.Clearance.Verify do
  use VoileWeb, :live_view
  use Gettext, backend: VoileWeb.Gettext

  alias Voile.Clearance

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
      <div class="max-w-lg mx-auto px-4 py-10">
        <div class="mb-6">
          <h1 class="text-2xl font-bold text-gray-900">Verifikasi Surat Bebas Perpustakaan</h1>
          <p class="text-gray-500 mt-1 text-sm">
            Masukkan ID surat untuk memeriksa keabsahannya
          </p>
        </div>

        <form phx-submit="verify" id="verify-form" class="flex gap-2">
          <input
            id="uuid-input"
            name="uuid"
            type="text"
            value={@uuid_input}
            phx-change="update_uuid"
            placeholder="Masukkan ID surat…"
            class="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
          />
          <button
            type="submit"
            id="verify-submit-btn"
            class="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700 disabled:opacity-60"
          >
            Periksa
          </button>
        </form>

        <%= if @not_found do %>
          <div class="mt-6 rounded-lg border border-red-200 bg-red-50 p-5 text-center">
            <.icon name="hero-x-circle" class="w-8 h-8 text-red-400 mx-auto" />
            <p class="mt-2 font-semibold text-red-700">Surat tidak ditemukan</p>
            <p class="text-sm text-red-600 mt-1">
              ID surat tidak valid atau tidak terdaftar dalam sistem.
            </p>
          </div>
        <% end %>

        <%= if @letter do %>
          <div class={[
            "mt-6 rounded-lg border p-5",
            if(@letter.is_revoked,
              do: "border-red-300 bg-red-50",
              else: "border-green-300 bg-green-50"
            )
          ]}>
            <%!-- Status badge --%>
            <div class="flex items-center justify-between mb-4">
              <h2 class="font-semibold text-gray-800 text-base">Detail Surat</h2>
              <%= if @letter.is_revoked do %>
                <span class="inline-flex items-center gap-1.5 rounded-full bg-red-100 px-3 py-1 text-sm font-bold text-red-700 border border-red-300">
                  <.icon name="hero-x-circle" class="w-4 h-4" /> DICABUT
                </span>
              <% else %>
                <span class="inline-flex items-center gap-1.5 rounded-full bg-green-100 px-3 py-1 text-sm font-bold text-green-700 border border-green-300">
                  <.icon name="hero-check-circle" class="w-4 h-4" /> VALID
                </span>
              <% end %>
            </div>

            <dl class="text-sm space-y-2">
              <div class="flex gap-2">
                <dt class="w-36 shrink-0 text-gray-500">Nomor Surat</dt>
                <dd class="font-medium text-gray-900">{@letter.letter_number}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="w-36 shrink-0 text-gray-500">Nama</dt>
                <dd class="text-gray-900">{@letter.member_snapshot["fullname"]}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="w-36 shrink-0 text-gray-500">NIM / NPM / NIP</dt>
                <dd class="text-gray-900">{@letter.member_snapshot["identifier"]}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="w-36 shrink-0 text-gray-500">Fakultas / Unit</dt>
                <dd class="text-gray-900">{@letter.member_snapshot["node_name"]}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="w-36 shrink-0 text-gray-500">Program Studi</dt>
                <dd class="text-gray-900">{@letter.member_snapshot["department"]}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="w-36 shrink-0 text-gray-500">Tanggal Terbit</dt>
                <dd class="text-gray-900">{format_datetime(@letter.generated_at)}</dd>
              </div>
              <%= if @letter.is_revoked do %>
                <div class="flex gap-2 pt-2 border-t border-red-200">
                  <dt class="w-36 shrink-0 text-red-500">Dicabut pada</dt>
                  <dd class="text-red-700">{format_datetime(@letter.revoked_at)}</dd>
                </div>
                <%= if @letter.revoke_reason do %>
                  <div class="flex gap-2">
                    <dt class="w-36 shrink-0 text-red-500">Alasan</dt>
                    <dd class="text-red-700">{@letter.revoke_reason}</dd>
                  </div>
                <% end %>
              <% end %>
            </dl>

            <div class="mt-4 pt-3 border-t border-gray-200 flex justify-end">
              <.link
                navigate={~p"/clearance/surat/#{@letter.id}"}
                class="text-sm text-indigo-600 hover:text-indigo-800 font-medium inline-flex items-center gap-1"
                target="_blank"
              >
                <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" /> Lihat surat
              </.link>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp format_datetime(nil), do: "-"

  defp format_datetime(%DateTime{} = dt) do
    months = ~w(Jan Feb Mar Apr Mei Jun Jul Agu Sep Okt Nov Des)
    month = Enum.at(months, dt.month - 1)
    "#{dt.day} #{month} #{dt.year}, #{pad2(dt.hour)}:#{pad2(dt.minute)} WIB"
  end

  defp format_datetime(_), do: "-"

  defp pad2(n), do: String.pad_leading(to_string(n), 2, "0")
end
