defmodule VoileWeb.Dashboard.Glam.Library.Circulation.Index do
  use VoileWeb, :live_view_dashboard

  import VoileWeb.Dashboard.Glam.Library.Circulation.Helpers
  import VoileWeb.Dashboard.Glam.Library.Circulation.Components

  alias Voile.Schema.Library.Circulation
  alias VoileWeb.Auth.Authorization
  alias Voile.Schema.System, as: VoileSystem

  def render(assigns) do
    ~H"""
    <div class="px-4 py-6">
      <.breadcrumb items={[
        %{label: gettext("Manage"), path: ~p"/manage"},
        %{label: gettext("GLAM"), path: ~p"/manage/glam"},
        %{label: gettext("Library"), path: ~p"/manage/glam/library"},
        %{label: gettext("Circulation"), path: nil}
      ]} />
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">
          {gettext("Library Circulation Dashboard")}
        </h1>

        <p class="mt-2 text-gray-600 dark:text-gray-400">
          {gettext("Manage all library circulation activities from this central dashboard.")}
        </p>
      </div>

      <%= if @is_super_admin do %>
        <div class="mb-6">
          <.form :let={f} for={%{}} phx-change="select_node">
            <.input
              field={f[:node_id]}
              type="select"
              options={
                [{gettext("All Nodes"), "all"}] ++
                  Enum.map(@nodes || [], fn n -> {n.name, to_string(n.id)} end)
              }
              value={if @selected_node_id, do: to_string(@selected_node_id), else: "all"}
              class="block w-64 text-sm border border-voile-muted rounded-md shadow-sm"
              label={gettext("Filter node")}
            />
          </.form>
        </div>
      <% end %>
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
      <!-- Circulation Stats -->
      <.circulation_stats stats={@stats} loading={@stats_loading} />
      <!-- Navigation Cards -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <.link navigate={~p"/manage/glam/library/circulation/transactions"} class="group">
          <div class="bg-white dark:bg-gray-700 rounded-lg shadow hover:shadow-lg transition-shadow p-6 h-full">
            <div class="flex items-center mb-4">
              <div class="flex-shrink-0">
                <.icon name="hero-arrow-path" class="w-8 h-8 text-blue-600 group-hover:text-blue-700" />
              </div>

              <h3 class="ml-3 text-lg font-semibold text-gray-900 group-hover:text-blue-700 dark:text-gray-100 dark:group-hover:text-blue-300">
                {gettext("Transactions")}
              </h3>
            </div>

            <p class="text-gray-600 dark:text-gray-300 text-sm">
              {gettext(
                "Manage book checkouts, returns, renewals, and track all circulation activities."
              )}
            </p>

            <div class="mt-4 flex items-center text-sm text-blue-600 group-hover:text-blue-700 dark:text-blue-400  dark:group-hover:text-blue-300">
              <span>{gettext("Manage Transactions")}</span>
              <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
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
                {gettext("Reservations")}
              </h3>
            </div>

            <p class="text-gray-600 dark:text-gray-300 text-sm">
              {gettext("Handle item reservations, queue management, and availability notifications.")}
            </p>

            <div class="mt-4 flex items-center text-sm text-green-600 group-hover:text-green-700 dark:text-green-400 dark:group-hover:text-green-300">
              <span>{gettext("Manage Reservations")}</span>
              <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
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
                {gettext("Requisitions")}
              </h3>
            </div>

            <p class="text-gray-600 dark:text-gray-300 text-sm">
              {gettext(
                "Process member requests for new items, interlibrary loans, and special services."
              )}
            </p>

            <div class="mt-4 flex items-center text-sm text-purple-600 group-hover:text-purple-700 dark:text-purple-400 dark:group-hover:text-purple-300">
              <span>{gettext("Manage Requisitions")}</span>
              <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
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
                {gettext("Fines Management")}
              </h3>
            </div>

            <p class="text-gray-600 dark:text-gray-300 text-sm">
              {gettext("Manage overdue fines, payments, waivers, and financial transactions.")}
            </p>

            <div class="mt-4 flex items-center text-sm text-red-600 group-hover:text-red-700 dark:text-red-400 dark:group-hover:text-red-300">
              <span>{gettext("Manage Fines")}</span>
              <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
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
                {gettext("Circulation History")}
              </h3>
            </div>

            <p class="text-gray-600 dark:text-gray-300 text-sm">
              {gettext("View detailed logs and audit trails of all circulation activities.")}
            </p>

            <div class="mt-4 flex items-center text-sm text-indigo-600 group-hover:text-indigo-700 dark:text-indigo-400 dark:group-hover:text-indigo-300">
              <span>{gettext("View History")}</span>
              <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
            </div>
          </div>
        </.link>
        <.quick_actions current_user={@current_scope.user} />
      </div>
      <!-- Recent Activity -->
      <div class="mt-8 bg-white dark:bg-gray-700 rounded-lg shadow">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
            {gettext("Recent Activity")}
          </h3>
        </div>

        <div class="divide-y divide-gray-200">
          <%= for activity <- @recent_activities do %>
            <div class="px-6 py-4 flex items-start justify-between gap-4">
              <div class="flex items-start gap-3 min-w-0">
                <div class="flex-shrink-0 mt-1.5">
                  <div class={"w-2 h-2 rounded-full #{activity_color(activity.event_type)}"}></div>
                </div>

                <div class="min-w-0">
                  <p class="text-sm font-medium text-gray-900 dark:text-gray-100">
                    <%= if activity.item && activity.item.collection do %>
                      {activity.item.collection.title}
                      <span class="font-normal text-gray-500 dark:text-gray-400 text-xs">
                        ({activity.item.item_code})
                      </span>
                    <% else %>
                      {activity.description}
                    <% end %>
                  </p>

                  <%= if activity.item && activity.item.node do %>
                    <p class="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
                      <.icon name="hero-map-pin" class="w-3 h-3 inline-block mr-0.5" />
                      {activity.item.node.name}
                    </p>
                  <% end %>

                  <p class="text-xs text-gray-600 dark:text-gray-300 mt-0.5">
                    <.icon name="hero-user" class="w-3 h-3 inline-block mr-0.5" />
                    <%= if activity.member do %>
                      {activity.member.fullname}
                      <span class="text-gray-400 dark:text-gray-500">
                        ({activity.member.identifier})
                      </span>
                    <% else %>
                      {gettext("Unknown member")}
                    <% end %>
                  </p>

                  <p class="text-xs text-gray-400 dark:text-gray-500 mt-0.5">
                    <.icon name="hero-user-circle" class="w-3 h-3 inline-block mr-0.5" />
                    {gettext("by")}
                    <%= if activity.processed_by do %>
                      {activity.processed_by.fullname}
                    <% else %>
                      —
                    <% end %>
                    · {format_datetime(activity.event_date)}
                  </p>
                </div>
              </div>

              <div class={"flex-shrink-0 text-xs font-medium px-2 py-0.5 rounded-full #{activity_badge_class(activity.event_type)}"}>
                {activity.event_type}
              </div>
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
        |> assign(:page_title, gettext("Circulation Dashboard"))
        |> assign(:stats, Voile.get_circulation_stats(nil))
        |> assign(:stats_loading, false)
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

      # expose node list for super_admin so they can filter stats per node
      current_user = socket.assigns.current_scope.user
      is_super_admin = Authorization.is_super_admin?(current_user)

      socket = assign(socket, :is_super_admin, is_super_admin)

      socket =
        if is_super_admin do
          nodes = VoileSystem.list_nodes()

          socket
          |> assign(:nodes, nodes)
          |> assign(:selected_node_id, nil)
        else
          socket |> assign(:nodes, []) |> assign(:selected_node_id, current_user.node_id)
        end

      # Trigger async load of stats and recent activities
      if connected?(socket), do: send(self(), :load_stats)

      {:ok, socket}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_info(:load_stats, socket) do
    # Perform DB queries asynchronously and scope by user's node/unit unless super_admin
    current_user = socket.assigns.current_scope.user

    # Allow super_admin to select a node; if selected_node_id is set, override
    # the user's node_id when computing scoped stats.
    node_id =
      if Authorization.is_super_admin?(current_user) and
           Map.has_key?(socket.assigns, :selected_node_id) and
           not is_nil(socket.assigns.selected_node_id) do
        socket.assigns.selected_node_id
      else
        current_user.node_id
      end

    stats = Voile.get_circulation_stats(node_id)

    {recent_activities, _, _} = Circulation.list_circulation_history_paginated(1, 10)

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
              case Catalog.get_item_by_code_or_barcode(item_id) do
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

      case Catalog.get_item_by_code_or_barcode(item_code) do
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

        {:error, error} ->
          error_message =
            cond do
              is_binary(error) ->
                error

              is_struct(error, Ecto.Changeset) and error.errors != %{} ->
                errors =
                  error
                  |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
                  |> Enum.map(fn {field, messages} ->
                    "#{field}: #{Enum.join(messages, ", ")}"
                  end)
                  |> Enum.join(", ")

                "Failed to return: #{errors}"

              true ->
                "Failed to return: Unknown error"
            end

          {:noreply, put_flash(socket, :error, error_message)}
      end
    end
  end

  def handle_event("select_node", %{"node_id" => node_id_str}, socket) do
    node_id =
      case node_id_str do
        nil -> nil
        "all" -> nil
        "" -> nil
        id -> String.to_integer(id)
      end

    socket =
      socket
      |> assign(:selected_node_id, node_id)

    # reload stats for selected node
    send(self(), :load_stats)

    {:noreply, socket}
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

  defp activity_color("loan"), do: "bg-blue-400"
  defp activity_color("return"), do: "bg-green-400"
  defp activity_color("renewal"), do: "bg-yellow-400"
  defp activity_color("reserve"), do: "bg-purple-400"
  defp activity_color("fine_paid"), do: "bg-green-400"
  defp activity_color(_), do: "bg-gray-400"

  defp activity_badge_class("loan"),
    do: "bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300"

  defp activity_badge_class("return"),
    do: "bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300"

  defp activity_badge_class("renewal"),
    do: "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/40 dark:text-yellow-300"

  defp activity_badge_class("reserve"),
    do: "bg-purple-100 text-purple-700 dark:bg-purple-900/40 dark:text-purple-300"

  defp activity_badge_class("cancel_reserve"),
    do: "bg-orange-100 text-orange-700 dark:bg-orange-900/40 dark:text-orange-300"

  defp activity_badge_class("fine_paid"),
    do: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300"

  defp activity_badge_class("fine_waived"),
    do: "bg-teal-100 text-teal-700 dark:bg-teal-900/40 dark:text-teal-300"

  defp activity_badge_class(_),
    do: "bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400"
end
