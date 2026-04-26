defmodule VoileWeb.Frontend.Clearance.ShowLetter do
  use VoileWeb, :live_view
  use Gettext, backend: VoileWeb.Gettext

  alias Voile.Clearance
  alias VoileWeb.Utils.FormatIndonesiaTime

  @impl true
  def mount(%{"uuid" => uuid}, _session, socket) do
    letter = Clearance.get_letter(uuid)
    settings = Clearance.get_settings()
    app_logo_url = Voile.Schema.System.get_setting_value("app_logo_url", nil)

    socket =
      socket
      |> assign(:letter, letter)
      |> assign(:settings, settings)
      |> assign(:app_logo_url, app_logo_url)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="print:hidden px-6 py-3 bg-gray-50 border-b border-gray-200">
      <button
        onclick="history.back()"
        class="inline-flex items-center gap-1.5 text-sm font-medium text-gray-600 hover:text-gray-900"
      >
        <.icon name="hero-arrow-left" class="w-4 h-4" /> Kembali
      </button>
    </div>
    <%= if is_nil(@letter) do %>
      <div class="min-h-screen flex items-center justify-center">
        <div class="text-center">
          <.icon name="hero-document-magnifying-glass" class="w-16 h-16 text-gray-300 mx-auto" />
          <h1 class="mt-4 text-xl font-semibold text-gray-700">Surat tidak ditemukan</h1>
          <p class="text-gray-500 mt-2 text-sm">
            ID surat tidak valid atau telah dihapus dari sistem.
          </p>
        </div>
      </div>
    <% else %>
      <%!-- Print button — hidden when printing --%>
      <div class="print:hidden flex justify-end gap-3 px-6 py-3 bg-gray-50 border-b border-gray-200">
        <button
          onclick="window.print()"
          class="inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700"
        >
          <.icon name="hero-printer" class="w-4 h-4" /> Cetak Surat
        </button>
        <%= if @letter.is_revoked do %>
          <span class="inline-flex items-center rounded-full bg-red-100 px-3 py-1 text-sm font-semibold text-red-700">
            DICABUT
          </span>
        <% else %>
          <span class="inline-flex items-center rounded-full bg-green-100 px-3 py-1 text-sm font-semibold text-green-700">
            VALID
          </span>
        <% end %>
      </div>

      <%!-- Revoked banner --%>
      <%= if @letter.is_revoked do %>
        <div class="print:border print:border-red-400 bg-red-50 border-b-2 border-red-300 px-6 py-3 text-center text-sm font-semibold text-red-700">
          SURAT INI TELAH DICABUT / REVOKED
          <%= if @letter.revoke_reason do %>
            — {@letter.revoke_reason}
          <% end %>
        </div>
      <% end %>

      <%!-- Letter body — A4-style --%>
      <div class="max-w-[794px] mx-auto my-6 print:my-0 bg-white shadow-md print:shadow-none border border-gray-200 print:border-0 p-12 print:p-10 font-serif text-gray-900">
        <%!-- Letterhead --%>
        <div class="pb-3 mb-6" style="border-bottom: 4px double #1f2937;">
          <div class="flex items-center gap-5">
            <div class="shrink-0">
              <img
                src={@app_logo_url || "/images/v.png"}
                alt="Logo"
                class="h-20 w-auto object-contain"
              />
            </div>
            <div class="flex-1 text-center">
              <%= if @settings["institution_subtitle"] && @settings["institution_subtitle"] != "" do %>
                <p class="text-xs font-semibold uppercase tracking-wide text-gray-700">
                  {@settings["institution_subtitle"]}
                </p>
              <% end %>
              <p class="text-lg font-bold uppercase tracking-wide mt-0.5">
                {@settings["institution_name"]}
              </p>
              <%= if @settings["institution_address"] && @settings["institution_address"] != "" do %>
                <p class="text-xs mt-1 text-gray-700">{@settings["institution_address"]}</p>
              <% end %>
              <% contact_parts =
                Enum.reject(
                  [
                    if(@settings["institution_phone"] && @settings["institution_phone"] != "",
                      do: "Telp. " <> @settings["institution_phone"],
                      else: nil
                    ),
                    if(@settings["institution_email"] && @settings["institution_email"] != "",
                      do: "E-mail : " <> @settings["institution_email"],
                      else: nil
                    )
                  ],
                  &is_nil/1
                ) %>
              <%= if contact_parts != [] do %>
                <p class="text-xs text-gray-700">{Enum.join(contact_parts, " , ")}</p>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Title --%>
        <div class="text-center mb-6">
          <h2 class="text-base font-bold uppercase underline tracking-wider">
            Surat Keterangan Bebas Perpustakaan
          </h2>
          <p class="text-sm mt-1">Nomor: {@letter.letter_number}</p>
        </div>

        <%!-- Opening paragraph --%>
        <p class="text-sm leading-relaxed mb-5">
          Yang bertanda tangan di bawah ini menerangkan bahwa:
        </p>

        <%!-- Member info table --%>
        <table class="w-full text-sm mb-6">
          <tbody>
            <tr>
              <td class="py-1 w-40">Nama</td>
              <td class="py-1 w-4">:</td>
              <td class="py-1 font-semibold">{@letter.member_snapshot["fullname"]}</td>
            </tr>
            <tr>
              <td class="py-1">NIM / NPM / NIP</td>
              <td class="py-1">:</td>
              <td class="py-1">{@letter.member_snapshot["identifier"]}</td>
            </tr>
            <tr>
              <td class="py-1">Fakultas / Unit</td>
              <td class="py-1">:</td>
              <td class="py-1">{@letter.member_snapshot["node_name"]}</td>
            </tr>
            <tr>
              <td class="py-1">Program Studi / Dept.</td>
              <td class="py-1">:</td>
              <td class="py-1">{@letter.member_snapshot["department"]}</td>
            </tr>
          </tbody>
        </table>

        <%!-- Body text --%>
        <div class="text-sm leading-relaxed mb-5">
          {Phoenix.HTML.raw(HtmlSanitizeEx.basic_html(@settings["body_text"] || ""))}
        </div>

        <div class="text-sm leading-relaxed mb-10">
          {Phoenix.HTML.raw(HtmlSanitizeEx.basic_html(@settings["closing_text"] || ""))}
        </div>

        <%!-- City, date, signature --%>
        <div class="flex justify-end">
          <div class="text-center text-sm w-64">
            <p class="mb-1">
              {if @settings["city"] && @settings["city"] != "",
                do: @settings["city"] <> ", ",
                else: ""}
              {FormatIndonesiaTime.format_indonesian_date_specific(@letter.generated_at)}
            </p>

            <%= if @settings["signer_title"] && @settings["signer_title"] != "" do %>
              <p class="font-medium">{@settings["signer_title"]}</p>
            <% end %>

            <div class="my-4 h-20 flex items-end justify-center">
              <%= if @settings["signature_image"] && @settings["signature_image"] != "" do %>
                <img
                  src={@settings["signature_image"]}
                  alt="Tanda tangan"
                  class="max-h-20 max-w-[180px] object-contain"
                />
              <% else %>
                <div class="h-16" />
              <% end %>
            </div>

            <p class="font-bold underline">{@settings["signer_name"]}</p>
            <%= if @settings["signer_nip"] && @settings["signer_nip"] != "" do %>
              <p>NIP. {@settings["signer_nip"]}</p>
            <% end %>
          </div>
        </div>

        <%!-- UUID footer with QR code --%>
        <div class="mt-10 pt-4 border-t border-gray-200">
          <div class="grid items-start gap-4 sm:grid-cols-[auto_1fr]">
            <div class="flex items-center justify-center rounded-lg border border-gray-200 bg-white p-2">
              <img
                src={~p"/clearance/surat/#{@letter.id}/qrcode"}
                alt="QR code"
                class="h-14 w-14"
              />
            </div>

            <div class="space-y-1 text-left text-xs text-gray-700">
              <p>
                <span class="font-semibold">ID Surat:</span>
                {@letter.id}
              </p>
              <p class="break-all">
                <span class="font-semibold">Verifikasi Surat di:</span>
                {VoileWeb.Endpoint.url() <> "/atrium/clearance/verify"}
              </p>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
