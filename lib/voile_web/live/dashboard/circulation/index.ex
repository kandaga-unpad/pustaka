defmodule VoileWeb.Dashboard.Circulation.Index do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Circulation.Helpers
  alias Voile.Schema.Library.Circulation

  def render(assigns) do
    ~H"""
    <div class="px-4 py-6">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Library Circulation Dashboard</h1>
        
        <p class="mt-2 text-gray-600">
          Manage all library circulation activities from this central dashboard.
        </p>
      </div>
      <!-- Quick Stats -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div class="bg-white rounded-lg shadow p-6 border-l-4 border-blue-500">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <.icon name="hero-book-open" class="w-8 h-8 text-blue-500" />
            </div>
            
            <div class="ml-4">
              <h3 class="text-sm font-medium text-gray-500">Active Transactions</h3>
              
              <p class="text-2xl font-semibold text-gray-900">{@stats.active_transactions}</p>
            </div>
          </div>
        </div>
        
        <div class="bg-white rounded-lg shadow p-6 border-l-4 border-yellow-500">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <.icon name="hero-clock" class="w-8 h-8 text-yellow-500" />
            </div>
            
            <div class="ml-4">
              <h3 class="text-sm font-medium text-gray-500">Overdue Items</h3>
              
              <p class="text-2xl font-semibold text-gray-900">{@stats.overdue_count}</p>
            </div>
          </div>
        </div>
        
        <div class="bg-white rounded-lg shadow p-6 border-l-4 border-green-500">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <.icon name="hero-bookmark" class="w-8 h-8 text-green-500" />
            </div>
            
            <div class="ml-4">
              <h3 class="text-sm font-medium text-gray-500">Active Reservations</h3>
              
              <p class="text-2xl font-semibold text-gray-900">{@stats.active_reservations}</p>
            </div>
          </div>
        </div>
        
        <div class="bg-white rounded-lg shadow p-6 border-l-4 border-red-500">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <.icon name="hero-currency-dollar" class="w-8 h-8 text-red-500" />
            </div>
            
            <div class="ml-4">
              <h3 class="text-sm font-medium text-gray-500">Outstanding Fines</h3>
              
              <p class="text-2xl font-semibold text-gray-900">
                {format_idr(@stats.outstanding_fines)}
              </p>
            </div>
          </div>
        </div>
      </div>
      <!-- Navigation Cards -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <.link navigate={~p"/manage/circulation/transactions"} class="group">
          <div class="bg-white rounded-lg shadow hover:shadow-lg transition-shadow p-6 h-full">
            <div class="flex items-center mb-4">
              <div class="flex-shrink-0">
                <.icon name="hero-arrow-path" class="w-8 h-8 text-blue-600 group-hover:text-blue-700" />
              </div>
              
              <h3 class="ml-3 text-lg font-semibold text-gray-900 group-hover:text-blue-700">
                Transactions
              </h3>
            </div>
            
            <p class="text-gray-600 text-sm">
              Manage book checkouts, returns, renewals, and track all circulation activities.
            </p>
            
            <div class="mt-4 flex items-center text-sm text-blue-600 group-hover:text-blue-700">
              <span>Manage Transactions</span> <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
            </div>
          </div>
        </.link>
        <.link navigate={~p"/manage/circulation/reservations"} class="group">
          <div class="bg-white rounded-lg shadow hover:shadow-lg transition-shadow p-6 h-full">
            <div class="flex items-center mb-4">
              <div class="flex-shrink-0">
                <.icon
                  name="hero-bookmark-square"
                  class="w-8 h-8 text-green-600 group-hover:text-green-700"
                />
              </div>
              
              <h3 class="ml-3 text-lg font-semibold text-gray-900 group-hover:text-green-700">
                Reservations
              </h3>
            </div>
            
            <p class="text-gray-600 text-sm">
              Handle item reservations, queue management, and availability notifications.
            </p>
            
            <div class="mt-4 flex items-center text-sm text-green-600 group-hover:text-green-700">
              <span>Manage Reservations</span> <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
            </div>
          </div>
        </.link>
        <.link navigate={~p"/manage/circulation/requisitions"} class="group">
          <div class="bg-white rounded-lg shadow hover:shadow-lg transition-shadow p-6 h-full">
            <div class="flex items-center mb-4">
              <div class="flex-shrink-0">
                <.icon
                  name="hero-document-plus"
                  class="w-8 h-8 text-purple-600 group-hover:text-purple-700"
                />
              </div>
              
              <h3 class="ml-3 text-lg font-semibold text-gray-900 group-hover:text-purple-700">
                Requisitions
              </h3>
            </div>
            
            <p class="text-gray-600 text-sm">
              Process member requests for new items, interlibrary loans, and special services.
            </p>
            
            <div class="mt-4 flex items-center text-sm text-purple-600 group-hover:text-purple-700">
              <span>Manage Requisitions</span> <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
            </div>
          </div>
        </.link>
        <.link navigate={~p"/manage/circulation/fines"} class="group">
          <div class="bg-white rounded-lg shadow hover:shadow-lg transition-shadow p-6 h-full">
            <div class="flex items-center mb-4">
              <div class="flex-shrink-0">
                <.icon name="hero-banknotes" class="w-8 h-8 text-red-600 group-hover:text-red-700" />
              </div>
              
              <h3 class="ml-3 text-lg font-semibold text-gray-900 group-hover:text-red-700">
                Fines Management
              </h3>
            </div>
            
            <p class="text-gray-600 text-sm">
              Manage overdue fines, payments, waivers, and financial transactions.
            </p>
            
            <div class="mt-4 flex items-center text-sm text-red-600 group-hover:text-red-700">
              <span>Manage Fines</span> <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
            </div>
          </div>
        </.link>
        <.link navigate={~p"/manage/circulation/circulation_history"} class="group">
          <div class="bg-white rounded-lg shadow hover:shadow-lg transition-shadow p-6 h-full">
            <div class="flex items-center mb-4">
              <div class="flex-shrink-0">
                <.icon name="hero-clock" class="w-8 h-8 text-indigo-600 group-hover:text-indigo-700" />
              </div>
              
              <h3 class="ml-3 text-lg font-semibold text-gray-900 group-hover:text-indigo-700">
                Circulation History
              </h3>
            </div>
            
            <p class="text-gray-600 text-sm">
              View detailed logs and audit trails of all circulation activities.
            </p>
            
            <div class="mt-4 flex items-center text-sm text-indigo-600 group-hover:text-indigo-700">
              <span>View History</span> <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
            </div>
          </div>
        </.link>
        <!-- Quick Actions Card -->
        <div class="bg-gradient-to-br from-gray-50 to-gray-100 rounded-lg p-6 h-full">
          <div class="flex items-center mb-4">
            <div class="flex-shrink-0"><.icon name="hero-bolt" class="w-8 h-8 text-gray-700" /></div>
            
            <h3 class="ml-3 text-lg font-semibold text-gray-900">Quick Actions</h3>
          </div>
          
          <div class="space-y-2">
            <button class="w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-white hover:shadow-sm rounded-md transition-colors">
              Quick Checkout
            </button>
            <button class="w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-white hover:shadow-sm rounded-md transition-colors">
              Quick Return
            </button>
            <button class="w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-white hover:shadow-sm rounded-md transition-colors">
              Member Lookup
            </button>
            <button class="w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-white hover:shadow-sm rounded-md transition-colors">
              Item Search
            </button>
          </div>
        </div>
      </div>
      <!-- Recent Activity -->
      <div class="mt-8 bg-white rounded-lg shadow">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-semibold text-gray-900">Recent Activity</h3>
        </div>
        
        <div class="divide-y divide-gray-200">
          <%= for activity <- @recent_activities do %>
            <div class="px-6 py-4 flex items-center justify-between">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <div class={"w-2 h-2 rounded-full #{activity_color(activity.event_type)}"}></div>
                </div>
                
                <div class="ml-4">
                  <p class="text-sm text-gray-900">{activity.description}</p>
                  
                  <p class="text-xs text-gray-500">{format_datetime(activity.event_date)}</p>
                </div>
              </div>
              
              <div class="text-xs text-gray-400">{activity.event_type}</div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    # Get circulation statistics
    stats = %{
      active_transactions: get_active_transactions_count(),
      overdue_count: length(Circulation.list_overdue_transactions() || []),
      active_reservations: get_active_reservations_count(),
      outstanding_fines: calculate_outstanding_fines()
    }

    # Get recent activities (limit to 10)
    {recent_activities, _} = Circulation.list_circulation_history_paginated(1, 10)

    socket =
      socket
      |> assign(:page_title, "Circulation Dashboard")
      |> assign(:stats, stats)
      |> assign(:recent_activities, recent_activities || [])

    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  defp calculate_outstanding_fines do
    fines = Circulation.list_fines()

    fines
    |> Enum.reduce(Decimal.new(0), fn fine, acc ->
      if fine.fine_status in ["pending", "partial_paid"] do
        Decimal.add(acc, fine.balance || Decimal.new(0))
      else
        acc
      end
    end)
    |> Decimal.to_float()
    |> trunc()
  end

  defp get_active_transactions_count do
    # Count all active transactions in the system
    alias Voile.Schema.Library.Transaction
    alias Voile.Repo
    import Ecto.Query

    Transaction
    |> where([t], t.status == "active")
    |> Repo.aggregate(:count, :id)
  end

  defp get_active_reservations_count do
    # Count all active reservations (pending and available) in the system
    alias Voile.Schema.Library.Reservation
    alias Voile.Repo
    import Ecto.Query

    Reservation
    |> where([r], r.status in ["pending", "available"])
    |> Repo.aggregate(:count, :id)
  end

  defp activity_color("loan"), do: "bg-blue-400"
  defp activity_color("return"), do: "bg-green-400"
  defp activity_color("renewal"), do: "bg-yellow-400"
  defp activity_color("reserve"), do: "bg-purple-400"
  defp activity_color("fine_paid"), do: "bg-green-400"
  defp activity_color(_), do: "bg-gray-400"
end
