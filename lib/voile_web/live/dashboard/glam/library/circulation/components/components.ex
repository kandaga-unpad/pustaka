defmodule VoileWeb.Dashboard.Glam.Library.Circulation.Components do
  @moduledoc """
  Shared components for the circulation dashboard.
  """
  use VoileWeb, :live_component

  import VoileWeb.Dashboard.Glam.Library.Circulation.Helpers

  @doc """
  Renders a status badge with appropriate styling.
  """
  attr :status, :string, required: true

  attr :type, :atom,
    default: :general,
    values: [:general, :transaction, :reservation, :requisition, :fine]

  def status_badge(assigns) do
    assigns = assign(assigns, :class, badge_class_for_type(assigns.type, assigns.status))

    ~H"""
    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{@class}"}>
      {String.capitalize(@status)}
    </span>
    """
  end

  @doc """
  Renders a member info card.
  """
  attr :member, :map, required: true
  attr :compact, :boolean, default: false

  def member_card(assigns) do
    ~H"""
    <div class="flex items-center">
      <div class="flex-shrink-0 h-10 w-10">
        <div class="h-10 w-10 rounded-full bg-voile-light flex items-center justify-center">
          <span class="text-sm font-medium text-gray-700">
            {if @member, do: String.first(@member.fullname || "?"), else: "?"}
          </span>
        </div>
      </div>

      <div class="ml-4">
        <div class="text-sm font-medium text-gray-900">
          {if @member, do: @member.fullname, else: "Unknown Member"}
        </div>

        <%= unless @compact do %>
          <div class="text-sm text-gray-500">ID: {@member.id}</div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders an item info card.
  """
  attr :item, :map, required: true
  attr :compact, :boolean, default: false

  def item_card(assigns) do
    ~H"""
    <div>
      <%= if @item do %>
        <div class="text-sm font-medium text-gray-900">{@item.item_code}</div>

        <%= unless @compact do %>
          <div class="text-sm text-gray-500">
            {if @item.collection, do: @item.collection.title, else: "No collection"}
          </div>
        <% end %>
      <% else %>
        <div class="text-sm text-gray-500">Unknown Item</div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a quick stats grid.
  """
  attr :stats, :list, required: true

  def stats_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <%= for stat <- @stats do %>
        <div class={"bg-white rounded-lg shadow p-6 border-l-4 #{stat.border_color}"}>
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <.icon name={stat.icon} class={"w-8 h-8 #{stat.icon_color}"} />
            </div>

            <div class="ml-4">
              <h3 class="text-sm font-medium text-gray-500">{stat.label}</h3>

              <p class="text-2xl font-semibold text-gray-900">{stat.value}</p>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a filter section.
  """
  attr :filters, :list, required: true
  attr :current_filters, :map, default: %{}

  def filter_section(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg mb-6">
      <div class="px-6 py-4 border-b border-gray-200">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <%= for filter <- @filters do %>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">{filter.label}</label>
              <%= case filter.type do %>
                <% :select -> %>
                  <select
                    phx-change={filter.event}
                    name={filter.name}
                    class="block w-full text-sm border-voile-muted rounded-md shadow-sm focus:ring-voile-primary focus:border-voile-primary"
                  >
                    <%= for option <- filter.options do %>
                      <option
                        value={option.value}
                        selected={Map.get(@current_filters, filter.name) == option.value}
                      >
                        {option.label}
                      </option>
                    <% end %>
                  </select>
                <% :text -> %>
                  <form phx-change={filter.event} phx-submit={filter.event}>
                    <input
                      type="text"
                      name={filter.name}
                      value={Map.get(@current_filters, filter.name, "")}
                      placeholder={filter.placeholder}
                      class="block w-full text-sm border-voile-muted rounded-md shadow-sm focus:ring-voile-primary focus:border-voile-primary"
                    />
                  </form>
                <% :date -> %>
                  <form phx-change={filter.event}>
                    <input
                      type="date"
                      name={filter.name}
                      value={Map.get(@current_filters, filter.name, "")}
                      class="block w-full text-sm border-voile-muted rounded-md shadow-sm focus:ring-voile-primary focus:border-voile-primary"
                    />
                  </form>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the Quick Actions card used on the circulation dashboard.
  """
  attr :current_user, :map, required: true

  def quick_actions(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-700 shadow rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100">Quick Actions</h3>

      <div class="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-3">
        <%= if can?(@current_user, "circulation.checkout") do %>
          <button
            phx-click="show_quick_checkout"
            class="w-full inline-flex items-center justify-center px-4 py-2 border border-voile text-xs font-medium rounded-md shadow-sm bg-voile-primary text-white hover:bg-voile-primary-dark transition-colors"
          >
            <.icon name="hero-arrow-right-circle" class="w-4 h-4 mr-2" /> Quick Checkout
          </button>
        <% else %>
          <button
            disabled
            title="You don't have permission to checkout items"
            class="w-full inline-flex items-center justify-center px-4 py-2 border border-gray-200 text-xs font-medium rounded-md bg-gray-100 text-gray-400 dark:bg-gray-600 dark:text-gray-300 dark:border-gray-500 cursor-not-allowed"
          >
            <.icon name="hero-arrow-right-circle" class="w-4 h-4 mr-2" /> Quick Checkout
          </button>
        <% end %>

        <%= if can?(@current_user, "circulation.return") do %>
          <button
            phx-click="show_quick_return"
            class="success-btn text-xs"
          >
            <.icon name="hero-arrow-left-circle" class="w-4 h-4 mr-2" /> Quick Return
          </button>
        <% else %>
          <button
            disabled
            title="You don't have permission to return items"
            class="w-full inline-flex items-center justify-center px-4 py-2 border border-gray-200 text-xs font-medium rounded-md bg-gray-100 text-gray-400 dark:bg-gray-600 dark:text-gray-300 dark:border-gray-500 cursor-not-allowed"
          >
            <.icon name="hero-arrow-left-circle" class="w-4 h-4 mr-2" /> Quick Return
          </button>
        <% end %>

        <%= if can?(@current_user, "members.lookup") do %>
          <button
            phx-click="show_member_lookup"
            class="primary-btn text-xs"
          >
            <.icon name="hero-user-circle" class="w-4 h-4 mr-2" /> Member Lookup
          </button>
        <% else %>
          <button
            disabled
            title="You don't have permission to lookup members"
            class="w-full inline-flex items-center justify-center px-4 py-2 border border-gray-200 text-xs font-medium rounded-md bg-gray-100 text-gray-400 dark:bg-gray-600 dark:text-gray-300 dark:border-gray-500 cursor-not-allowed"
          >
            <.icon name="hero-user-circle" class="w-4 h-4 mr-2" /> Member Lookup
          </button>
        <% end %>

        <.link
          navigate={~p"/search?type=items"}
          class="w-full inline-flex items-center justify-center px-4 py-2 text-xs font-medium rounded-md shadow-sm border border-voile bg-voile-primary text-white hover:bg-voile-primary-dark transition-colors"
        >
          <.icon name="hero-magnifying-glass" class="w-4 h-4 mr-2" /> Item Search
        </.link>
      </div>
    </div>
    """
  end

  # Transaction modals (migrated from Transaction.Components)

  @doc """
  Renders a quick checkout modal for rapid item checkout.
  """
  def quick_checkout_modal(assigns) do
    assigns =
      assigns
      |> assign_new(:quick_checkout_visible, fn -> false end)
      |> assign_new(:checkout_form, fn -> to_form(%{}) end)

    ~H"""
    <.modal
      :if={@quick_checkout_visible}
      id="quick-checkout-modal"
      show
      on_cancel={JS.hide(to: "#quick-checkout-modal") |> JS.push("cancel_quick_checkout")}
    >
      <div class="space-y-4">
        <div class="flex items-start space-x-3">
          <div class="p-2 rounded-full bg-voile-info/10 text-voile-info dark:bg-voile-info/20 dark:text-voile-info">
            <.icon name="hero-arrow-right-circle" class="w-5 h-5" />
          </div>

          <div>
            <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
              {gettext("Quick Checkout")}
            </h3>

            <p class="text-sm text-gray-600 dark:text-gray-300">
              {gettext("Enter member identifier and item code to quickly checkout an item.")}
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@checkout_form}
          id="quick-checkout-form"
          phx-submit="quick_checkout_submit"
          class="space-y-4"
        >
          <.input
            field={f[:member_id]}
            name="member_id"
            type="text"
            label={gettext("Member ID or Username")}
            placeholder={gettext("Enter member ID or username")}
            required
          />
          <.input
            field={f[:item_id]}
            name="item_id"
            type="text"
            label={gettext("Item Code")}
            placeholder={gettext("Enter item barcode or code")}
            required
          />
          <div class="flex justify-end items-center space-x-3">
            <button
              type="button"
              phx-click="cancel_quick_checkout"
              class="secondary-btn"
            >
              {gettext("Cancel")}
            </button>
            <button type="submit" class="primary-btn">{gettext("Checkout")}</button>
          </div>
        </.form>
      </div>
    </.modal>
    """
  end

  @doc """
  Renders a quick return modal for rapid item return.
  """
  def quick_return_modal(assigns) do
    assigns =
      assigns
      |> assign_new(:quick_return_visible, fn -> false end)
      |> assign_new(:return_form, fn -> to_form(%{}) end)
      |> assign_new(:quick_return_transaction, fn -> nil end)
      |> assign_new(:quick_return_predicted_fine, fn -> Decimal.new("0") end)

    ~H"""
    <.modal
      :if={@quick_return_visible}
      id="quick-return-modal"
      show
      on_cancel={JS.hide(to: "#quick-return-modal") |> JS.push("cancel_quick_return")}
    >
      <div class="space-y-4">
        <div class="flex items-start space-x-3">
          <div class="p-2 rounded-full bg-voile-success/10 text-voile-success dark:bg-voile-success/20 dark:text-voile-success">
            <.icon name="hero-arrow-left-circle" class="w-5 h-5" />
          </div>

          <div>
            <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
              {gettext("Quick Return")}
            </h3>

            <p class="text-sm text-gray-600 dark:text-gray-300">
              {gettext("Enter item code to quickly return an item.")}
            </p>
          </div>
        </div>

        <%= if @quick_return_transaction do %>
          <div class="p-3 rounded-lg bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700">
            <div class="text-xs text-gray-500 dark:text-gray-400">{gettext("Transaction found")}</div>

            <div class="mt-1 text-sm font-medium text-gray-800 dark:text-gray-100">
              {@quick_return_transaction.item.item_code}
            </div>

            <div class="mt-2 text-xs text-gray-500 dark:text-gray-400">
              {gettext("Predicted fine")}
            </div>

            <div class="mt-1 text-lg font-semibold text-voile-error dark:text-voile-error">
              Rp {Decimal.to_string(@quick_return_predicted_fine)}
            </div>
          </div>

          <.form
            :let={f}
            for={@return_form}
            id="quick-return-confirm-form"
            phx-submit="quick_return_confirm"
            class="space-y-4"
          >
            <.input
              field={f[:payment_amount]}
              name="payment_amount"
              type="text"
              label={gettext("Payment Amount")}
              value={Decimal.to_string(@quick_return_predicted_fine)}
            />
            <.input
              field={f[:payment_method]}
              name="payment_method"
              type="select"
              options={[
                {gettext("Cash"), "cash"},
                {gettext("Card"), "card"},
                {gettext("Other"), "other"}
              ]}
              label={gettext("Payment Method")}
              value="cash"
            />
            <div class="flex justify-end items-center space-x-3">
              <button
                type="button"
                phx-click="cancel_quick_return"
                class="secondary-btn"
              >
                {gettext("Cancel")}
              </button>
              <button
                type="submit"
                class="success-btn"
              >
                {gettext("Return")}
              </button>
            </div>
            <input type="hidden" name="transaction_id" value={@quick_return_transaction.id} />
          </.form>
        <% else %>
          <.form
            :let={f}
            for={@return_form}
            id="quick-return-search-form"
            phx-submit="quick_return_search"
            class="space-y-4"
          >
            <.input
              field={f[:item_code]}
              name="item_code"
              type="text"
              label={gettext("Item Code")}
              placeholder={gettext("Enter item barcode or code")}
              required
            />
            <div class="flex justify-end items-center space-x-3">
              <button
                type="button"
                phx-click="cancel_quick_return"
                class="secondary-btn"
              >
                {gettext("Cancel")}
              </button>
              <button type="submit" class="primary-btn">{gettext("Find Transaction")}</button>
            </div>
          </.form>
        <% end %>
      </div>
    </.modal>
    """
  end

  @doc """
  Renders a member lookup modal for searching members.
  """
  def member_lookup_modal(assigns) do
    assigns =
      assigns
      |> assign_new(:member_lookup_visible, fn -> false end)
      |> assign_new(:lookup_form, fn -> to_form(%{}) end)
      |> assign_new(:member_results, fn -> [] end)
      |> assign_new(:selected_member, fn -> nil end)

    ~H"""
    <.modal
      :if={@member_lookup_visible}
      id="member-lookup-modal"
      show
      on_cancel={JS.hide(to: "#member-lookup-modal") |> JS.push("cancel_member_lookup")}
    >
      <div class="space-y-4">
        <div class="flex items-start space-x-3">
          <div class="p-2 rounded-full bg-voile-primary/10 text-voile-primary dark:bg-voile-primary/20 dark:text-voile-primary">
            <.icon name="hero-user-circle" class="w-5 h-5" />
          </div>

          <div>
            <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
              {gettext("Member Lookup")}
            </h3>

            <p class="text-sm text-gray-600 dark:text-gray-300">
              {gettext("Search for members by name, username, or ID.")}
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@lookup_form}
          id="member-lookup-form"
          phx-submit="member_lookup_search"
          phx-change="member_lookup_search"
          class="space-y-4"
        >
          <.input
            field={f[:query]}
            name="query"
            type="text"
            label={gettext("Search")}
            placeholder={gettext("Enter name, username, or ID")}
          />
        </.form>

        <%= if @selected_member do %>
          <div class="p-4 rounded-lg bg-voile-info/10 dark:bg-voile-info/20 border border-voile-info/10 dark:border-voile-info/20">
            <div class="flex items-start space-x-3">
              <div class="h-12 w-12 rounded-full bg-voile-info flex items-center justify-center text-white font-semibold">
                {String.first(@selected_member.fullname || "?")}
              </div>

              <div class="flex-1">
                <h4 class="font-semibold text-gray-900 dark:text-gray-100">
                  {@selected_member.fullname}
                </h4>

                <p class="text-sm text-gray-600 dark:text-gray-300">@{@selected_member.username}</p>

                <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                  {gettext("ID:")} {@selected_member.id}
                </p>

                <%= if @selected_member.email do %>
                  <p class="text-xs text-gray-500 dark:text-gray-400">
                    {gettext("Email:")} {@selected_member.email}
                  </p>
                <% end %>

                <%= if @selected_member.user_type do %>
                  <div class="mt-2">
                    <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-voile-info/10 text-voile-info dark:bg-voile-info/20 dark:text-voile-info">
                      {@selected_member.user_type.name}
                    </span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% else %>
          <%= if @member_results != [] do %>
            <div class="max-h-60 overflow-y-auto space-y-2">
              <%= for member <- @member_results do %>
                <button
                  type="button"
                  phx-click="select_member"
                  phx-value-id={member.id}
                  class="w-full text-left p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                >
                  <div class="flex items-center space-x-3">
                    <div class="h-10 w-10 rounded-full bg-gray-300 dark:bg-gray-600 flex items-center justify-center text-gray-700 dark:text-gray-200 font-semibold">
                      {String.first(member.fullname || "?")}
                    </div>

                    <div class="flex-1">
                      <p class="font-medium text-gray-900 dark:text-gray-100">{member.fullname}</p>

                      <p class="text-sm text-gray-600 dark:text-gray-400">@{member.username}</p>
                    </div>
                  </div>
                </button>
              <% end %>
            </div>
          <% end %>
        <% end %>

        <div class="flex justify-end">
          <button
            type="button"
            phx-click="cancel_member_lookup"
            class="px-4 py-2 border rounded bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-200 hover:bg-gray-50"
          >
            {gettext("Close")}
          </button>
        </div>
      </div>
    </.modal>
    """
  end

  def return_modal(assigns) do
    assigns =
      assigns
      |> assign_new(:return_modal_visible, fn -> false end)
      |> assign_new(:transaction, fn -> nil end)
      |> assign_new(:predicted_fine, fn -> Decimal.new("0") end)
      |> assign_new(:payment_method, fn -> "cash" end)
      |> assign_new(:return_transaction_id, fn -> nil end)

    ~H"""
    <.modal
      :if={@return_modal_visible}
      id="return-modal"
      show
      on_cancel={JS.hide(to: "#return-modal") |> JS.push("cancel_return")}
    >
      <div class="space-y-4">
        <div class="flex items-start space-x-3">
          <div class="p-2 rounded-full bg-rose-100 text-rose-600 dark:bg-rose-700/10 dark:text-rose-300">
            <.icon name="hero-check" class="w-5" />
          </div>

          <div>
            <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
              {gettext("Return Item")}
            </h3>

            <p class="text-sm text-gray-600 dark:text-gray-300">
              {gettext("Process the return and optionally accept payment for any fine.")}
            </p>
          </div>
        </div>

        <div class="p-3 rounded-lg bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700">
          <div class="text-xs text-gray-500 dark:text-gray-400">{gettext("Predicted fine")}</div>

          <div class="mt-2 text-2xl font-semibold text-rose-600 dark:text-rose-300">
            Rp {Decimal.to_string(@predicted_fine || Decimal.new("0"))}
          </div>
        </div>

        <.form :let={f} for={%{}} id="return-payment-form" phx-submit="confirm_return">
          <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
            <.input
              field={f[:payment_amount]}
              name="payment_amount"
              type="text"
              label={gettext("Payment Amount")}
              value="0"
            />
            <.input
              field={f[:payment_method]}
              name="payment_method"
              type="select"
              options={[
                {gettext("Cash"), "cash"},
                {gettext("Card"), "card"},
                {gettext("Other"), "other"}
              ]}
              label={gettext("Payment Method")}
              value={@payment_method || "cash"}
            />
          </div>

          <div class="mt-4 flex justify-end items-center space-x-3">
            <button
              type="button"
              phx-click="cancel_return"
              class="cancel-btn"
            >
              {gettext("Cancel")}
            </button>
            <button type="submit" class="success-btn">{gettext("Return")}</button>
          </div>

          <input
            type="hidden"
            name="transaction_id"
            value={@return_transaction_id || (@transaction && @transaction.id)}
          />
        </.form>
      </div>
    </.modal>
    """
  end

  def renew_modal(assigns) do
    assigns =
      assigns
      |> assign_new(:renew_modal_visible, fn -> false end)
      |> assign_new(:transaction, fn -> nil end)
      |> assign_new(:recommended_renew_days, fn -> nil end)
      |> assign_new(:preview_due_date, fn -> nil end)
      |> assign_new(:remaining_renewals, fn -> 0 end)
      |> assign_new(:current_user, fn -> nil end)

    ~H"""
    <.modal
      :if={@renew_modal_visible}
      id="renew-modal"
      show
      on_cancel={JS.hide(to: "#renew-modal") |> JS.push("cancel_renew")}
    >
      <div class="space-y-4">
        <div class="flex items-center space-x-3">
          <div class="p-2 rounded-full bg-voile-primary/10 dark:bg-voile-primary/20 text-voile-primary dark:text-voile-surface">
            <.icon name="hero-arrow-path" class="w-5 h-5" />
          </div>

          <div>
            <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
              {gettext("Renew Item")}
            </h3>

            <p class="text-sm text-gray-600 dark:text-gray-300">
              {gettext(
                "Extend the due date for this transaction. You can use the recommended duration or enter a custom number of days."
              )}
            </p>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
          <div class="p-3 rounded-lg bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700">
            <div class="text-xs text-gray-500 dark:text-gray-400">{gettext("Recommended")}</div>

            <div class="mt-1 text-xl font-semibold text-gray-800 dark:text-gray-100">
              {if @recommended_renew_days, do: "#{@recommended_renew_days} days", else: "-"}
            </div>

            <div class="mt-1 text-xs text-gray-500 dark:text-gray-400">
              {gettext("Based on member type")}
            </div>
          </div>

          <div class="p-3 rounded-lg bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700">
            <div class="text-xs text-gray-500 dark:text-gray-400">{gettext("Current due date")}</div>

            <div class="mt-1 text-sm font-medium text-gray-800 dark:text-gray-100">
              {if @transaction && @transaction.due_date,
                do: format_datetime(@transaction.due_date),
                else: "-"}
            </div>

            <div class="mt-3 text-xs text-gray-500 dark:text-gray-400">
              {gettext("Expected new due date")}
            </div>

            <div class="mt-1 text-sm font-medium text-gray-800 dark:text-gray-100">
              {if @preview_due_date, do: format_datetime(@preview_due_date), else: "-"}
            </div>
          </div>
        </div>

        <.form
          :let={f}
          for={%{}}
          id="renew-form"
          phx-submit="confirm_renew"
          phx-change="renew_days_change"
          class="mt-1"
        >
          <div class="flex items-center space-x-3">
            <%= if @current_user && is_super_admin?(@current_user) do %>
              <.input
                field={f[:renew_days]}
                name="renew_days"
                type="number"
                min="1"
                label={gettext("Renewal Duration (days)")}
                value={@recommended_renew_days || 1}
              />
            <% else %>
              <.input
                field={f[:renew_days]}
                name="renew_days"
                type="number"
                min="1"
                label="Renewal Duration (days)"
                value={@recommended_renew_days || 1}
                readonly
                disabled
              />
            <% end %>

            <div class="ml-auto flex items-center space-x-3">
              <div class="text-sm text-gray-600 dark:text-gray-300">{gettext("Remaining")}</div>

              <div class="inline-flex items-center px-2 py-1 rounded-full text-sm font-medium bg-voile-warning/10 text-voile-warning dark:bg-voile-warning/20 dark:text-voile-warning">
                {@remaining_renewals || 0}
              </div>
            </div>
          </div>

          <%= if @current_user && !is_super_admin?(@current_user) do %>
            <p class="mt-2 text-xs text-gray-500 dark:text-gray-400">
              <.icon name="hero-information-circle" class="w-4 h-4 inline" />
              {gettext(
                "Only super admins can change the renewal duration. Non-super admins must use the recommended duration."
              )}
            </p>
          <% end %>

          <div class="mt-4 flex justify-end items-center space-x-3">
            <button
              type="button"
              phx-click="cancel_renew"
              class="cancel-btn"
            >
              {gettext("Cancel")}
            </button>
            <button
              type="submit"
              class={[
                "px-4 py-2 rounded text-white font-medium",
                @remaining_renewals > 0 && "bg-voile-primary hover:bg-voile-primary-dark",
                @remaining_renewals <= 0 && "bg-gray-400 cursor-not-allowed"
              ]}
              disabled={@remaining_renewals <= 0}
            >
              {gettext("Renew")}
            </button>
          </div>

          <input
            type="hidden"
            name="transaction_id"
            value={@renew_transaction_id || (@transaction && @transaction.id)}
          />
        </.form>
      </div>
    </.modal>
    """
  end

  # Private helper functions

  defp badge_class_for_type(:transaction, status), do: transaction_type_badge_class(status)
  defp badge_class_for_type(:reservation, status), do: reservation_status_badge_class(status)
  defp badge_class_for_type(:requisition, status), do: requisition_status_badge_class(status)
  defp badge_class_for_type(:fine, status), do: fine_status_badge_class(status)
  defp badge_class_for_type(:general, status), do: status_badge_class(status)

  @doc """
  Renders a circulation stats dashboard component.
  Displays key circulation metrics: active transactions, overdue items,
  active reservations, and outstanding fines.

  ## Attributes

    * `stats` - A map containing :active_transactions, :overdue_count,
                :active_reservations, :outstanding_fines
    * `loading` - Boolean flag to show loading spinners (default: false)
    * `format_fines` - Boolean to format fines as IDR currency (default: true)

  ## Example

      <.circulation_stats stats={@stats} loading={@loading} />
  """
  attr :stats, :map, required: true
  attr :loading, :boolean, default: false
  attr :format_fines, :boolean, default: true

  def circulation_stats(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
      <%!-- Active Transactions --%>
      <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6 border-l-4 border-blue-500">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <.icon name="hero-book-open" class="w-8 h-8 text-blue-500" />
          </div>

          <div class="ml-4">
            <h3 class="text-sm font-medium text-gray-500 dark:text-gray-400">
              {gettext("Active Transactions")}
            </h3>

            <p class="text-2xl font-semibold text-gray-900 dark:text-gray-100">
              <%= if @loading || is_nil(@stats.active_transactions) do %>
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
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z">
                  </path>
                </svg>
              <% else %>
                {@stats.active_transactions}
              <% end %>
            </p>
          </div>
        </div>
      </div>

      <%!-- Overdue Items --%>
      <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6 border-l-4 border-yellow-500">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <.icon name="hero-clock" class="w-8 h-8 text-yellow-500" />
          </div>

          <div class="ml-4">
            <h3 class="text-sm font-medium text-gray-500 dark:text-gray-400">
              {gettext("Overdue Items")}
            </h3>

            <p class="text-2xl font-semibold text-gray-900 dark:text-gray-100">
              <%= if @loading || is_nil(@stats.overdue_count) do %>
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
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z">
                  </path>
                </svg>
              <% else %>
                {@stats.overdue_count}
              <% end %>
            </p>
          </div>
        </div>
      </div>

      <%!-- Active Reservations --%>
      <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6 border-l-4 border-green-500">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <.icon name="hero-bookmark" class="w-8 h-8 text-green-500" />
          </div>

          <div class="ml-4">
            <h3 class="text-sm font-medium text-gray-500 dark:text-gray-400">
              {gettext("Active Reservations")}
            </h3>

            <p class="text-2xl font-semibold text-gray-900 dark:text-gray-100">
              <%= if @loading || is_nil(@stats.active_reservations) do %>
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
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z">
                  </path>
                </svg>
              <% else %>
                {@stats.active_reservations}
              <% end %>
            </p>
          </div>
        </div>
      </div>

      <%!-- Outstanding Fines --%>
      <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6 border-l-4 border-red-500">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <.icon name="hero-banknotes" class="w-8 h-8 text-red-500" />
          </div>

          <div class="ml-4">
            <h3 class="text-sm font-medium text-gray-500 dark:text-gray-400">
              {gettext("Outstanding Fines")}
            </h3>

            <p class="text-2xl font-semibold text-gray-900 dark:text-gray-100">
              <%= if @loading || is_nil(@stats.outstanding_fines) do %>
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
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z">
                  </path>
                </svg>
              <% else %>
                <%= if @format_fines do %>
                  {format_idr(@stats.outstanding_fines)}
                <% else %>
                  {@stats.outstanding_fines}
                <% end %>
              <% end %>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
