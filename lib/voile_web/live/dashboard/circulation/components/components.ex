defmodule VoileWeb.Dashboard.Circulation.Components do
  @moduledoc """
  Shared components for the circulation dashboard.
  """
  use VoileWeb, :live_component

  import VoileWeb.Dashboard.Circulation.Helpers

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
        <button
          disabled
          class="w-full inline-flex items-center justify-center px-4 py-2 border border-gray-200 text-sm font-medium rounded-md bg-gray-100 text-gray-400 dark:bg-gray-600 dark:text-gray-300 dark:border-gray-500"
        >
          Quick Checkout
        </button>
        <button
          disabled
          class="w-full inline-flex items-center justify-center px-4 py-2 border border-gray-200 text-sm font-medium rounded-md bg-gray-100 text-gray-400 dark:bg-gray-600 dark:text-gray-300 dark:border-gray-500"
        >
          Quick Return
        </button>
        <button
          disabled
          class="w-full inline-flex items-center justify-center px-4 py-2 border border-gray-200 text-sm font-medium rounded-md bg-gray-100 text-gray-400 dark:bg-gray-600 dark:text-gray-300 dark:border-gray-500"
        >
          Member Lookup
        </button>
        <.link
          navigate={~p"/search?type=items"}
          class="w-full inline-flex items-center justify-center px-4 py-2 text-sm font-medium rounded-md shadow-sm border border-voile bg-voile-primary text-white"
        >
          Item Search
        </.link>
      </div>
    </div>
    """
  end

  @doc """
  Renders a small breadcrumb for circulation pages.
  Accepts optional `:root_label` and `:root_path` (when provided, the root becomes a link),
  and required `:current_label` for the active page.
  """
  attr :root_label, :string, default: "Circulation"
  attr :root_path, :any, default: nil
  attr :section_label, :string, default: nil
  attr :section_path, :any, default: nil
  attr :current_label, :string, required: true

  def circulation_breadcrumb(assigns) do
    ~H"""
    <nav class="flex mb-4" aria-label="Breadcrumb">
      <ol class="inline-flex items-center space-x-1 md:space-x-3">
        <li class="inline-flex items-center">
          <%= if @root_path do %>
            <.link
              navigate={@root_path}
              class="text-gray-700 hover:text-gray-900 dark:text-gray-300 dark:hover:text-white flex items-center"
            >
              <.icon name="hero-home" class="w-4 h-4 mr-2" /> {@root_label}
            </.link>
          <% else %>
            <div class="text-gray-700 dark:text-gray-300 flex items-center">
              <.icon name="hero-home" class="w-4 h-4 mr-2" /> {@root_label}
            </div>
          <% end %>
        </li>
        
        <%= if @section_label do %>
          <li>
            <div class="flex items-center">
              <.icon name="hero-chevron-right" class="w-4 h-4 text-gray-500" />
              <%= if @section_path do %>
                <.link
                  navigate={@section_path}
                  class="ml-1 text-gray-700 hover:text-gray-900 dark:text-gray-300 dark:hover:text-white"
                >
                  {@section_label}
                </.link>
              <% else %>
                <span class="ml-1 text-gray-500 dark:text-gray-300">{@section_label}</span>
              <% end %>
            </div>
          </li>
          
          <li aria-current="page">
            <div class="flex items-center">
              <.icon name="hero-chevron-right" class="w-4 h-4 text-gray-500" />
              <span class="ml-1 text-gray-500 dark:text-gray-300">{@current_label}</span>
            </div>
          </li>
        <% else %>
          <li aria-current="page">
            <div class="flex items-center">
              <.icon name="hero-chevron-right" class="w-4 h-4 text-gray-500" />
              <span class="ml-1 text-gray-500 dark:text-gray-300">{@current_label}</span>
            </div>
          </li>
        <% end %>
      </ol>
    </nav>
    """
  end

  # Transaction modals (migrated from Transaction.Components)

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
            <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">Return Item</h3>
            
            <p class="text-sm text-gray-600 dark:text-gray-300">
              Process the return and optionally accept payment for any fine.
            </p>
          </div>
        </div>
        
        <div class="p-3 rounded-lg bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700">
          <div class="text-xs text-gray-500 dark:text-gray-400">Predicted fine</div>
          
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
              label="Payment Amount"
              value={Decimal.to_string(@predicted_fine || Decimal.new("0"))}
            />
            <.input
              field={f[:payment_method]}
              name="payment_method"
              type="select"
              options={[{"Cash", "cash"}, {"Card", "card"}, {"Other", "other"}]}
              label="Payment Method"
              value={@payment_method || "cash"}
            />
          </div>
          
          <div class="mt-4 flex justify-end items-center space-x-3">
            <button
              type="button"
              phx-click="cancel_return"
              class="px-4 py-2 border rounded bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-200 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button type="submit" class="px-4 py-2 rounded bg-rose-600 hover:bg-rose-700 text-white">
              Return
            </button>
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

    ~H"""
    <.modal
      :if={@renew_modal_visible}
      id="renew-modal"
      show
      on_cancel={JS.hide(to: "#renew-modal") |> JS.push("cancel_renew")}
    >
      <div class="space-y-4">
        <div class="flex items-start space-x-3">
          <div class="p-2 rounded-full bg-voile-primary/10 dark:bg-voile-primary/20 text-voile-primary dark:text-voile-surface">
            <.icon name="hero-arrow-path" class="w-5 h-5" />
          </div>
          
          <div>
            <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">Renew Item</h3>
            
            <p class="text-sm text-gray-600 dark:text-gray-300">
              Extend the due date for this transaction. You can use the recommended duration or enter a custom number of days.
            </p>
          </div>
        </div>
        
        <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
          <div class="p-3 rounded-lg bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700">
            <div class="text-xs text-gray-500 dark:text-gray-400">Recommended</div>
            
            <div class="mt-1 text-xl font-semibold text-gray-800 dark:text-gray-100">
              {if @recommended_renew_days, do: "#{@recommended_renew_days} days", else: "-"}
            </div>
            
            <div class="mt-1 text-xs text-gray-500 dark:text-gray-400">Based on member type</div>
          </div>
          
          <div class="p-3 rounded-lg bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700">
            <div class="text-xs text-gray-500 dark:text-gray-400">Current due date</div>
            
            <div class="mt-1 text-sm font-medium text-gray-800 dark:text-gray-100">
              {if @transaction && @transaction.due_date,
                do: format_datetime(@transaction.due_date),
                else: "-"}
            </div>
            
            <div class="mt-3 text-xs text-gray-500 dark:text-gray-400">Expected new due date</div>
            
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
            <.input
              field={f[:renew_days]}
              name="renew_days"
              type="number"
              min="1"
              label="Renewal Duration (days)"
              value={@recommended_renew_days || 1}
              class="w-40"
            />
            <div class="ml-auto flex items-center space-x-3">
              <div class="text-sm text-gray-600 dark:text-gray-300">Remaining</div>
              
              <div class="inline-flex items-center px-2 py-1 rounded-full text-sm font-medium bg-amber-100 text-amber-800 dark:bg-amber-700/20 dark:text-amber-300">
                {@remaining_renewals || 0}
              </div>
            </div>
          </div>
          
          <div class="mt-4 flex justify-end items-center space-x-3">
            <button
              type="button"
              phx-click="cancel_renew"
              class="px-4 py-2 border rounded bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-200 hover:bg-gray-50"
            >
              Cancel
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
              Renew
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
end
