defmodule VoileWeb.Dashboard.Circulation.Index do
  use VoileWeb, :live_view_dashboard

  import VoileWeb.Dashboard.Circulation.Helpers
  import VoileWeb.Dashboard.Circulation.Components

  alias Voile.Schema.Library.Circulation

  def render(assigns) do
    ~H"""
    <div class="px-4 py-6">
      <.circulation_breadcrumb
        root_label="Manage"
        root_path={~p"/manage"}
        current_label="Circulation"
      />
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Library Circulation Dashboard</h1>
        
        <p class="mt-2 text-gray-600">
          Manage all library circulation activities from this central dashboard.
        </p>
      </div>
      <!-- Quick Stats -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        <div class="bg-white rounded-lg shadow p-6 border-l-4 border-blue-500">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <.icon name="hero-book-open" class="w-8 h-8 text-blue-500" />
            </div>
            
            <div class="ml-4">
              <h3 class="text-sm font-medium text-gray-500">Active Transactions</h3>
              
              <p class="text-2xl font-semibold text-gray-900">
                <%= if @stats.active_transactions do %>
                  {@stats.active_transactions}
                <% else %>
                  <svg
                    class="animate-spin h-6 w-6 text-gray-600 inline-block"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    >
                    </circle>
                    
                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
                    >
                    </path>
                  </svg>
                <% end %>
              </p>
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
              
              <p class="text-2xl font-semibold text-gray-900">
                <%= if @stats.overdue_count do %>
                  {@stats.overdue_count}
                <% else %>
                  <svg
                    class="animate-spin h-6 w-6 text-gray-600 inline-block"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    >
                    </circle>
                    
                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
                    >
                    </path>
                  </svg>
                <% end %>
              </p>
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
              
              <p class="text-2xl font-semibold text-gray-900">
                <%= if @stats.active_reservations do %>
                  {@stats.active_reservations}
                <% else %>
                  <svg
                    class="animate-spin h-6 w-6 text-gray-600 inline-block"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    >
                    </circle>
                    
                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
                    >
                    </path>
                  </svg>
                <% end %>
              </p>
            </div>
          </div>
        </div>
      </div>
      
      <div class="bg-white rounded-lg shadow p-6 border-l-4 border-red-500 mb-8">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <.icon name="hero-banknotes" class="w-8 h-8 text-red-500" />
          </div>
          
          <div class="ml-4">
            <h3 class="text-sm font-medium text-gray-500">Outstanding Fines</h3>
            
            <p class="text-2xl font-semibold text-gray-900">
              <%= if @stats.outstanding_fines do %>
                {format_idr(@stats.outstanding_fines)}
              <% else %>
                <svg
                  class="animate-spin h-6 w-6 text-gray-600 inline-block"
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <circle
                    class="opacity-25"
                    cx="12"
                    cy="12"
                    r="10"
                    stroke="currentColor"
                    stroke-width="4"
                  >
                  </circle>
                  
                  <path
                    class="opacity-75"
                    fill="currentColor"
                    d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
                  >
                  </path>
                </svg>
              <% end %>
            </p>
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
        </.link> <.quick_actions current_user={@current_scope.user} />
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
    # Assign placeholders and load heavy data asynchronously to speed up mount
    socket =
      socket
      |> assign(:page_title, "Circulation Dashboard")
      |> assign(:stats, %{
        active_transactions: nil,
        overdue_count: nil,
        active_reservations: nil,
        outstanding_fines: nil
      })
      |> assign(:recent_activities, [])

    # Trigger async load of stats and recent activities
    if connected?(socket), do: send(self(), :load_stats)

    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_info(:load_stats, socket) do
    # Perform DB queries asynchronously
    stats = %{
      active_transactions: get_active_transactions_count(),
      overdue_count: length(Circulation.list_overdue_transactions() || []),
      active_reservations: get_active_reservations_count(),
      outstanding_fines: calculate_outstanding_fines()
    }

    {recent_activities, _} = Circulation.list_circulation_history_paginated(1, 10)

    {:noreply,
     socket
     |> assign(:stats, stats)
     |> assign(:recent_activities, recent_activities || [])}
  end

  defp calculate_outstanding_fines do
    # Use cached result when available
    case cache_get(:outstanding_fines) do
      {:ok, val} ->
        val

      :miss ->
        fines = Circulation.list_fines()

        total =
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

        cache_put(:outstanding_fines, total, 30_000)
        total
    end
  end

  defp get_active_transactions_count do
    # Count all active transactions in the system
    alias Voile.Schema.Library.Transaction
    alias Voile.Repo
    import Ecto.Query

    case cache_get(:active_transactions) do
      {:ok, val} ->
        val

      :miss ->
        val =
          Transaction
          |> where([t], t.status == "active")
          |> Repo.aggregate(:count, :id)

        cache_put(:active_transactions, val, 30_000)
        val
    end
  end

  defp get_active_reservations_count do
    # Count all active reservations (pending and available) in the system
    alias Voile.Schema.Library.Reservation
    alias Voile.Repo
    import Ecto.Query

    case cache_get(:active_reservations) do
      {:ok, val} ->
        val

      :miss ->
        val =
          Reservation
          |> where([r], r.status in ["pending", "available"])
          |> Repo.aggregate(:count, :id)

        cache_put(:active_reservations, val, 30_000)
        val
    end
  end

  # Simple ETS cache helpers (table: :voile_dashboard_cache)
  defp ensure_cache_table do
    case :ets.info(:voile_dashboard_cache) do
      :undefined ->
        :ets.new(:voile_dashboard_cache, [:named_table, :public, read_concurrency: true])

      _ ->
        :ok
    end
  end

  defp cache_put(key, value, ttl_ms) do
    ensure_cache_table()
    expire_at = System.system_time(:millisecond) + ttl_ms
    :ets.insert(:voile_dashboard_cache, {key, value, expire_at})
    :ok
  end

  defp cache_get(key) do
    ensure_cache_table()

    case :ets.lookup(:voile_dashboard_cache, key) do
      [{^key, value, expire_at}] ->
        if System.system_time(:millisecond) <= expire_at do
          {:ok, value}
        else
          :ets.delete(:voile_dashboard_cache, key)
          :miss
        end

      _ ->
        :miss
    end
  end

  defp activity_color("loan"), do: "bg-blue-400"
  defp activity_color("return"), do: "bg-green-400"
  defp activity_color("renewal"), do: "bg-yellow-400"
  defp activity_color("reserve"), do: "bg-purple-400"
  defp activity_color("fine_paid"), do: "bg-green-400"
  defp activity_color(_), do: "bg-gray-400"
end
