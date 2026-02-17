defmodule VoileWeb.Dashboard.Settings.HolidayLive do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.System.{LibHolidays, LibHoliday}
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <.header>
      {gettext("Library Holidays & Schedule Management")}
      <:subtitle>
        {gettext("Manage holidays, weekly schedules, and non-business days for fine calculations")}
      </:subtitle>

      <:actions>
        <.button phx-click="new_holiday" class="primary-btn">
          <.icon name="hero-plus" class="w-4 h-4 mr-2" /> {gettext("Add Holiday")}
        </.button>
        <.button phx-click="setup_default_schedule" class="warning-btn">
          <.icon name="hero-calendar-days" class="w-4 h-4 mr-2" /> {gettext("Setup Default Schedule")}
        </.button>
      </:actions>
    </.header>

    <section class="flex gap-4">
      <div class="w-full max-w-64">
        <.dashboard_settings_sidebar
          current_user={@current_scope.user}
          current_path={@current_path}
        />
      </div>

      <div class="space-y-6">
        <!-- Holiday Stats -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-calendar" class="h-8 w-8 text-voile-info" />
              </div>

              <div class="ml-4">
                <div class="text-2xl font-bold">{@holiday_stats.total_holidays}</div>

                <div class="text-sm font-medium">{gettext("Total Holidays")}</div>
              </div>
            </div>
          </div>

          <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-flag" class="h-8 w-8 text-voile-success" />
              </div>

              <div class="ml-4">
                <div class="text-2xl font-bold">{@holiday_stats.public_holidays}</div>

                <div class="text-sm font-medium">{gettext("Public Holidays")}</div>
              </div>
            </div>
          </div>

          <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-building-library" class="h-8 w-8 text-voile-primary" />
              </div>

              <div class="ml-4">
                <div class="text-2xl font-bold">{@holiday_stats.library_holidays}</div>

                <div class="text-sm font-medium">{gettext("Library Holidays")}</div>
              </div>
            </div>
          </div>

          <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-star" class="h-8 w-8 text-voile-warning" />
              </div>

              <div class="ml-4">
                <div class="text-2xl font-bold">{@holiday_stats.custom_holidays}</div>

                <div class="text-sm font-medium">{gettext("Custom Holidays")}</div>
              </div>
            </div>
          </div>
        </div>
        <!-- Info Panel -->
        <div class="bg-voile-info/10 dark:bg-voile-info/20 border border-voile-info/30 rounded-lg p-4">
          <div class="flex">
            <.icon name="hero-information-circle" class="h-5 w-5 text-voile-info" />
            <div class="ml-3">
              <h3 class="text-sm font-medium text-voile-info">
                {gettext("Holiday Impact on Fines")}
              </h3>

              <p class="mt-2 text-sm text-voile-info">
                {gettext(
                  "Non-business days (weekly schedule) and holidays defined here will be excluded from overdue fine calculations. Only business days will count toward fine amounts. This ensures fair fine calculation during library closures."
                )}
              </p>
            </div>
          </div>
        </div>
        <!-- Weekly Schedule Configuration -->
        <div class="bg-white dark:bg-gray-700 shadow rounded-lg">
          <div class="px-4 py-5 border-b border-gray-200 sm:px-6">
            <div class="flex items-center justify-between">
              <h3 class="text-lg leading-6 font-medium">{gettext("Weekly Schedule")}</h3>

              <div class="text-sm">{gettext("Configure which days are business days")}</div>
            </div>
          </div>

          <div class="px-4 py-5 sm:p-6">
            <div class="mb-4 flex items-center space-x-3">
              <label class="text-sm font-medium">{gettext("Viewing schedule for")}</label>
              <form phx-change="select_unit">
                <select
                  class="border border-gray-300 rounded-md px-2 py-1 bg-white dark:bg-gray-700"
                  name="unit_id"
                  disabled={not @is_super_admin}
                  title={
                    if @is_super_admin,
                      do: gettext("Select unit to view/edit schedule"),
                      else: gettext("Only super admins can switch units")
                  }
                >
                  <option value="">{gettext("System Wide")}</option>

                  <%= for node <- @nodes do %>
                    <option
                      value={node.id}
                      selected={to_string(@selected_unit_id || "") == to_string(node.id)}
                    >
                      {node.name}
                    </option>
                  <% end %>
                </select>
              </form>
            </div>

            <div class="grid grid-cols-2 md:grid-cols-7 gap-4">
              <%= for day <- @weekly_schedule do %>
                <div
                  class={[
                    "border-2 rounded-lg p-4 text-center cursor-pointer transition-all duration-200",
                    if day.is_business_day do
                      "border-voile-success bg-voile-success/10 hover:bg-voile-success/20"
                    else
                      "border-voile-error bg-voile-error/10 hover:bg-voile-error/20"
                    end
                  ]}
                  phx-click="toggle_day_schedule"
                  phx-value-day={day.day_of_week}
                >
                  <div class="text-sm font-medium text-gray-900">{day.day_name}</div>

                  <div class={[
                    "mt-2 text-xs font-semibold",
                    if(day.is_business_day, do: "text-voile-success", else: "text-voile-error")
                  ]}>
                    {if day.is_business_day,
                      do: gettext("Business Day"),
                      else: gettext("Non-Business")}
                  </div>

                  <div class={[
                    "mt-1 inline-flex rounded-full px-2 py-1 text-xs font-medium",
                    if day.is_business_day do
                      "bg-voile-success/10 text-voile-success"
                    else
                      "bg-voile-error/10 text-voile-error"
                    end
                  ]}>
                    {if day.is_business_day, do: gettext("Open"), else: gettext("Closed")}
                  </div>
                </div>
              <% end %>
            </div>

            <div class="mt-6 flex items-center justify-between">
              <div class="text-xs">{gettext("Click on any day to toggle its business status")}</div>

              <div class="space-x-2">
                <.button
                  phx-click="set_all_business"
                  phx-value-unit_id={@selected_unit_id}
                  class="success-btn"
                >
                  {gettext("All Business Days")}
                </.button>
                <.button
                  phx-click="set_weekdays_only"
                  phx-value-unit_id={@selected_unit_id}
                  class="primary-btn"
                >
                  {gettext("Weekdays Only")}
                </.button>
                <.button
                  phx-click="set_all_closed"
                  phx-value-unit_id={@selected_unit_id}
                  class="cancel-btn"
                >
                  {gettext("All Closed")}
                </.button>
              </div>
            </div>
          </div>
        </div>
        <!-- Holidays Table -->
        <div class="bg-white dark:bg-gray-700 shadow rounded-lg">
          <div class="px-4 py-5 border-b border-gray-200 sm:px-6">
            <div class="flex items-center justify-between">
              <h3 class="text-lg leading-6 font-medium">{gettext("Holidays List")}</h3>

              <div class="text-sm">
                {gettext("Current Year: %{year}", year: @holiday_stats.current_year)}
              </div>
            </div>
          </div>

          <div class="overflow-hidden">
            <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
              <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
                <table class="min-w-full divide-y divide-gray-300">
                  <thead>
                    <tr>
                      <th class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold">
                        {gettext("Holiday Name")}
                      </th>

                      <th class="px-3 py-3.5 text-left text-sm font-semibold">{gettext("Date")}</th>

                      <th class="px-3 py-3.5 text-left text-sm font-semibold">{gettext("Type")}</th>

                      <th class="px-3 py-3.5 text-left text-sm font-semibold">{gettext("Status")}</th>

                      <th class="relative py-3.5 pl-3 pr-4 text-right text-sm font-semibold">
                        {gettext("Actions")}
                      </th>
                    </tr>
                  </thead>

                  <tbody class="divide-y divide-gray-200">
                    <%= for holiday <- @holidays do %>
                      <tr class={if holiday.is_active, do: "", else: "opacity-50"}>
                        <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm">
                          <div class="font-medium">{holiday.name}</div>

                          <%= if holiday.description do %>
                            <div class=" text-xs">{holiday.description}</div>
                          <% end %>
                        </td>

                        <td class="whitespace-nowrap px-3 py-4 text-sm ">
                          {Calendar.strftime(holiday.holiday_date, "%A, %B %d, %Y")}
                        </td>

                        <td class="whitespace-nowrap px-3 py-4 text-sm">
                          <span class={[
                            "inline-flex rounded-full px-2 text-xs font-semibold leading-5",
                            case holiday.holiday_type do
                              "public" -> "bg-voile-success/10 text-voile-success"
                              "library" -> "bg-voile-primary/10 text-voile-primary"
                              "custom" -> "bg-voile-warning/10 text-voile-warning"
                              _ -> "bg-gray-100 text-gray-800"
                            end
                          ]}>
                            {String.capitalize(holiday.holiday_type)}
                          </span>
                        </td>

                        <td class="whitespace-nowrap px-3 py-4 text-sm">
                          <span class={[
                            "inline-flex rounded-full px-2 text-xs font-semibold leading-5",
                            if holiday.is_active do
                              "bg-voile-success/10 text-voile-success"
                            else
                              "bg-voile-error/10 text-voile-error"
                            end
                          ]}>
                            {if holiday.is_active, do: gettext("Active"), else: gettext("Inactive")}
                          </span>
                        </td>

                        <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium space-x-2">
                          <.button
                            phx-click="edit_holiday"
                            phx-value-id={holiday.id}
                            class="primary-btn"
                          >
                            {gettext("Edit")}
                          </.button>
                          <.button
                            phx-click="toggle_holiday"
                            phx-value-id={holiday.id}
                            class={
                              if holiday.is_active,
                                do: "warning-btn",
                                else: "success-btn"
                            }
                          >
                            {if holiday.is_active, do: gettext("Disable"), else: gettext("Enable")}
                          </.button>
                          <.button
                            phx-click="delete_holiday"
                            phx-value-id={holiday.id}
                            data-confirm={gettext("Are you sure you want to delete this holiday?")}
                            class="cancel-btn"
                          >
                            {gettext("Delete")}
                          </.button>
                        </td>
                      </tr>
                    <% end %>

                    <%= if length(@holidays) == 0 do %>
                      <tr>
                        <td colspan="5" class="px-6 py-12 text-center text-sm">
                          <.icon name="hero-calendar-x" class="mx-auto h-12 w-12" />
                          <h3 class="mt-2 text-sm font-medium">
                            {gettext("No holidays configured")}
                          </h3>

                          <p class="mt-1 text-sm">{gettext("Get started by adding a holiday.")}</p>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
    <!-- Holiday Form Modal -->
    <%= if @show_form do %>
      <.modal id="holiday-form-modal" show={@show_form} on_cancel={JS.push("cancel_form")}>
        <div class="mt-3">
          <h3 class="text-lg font-medium mb-4">
            {if @form_holiday, do: gettext("Edit Holiday"), else: gettext("Add New Holiday")}
          </h3>

          <.form for={@form} id="holiday-form" phx-submit="save_holiday">
            <.input
              field={@form[:unit_id]}
              type="select"
              label={gettext("Unit (optional)")}
              options={
                [
                  {gettext("System Wide"), ""}
                ] ++ Enum.map(@nodes, &{"#{&1.name} (#{&1.abbr})", &1.id})
              }
              disabled={not @is_super_admin}
            />
            <.input field={@form[:name]} type="text" label={gettext("Holiday Name")} required />
            <.input field={@form[:holiday_date]} type="date" label={gettext("Date")} required />
            <.input
              field={@form[:holiday_type]}
              type="select"
              label={gettext("Type")}
              options={[
                {gettext("Public Holiday"), "public"},
                {gettext("Library Holiday"), "library"},
                {gettext("Custom Holiday"), "custom"}
              ]}
              required
            /> <.input field={@form[:description]} type="textarea" label={gettext("Description")} />
            <.input
              field={@form[:is_recurring]}
              type="checkbox"
              label={gettext("Recurring annually")}
            />
            <.input field={@form[:is_active]} type="checkbox" label={gettext("Active")} />
            <!-- Hidden field to ensure schedule_type is set to 'holiday' -->
            <input type="hidden" name="lib_holiday[schedule_type]" value="holiday" />
            <div class="flex items-center justify-end space-x-2 mt-6">
              <.button
                type="button"
                phx-click="cancel_form"
                class="cancel-btn"
              >
                {gettext("Cancel")}
              </.button>
              <.button type="submit" class="success-btn">
                {if @form_holiday, do: gettext("Update"), else: gettext("Create")} Holiday
              </.button>
            </div>
          </.form>
        </div>
      </.modal>
    <% end %>
    """
  end

  def mount(_params, _session, socket) do
    handle_mount_errors do
      # Check permission for managing system settings
      authorize!(socket, "system.settings")

      # Determine default unit scoping for admins: non-super-admins should be scoped to their node
      current_user = socket.assigns.current_scope.user
      is_super_admin = VoileWeb.Auth.Authorization.is_super_admin?(socket)

      selected_unit_id =
        if is_super_admin do
          nil
        else
          # scope to user's node_id by default
          current_user && current_user.node_id
        end

      holidays = LibHolidays.list_holidays(selected_unit_id)
      holiday_stats = LibHolidays.get_holiday_stats(selected_unit_id)
      weekly_schedule = LibHolidays.get_weekly_schedule(selected_unit_id)
      current_year = Date.utc_today().year

      # load units (nodes) for admin to choose when creating holidays
      nodes = Voile.Schema.System.list_nodes()

      socket =
        socket
        |> assign(:holidays, holidays)
        |> assign(:holiday_stats, holiday_stats)
        |> assign(:weekly_schedule, weekly_schedule)
        |> assign(:current_year, current_year)
        |> assign(:selected_unit_id, selected_unit_id)
        |> assign(:is_super_admin, is_super_admin)
        |> assign(:show_form, false)
        |> assign(:form_holiday, nil)
        |> assign(:current_path, "/manage/settings/holidays")
        |> assign(:form, to_form(LibHolidays.change_holiday(%LibHoliday{})))
        |> assign(:nodes, nodes)

      {:ok, socket}
    end
  end

  def handle_event("new_holiday", _params, socket) do
    current_user = socket.assigns.current_scope.user
    is_super_admin = socket.assigns.is_super_admin

    holiday_struct =
      if is_super_admin do
        %LibHoliday{}
      else
        %LibHoliday{unit_id: current_user.node_id}
      end

    changeset = LibHolidays.change_holiday(holiday_struct)

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:form_holiday, nil)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("edit_holiday", %{"id" => id}, socket) do
    holiday = LibHolidays.get_holiday!(id)
    changeset = LibHolidays.change_holiday(holiday)

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:form_holiday, holiday)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("save_holiday", %{"lib_holiday" => holiday_params}, socket) do
    current_user = socket.assigns.current_scope.user
    is_super_admin = socket.assigns.is_super_admin

    # For non-super-admins, force unit_id to their assigned node
    holiday_params =
      if is_super_admin do
        holiday_params
      else
        Map.put(holiday_params, "unit_id", to_string(current_user.node_id))
      end

    case socket.assigns.form_holiday do
      nil ->
        case LibHolidays.create_holiday(holiday_params) do
          {:ok, _holiday} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Holiday created successfully"))
             |> assign(:show_form, false)
             |> assign(:holidays, LibHolidays.list_holidays(socket.assigns.selected_unit_id))
             |> assign(
               :holiday_stats,
               LibHolidays.get_holiday_stats(socket.assigns.selected_unit_id)
             )}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      holiday ->
        case LibHolidays.update_holiday(holiday, holiday_params) do
          {:ok, _holiday} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Holiday updated successfully"))
             |> assign(:show_form, false)
             |> assign(:holidays, LibHolidays.list_holidays(socket.assigns.selected_unit_id))
             |> assign(
               :holiday_stats,
               LibHolidays.get_holiday_stats(socket.assigns.selected_unit_id)
             )}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end
    end
  end

  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket, :show_form, false)}
  end

  def handle_event("delete_holiday", %{"id" => id}, socket) do
    holiday = LibHolidays.get_holiday!(id)
    {:ok, _} = LibHolidays.delete_holiday(holiday)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Holiday deleted successfully"))
     |> assign(:holidays, LibHolidays.list_holidays(socket.assigns.selected_unit_id))
     |> assign(:holiday_stats, LibHolidays.get_holiday_stats(socket.assigns.selected_unit_id))}
  end

  def handle_event("toggle_holiday", %{"id" => id}, socket) do
    holiday = LibHolidays.get_holiday!(id)
    new_status = !holiday.is_active

    case LibHolidays.update_holiday(holiday, %{is_active: new_status}) do
      {:ok, _} ->
        status_text = if new_status, do: "enabled", else: "disabled"

        {:noreply,
         socket
         |> put_flash(:info, gettext("Holiday %{status} successfully", status: status_text))
         |> assign(:holidays, LibHolidays.list_holidays(socket.assigns.selected_unit_id))
         |> assign(:holiday_stats, LibHolidays.get_holiday_stats(socket.assigns.selected_unit_id))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update holiday status"))}
    end
  end

  # Weekly Schedule Management Events

  def handle_event("setup_default_schedule", _params, socket) do
    # prefer explicit param, fall back to currently selected unit
    unit_id = socket.assigns.selected_unit_id

    LibHolidays.setup_default_weekly_schedule(unit_id)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Default weekly schedule set up (Monday-Friday business days)"))
     |> assign(:weekly_schedule, LibHolidays.get_weekly_schedule(unit_id))}
  end

  def handle_event("toggle_day_schedule", %{"day" => day_str}, socket) do
    day_of_week = String.to_integer(day_str)
    current_schedule = Enum.find(socket.assigns.weekly_schedule, &(&1.day_of_week == day_of_week))

    new_status = not current_schedule.is_business_day
    description = if new_status, do: "Business day", else: "Non-business day"

    unit_id = socket.assigns.selected_unit_id

    case LibHolidays.update_day_schedule(day_of_week, new_status, description, unit_id) do
      {:ok, _} ->
        day_name = current_schedule.day_name
        status_text = if new_status, do: "business day", else: "non-business day"

        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("%{day} set as %{status}", day: day_name, status: status_text)
         )
         |> assign(:weekly_schedule, LibHolidays.get_weekly_schedule(unit_id))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update day schedule"))}
    end
  end

  def handle_event("set_all_business", _params, socket) do
    # Set all days as business days for the currently selected unit
    unit_id = socket.assigns.selected_unit_id

    for day <- 1..7 do
      LibHolidays.update_day_schedule(day, true, "Business day", unit_id)
    end

    {:noreply,
     socket
     |> put_flash(:info, gettext("All days set as business days"))
     |> assign(:weekly_schedule, LibHolidays.get_weekly_schedule(unit_id))}
  end

  def handle_event("set_weekdays_only", _params, socket) do
    # Set Monday-Friday as business, Saturday-Sunday as non-business for selected unit
    unit_id = socket.assigns.selected_unit_id

    LibHolidays.setup_default_weekly_schedule(unit_id)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Schedule set to weekdays only (Monday-Friday)"))
     |> assign(:weekly_schedule, LibHolidays.get_weekly_schedule(unit_id))}
  end

  def handle_event("set_all_closed", _params, socket) do
    # Set all days as non-business days for selected unit
    unit_id = socket.assigns.selected_unit_id

    for day <- 1..7 do
      LibHolidays.update_day_schedule(day, false, "Non-business day", unit_id)
    end

    {:noreply,
     socket
     |> put_flash(:info, gettext("All days set as non-business days"))
     |> assign(:weekly_schedule, LibHolidays.get_weekly_schedule(unit_id))}
  end

  def handle_event("select_unit", %{"unit_id" => unit_id_str}, socket) do
    # Only super admins can change the selected unit; ignore changes from non-super-admins
    if not socket.assigns[:is_super_admin] do
      {:noreply, socket}
    else
      unit_id =
        case unit_id_str do
          "" -> nil
          val -> String.to_integer(val)
        end

      {:noreply,
       socket
       |> assign(:selected_unit_id, unit_id)
       |> assign(:weekly_schedule, LibHolidays.get_weekly_schedule(unit_id))}
    end
  end
end
