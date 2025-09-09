defmodule VoileWeb.Dashboard.Settings.HolidayLive do
  use VoileWeb, :live_view

  alias Voile.Schema.System.{LibHolidays, LibHoliday}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <.header>
          Library Holidays & Schedule Management
          <:subtitle>
            Manage holidays, weekly schedules, and non-business days for fine calculations
          </:subtitle>
          
          <:actions>
            <.button phx-click="new_holiday" class="bg-blue-600 hover:bg-blue-700">
              <.icon name="hero-plus" class="w-4 h-4 mr-2" /> Add Holiday
            </.button>
            <.button phx-click="setup_default_schedule" class="bg-indigo-600 hover:bg-indigo-700">
              <.icon name="hero-calendar-days" class="w-4 h-4 mr-2" /> Setup Default Schedule
            </.button>
            <.button phx-click="import_holidays" class="bg-green-600 hover:bg-green-700">
              <.icon name="hero-calendar-days" class="w-4 h-4 mr-2" /> Import Common Holidays
            </.button>
          </:actions>
        </.header>
        <!-- Holiday Stats -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-calendar" class="h-8 w-8 text-blue-600" />
              </div>
              
              <div class="ml-4">
                <div class="text-2xl font-bold text-gray-900">{@holiday_stats.total_holidays}</div>
                
                <div class="text-sm font-medium text-gray-500">Total Holidays</div>
              </div>
            </div>
          </div>
          
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-flag" class="h-8 w-8 text-green-600" />
              </div>
              
              <div class="ml-4">
                <div class="text-2xl font-bold text-gray-900">{@holiday_stats.public_holidays}</div>
                
                <div class="text-sm font-medium text-gray-500">Public Holidays</div>
              </div>
            </div>
          </div>
          
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-building-library" class="h-8 w-8 text-purple-600" />
              </div>
              
              <div class="ml-4">
                <div class="text-2xl font-bold text-gray-900">{@holiday_stats.library_holidays}</div>
                
                <div class="text-sm font-medium text-gray-500">Library Holidays</div>
              </div>
            </div>
          </div>
          
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-star" class="h-8 w-8 text-orange-600" />
              </div>
              
              <div class="ml-4">
                <div class="text-2xl font-bold text-gray-900">{@holiday_stats.custom_holidays}</div>
                
                <div class="text-sm font-medium text-gray-500">Custom Holidays</div>
              </div>
            </div>
          </div>
        </div>
        <!-- Info Panel -->
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div class="flex">
            <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400" />
            <div class="ml-3">
              <h3 class="text-sm font-medium text-blue-800">Holiday Impact on Fines</h3>
              
              <p class="mt-2 text-sm text-blue-700">
                Non-business days (weekly schedule) and holidays defined here will be excluded from overdue fine calculations.
                Only business days will count toward fine amounts. This ensures fair fine calculation during library closures.
              </p>
            </div>
          </div>
        </div>
        <!-- Weekly Schedule Configuration -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 border-b border-gray-200 sm:px-6">
            <div class="flex items-center justify-between">
              <h3 class="text-lg leading-6 font-medium text-gray-900">Weekly Schedule</h3>
              
              <div class="text-sm text-gray-500">Configure which days are business days</div>
            </div>
          </div>
          
          <div class="px-4 py-5 sm:p-6">
            <div class="grid grid-cols-2 md:grid-cols-7 gap-4">
              <%= for day <- @weekly_schedule do %>
                <div
                  class={[
                    "border-2 rounded-lg p-4 text-center cursor-pointer transition-all duration-200",
                    if day.is_business_day do
                      "border-green-300 bg-green-50 hover:bg-green-100"
                    else
                      "border-red-300 bg-red-50 hover:bg-red-100"
                    end
                  ]}
                  phx-click="toggle_day_schedule"
                  phx-value-day={day.day_of_week}
                >
                  <div class="text-sm font-medium text-gray-900">{day.day_name}</div>
                  
                  <div class={[
                    "mt-2 text-xs font-semibold",
                    if(day.is_business_day, do: "text-green-700", else: "text-red-700")
                  ]}>
                    {if day.is_business_day, do: "Business Day", else: "Non-Business"}
                  </div>
                  
                  <div class={[
                    "mt-1 inline-flex rounded-full px-2 py-1 text-xs font-medium",
                    if day.is_business_day do
                      "bg-green-100 text-green-800"
                    else
                      "bg-red-100 text-red-800"
                    end
                  ]}>
                    {if day.is_business_day, do: "Open", else: "Closed"}
                  </div>
                </div>
              <% end %>
            </div>
            
            <div class="mt-6 flex items-center justify-between">
              <div class="text-sm text-gray-500">Click on any day to toggle its business status</div>
              
              <div class="space-x-2">
                <.button phx-click="set_all_business" class="bg-green-600 hover:bg-green-700">
                  All Business Days
                </.button>
                <.button phx-click="set_weekdays_only" class="bg-blue-600 hover:bg-blue-700">
                  Weekdays Only
                </.button>
                <.button phx-click="set_all_closed" class="bg-red-600 hover:bg-red-700">
                  All Closed
                </.button>
              </div>
            </div>
          </div>
        </div>
        <!-- Holidays Table -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 border-b border-gray-200 sm:px-6">
            <div class="flex items-center justify-between">
              <h3 class="text-lg leading-6 font-medium text-gray-900">Holidays List</h3>
              
              <div class="text-sm text-gray-500">Current Year: {@holiday_stats.current_year}</div>
            </div>
          </div>
          
          <div class="overflow-hidden">
            <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
              <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
                <table class="min-w-full divide-y divide-gray-300">
                  <thead>
                    <tr>
                      <th class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900">
                        Holiday Name
                      </th>
                      
                      <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Date</th>
                      
                      <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Type</th>
                      
                      <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                        Status
                      </th>
                      
                      <th class="relative py-3.5 pl-3 pr-4 text-right text-sm font-semibold text-gray-900">
                        Actions
                      </th>
                    </tr>
                  </thead>
                  
                  <tbody class="divide-y divide-gray-200">
                    <%= for holiday <- @holidays do %>
                      <tr class={if holiday.is_active, do: "", else: "opacity-50"}>
                        <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm">
                          <div class="font-medium text-gray-900">{holiday.name}</div>
                          
                          <%= if holiday.description do %>
                            <div class="text-gray-500 text-xs">{holiday.description}</div>
                          <% end %>
                        </td>
                        
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                          {Calendar.strftime(holiday.holiday_date, "%A, %B %d, %Y")}
                        </td>
                        
                        <td class="whitespace-nowrap px-3 py-4 text-sm">
                          <span class={[
                            "inline-flex rounded-full px-2 text-xs font-semibold leading-5",
                            case holiday.holiday_type do
                              "public" -> "bg-green-100 text-green-800"
                              "library" -> "bg-purple-100 text-purple-800"
                              "custom" -> "bg-orange-100 text-orange-800"
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
                              "bg-green-100 text-green-800"
                            else
                              "bg-red-100 text-red-800"
                            end
                          ]}>
                            {if holiday.is_active, do: "Active", else: "Inactive"}
                          </span>
                        </td>
                        
                        <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium space-x-2">
                          <.button
                            phx-click="edit_holiday"
                            phx-value-id={holiday.id}
                            class="bg-blue-600 hover:bg-blue-700"
                          >
                            Edit
                          </.button>
                          <.button
                            phx-click="toggle_holiday"
                            phx-value-id={holiday.id}
                            class={
                              if holiday.is_active,
                                do: "bg-yellow-600 hover:bg-yellow-700",
                                else: "bg-green-600 hover:bg-green-700"
                            }
                          >
                            {if holiday.is_active, do: "Disable", else: "Enable"}
                          </.button>
                          <.button
                            phx-click="delete_holiday"
                            phx-value-id={holiday.id}
                            data-confirm="Are you sure you want to delete this holiday?"
                            class="bg-red-600 hover:bg-red-700"
                          >
                            Delete
                          </.button>
                        </td>
                      </tr>
                    <% end %>
                    
                    <%= if length(@holidays) == 0 do %>
                      <tr>
                        <td colspan="5" class="px-6 py-12 text-center text-sm text-gray-500">
                          <.icon name="hero-calendar-x" class="mx-auto h-12 w-12 text-gray-400" />
                          <h3 class="mt-2 text-sm font-medium text-gray-900">
                            No holidays configured
                          </h3>
                          
                          <p class="mt-1 text-sm text-gray-500">
                            Get started by adding a holiday or importing common holidays.
                          </p>
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
      <!-- Holiday Form Modal -->
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div class="mt-3">
              <h3 class="text-lg font-medium text-gray-900 mb-4">
                {if @form_holiday, do: "Edit Holiday", else: "Add New Holiday"}
              </h3>
              
              <.form for={@form} id="holiday-form" phx-submit="save_holiday">
                <.input field={@form[:name]} type="text" label="Holiday Name" required />
                <.input field={@form[:holiday_date]} type="date" label="Date" required />
                <.input
                  field={@form[:holiday_type]}
                  type="select"
                  label="Type"
                  options={[
                    {"Public Holiday", "public"},
                    {"Library Holiday", "library"},
                    {"Custom Holiday", "custom"}
                  ]}
                  required
                /> <.input field={@form[:description]} type="textarea" label="Description" />
                <.input field={@form[:is_recurring]} type="checkbox" label="Recurring annually" />
                <.input field={@form[:is_active]} type="checkbox" label="Active" />
                <!-- Hidden field to ensure schedule_type is set to 'holiday' -->
                <input type="hidden" name="lib_holiday[schedule_type]" value="holiday" />
                <div class="flex items-center justify-end space-x-2 mt-6">
                  <.button
                    type="button"
                    phx-click="cancel_form"
                    class="bg-gray-600 hover:bg-gray-700"
                  >
                    Cancel
                  </.button>
                  <.button type="submit" class="bg-blue-600 hover:bg-blue-700">
                    {if @form_holiday, do: "Update", else: "Create"} Holiday
                  </.button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      <% end %>
      <!-- Import Holidays Modal -->
      <%= if @show_import_modal do %>
        <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div class="mt-3">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Import Common Holidays</h3>
              
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Select Year</label>
                  <select
                    class="w-full border border-gray-300 rounded-md px-3 py-2"
                    phx-change="change_import_year"
                    name="year"
                  >
                    <%= for year <- (@current_year - 2)..(@current_year + 2) do %>
                      <option value={year} selected={year == @import_year}>{year}</option>
                    <% end %>
                  </select>
                </div>
                
                <div class="space-y-2">
                  <.button
                    phx-click="import_indonesian_holidays"
                    class="w-full bg-green-600 hover:bg-green-700"
                  >
                    Import Indonesian Public Holidays
                  </.button>
                  <.button
                    phx-click="import_library_holidays"
                    class="w-full bg-purple-600 hover:bg-purple-700"
                  >
                    Import Library Holidays
                  </.button>
                </div>
                
                <div class="flex items-center justify-end space-x-2 mt-6">
                  <.button
                    type="button"
                    phx-click="cancel_import"
                    class="bg-gray-600 hover:bg-gray-700"
                  >
                    Cancel
                  </.button>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    holidays = LibHolidays.list_holidays()
    holiday_stats = LibHolidays.get_holiday_stats()
    weekly_schedule = LibHolidays.get_weekly_schedule()
    current_year = Date.utc_today().year

    socket =
      socket
      |> assign(:holidays, holidays)
      |> assign(:holiday_stats, holiday_stats)
      |> assign(:weekly_schedule, weekly_schedule)
      |> assign(:current_year, current_year)
      |> assign(:import_year, current_year)
      |> assign(:show_form, false)
      |> assign(:show_import_modal, false)
      |> assign(:form_holiday, nil)
      |> assign(:form, to_form(LibHolidays.change_holiday(%LibHoliday{})))

    {:ok, socket}
  end

  def handle_event("new_holiday", _params, socket) do
    changeset = LibHolidays.change_holiday(%LibHoliday{})

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
    case socket.assigns.form_holiday do
      nil ->
        case LibHolidays.create_holiday(holiday_params) do
          {:ok, _holiday} ->
            {:noreply,
             socket
             |> put_flash(:info, "Holiday created successfully")
             |> assign(:show_form, false)
             |> assign(:holidays, LibHolidays.list_holidays())
             |> assign(:holiday_stats, LibHolidays.get_holiday_stats())}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      holiday ->
        case LibHolidays.update_holiday(holiday, holiday_params) do
          {:ok, _holiday} ->
            {:noreply,
             socket
             |> put_flash(:info, "Holiday updated successfully")
             |> assign(:show_form, false)
             |> assign(:holidays, LibHolidays.list_holidays())
             |> assign(:holiday_stats, LibHolidays.get_holiday_stats())}

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
     |> put_flash(:info, "Holiday deleted successfully")
     |> assign(:holidays, LibHolidays.list_holidays())
     |> assign(:holiday_stats, LibHolidays.get_holiday_stats())}
  end

  def handle_event("toggle_holiday", %{"id" => id}, socket) do
    holiday = LibHolidays.get_holiday!(id)
    new_status = !holiday.is_active

    case LibHolidays.update_holiday(holiday, %{is_active: new_status}) do
      {:ok, _} ->
        status_text = if new_status, do: "enabled", else: "disabled"

        {:noreply,
         socket
         |> put_flash(:info, "Holiday #{status_text} successfully")
         |> assign(:holidays, LibHolidays.list_holidays())
         |> assign(:holiday_stats, LibHolidays.get_holiday_stats())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update holiday status")}
    end
  end

  def handle_event("import_holidays", _params, socket) do
    {:noreply, assign(socket, :show_import_modal, true)}
  end

  def handle_event("cancel_import", _params, socket) do
    {:noreply, assign(socket, :show_import_modal, false)}
  end

  def handle_event("change_import_year", %{"year" => year}, socket) do
    {:noreply, assign(socket, :import_year, String.to_integer(year))}
  end

  def handle_event("import_indonesian_holidays", _params, socket) do
    {success, errors} = LibHolidays.import_indonesian_holidays(socket.assigns.import_year)

    message =
      if errors == 0 do
        "Successfully imported #{success} Indonesian holidays!"
      else
        "Imported #{success} holidays, #{errors} failed (may already exist)"
      end

    {:noreply,
     socket
     |> put_flash(:info, message)
     |> assign(:show_import_modal, false)
     |> assign(:holidays, LibHolidays.list_holidays())
     |> assign(:holiday_stats, LibHolidays.get_holiday_stats())}
  end

  def handle_event("import_library_holidays", _params, socket) do
    {success, errors} = LibHolidays.import_library_holidays(socket.assigns.import_year)

    message =
      if errors == 0 do
        "Successfully imported #{success} library holidays!"
      else
        "Imported #{success} holidays, #{errors} failed (may already exist)"
      end

    {:noreply,
     socket
     |> put_flash(:info, message)
     |> assign(:show_import_modal, false)
     |> assign(:holidays, LibHolidays.list_holidays())
     |> assign(:holiday_stats, LibHolidays.get_holiday_stats())}
  end

  # Weekly Schedule Management Events

  def handle_event("setup_default_schedule", _params, socket) do
    LibHolidays.setup_default_weekly_schedule()

    {:noreply,
     socket
     |> put_flash(:info, "Default weekly schedule set up (Monday-Friday business days)")
     |> assign(:weekly_schedule, LibHolidays.get_weekly_schedule())}
  end

  def handle_event("toggle_day_schedule", %{"day" => day_str}, socket) do
    day_of_week = String.to_integer(day_str)
    current_schedule = Enum.find(socket.assigns.weekly_schedule, &(&1.day_of_week == day_of_week))

    new_status = not current_schedule.is_business_day
    description = if new_status, do: "Business day", else: "Non-business day"

    case LibHolidays.update_day_schedule(day_of_week, new_status, description) do
      {:ok, _} ->
        day_name = current_schedule.day_name
        status_text = if new_status, do: "business day", else: "non-business day"

        {:noreply,
         socket
         |> put_flash(:info, "#{day_name} set as #{status_text}")
         |> assign(:weekly_schedule, LibHolidays.get_weekly_schedule())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update day schedule")}
    end
  end

  def handle_event("set_all_business", _params, socket) do
    # Set all days as business days
    for day <- 1..7 do
      LibHolidays.update_day_schedule(day, true, "Business day")
    end

    {:noreply,
     socket
     |> put_flash(:info, "All days set as business days")
     |> assign(:weekly_schedule, LibHolidays.get_weekly_schedule())}
  end

  def handle_event("set_weekdays_only", _params, socket) do
    # Set Monday-Friday as business, Saturday-Sunday as non-business
    LibHolidays.setup_default_weekly_schedule()

    {:noreply,
     socket
     |> put_flash(:info, "Schedule set to weekdays only (Monday-Friday)")
     |> assign(:weekly_schedule, LibHolidays.get_weekly_schedule())}
  end

  def handle_event("set_all_closed", _params, socket) do
    # Set all days as non-business days
    for day <- 1..7 do
      LibHolidays.update_day_schedule(day, false, "Non-business day")
    end

    {:noreply,
     socket
     |> put_flash(:info, "All days set as non-business days")
     |> assign(:weekly_schedule, LibHolidays.get_weekly_schedule())}
  end
end
