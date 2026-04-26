defmodule VoileWeb.Dashboard.Members.Clearance.Settings do
  use VoileWeb, :live_view_dashboard
  use Gettext, backend: VoileWeb.Gettext

  require Logger

  alias QRCode
  alias QRCode.Render.SvgSettings
  alias Voile.Clearance
  alias Voile.Schema.Master
  alias Voile.Schema.System
  alias Client.Storage

  @impl true
  def mount(_params, _session, socket) do
    handle_mount_errors do
      authorize!(socket, "system.settings")

      settings = Clearance.get_settings()
      member_types = Master.list_mst_member_types()
      app_logo_url = System.get_setting_value("app_logo_url", nil)
      preview_letter_id = Ecto.UUID.generate()
      preview_qr_code_uri = build_qr_code_data_uri(preview_letter_id)

      socket =
        socket
        |> assign(:settings, settings)
        |> assign(:form, to_form(settings, as: :settings))
        |> assign(:member_types, member_types)
        |> assign(:app_logo_url, app_logo_url)
        |> assign(:preview_letter_id, preview_letter_id)
        |> assign(:preview_qr_code_uri, preview_qr_code_uri)
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

    # eligible_member_types comes as a list from checkboxes; join to comma string
    params =
      case Map.get(params, "eligible_member_types") do
        list when is_list(list) ->
          Map.put(params, "eligible_member_types", Enum.join(list, ","))

        _ ->
          Map.put(params, "eligible_member_types", "")
      end

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
        {:noreply, put_flash(socket, :error, gettext("Failed to save settings."))}
    end
  end

  @impl true
  def handle_event("clear_save_success", _params, socket) do
    {:noreply, assign(socket, :save_success, false)}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :signature_image, ref)}
  end

  @impl true
  def handle_event("validate_signature", _params, socket) do
    {:noreply, socket}
  end

  defp handle_progress(:signature_image, entry, socket) do
    Logger.debug(
      "[ClearanceSettings] handle_progress called: done=#{entry.done?} progress=#{entry.progress}%"
    )

    if entry.done? do
      old_url = socket.assigns.settings["signature_image"]

      uploaded =
        consume_uploaded_entries(socket, :signature_image, fn %{path: path}, entry ->
          upload = %Plug.Upload{
            path: path,
            filename: entry.client_name,
            content_type: entry.client_type
          }

          try do
            case Storage.upload(upload,
                   folder: "clearance_signatures",
                   generate_filename: true
                 ) do
              {:ok, url} when is_binary(url) ->
                {:ok, {:success, url}}

              url when is_binary(url) ->
                {:ok, {:success, url}}

              error ->
                Logger.error("[ClearanceSettings] Storage.upload error: #{inspect(error)}")
                {:ok, {:upload_error, error}}
            end
          rescue
            exception ->
              Logger.error("[ClearanceSettings] Storage.upload exception: #{inspect(exception)}")
              {:ok, {:upload_error, exception}}
          end
        end)

      Logger.debug("[ClearanceSettings] consumed entries result: #{inspect(uploaded)}")

      socket =
        case uploaded do
          [{:success, new_url}] ->
            Clearance.delete_old_signature_image(old_url)
            Clearance.save_settings(%{"signature_image" => new_url})
            settings = Clearance.get_settings()

            socket
            |> assign(:settings, settings)
            |> assign(:form, to_form(settings, as: :settings))
            |> put_flash(:info, gettext("Signature updated successfully."))

          _ ->
            put_flash(socket, :error, gettext("Failed to upload signature."))
        end

      {:noreply, socket}
    else
      {:noreply, socket}
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
        %{label: gettext("Settings"), path: nil}
      ]} />

      <%!-- Clearance sub-navigation --%>
      <.clearance_nav active={:settings} />

      <%!-- Page header --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
          {gettext("Clearance Letter Settings")}
        </h1>
        <p class="text-gray-500 dark:text-gray-400 mt-1 text-sm">
          {gettext("Configure institution details, signer, and letter number format.")}
        </p>
      </div>

      <div class="grid grid-cols-1 gap-8 lg:grid-cols-2">
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
                {gettext("Institution Information")}
              </legend>
              <.input
                field={@form[:institution_name]}
                type="text"
                label={gettext("Institution Name")}
                placeholder="University of …"
              />
              <.input
                field={@form[:institution_subtitle]}
                type="text"
                label={gettext("Subtitle / Work Unit")}
                placeholder="Library Unit …"
              />
              <.input
                field={@form[:institution_address]}
                type="text"
                label={gettext("Address")}
                placeholder="123 Main St …"
              />
              <div class="grid grid-cols-2 gap-4">
                <.input
                  field={@form[:institution_phone]}
                  type="text"
                  label={gettext("Phone")}
                  placeholder="+62-xxx"
                />
                <.input
                  field={@form[:institution_email]}
                  type="text"
                  label={gettext("Email")}
                  placeholder="lib@university.ac.id"
                />
              </div>
              <.input
                field={@form[:city]}
                type="text"
                label={gettext("City (for date line)")}
                placeholder="City …"
              />
            </fieldset>

            <%!-- Signer --%>
            <fieldset class="rounded-lg border border-gray-200 p-4 space-y-4">
              <legend class="px-1 text-sm font-semibold text-gray-700">{gettext("Signer")}</legend>
              <.input
                field={@form[:signer_title]}
                type="text"
                label={gettext("Title / Position")}
                placeholder="Head of Library …"
              />
              <.input
                field={@form[:signer_name]}
                type="text"
                label={gettext("Full Name")}
                placeholder="Dr. …"
              />
              <.input
                field={@form[:signer_nip]}
                type="text"
                label={gettext("Employee ID (NIP)")}
                placeholder="19…"
              />
            </fieldset>

            <%!-- Numbering --%>
            <fieldset class="rounded-lg border border-gray-200 p-4 space-y-4">
              <legend class="px-1 text-sm font-semibold text-gray-700">
                {gettext("Letter Numbering")}
              </legend>
              <.input
                field={@form[:number_format]}
                type="text"
                label={gettext("Number Format")}
                placeholder="{N}/LIB/KM/{YEAR}"
              />
              <p class="text-xs text-gray-500 -mt-2">
                {gettext("Use")}
                <code phx-no-curly-interpolation>{N}</code>
                {gettext("for the sequence number (no padding) and")}
                <code phx-no-curly-interpolation>{YEAR}</code>
                {gettext("for the year. Example:")}
                <code>
                  {String.replace(
                    if(@settings["number_format"] && @settings["number_format"] != "",
                      do: @settings["number_format"],
                      else: "{N}/{YEAR}"
                    ),
                    "{N}",
                    to_string(String.to_integer(@settings["sequence"] || "0") + 1)
                  )
                  |> String.replace("{YEAR}", to_string(Date.utc_today().year))}
                </code>
              </p>
              <.input
                field={@form[:sequence]}
                type="number"
                label={gettext("Last sequence number (migration start)")}
                placeholder="0"
              />
              <p class="text-xs text-gray-500 -mt-2">
                {gettext("The next letter will use sequence number")} <em>{gettext("this value + 1")}</em>. {gettext(
                  "Set this to the last number issued manually."
                )}
              </p>
            </fieldset>

            <%!-- Body text --%>
            <fieldset class="rounded-lg border border-gray-200 p-4 space-y-3">
              <legend class="px-1 text-sm font-semibold text-gray-700">
                {gettext("Letter Body Text")}
              </legend>
              <p class="text-xs text-gray-500">
                {gettext(
                  "The main body paragraph of the clearance letter. HTML tags are allowed (e.g. <strong>, <em>, <br>)."
                )}
              </p>
              <.input
                field={@form[:body_text]}
                type="textarea"
                rows="4"
                label={gettext("Body paragraph")}
              />
            </fieldset>

            <%!-- Closing text --%>
            <fieldset class="rounded-lg border border-gray-200 p-4 space-y-3">
              <legend class="px-1 text-sm font-semibold text-gray-700">
                {gettext("Closing Text")}
              </legend>
              <p class="text-xs text-gray-500">
                {gettext("The closing sentence at the end of the letter body. HTML tags are allowed.")}
              </p>
              <.input
                field={@form[:closing_text]}
                type="textarea"
                rows="2"
                label={gettext("Closing sentence")}
              />
            </fieldset>

            <%!-- Eligible types --%>
            <fieldset class="rounded-lg border border-gray-200 p-4 space-y-3">
              <legend class="px-1 text-sm font-semibold text-gray-700">
                {gettext("Membership")}
              </legend>
              <p class="text-xs text-gray-500">
                {gettext("Select the member types eligible to request a clearance letter.")}
              </p>
              <% selected_slugs =
                (@settings["eligible_member_types"] || "")
                |> String.split(",")
                |> Enum.map(&String.trim/1)
                |> MapSet.new() %>
              <div class="space-y-2">
                <%= for mt <- @member_types do %>
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      name="settings[eligible_member_types][]"
                      value={mt.slug}
                      checked={MapSet.member?(selected_slugs, mt.slug)}
                      class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
                    />
                    <span class="text-sm text-gray-700">{mt.name}</span>
                    <span class="text-xs text-gray-400">({mt.slug})</span>
                  </label>
                <% end %>
              </div>
            </fieldset>

            <div class="flex items-center gap-3">
              <button
                type="submit"
                id="save-settings-btn"
                phx-disable-with={gettext("Saving…")}
                class="rounded-lg bg-indigo-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700"
              >
                {gettext("Save Settings")}
              </button>
              <%= if @save_success do %>
                <span
                  class="text-sm text-green-600 font-medium"
                  phx-mounted={JS.transition("opacity-0", time: 3000)}
                >
                  <.icon name="hero-check-circle" class="w-4 h-4 inline" /> {gettext("Saved")}
                </span>
              <% end %>
            </div>
          </.form>
        </div>

        <%!-- Signature image upload --%>
        <div>
          <div class="rounded-lg border border-gray-200 p-5 space-y-4">
            <div>
              <h3 class="font-semibold text-gray-800 text-sm">{gettext("Signature Image")}</h3>
              <p class="text-xs text-gray-500 mt-0.5">
                {gettext(
                  "Upload a signature in JPG/PNG format. The file will be stored in the storage system and can be replaced at any time."
                )}
              </p>
            </div>

            <%!-- Current signature preview --%>
            <%= if @settings["signature_image"] && @settings["signature_image"] != "" do %>
              <div class="rounded border border-gray-200 bg-gray-50 p-3 flex flex-col items-center gap-2">
                <img
                  src={@settings["signature_image"]}
                  alt={gettext("Current signature")}
                  class="max-h-24 max-w-full object-contain"
                />
                <p class="text-xs text-gray-400">{gettext("Active signature")}</p>
              </div>
            <% else %>
              <div class="rounded border border-dashed border-gray-300 bg-gray-50 p-6 text-center">
                <.icon name="hero-photo" class="w-8 h-8 text-gray-300 mx-auto" />
                <p class="text-xs text-gray-400 mt-2">{gettext("No signature uploaded yet.")}</p>
              </div>
            <% end %>

            <%!-- Upload area --%>
            <.form for={%{}} id="signature-upload-form" phx-change="validate_signature">
              <div
                id="signature-drop-area"
                phx-drop-target={@uploads.signature_image.ref}
                class="rounded-lg border-2 border-dashed border-indigo-300 bg-indigo-50 p-6 text-center hover:bg-indigo-100 transition-colors"
              >
                <.icon name="hero-arrow-up-tray" class="w-8 h-8 text-indigo-400 mx-auto" />
                <p class="text-sm text-indigo-700 mt-2 font-medium">
                  {gettext("Click or drag a file here")}
                </p>
                <p class="text-xs text-indigo-500 mt-1">
                  {gettext("JPG, JPEG, PNG, WEBP · max 5 MB")}
                </p>

                <.live_file_input upload={@uploads.signature_image} class="sr-only" />
                <label for={@uploads.signature_image.ref} class="mt-3 inline-block cursor-pointer">
                  <span class="rounded-md bg-indigo-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-indigo-700">
                    {gettext("Choose File")}
                  </span>
                </label>
              </div>
            </.form>

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

      <%!-- Letter preview --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
        <div class="flex items-center gap-3 mb-3">
          <h3 class="text-sm font-semibold text-gray-700">{gettext("Letter Preview")}</h3>
          <span class="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-700">
            {gettext("Preview — placeholder member data")}
          </span>
        </div>

        <div class="overflow-x-auto rounded-lg border border-gray-200 shadow-sm bg-gray-50 p-4">
          <div class="max-w-[794px] mx-auto bg-white border border-gray-200 p-12 font-serif text-gray-900 text-sm">
            <%!-- Letterhead --%>
            <div class="pb-3 mb-6" style="border-bottom: 4px double #1f2937;">
              <div class="flex items-center gap-5">
                <div class="shrink-0">
                  <img
                    src={@app_logo_url || "/images/v.png"}
                    alt={gettext("Institution logo")}
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
                    {if @settings["institution_name"] && @settings["institution_name"] != "",
                      do: @settings["institution_name"],
                      else: gettext("Institution Name")}
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
              <p class="text-sm mt-1">
                {gettext("Number:")}
                {%{
                  n: to_string(String.to_integer(@settings["sequence"] || "0") + 1),
                  year: to_string(Date.utc_today().year)
                }
                |> then(fn %{n: n, year: y} ->
                  if(@settings["number_format"] && @settings["number_format"] != "",
                    do: @settings["number_format"],
                    else: "{N}/{YEAR}"
                  )
                  |> String.replace("{N}", n)
                  |> String.replace("{YEAR}", y)
                end)}
              </p>
            </div>

            <%!-- Opening --%>
            <p class="leading-relaxed mb-5">
              Yang bertanda tangan di bawah ini menerangkan bahwa:
            </p>

            <%!-- Member info table --%>
            <table class="w-full mb-6">
              <tbody>
                <tr>
                  <td class="py-1 w-40">Nama</td>
                  <td class="py-1 w-4">:</td>
                  <td class="py-1 font-semibold text-gray-400 italic">
                    {gettext("Member Full Name")}
                  </td>
                </tr>
                <tr>
                  <td class="py-1">NIM / NPM / NIP</td>
                  <td class="py-1">:</td>
                  <td class="py-1 text-gray-400 italic">{gettext("Member ID")}</td>
                </tr>
                <tr>
                  <td class="py-1">Fakultas / Unit</td>
                  <td class="py-1">:</td>
                  <td class="py-1 text-gray-400 italic">{gettext("Node / Faculty")}</td>
                </tr>
                <tr>
                  <td class="py-1">Program Studi / Dept.</td>
                  <td class="py-1">:</td>
                  <td class="py-1 text-gray-400 italic">{gettext("Department")}</td>
                </tr>
              </tbody>
            </table>

            <%!-- Body text --%>
            <div class="leading-relaxed mb-5">
              {Phoenix.HTML.raw(HtmlSanitizeEx.basic_html(@settings["body_text"] || ""))}
            </div>

            <div class="leading-relaxed mb-10">
              {Phoenix.HTML.raw(HtmlSanitizeEx.basic_html(@settings["closing_text"] || ""))}
            </div>

            <%!-- Signature block --%>
            <div class="flex justify-end">
              <div class="text-center w-64">
                <p class="mb-1">
                  {if @settings["city"] && @settings["city"] != "",
                    do: @settings["city"] <> ", ",
                    else: ""}
                  {format_preview_date(Date.utc_today())}
                </p>
                <%= if @settings["signer_title"] && @settings["signer_title"] != "" do %>
                  <p class="font-medium">{@settings["signer_title"]}</p>
                <% end %>
                <div class="my-4 h-20 flex items-end justify-center">
                  <%= if @settings["signature_image"] && @settings["signature_image"] != "" do %>
                    <img
                      src={@settings["signature_image"]}
                      alt={gettext("Signature")}
                      class="max-h-20 max-w-[180px] object-contain"
                    />
                  <% else %>
                    <div class="h-16 w-40 border-b border-dashed border-gray-300" />
                  <% end %>
                </div>
                <p class="font-bold underline">
                  {if @settings["signer_name"] && @settings["signer_name"] != "",
                    do: @settings["signer_name"],
                    else: gettext("Signer Name")}
                </p>
                <%= if @settings["signer_nip"] && @settings["signer_nip"] != "" do %>
                  <p>NIP. {@settings["signer_nip"]}</p>
                <% end %>
              </div>
            </div>

            <%!-- Footer --%>
            <div class="mt-10 pt-4 border-t border-gray-200">
              <div class="grid items-start gap-3 sm:grid-cols-[auto_1fr]">
                <div class="flex items-center justify-center rounded-lg border border-gray-200 bg-white p-1">
                  <img
                    src={@preview_qr_code_uri || build_qr_code_data_uri(@preview_letter_id)}
                    alt={gettext("Preview QR code")}
                    class="h-12 w-12"
                  />
                </div>

                <div class="space-y-1 text-left text-xs text-gray-700">
                  <p>
                    <span class="font-semibold">{gettext("Letter ID:")}</span>
                    {@preview_letter_id}
                  </p>
                  <p class="break-all">
                    <span class="font-semibold">{gettext("Verify at:")}</span>
                    {VoileWeb.Endpoint.url() <> "/atrium/clearance/verify"}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_preview_date(%Date{} = d) do
    months =
      ~w(Januari Februari Maret April Mei Juni Juli Agustus September Oktober November Desember)

    "#{d.day} #{Enum.at(months, d.month - 1)} #{d.year}"
  end

  defp build_qr_code_data_uri(id) when is_binary(id) do
    svg_settings = %SvgSettings{
      scale: 4,
      background_color: "transparent",
      qrcode_color: "#1f2937",
      structure: :minify,
      quiet_zone: 2
    }

    qr_result = QRCode.create(id, :high)

    with {:ok, svg} <- QRCode.render(qr_result, :svg, svg_settings),
         {:ok, base64} <- QRCode.to_base64(svg) do
      "data:image/svg+xml;base64,#{base64}"
    else
      _ -> nil
    end
  end

  defp error_to_string(:too_large), do: gettext("File is too large.")
  defp error_to_string(:not_accepted), do: gettext("File format not supported.")
  defp error_to_string(:too_many_files), do: gettext("Too many files.")
  defp error_to_string(err), do: "Error: #{inspect(err)}"
end
