defmodule VoileWeb.Dashboard.Settings.SystemNodeRulesLive do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.System
  alias Decimal

  def render(assigns) do
    ~H"""
    <section class="flex flex-col md:flex-row gap-4">
      <div class="w-full md:w-auto md:max-w-64">
        <.dashboard_settings_sidebar
          current_user={@current_scope.user}
          current_path={@current_path}
        />
      </div>

      <div class="container mx-auto px-2 sm:px-4 py-3 sm:py-6 max-w-6xl">
        <.back navigate={~p"/manage/settings/nodes"}>{gettext("Back to Nodes")}</.back>
        <%!-- Header --%>
        <div class="mb-6">
          <h1 class="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
            {gettext("Node Loan Rules Configuration")}
          </h1>

          <p class="text-sm sm:text-base text-gray-600 dark:text-gray-400 mt-2">
            {gettext("Configure branch-specific lending policies and operational rules")}
          </p>
        </div>
        <%!-- Node Selector --%>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-4 sm:p-6 mb-6">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
            {gettext("Select Branch/Node")}
          </label>
          <form phx-change="select_node">
            <select
              name="node_id"
              class="w-full px-4 py-3 rounded-lg border-2 border-gray-300 dark:border-gray-600 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:bg-gray-700 dark:text-gray-200"
            >
              <option value="">{gettext("-- Select a branch --")}</option>

              <option
                :for={node <- @nodes}
                value={node.id}
                selected={@selected_node && @selected_node.id == node.id}
              >
                {node.name} ({node.abbr})
              </option>
            </select>
          </form>
        </div>
        <%!-- Configuration Form --%>
        <div :if={@selected_node} class="space-y-6">
          <%!-- Override Toggle --%>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-4 sm:p-6">
            <div class="flex items-start gap-4">
              <input
                type="checkbox"
                id="override_toggle"
                phx-click="toggle_override"
                checked={@form_data.override_loan_rules}
                class="mt-1 w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
              />
              <div class="flex-1">
                <label
                  for="override_toggle"
                  class="font-semibold text-gray-900 dark:text-gray-100 cursor-pointer"
                >
                  {gettext("Enable Branch-Specific Rules")}
                </label>
                <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
                  {gettext(
                    "When enabled, this branch's rules will override member type rules. When disabled, member type rules will apply."
                  )}
                </p>
              </div>
            </div>
          </div>
          <%!-- Loan Limits --%>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-4 sm:p-6">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
              {gettext("Loan Limits")}
            </h3>

            <.form for={@form} phx-change="update_field" class="space-y-4">
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    {gettext("Max Items per Loan")}
                  </label>
                  <input
                    type="number"
                    name="max_items"
                    value={@form_data.max_items}
                    min="0"
                    disabled={!@form_data.override_loan_rules}
                    class="w-full px-4 py-2 rounded-lg border-2 border-gray-300 dark:border-gray-600 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:bg-gray-700 dark:text-gray-200 disabled:bg-gray-100 dark:disabled:bg-gray-800 disabled:cursor-not-allowed"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    {gettext("Max Loan Days")}
                  </label>
                  <input
                    type="number"
                    name="max_days"
                    value={@form_data.max_days}
                    min="0"
                    disabled={!@form_data.override_loan_rules}
                    class="w-full px-4 py-2 rounded-lg border-2 border-gray-300 dark:border-gray-600 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:bg-gray-700 dark:text-gray-200 disabled:bg-gray-100 dark:disabled:bg-gray-800 disabled:cursor-not-allowed"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    {gettext("Max Renewals")}
                  </label>
                  <input
                    type="number"
                    name="max_renewals"
                    value={@form_data.max_renewals}
                    min="0"
                    disabled={!@form_data.override_loan_rules}
                    class="w-full px-4 py-2 rounded-lg border-2 border-gray-300 dark:border-gray-600 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:bg-gray-700 dark:text-gray-200 disabled:bg-gray-100 dark:disabled:bg-gray-800 disabled:cursor-not-allowed"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    {gettext("Max Reserves")}
                  </label>
                  <input
                    type="number"
                    name="max_reserves"
                    value={@form_data.max_reserves}
                    min="0"
                    disabled={!@form_data.override_loan_rules}
                    class="w-full px-4 py-2 rounded-lg border-2 border-gray-300 dark:border-gray-600 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:bg-gray-700 dark:text-gray-200 disabled:bg-gray-100 dark:disabled:bg-gray-800 disabled:cursor-not-allowed"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    {gettext("Max Concurrent Loans")}
                  </label>
                  <input
                    type="number"
                    name="max_concurrent_loans"
                    value={@form_data.max_concurrent_loans}
                    min="0"
                    disabled={!@form_data.override_loan_rules}
                    class="w-full px-4 py-2 rounded-lg border-2 border-gray-300 dark:border-gray-600 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:bg-gray-700 dark:text-gray-200 disabled:bg-gray-100 dark:disabled:bg-gray-800 disabled:cursor-not-allowed"
                  />
                </div>
              </div>
            </.form>
          </div>
          <%!-- Fine Configuration --%>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-4 sm:p-6">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
              {gettext("Fine & Currency Settings")}
            </h3>

            <.form for={@form} phx-change="update_field" class="space-y-4">
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    {gettext("Fine per Day")}
                  </label>
                  <input
                    type="number"
                    name="fine_per_day"
                    value={@form_data.fine_per_day}
                    min="0"
                    step="0.01"
                    disabled={!@form_data.override_loan_rules}
                    class="w-full px-4 py-2 rounded-lg border-2 border-gray-300 dark:border-gray-600 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:bg-gray-700 dark:text-gray-200 disabled:bg-gray-100 dark:disabled:bg-gray-800 disabled:cursor-not-allowed"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    {gettext("Max Fine (optional)")}
                  </label>
                  <input
                    type="number"
                    name="max_fine"
                    value={@form_data.max_fine}
                    min="0"
                    step="0.01"
                    placeholder={gettext("No limit")}
                    disabled={!@form_data.override_loan_rules}
                    class="w-full px-4 py-2 rounded-lg border-2 border-gray-300 dark:border-gray-600 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:bg-gray-700 dark:text-gray-200 disabled:bg-gray-100 dark:disabled:bg-gray-800 disabled:cursor-not-allowed"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    {gettext("Currency")}
                  </label>
                  <select
                    name="currency"
                    disabled={!@form_data.override_loan_rules}
                    class="w-full px-4 py-2 rounded-lg border-2 border-gray-300 dark:border-gray-600 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:bg-gray-700 dark:text-gray-200 disabled:bg-gray-100 dark:disabled:bg-gray-800 disabled:cursor-not-allowed"
                  >
                    <option value="IDR" selected={@form_data.currency == "IDR"}>
                      {gettext("IDR (Rupiah)")}
                    </option>

                    <option value="USD" selected={@form_data.currency == "USD"}>
                      {gettext("USD (Dollar)")}
                    </option>

                    <option value="EUR" selected={@form_data.currency == "EUR"}>
                      {gettext("EUR (Euro)")}
                    </option>

                    <option value="SGD" selected={@form_data.currency == "SGD"}>
                      {gettext("SGD (Singapore Dollar)")}
                    </option>

                    <option value="MYR" selected={@form_data.currency == "MYR"}>
                      {gettext("MYR (Ringgit)")}
                    </option>
                  </select>
                </div>
              </div>
            </.form>
          </div>
          <%!-- Feature Toggles --%>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-4 sm:p-6">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
              {gettext("Features & Permissions")}
            </h3>

            <div class="space-y-3">
              <div class="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="can_reserve"
                  phx-click="toggle_feature"
                  phx-value-field="can_reserve"
                  checked={@form_data.can_reserve}
                  disabled={!@form_data.override_loan_rules}
                  class="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
                />
                <label for="can_reserve" class="text-sm font-medium text-gray-700 dark:text-gray-300">
                  {gettext("Allow Reservations")}
                </label>
              </div>

              <div class="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="can_renew"
                  phx-click="toggle_feature"
                  phx-value-field="can_renew"
                  checked={@form_data.can_renew}
                  disabled={!@form_data.override_loan_rules}
                  class="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
                />
                <label for="can_renew" class="text-sm font-medium text-gray-700 dark:text-gray-300">
                  {gettext("Allow Renewals")}
                </label>
              </div>

              <div class="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="digital_access_enabled"
                  phx-click="toggle_feature"
                  phx-value-field="digital_access_enabled"
                  checked={@form_data.digital_access_enabled}
                  class="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                />
                <label
                  for="digital_access_enabled"
                  class="text-sm font-medium text-gray-700 dark:text-gray-300"
                >
                  {gettext("Enable Digital Access")}
                </label>
              </div>
            </div>
          </div>
          <%!-- Operational Policies --%>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-4 sm:p-6">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
              {gettext("Operational Policies")}
            </h3>

            <div class="space-y-4">
              <div class="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="allow_external_returns"
                  phx-click="toggle_feature"
                  phx-value-field="allow_external_returns"
                  checked={@form_data.allow_external_returns}
                  class="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                />
                <div>
                  <label
                    for="allow_external_returns"
                    class="text-sm font-medium text-gray-700 dark:text-gray-300"
                  >
                    {gettext("Allow Returns from Other Branches")}
                  </label>
                  <p class="text-xs text-gray-500 dark:text-gray-400">
                    {gettext("Accept items borrowed from other branches")}
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="allow_inter_node_loans"
                  phx-click="toggle_feature"
                  phx-value-field="allow_inter_node_loans"
                  checked={@form_data.allow_inter_node_loans}
                  class="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                />
                <div>
                  <label
                    for="allow_inter_node_loans"
                    class="text-sm font-medium text-gray-700 dark:text-gray-300"
                  >
                    {gettext("Allow Inter-Branch Loans")}
                  </label>
                  <p class="text-xs text-gray-500 dark:text-gray-400">
                    {gettext("Permit borrowing items from other branches")}
                  </p>
                </div>
              </div>

              <div class="border-t border-gray-200 dark:border-gray-700 pt-4 mt-4">
                <div class="flex items-start gap-3">
                  <input
                    type="checkbox"
                    id="require_deposit"
                    phx-click="toggle_feature"
                    phx-value-field="require_deposit"
                    checked={@form_data.require_deposit}
                    class="mt-1 w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                  />
                  <div class="flex-1">
                    <label
                      for="require_deposit"
                      class="text-sm font-medium text-gray-700 dark:text-gray-300"
                    >
                      {gettext("Require Security Deposit")}
                    </label>
                    <p class="text-xs text-gray-500 dark:text-gray-400 mb-2">
                      {gettext("Require members to pay a refundable deposit")}
                    </p>

                    <.form for={@form} phx-change="update_field">
                      <input
                        type="number"
                        name="deposit_amount"
                        value={@form_data.deposit_amount}
                        min="0"
                        step="0.01"
                        placeholder={gettext("Enter amount")}
                        disabled={!@form_data.require_deposit}
                        class="w-full sm:w-48 px-4 py-2 rounded-lg border-2 border-gray-300 dark:border-gray-600 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:bg-gray-700 dark:text-gray-200 disabled:bg-gray-100 dark:disabled:bg-gray-800 disabled:cursor-not-allowed text-sm"
                      />
                    </.form>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <%!-- Save Button --%>
          <div class="flex gap-3">
            <button
              type="button"
              phx-click="save_rules"
              class="flex-1 sm:flex-none px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
            >
              {gettext("Save Configuration")}
            </button>
            <button
              type="button"
              phx-click="reset_to_defaults"
              class="px-6 py-3 bg-gray-200 hover:bg-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 font-medium rounded-lg transition-colors"
            >
              {gettext("Reset to Defaults")}
            </button>
          </div>
          <%!-- Rule Preview --%>
          <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
            <h4 class="font-semibold text-blue-900 dark:text-blue-300 mb-2">
              {gettext("Active Rule Source:")} {rule_source_badge(assigns)}
            </h4>

            <p class="text-sm text-blue-700 dark:text-blue-400">
              {explain_rule_source(@form_data.override_loan_rules)}
            </p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def mount(_params, _session, socket) do
    nodes = System.list_nodes()

    socket =
      socket
      |> assign(:page_title, gettext("Node Loan Rules"))
      |> assign(:nodes, nodes)
      |> assign(:selected_node, nil)
      |> assign(:form, to_form(%{}))
      |> assign(:form_data, default_form_data())

    {:ok, socket}
  end

  def handle_event("select_node", %{"node_id" => ""}, socket) do
    socket =
      socket
      |> assign(:selected_node, nil)
      |> assign(:form_data, default_form_data())
      |> assign(:form, to_form(%{}))

    {:noreply, socket}
  end

  def handle_event("select_node", %{"node_id" => node_id}, socket) do
    node = System.get_node!(node_id)
    form_data = node_to_form_data(node)

    socket =
      socket
      |> assign(:selected_node, node)
      |> assign(:form_data, form_data)
      |> assign(:form, to_form(%{}))

    {:noreply, socket}
  end

  def handle_event("toggle_override", _params, socket) do
    form_data = Map.update!(socket.assigns.form_data, :override_loan_rules, &(!&1))
    {:noreply, assign(socket, :form_data, form_data)}
  end

  def handle_event("toggle_feature", %{"field" => field}, socket) do
    field_atom = String.to_existing_atom(field)
    form_data = Map.update!(socket.assigns.form_data, field_atom, &(!&1))
    {:noreply, assign(socket, :form_data, form_data)}
  end

  def handle_event("update_field", params, socket) do
    form_data =
      Enum.reduce(params, socket.assigns.form_data, fn {key, value}, acc ->
        case key do
          "_target" ->
            acc

          "fine_per_day" ->
            Map.put(acc, :fine_per_day, value)

          "max_fine" ->
            Map.put(acc, :max_fine, value)

          "deposit_amount" ->
            Map.put(acc, :deposit_amount, value)

          "currency" ->
            Map.put(acc, :currency, value)

          key
          when key in [
                 "max_items",
                 "max_days",
                 "max_renewals",
                 "max_reserves",
                 "max_concurrent_loans"
               ] ->
            int_val = if value == "", do: nil, else: String.to_integer(value)
            Map.put(acc, String.to_existing_atom(key), int_val)

          _ ->
            acc
        end
      end)

    {:noreply, assign(socket, :form_data, form_data)}
  end

  def handle_event("save_rules", _params, socket) do
    case System.update_node_rules(
           socket.assigns.selected_node,
           form_data_to_attrs(socket.assigns.form_data)
         ) do
      {:ok, _node} ->
        socket =
          socket
          |> put_flash(:info, gettext("Node rules updated successfully!"))
          |> push_navigate(to: ~p"/manage/settings/nodes/rules")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update node rules"))}
    end
  end

  def handle_event("reset_to_defaults", _params, socket) do
    form_data = default_form_data()
    {:noreply, assign(socket, :form_data, form_data)}
  end

  defp default_form_data do
    %{
      override_loan_rules: false,
      max_items: nil,
      max_days: nil,
      max_renewals: nil,
      max_reserves: nil,
      max_concurrent_loans: nil,
      fine_per_day: nil,
      max_fine: nil,
      currency: "IDR",
      can_reserve: true,
      can_renew: true,
      digital_access_enabled: true,
      allow_external_returns: true,
      allow_inter_node_loans: true,
      require_deposit: false,
      deposit_amount: nil
    }
  end

  defp node_to_form_data(node) do
    %{
      override_loan_rules: node.override_loan_rules || false,
      max_items: node.max_items,
      max_days: node.max_days,
      max_renewals: node.max_renewals,
      max_reserves: node.max_reserves,
      max_concurrent_loans: node.max_concurrent_loans,
      fine_per_day: if(node.fine_per_day, do: Decimal.to_string(node.fine_per_day), else: nil),
      max_fine: if(node.max_fine, do: Decimal.to_string(node.max_fine), else: nil),
      currency: node.currency || "IDR",
      can_reserve: if(is_nil(node.can_reserve), do: true, else: node.can_reserve),
      can_renew: if(is_nil(node.can_renew), do: true, else: node.can_renew),
      digital_access_enabled:
        if(is_nil(node.digital_access_enabled), do: true, else: node.digital_access_enabled),
      allow_external_returns:
        if(is_nil(node.allow_external_returns), do: true, else: node.allow_external_returns),
      allow_inter_node_loans:
        if(is_nil(node.allow_inter_node_loans), do: true, else: node.allow_inter_node_loans),
      require_deposit: node.require_deposit || false,
      deposit_amount:
        if(node.deposit_amount, do: Decimal.to_string(node.deposit_amount), else: nil)
    }
  end

  defp form_data_to_attrs(form_data) do
    %{
      "override_loan_rules" => form_data.override_loan_rules,
      "max_items" => form_data.max_items,
      "max_days" => form_data.max_days,
      "max_renewals" => form_data.max_renewals,
      "max_reserves" => form_data.max_reserves,
      "max_concurrent_loans" => form_data.max_concurrent_loans,
      "fine_per_day" => decimal_or_nil(form_data.fine_per_day),
      "max_fine" => decimal_or_nil(form_data.max_fine),
      "currency" => form_data.currency,
      "can_reserve" => form_data.can_reserve,
      "can_renew" => form_data.can_renew,
      "digital_access_enabled" => form_data.digital_access_enabled,
      "allow_external_returns" => form_data.allow_external_returns,
      "allow_inter_node_loans" => form_data.allow_inter_node_loans,
      "require_deposit" => form_data.require_deposit,
      "deposit_amount" => decimal_or_nil(form_data.deposit_amount)
    }
  end

  defp decimal_or_nil(nil), do: nil
  defp decimal_or_nil(""), do: nil
  defp decimal_or_nil(value) when is_binary(value), do: Decimal.new(value)
  defp decimal_or_nil(value), do: value

  defp rule_source_badge(assigns) do
    if assigns.form_data.override_loan_rules do
      ~H"""
      <span class="inline-flex items-center px-2 py-1 text-xs font-medium rounded bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400">
        {gettext("Branch Rules")}
      </span>
      """
    else
      ~H"""
      <span class="inline-flex items-center px-2 py-1 text-xs font-medium rounded bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400">
        {gettext("Member Type Rules")}
      </span>
      """
    end
  end

  defp explain_rule_source(true) do
    gettext("This branch uses its own custom lending rules. Member type rules are overridden.")
  end

  defp explain_rule_source(false) do
    gettext(
      "This branch follows standard member type rules. Branch-specific fields are disabled."
    )
  end
end
