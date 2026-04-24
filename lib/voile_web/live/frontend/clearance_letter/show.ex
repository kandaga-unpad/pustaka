defmodule VoileWeb.Frontend.Clearance.ShowLetter do
  use VoileWeb, :live_view
  use Gettext, backend: VoileWeb.Gettext

  alias Voile.Clearance

  @impl true
  def mount(%{"uuid" => uuid}, _session, socket) do
    letter = Clearance.get_letter(uuid)
    settings = Clearance.get_settings()

    socket =
      socket
      |> assign(:letter, letter)
      |> assign(:settings, settings)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
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
        <div class="border-b-2 border-gray-800 pb-4 mb-6">
          <div class="text-center">
            <p class="text-lg font-bold uppercase tracking-wide">
              {@settings["institution_name"]}
            </p>
            <%= if @settings["institution_subtitle"] && @settings["institution_subtitle"] != "" do %>
              <p class="text-sm font-semibold uppercase mt-0.5">
                {@settings["institution_subtitle"]}
              </p>
            <% end %>
            <%= if @settings["institution_address"] && @settings["institution_address"] != "" do %>
              <p class="text-xs mt-1">{@settings["institution_address"]}</p>
            <% end %>
            <%= if @settings["institution_phone"] && @settings["institution_phone"] != "" do %>
              <p class="text-xs">Telp. {@settings["institution_phone"]}</p>
            <% end %>
            <%= if @settings["institution_email"] && @settings["institution_email"] != "" do %>
              <p class="text-xs">{@settings["institution_email"]}</p>
            <% end %>
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
        <p class="text-sm leading-relaxed mb-5">
          adalah benar telah <strong>bebas dari kewajiban kepada perpustakaan</strong>,
          meliputi tidak ada peminjaman buku yang belum dikembalikan dan tidak ada
          denda yang belum dibayarkan, sehingga yang bersangkutan dinyatakan <strong>BEBAS PERPUSTAKAAN</strong>.
        </p>

        <p class="text-sm leading-relaxed mb-10">
          Surat keterangan ini dibuat untuk dipergunakan sebagaimana mestinya.
        </p>

        <%!-- City, date, signature --%>
        <div class="flex justify-end">
          <div class="text-center text-sm w-64">
            <p class="mb-1">
              {if @settings["city"] && @settings["city"] != "",
                do: @settings["city"] <> ", ",
                else: ""}
              {format_date(@letter.generated_at)}
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

        <%!-- UUID footer --%>
        <div class="mt-10 pt-4 border-t border-gray-200 text-center">
          <p class="text-xs text-gray-400">
            ID Surat: {@letter.id}
          </p>
          <p class="text-xs text-gray-400 mt-0.5">
            Verifikasi surat di: /atrium/clearance/verify
          </p>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_date(%DateTime{} = dt) do
    months =
      ~w(Januari Februari Maret April Mei Juni Juli Agustus September Oktober November Desember)

    month_name = Enum.at(months, dt.month - 1)
    "#{dt.day} #{month_name} #{dt.year}"
  end

  defp format_date(_), do: ""
end
