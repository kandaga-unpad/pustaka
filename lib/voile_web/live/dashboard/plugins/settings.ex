defmodule VoileWeb.Dashboard.Plugins.Settings do
  @moduledoc """
  Per-plugin settings form.

  Dynamically renders a settings form based on the plugin's settings_schema/0
  callback. Settings are stored in the voile_plugins.settings JSONB column.
  """
  use VoileWeb, :live_view_dashboard

  alias Voile.Plugins

  @impl true
  def mount(%{"plugin_id" => plugin_id}, _session, socket) do
    unless VoileWeb.Auth.Authorization.is_super_admin?(socket) do
      {:ok,
       socket
       |> put_flash(:error, gettext("Access denied. Super admin only."))
       |> push_navigate(to: ~p"/manage/plugins/#{plugin_id}")}
    else
      case Plugins.get_plugin_by_plugin_id(plugin_id) do
        nil ->
          {:ok,
           socket
           |> put_flash(:error, gettext("Plugin not found."))
           |> push_navigate(to: ~p"/manage/plugins")}

        plugin ->
          settings_schema = get_settings_schema(plugin.module)
          form = build_form(settings_schema, plugin.settings || %{})
          is_super_admin = VoileWeb.Auth.Authorization.is_super_admin?(socket)

          {:ok,
           socket
           |> assign(:plugin, plugin)
           |> assign(:settings_schema, settings_schema)
           |> assign(:form, form)
           |> assign(:current_path, "/manage/plugins/#{plugin_id}/settings")
           |> assign(:page_title, gettext("%{name} Settings", name: plugin.name))
           |> assign(:is_super_admin, is_super_admin)}
      end
    end
  end

  @impl true
  def handle_event("validate", %{"settings" => params}, socket) do
    form = validate_form(socket.assigns.settings_schema, params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"settings" => params}, socket) do
    plugin = socket.assigns.plugin

    case validate_and_convert(socket.assigns.settings_schema, params) do
      {:ok, converted_settings} ->
        case Plugins.put_plugin_settings(plugin.plugin_id, converted_settings) do
          {:ok, updated_plugin} ->
            {:noreply,
             socket
             |> assign(:plugin, updated_plugin)
             |> put_flash(:info, gettext("Settings saved successfully."))}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, gettext("Failed to save settings."))}
        end

      {:error, errors} ->
        form = Map.put(socket.assigns.form, :errors, errors)
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6 p-6">
      <div class="flex flex-col md:flex-row gap-4">
        <div class="w-full md:w-auto md:max-w-64">
          <.plugin_settings_sidebar
            current_path={@current_path}
            current_plugin_id={@plugin.plugin_id}
            is_super_admin={@is_super_admin}
          />
        </div>

        <div class="space-y-6 flex-1">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-gray-900 dark:text-white">
                {@plugin.name} {gettext("Settings")}
              </h1>
              <p class="text-gray-600 dark:text-gray-400 mt-1">
                {gettext("Configure plugin behavior and options")}
              </p>
            </div>
            <.link
              navigate={~p"/manage/plugins"}
              class="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-gray-100 dark:bg-gray-700 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-600"
            >
              {gettext("Back to Plugins")}
            </.link>
          </div>

          <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
            <%= if @settings_schema == [] do %>
              <div class="text-center py-8">
                <div class="text-gray-400 dark:text-gray-500 mb-4">
                  <.icon name="hero-cog-6-tooth" class="w-12 h-12 mx-auto" />
                </div>
                <p class="text-gray-500 dark:text-gray-400">
                  {gettext("This plugin has no configurable settings.")}
                </p>
              </div>
            <% else %>
              <.form
                for={to_form(%{}, as: :settings)}
                phx-change="validate"
                phx-submit="save"
                id="plugin-settings-form"
              >
                <div class="space-y-6">
                  <%= for field <- @settings_schema do %>
                    <div class="space-y-1">
                      <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                        {field.label}
                        <%= if Map.get(field, :required) do %>
                          <span class="text-red-500">*</span>
                        <% end %>
                      </label>

                      <%= if Map.get(field, :description) do %>
                        <p class="text-xs text-gray-500 dark:text-gray-400 mb-1">
                          {field.description}
                        </p>
                      <% end %>

                      <%= case field.type do %>
                        <% :string -> %>
                          <.input
                            type={if Map.get(field, :secret), do: "password", else: "text"}
                            name={"settings[#{field.key}]"}
                            value={get_form_value(@form, field.key)}
                          />
                        <% :integer -> %>
                          <.input
                            type="number"
                            name={"settings[#{field.key}]"}
                            value={get_form_value(@form, field.key)}
                          />
                        <% :boolean -> %>
                          <label class="flex items-center gap-2 cursor-pointer">
                            <.input
                              type="checkbox"
                              name={"settings[#{field.key}]"}
                              checked={get_form_value(@form, field.key) == true}
                            />
                            <span class="text-sm text-gray-600 dark:text-gray-400">
                              {gettext("Enabled")}
                            </span>
                          </label>
                        <% :select -> %>
                          <.input
                            type="select"
                            name={"settings[#{field.key}]"}
                            options={Map.get(field, :options, [])}
                            value={get_form_value(@form, field.key)}
                          />
                      <% end %>

                      <%= if Map.get(field, :secret) do %>
                        <p class="text-xs text-amber-600 dark:text-amber-400">
                          <.icon name="hero-lock-closed" class="w-3 h-3 inline" />
                          {gettext("Sensitive — stored securely.")}
                        </p>
                      <% end %>

                      <%= if @form.errors[field.key] do %>
                        <p class="text-sm text-red-600 dark:text-red-400">
                          {@form.errors[field.key]}
                        </p>
                      <% end %>
                    </div>
                  <% end %>

                  <div class="flex justify-end pt-4 border-t border-gray-200 dark:border-gray-700">
                    <button
                      type="submit"
                      class="px-6 py-2 text-sm font-medium text-white bg-violet-600 rounded-lg hover:bg-violet-700"
                    >
                      {gettext("Save Settings")}
                    </button>
                  </div>
                </div>
              </.form>
            <% end %>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # Private helpers

  defp get_settings_schema(module_str) do
    try do
      module = String.to_existing_atom(module_str)

      if function_exported?(module, :settings_schema, 0) do
        module.settings_schema()
      else
        []
      end
    rescue
      ArgumentError -> []
    end
  end

  defp build_form(schema, current_settings) do
    values =
      schema
      |> Enum.map(fn field ->
        key = field.key
        value = Map.get(current_settings, to_string(key), Map.get(field, :default))
        {key, value}
      end)
      |> Map.new()

    %{values: values, errors: %{}}
  end

  defp validate_form(schema, params) do
    values =
      schema
      |> Enum.map(fn field ->
        key = field.key
        value = Map.get(params, to_string(key))
        {key, value}
      end)
      |> Map.new()

    %{values: values, errors: %{}}
  end

  defp validate_and_convert(schema, params) do
    errors =
      Enum.reduce(schema, %{}, fn field, acc ->
        key = field.key
        raw_value = Map.get(params, to_string(key))

        case validate_field(field, raw_value) do
          {:ok, _} -> acc
          {:error, msg} -> Map.put(acc, key, msg)
        end
      end)

    if map_size(errors) > 0 do
      {:error, errors}
    else
      converted =
        Enum.reduce(schema, %{}, fn field, acc ->
          key = field.key
          raw_value = Map.get(params, to_string(key))

          case convert_field(field, raw_value) do
            {:ok, value} -> Map.put(acc, key, value)
            :error -> acc
          end
        end)

      {:ok, converted}
    end
  end

  defp validate_field(field, value) do
    required = Map.get(field, :required, false)

    cond do
      required and (value == nil or value == "") ->
        {:error, gettext("This field is required")}

      true ->
        {:ok, value}
    end
  end

  defp convert_field(%{type: :integer}, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  defp convert_field(%{type: :boolean}, "true"), do: {:ok, true}
  defp convert_field(%{type: :boolean}, "false"), do: {:ok, false}
  defp convert_field(%{type: :boolean}, true), do: {:ok, true}
  defp convert_field(%{type: :boolean}, false), do: {:ok, false}
  defp convert_field(%{type: :boolean}, _), do: {:ok, false}

  defp convert_field(_field, value), do: {:ok, value}

  defp get_form_value(form, key) do
    Map.get(form.values, key) || Map.get(form.values, to_string(key))
  end
end
