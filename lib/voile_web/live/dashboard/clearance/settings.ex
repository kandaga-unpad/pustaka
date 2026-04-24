defmodule VoileWeb.Dashboard.Clearance.Settings do
  use VoileWeb, :live_view_dashboard
  use Gettext, backend: VoileWeb.Gettext

  alias Voile.Clearance
  alias Client.Storage

  @impl true
  def mount(_params, _session, socket) do
    handle_mount_errors do
      authorize!(socket, "system.settings")

      settings = Clearance.get_settings()

      socket =
        socket
        |> assign(:settings, settings)
        |> assign(:form, to_form(settings, as: :settings))
        |> assign(:save_success, false)
        |> allow_upload(:signature_image,
          accept: ~w(.jpg .jpeg .png .webp),
          max_entries: 1,
          auto_upload: true,
          progress: &handle_progress/3
        )

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("save_settings", %{"settings" => params}, socket) do
    # Don't overwrite signature_image from text params — it's managed by upload
    params = Map.delete(params, "signature_image")

    case Clearance.save_settings(params) do
      :ok ->
        settings = Clearance.get_settings()

        socket =
          socket
          |> assign(:settings, settings)
          |> assign(:form, to_form(settings, as: :settings))
          |> assign(:save_success, true)

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Gagal menyimpan pengaturan")}
    end
  end

  @impl true
  def handle_event("clear_save_success", _params, socket) do
    {:noreply, assign(socket, :save_success, false)}
  end

  defp handle_progress(:signature_image, entry, socket) do
    if entry.done? do
      old_url = socket.assigns.settings["signature_image"]

      result =
        consume_uploaded_entries(socket, :signature_image, fn %{path: path}, entry ->
          upload = %Plug.Upload{
            path: path,
            filename: entry.client_name,
            content_type: entry.client_type
          }

          try do
            Storage.upload(upload,
              folder: "clearance_signatures",
              generate_filename: true
            )
          rescue
            _ -> {:error, "Gagal mengunggah gambar tanda tangan"}
          end
        end)

      case result do
        [{:ok, new_url}] ->
          Clearance.delete_old_signature_image(old_url)
          Clearance.save_settings(%{"signature_image" => new_url})
          settings = Clearance.get_settings()

          socket
          |> assign(:settings, settings)
          |> assign(:form, to_form(settings, as: :settings))
          |> put_flash(:info, "Tanda tangan berhasil diperbarui")

        _ ->
          put_flash(socket, :error, "Gagal mengunggah tanda tangan")
      end
    else
      socket
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <h4>{gettext("Pengaturan Surat Bebas Perpustakaan")}</h4>
      <:subtitle>{gettext("Konfigurasi institusi, penandatangan, dan format nomor surat")}</:subtitle>
    </.header>

    <div class="mt-6 grid grid-cols-1 gap-8 lg:grid-cols-2">
      <%!-- Settings form --%>
      <div class="space-y-6">
        <.form
          for={@form}
          id="clearance-settings-form"
          phx-submit="save_settings"
          class="space-y-5"
        >
          <%!-- Institution --%>
          <fieldset class="rounded-lg border border-gray-200 p-4 space-y-4">
            <legend class="px-1 text-sm font-semibold text-gray-700">
              Informasi Institusi
            </legend>
            <.input
              field={@form[:institution_name]}
              type="text"
              label="Nama Institusi"
              placeholder="Universitas …"
            />
            <.input
              field={@form[:institution_subtitle]}
              type="text"
              label="Sub-judul / Unit Kerja"
              placeholder="UPT Perpustakaan …"
            />
            <.input
              field={@form[:institution_address]}
              type="text"
              label="Alamat"
              placeholder="Jl. …"
            />
            <div class="grid grid-cols-2 gap-4">
              <.input
                field={@form[:institution_phone]}
                type="text"
                label="Telepon"
                placeholder="022-xxx"
              />
              <.input
                field={@form[:institution_email]}
                type="text"
                label="Email"
                placeholder="lib@university.ac.id"
              />
            </div>
            <.input
              field={@form[:city]}
              type="text"
              label="Kota (untuk baris tanggal)"
              placeholder="Bandung"
            />
          </fieldset>

          <%!-- Signer --%>
          <fieldset class="rounded-lg border border-gray-200 p-4 space-y-4">
            <legend class="px-1 text-sm font-semibold text-gray-700">Penandatangan</legend>
            <.input
              field={@form[:signer_title]}
              type="text"
              label="Jabatan"
              placeholder="Kepala UPT Perpustakaan"
            />
            <.input
              field={@form[:signer_name]}
              type="text"
              label="Nama Lengkap"
              placeholder="Dr. …"
            />
            <.input field={@form[:signer_nip]} type="text" label="NIP" placeholder="19…" />
          </fieldset>

          <%!-- Numbering --%>
          <fieldset class="rounded-lg border border-gray-200 p-4 space-y-4">
            <legend class="px-1 text-sm font-semibold text-gray-700">Penomoran Surat</legend>
            <.input
              field={@form[:number_format]}
              type="text"
              label="Format Nomor"
              placeholder="{N}/UN6.1.1.4/KM/{YEAR}"
            />
            <p class="text-xs text-gray-500 -mt-2">
              Gunakan <code phx-no-curly-interpolation>{N}</code>
              untuk nomor urut (4 digit) dan <code phx-no-curly-interpolation>{YEAR}</code>
              untuk tahun.
            </p>
            <.input
              field={@form[:sequence]}
              type="number"
              label="Nomor urut terakhir (awal migrasi)"
              placeholder="0"
            />
            <p class="text-xs text-gray-500 -mt-2">
              Surat berikutnya akan diberi nomor urut <em>nilai ini + 1</em>.
              Atur sesuai nomor terakhir yang telah diterbitkan secara manual.
            </p>
          </fieldset>

          <%!-- Eligible types --%>
          <fieldset class="rounded-lg border border-gray-200 p-4 space-y-3">
            <legend class="px-1 text-sm font-semibold text-gray-700">Keanggotaan</legend>
            <.input
              field={@form[:eligible_member_types]}
              type="text"
              label="Tipe anggota yang berhak (slug, pisahkan koma)"
              placeholder="member_verified"
            />
          </fieldset>

          <div class="flex items-center gap-3">
            <button
              type="submit"
              id="save-settings-btn"
              phx-disable-with="Menyimpan…"
              class="rounded-lg bg-indigo-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700"
            >
              Simpan Pengaturan
            </button>
            <%= if @save_success do %>
              <span
                class="text-sm text-green-600 font-medium"
                phx-mounted={JS.transition("opacity-0", time: 3000)}
              >
                <.icon name="hero-check-circle" class="w-4 h-4 inline" /> Tersimpan
              </span>
            <% end %>
          </div>
        </.form>
      </div>

      <%!-- Signature image upload --%>
      <div>
        <div class="rounded-lg border border-gray-200 p-5 space-y-4">
          <div>
            <h3 class="font-semibold text-gray-800 text-sm">Gambar Tanda Tangan</h3>
            <p class="text-xs text-gray-500 mt-0.5">
              Upload tanda tangan dalam format JPG/PNG. File akan disimpan ke sistem penyimpanan.
              Gambar dapat diganti sewaktu-waktu.
            </p>
          </div>

          <%!-- Current signature preview --%>
          <%= if @settings["signature_image"] && @settings["signature_image"] != "" do %>
            <div class="rounded border border-gray-200 bg-gray-50 p-3 flex flex-col items-center gap-2">
              <img
                src={@settings["signature_image"]}
                alt="Tanda tangan saat ini"
                class="max-h-24 max-w-full object-contain"
              />
              <p class="text-xs text-gray-400">Tanda tangan aktif</p>
            </div>
          <% else %>
            <div class="rounded border border-dashed border-gray-300 bg-gray-50 p-6 text-center">
              <.icon name="hero-photo" class="w-8 h-8 text-gray-300 mx-auto" />
              <p class="text-xs text-gray-400 mt-2">Belum ada tanda tangan</p>
            </div>
          <% end %>

          <%!-- Upload area --%>
          <div
            id="signature-drop-area"
            phx-drop-target={@uploads.signature_image.ref}
            class="rounded-lg border-2 border-dashed border-indigo-300 bg-indigo-50 p-6 text-center hover:bg-indigo-100 transition-colors"
          >
            <.icon name="hero-arrow-up-tray" class="w-8 h-8 text-indigo-400 mx-auto" />
            <p class="text-sm text-indigo-700 mt-2 font-medium">
              Klik atau seret file ke sini
            </p>
            <p class="text-xs text-indigo-500 mt-1">JPG, JPEG, PNG, WEBP · maks 5 MB</p>

            <label for={@uploads.signature_image.ref} class="mt-3 inline-block cursor-pointer">
              <span class="rounded-md bg-indigo-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-indigo-700">
                Pilih File
              </span>
              <.live_file_input upload={@uploads.signature_image} class="sr-only" />
            </label>
          </div>

          <%!-- Upload entries progress --%>
          <%= for entry <- @uploads.signature_image.entries do %>
            <div class="flex items-center gap-3 text-sm">
              <.icon name="hero-document" class="w-4 h-4 text-gray-400 shrink-0" />
              <span class="flex-1 truncate text-gray-700">{entry.client_name}</span>
              <span class="text-xs text-gray-500">{entry.progress}%</span>
              <button
                type="button"
                phx-click="cancel-upload"
                phx-value-ref={entry.ref}
                class="text-red-400 hover:text-red-600"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
            <%= for err <- upload_errors(@uploads.signature_image, entry) do %>
              <p class="text-xs text-red-600">{error_to_string(err)}</p>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "File terlalu besar"
  defp error_to_string(:not_accepted), do: "Format file tidak didukung"
  defp error_to_string(:too_many_files), do: "Terlalu banyak file"
  defp error_to_string(err), do: "Error: #{inspect(err)}"
end
