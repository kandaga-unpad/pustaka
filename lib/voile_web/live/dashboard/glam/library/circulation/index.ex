defmodule VoileWeb.Dashboard.Glam.Library.Circulation.Index do
  use VoileWeb, :live_view_dashboard

  import VoileWeb.Dashboard.Glam.Library.Circulation.Helpers
  import VoileWeb.Dashboard.Glam.Library.Circulation.Components

  alias Voile.Schema.Library.Circulation
  alias VoileWeb.Auth.Authorization

  def render(assigns) do
    ~H"""
    <div class="px-4 py-6">
      <.breadcrumb items={[
        %{label: "Manage", path: ~p"/manage"},
        %{label: "GLAM", path: ~p"/manage/glam"},
        %{label: "Library", path: ~p"/manage/glam/library"},
        %{label: "Circulation", path: nil}
      ]} />
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">
          Library Circulation Dashboard
        </h1>

        <p class="mt-2 text-gray-600 dark:text-gray-400">
          Manage all library circulation activities from this central dashboard.
        </p>
      </div>
      <%!-- Quick Action Modals --%>
      <.quick_checkout_modal
        quick_checkout_visible={@quick_checkout_visible}
        checkout_form={@checkout_form}
      />
      <.quick_return_modal
        quick_return_visible={@quick_return_visible}
        return_form={@return_form}
        quick_return_transaction={@quick_return_transaction}
        quick_return_predicted_fine={@quick_return_predicted_fine}
      />
      <.member_lookup_modal
        member_lookup_visible={@member_lookup_visible}
        lookup_form={@lookup_form}
        member_results={@member_results}
        selected_member={@selected_member}
      />
      <!-- Quick Stats -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6 border-l-4 border-blue-500">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <.icon name="hero-book-open" class="w-8 h-8 text-blue-500" />
            </div>

            <div class="ml-4">
              <h3 class="text-sm font-medium text-gray-500 dark:text-gray-400">
                Active Transactions
              </h3>

              <p class="text-2xl font-semibold text-gray-900 dark:text-gray-100">
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

        <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6 border-l-4 border-yellow-500">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <.icon name="hero-clock" class="w-8 h-8 text-yellow-500" />
            </div>

            <div class="ml-4">
              <h3 class="text-sm font-medium text-gray-500 dark:text-gray-400">Overdue Items</h3>

              <p class="text-2xl font-semibold text-gray-900 dark:text-gray-100">
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

        <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6 border-l-4 border-green-500">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <.icon name="hero-bookmark" class="w-8 h-8 text-green-500" />
            </div>

            <div class="ml-4">
              <h3 class="text-sm font-medium text-gray-500 dark:text-gray-400">
                Active Reservations
              </h3>

              <p class="text-2xl font-semibold text-gray-900 dark:text-gray-100">
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

      <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6 border-l-4 border-red-500 mb-8">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <.icon name="hero-banknotes" class="w-8 h-8 text-red-500" />
          </div>

          <div class="ml-4">
            <h3 class="text-sm font-medium text-gray-500 dark:text-gray-400">Outstanding Fines</h3>

            <p class="text-2xl font-semibold text-gray-900 dark:text-gray-100">
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
        <.link navigate={~p"/manage/glam/library/circulation/transactions"} class="group">
          <div class="bg-white dark:bg-gray-700 rounded-lg shadow hover:shadow-lg transition-shadow p-6 h-full">
            <div class="flex items-center mb-4">
              <div class="flex-shrink-0">
                <.icon name="hero-arrow-path" class="w-8 h-8 text-blue-600 group-hover:text-blue-700" />
              </div>

              <h3 class="ml-3 text-lg font-semibold text-gray-900 group-hover:text-blue-700 dark:text-gray-100 dark:group-hover:text-blue-300">
                Transactions
              </h3>
            </div>

            <p class="text-gray-600 dark:text-gray-300 text-sm">
              Manage book checkouts, returns, renewals, and track all circulation activities.
            </p>

            <div class="mt-4 flex items-center text-sm text-blue-600 group-hover:text-blue-700 dark:text-blue-400  dark:group-hover:text-blue-300">
              <span>Manage Transactions</span> <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
            </div>
          </div>
        </.link>
        <.link navigate={~p"/manage/glam/library/circulation/reservations"} class="group">
          <div class="bg-white dark:bg-gray-700 rounded-lg shadow hover:shadow-lg transition-shadow p-6 h-full">
            <div class="flex items-center mb-4">
              <div class="flex-shrink-0">
                <.icon
                  name="hero-bookmark-square"
                  class="w-8 h-8 text-green-600 group-hover:text-green-700"
                />
              </div>

              <h3 class="ml-3 text-lg font-semibold text-gray-900 group-hover:text-green-700 dark:text-gray-100 dark:group-hover:text-green-300">
                Reservations
              </h3>
            </div>

            <p class="text-gray-600 dark:text-gray-300 text-sm">
              Handle item reservations, queue management, and availability notifications.
            </p>

            <div class="mt-4 flex items-center text-sm text-green-600 group-hover:text-green-700 dark:text-green-400 dark:group-hover:text-green-300">
              <span>Manage Reservations</span> <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
            </div>
          </div>
        </.link>
        <.link navigate={~p"/manage/glam/library/circulation/requisitions"} class="group">
          <div class="bg-white dark:bg-gray-700 rounded-lg shadow hover:shadow-lg transition-shadow p-6 h-full">
            <div class="flex items-center mb-4">
              <div class="flex-shrink-0">
                <.icon
                  name="hero-document-plus"
                  class="w-8 h-8 text-purple-600 group-hover:text-purple-700 dark:text-purple-400 dark:group-hover:text-purple-300"
                />
              </div>

              <h3 class="ml-3 text-lg font-semibold text-gray-900 group-hover:text-purple-700  dark:text-gray-100 dark:group-hover:text-purple-300">
                Requisitions
              </h3>
            </div>

            <p class="text-gray-600 dark:text-gray-300 text-sm">
              Process member requests for new items, interlibrary loans, and special services.
            </p>

            <div class="mt-4 flex items-center text-sm text-purple-600 group-hover:text-purple-700 dark:text-purple-400 dark:group-hover:text-purple-300">
              <span>Manage Requisitions</span> <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
            </div>
          </div>
        </.link>
        <.link navigate={~p"/manage/glam/library/circulation/fines"} class="group">
          <div class="bg-white dark:bg-gray-700 rounded-lg shadow hover:shadow-lg transition-shadow p-6 h-full">
            <div class="flex items-center mb-4">
              <div class="flex-shrink-0">
                <.icon name="hero-banknotes" class="w-8 h-8 text-red-600 group-hover:text-red-700" />
              </div>

              <h3 class="ml-3 text-lg font-semibold text-gray-900 group-hover:text-red-700  dark:text-gray-100 dark:group-hover:text-red-300">
                Fines Management
              </h3>
            </div>

            <p class="text-gray-600 dark:text-gray-300 text-sm">
              Manage overdue fines, payments, waivers, and financial transactions.
            </p>

            <div class="mt-4 flex items-center text-sm text-red-600 group-hover:text-red-700 dark:text-red-400 dark:group-hover:text-red-300">
              <span>Manage Fines</span> <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
            </div>
          </div>
        </.link>
        <.link navigate={~p"/manage/glam/library/circulation/circulation_history"} class="group">
          <div class="bg-white dark:bg-gray-700 rounded-lg shadow hover:shadow-lg transition-shadow p-6 h-full">
            <div class="flex items-center mb-4">
              <div class="flex-shrink-0">
                <.icon
                  name="hero-clock"
                  class="w-8 h-8 text-indigo-600 group-hover:text-indigo-700 dark:text-indigo-400 dark:group-hover:text-indigo-300"
                />
              </div>

              <h3 class="ml-3 text-lg font-semibold text-gray-900 group-hover:text-indigo-700 dark:text-gray-100 dark:group-hover:text-indigo-300">
                Circulation History
              </h3>
            </div>

            <p class="text-gray-600 dark:text-gray-300 text-sm">
              View detailed logs and audit trails of all circulation activities.
            </p>

            <div class="mt-4 flex items-center text-sm text-indigo-600 group-hover:text-indigo-700 dark:text-indigo-400 dark:group-hover:text-indigo-300">
              <span>View History</span> <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
            </div>
          </div>
        </.link>
         <.quick_actions current_user={@current_scope.user} />
      </div>
      <!-- Recent Activity -->
      <div class="mt-8 bg-white dark:bg-gray-700 rounded-lg shadow">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">Recent Activity</h3>
        </div>

        <div class="divide-y divide-gray-200">
          <%= for activity <- @recent_activities do %>
            <div class="px-6 py-4 flex items-center justify-between">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <div class={"w-2 h-2 rounded-full #{activity_color(activity.event_type)}"}></div>
                </div>

                <div class="ml-4">
                  <p class="text-sm text-gray-900 dark:text-gray-100">{activity.description}</p>

                  <p class="text-xs text-gray-500 dark:text-gray-400">
                    {format_datetime(activity.event_date)}
                  </p>
                </div>
              </div>

              <div class="text-xs text-gray-400 dark:text-gray-300">{activity.event_type}</div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    # Check if user has permission to view circulation
    unless Authorization.can?(socket, "circulation.view_transactions") do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access circulation management")
        |> push_navigate(to: ~p"/manage/glam/library")

      {:ok, socket}
    else
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
        |> assign(:quick_checkout_visible, false)
        |> assign(:checkout_form, to_form(%{}))
        |> assign(:quick_return_visible, false)
        |> assign(:return_form, to_form(%{}))
        |> assign(:quick_return_transaction, nil)
        |> assign(:quick_return_predicted_fine, Decimal.new("0"))
        |> assign(:member_lookup_visible, false)
        |> assign(:lookup_form, to_form(%{}))
        |> assign(:member_results, [])
        |> assign(:selected_member, nil)

      # Trigger async load of stats and recent activities
      if connected?(socket), do: send(self(), :load_stats)

      {:ok, socket}
    end
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

  # Quick Checkout handlers
  def handle_event("show_quick_checkout", _params, socket) do
    if can?(socket, "circulation.checkout") do
      {:noreply, assign(socket, :quick_checkout_visible, true)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to checkout items")}
    end
  end

  def handle_event("cancel_quick_checkout", _params, socket) do
    socket =
      socket
      |> assign(:quick_checkout_visible, false)
      |> assign(:checkout_form, to_form(%{}))

    {:noreply, socket}
  end

  def handle_event("quick_checkout_submit", params, socket) do
    unless can?(socket, "circulation.checkout") do
      {:noreply, put_flash(socket, :error, "You don't have permission to checkout items")}
    else
      member_id = Map.get(params, "member_id", "")
      item_id = Map.get(params, "item_id", "")

      cond do
        member_id == "" ->
          {:noreply, put_flash(socket, :error, "Member identifier is required")}

        item_id == "" ->
          {:noreply, put_flash(socket, :error, "Item code is required")}

        true ->
          alias Voile.Schema.Accounts
          alias Voile.Schema.Catalog

          case Accounts.get_user_by_identifier(member_id) do
            nil ->
              {:noreply, put_flash(socket, :error, "Member not found")}

            member ->
              case Catalog.get_item_by_code(item_id) do
                nil ->
                  {:noreply, put_flash(socket, :error, "Item not found")}

                item ->
                  librarian = socket.assigns.current_scope.user.id

                  case Circulation.checkout_item(member.id, item.id, librarian) do
                    {:ok, _transaction} ->
                      socket =
                        socket
                        |> assign(:quick_checkout_visible, false)
                        |> assign(:checkout_form, to_form(%{}))
                        |> put_flash(:info, "Item checked out successfully")

                      send(self(), :load_stats)
                      {:noreply, socket}

                    {:error, changeset} ->
                      errors =
                        changeset
                        |> Map.get(:errors, [])
                        |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
                        |> Enum.join(", ")

                      {:noreply, put_flash(socket, :error, "Failed to checkout: #{errors}")}
                  end
              end
          end
      end
    end
  end

  # Quick Return handlers
  def handle_event("show_quick_return", _params, socket) do
    if can?(socket, "circulation.return") do
      {:noreply, assign(socket, :quick_return_visible, true)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to return items")}
    end
  end

  def handle_event("cancel_quick_return", _params, socket) do
    socket =
      socket
      |> assign(:quick_return_visible, false)
      |> assign(:return_form, to_form(%{}))
      |> assign(:quick_return_transaction, nil)
      |> assign(:quick_return_predicted_fine, Decimal.new("0"))

    {:noreply, socket}
  end

  def handle_event("quick_return_search", %{"item_code" => item_code}, socket) do
    unless can?(socket, "circulation.return") do
      {:noreply, put_flash(socket, :error, "You don't have permission to return items")}
    else
      alias Voile.Schema.Catalog
      alias Voile.Schema.Accounts

      case Catalog.get_item_by_code(item_code) do
        nil ->
          {:noreply, put_flash(socket, :error, "Item not found")}

        item ->
          # Find active transaction for this item
          case Circulation.get_active_transaction_by_item(item.id) do
            nil ->
              {:noreply, put_flash(socket, :error, "No active transaction found for this item")}

            transaction ->
              # Load member with user_type for fine calculation
              member = Accounts.get_user!(transaction.member_id)

              predicted_fine =
                if Voile.Schema.Library.Transaction.overdue?(transaction) do
                  days = Voile.Schema.Library.Transaction.days_overdue(transaction)
                  daily = member.user_type.fine_per_day || Decimal.new("1.00")
                  Decimal.mult(Decimal.new(days), daily)
                else
                  Decimal.new("0")
                end

              socket =
                socket
                |> assign(:quick_return_transaction, transaction)
                |> assign(:quick_return_predicted_fine, predicted_fine)

              {:noreply, socket}
          end
      end
    end
  end

  def handle_event("quick_return_confirm", params, socket) do
    unless can?(socket, "circulation.return") do
      {:noreply, put_flash(socket, :error, "You don't have permission to return items")}
    else
      transaction_id = Map.get(params, "transaction_id")
      payment_amount = Map.get(params, "payment_amount", "0")
      payment_method = Map.get(params, "payment_method", "cash")
      current_user_id = socket.assigns.current_scope.user.id

      payment_amount_decimal =
        case Decimal.parse(payment_amount) do
          {dec, _rest} when is_struct(dec) -> dec
          :error -> Decimal.new("0")
        end

      case Circulation.return_item(transaction_id, current_user_id) do
        {:ok, _transaction} ->
          socket =
            socket
            |> assign(:quick_return_visible, false)
            |> assign(:return_form, to_form(%{}))
            |> assign(:quick_return_transaction, nil)
            |> assign(:quick_return_predicted_fine, Decimal.new("0"))

          # Try to pay fine if payment amount > 0
          socket =
            if Decimal.compare(payment_amount_decimal, Decimal.new("0")) == :gt do
              case Circulation.get_fine_by_transaction(transaction_id) do
                {:ok, fine} ->
                  case Circulation.pay_fine(
                         fine.id,
                         payment_amount_decimal,
                         payment_method,
                         current_user_id
                       ) do
                    {:ok, _} ->
                      put_flash(socket, :info, "Item returned and fine paid successfully")

                    {:error, _} ->
                      put_flash(socket, :info, "Item returned (fine payment failed)")
                  end

                _ ->
                  put_flash(socket, :info, "Item returned successfully")
              end
            else
              put_flash(socket, :info, "Item returned successfully")
            end

          send(self(), :load_stats)
          {:noreply, socket}

        {:error, changeset} ->
          errors =
            changeset
            |> Map.get(:errors, [])
            |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
            |> Enum.join(", ")

          {:noreply, put_flash(socket, :error, "Failed to return: #{errors}")}
      end
    end
  end

  # Member Lookup handlers
  def handle_event("show_member_lookup", _params, socket) do
    if can?(socket, "members.lookup") do
      {:noreply, assign(socket, :member_lookup_visible, true)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to lookup members")}
    end
  end

  def handle_event("cancel_member_lookup", _params, socket) do
    socket =
      socket
      |> assign(:member_lookup_visible, false)
      |> assign(:lookup_form, to_form(%{}))
      |> assign(:member_results, [])
      |> assign(:selected_member, nil)

    {:noreply, socket}
  end

  def handle_event("member_lookup_search", %{"query" => query}, socket) do
    unless can?(socket, "members.lookup") do
      {:noreply, put_flash(socket, :error, "You don't have permission to lookup members")}
    else
      alias Voile.Schema.Accounts

      results =
        if String.trim(query) != "" and String.length(query) >= 2 do
          Accounts.search_users(query)
        else
          []
        end

      socket =
        socket
        |> assign(:member_results, results)
        |> assign(:selected_member, nil)

      {:noreply, socket}
    end
  end

  def handle_event("select_member", %{"id" => id}, socket) do
    unless can?(socket, "members.lookup") do
      {:noreply, put_flash(socket, :error, "You don't have permission to lookup members")}
    else
      alias Voile.Schema.Accounts

      member = Accounts.get_user!(id)

      socket =
        socket
        |> assign(:selected_member, member)
        |> assign(:member_results, [])

      {:noreply, socket}
    end
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
