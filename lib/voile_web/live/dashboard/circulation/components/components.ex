defmodule VoileWeb.Dashboard.Circulation.Components do
  @moduledoc """
  Shared components for the circulation dashboard.
  """
  use VoileWeb, :live_component

  import VoileWeb.Dashboard.Circulation.Helpers
  import VoileWeb.Utils.AuthHelper

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
        <div class="h-10 w-10 rounded-full bg-gray-200 flex items-center justify-center">
          <span class="text-sm font-medium text-gray-700">
            {if @member, do: String.first(@member.full_name || "?"), else: "?"}
          </span>
        </div>
      </div>
      
      <div class="ml-4">
        <div class="text-sm font-medium text-gray-900">
          {if @member, do: @member.full_name, else: "Unknown Member"}
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
                    class="block w-full text-sm border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
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
                      class="block w-full text-sm border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                    />
                  </form>
                <% :date -> %>
                  <form phx-change={filter.event}>
                    <input
                      type="date"
                      name={filter.name}
                      value={Map.get(@current_filters, filter.name, "")}
                      class="block w-full text-sm border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
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
    <div class="bg-white shadow rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900">Quick Actions</h3>
       {can_access?(@current_user, "circulation.transactions.checkout")}
      <div class="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-3">
        <%= if can_access?(@current_user, "circulation.transactions.checkout") do %>
          <.link
            navigate={~p"/manage/circulation/transactions/checkout"}
            class="w-full inline-flex items-center justify-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700"
          >
            Quick Checkout
          </.link>
        <% else %>
          <button
            disabled
            class="w-full inline-flex items-center justify-center px-4 py-2 border border-gray-200 text-sm font-medium rounded-md bg-gray-100 text-gray-400"
          >
            Quick Checkout
          </button>
        <% end %>
        
        <%= if can_access?(@current_user, "circulation.transactions") do %>
          <.link
            navigate={~p"/manage/circulation/transactions"}
            class="w-full inline-flex items-center justify-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
          >
            Quick Return
          </.link>
        <% else %>
          <button
            disabled
            class="w-full inline-flex items-center justify-center px-4 py-2 border border-gray-200 text-sm font-medium rounded-md bg-gray-100 text-gray-400"
          >
            Quick Return
          </button>
        <% end %>
        
        <%= if can_access?(@current_user, "settings.users") do %>
          <.link
            navigate={~p"/manage/settings/users"}
            class="w-full inline-flex items-center justify-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
          >
            Member Lookup
          </.link>
        <% else %>
          <button
            disabled
            class="w-full inline-flex items-center justify-center px-4 py-2 border border-gray-200 text-sm font-medium rounded-md bg-gray-100 text-gray-400"
          >
            Member Lookup
          </button>
        <% end %>
        
        <.link
          navigate={~p"/search?type=items"}
          class="w-full inline-flex items-center justify-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50"
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
            <.link navigate={@root_path} class="text-gray-700 hover:text-gray-900">
              <.icon name="hero-home" class="w-4 h-4 mr-2" /> {@root_label}
            </.link>
          <% else %>
            <div class="text-gray-700">
              <.icon name="hero-home" class="w-4 h-4 mr-2" /> {@root_label}
            </div>
          <% end %>
        </li>
        
        <%= if @section_label do %>
          <li>
            <div class="flex items-center">
              <.icon name="hero-chevron-right" class="w-4 h-4 text-gray-500" />
              <%= if @section_path do %>
                <.link navigate={@section_path} class="ml-1 text-gray-700 hover:text-gray-900">
                  {@section_label}
                </.link>
              <% else %>
                <span class="ml-1 text-gray-500">{@section_label}</span>
              <% end %>
            </div>
          </li>
          
          <li aria-current="page">
            <div class="flex items-center">
              <.icon name="hero-chevron-right" class="w-4 h-4 text-gray-500" />
              <span class="ml-1 text-gray-500">{@current_label}</span>
            </div>
          </li>
        <% else %>
          <li aria-current="page">
            <div class="flex items-center">
              <.icon name="hero-chevron-right" class="w-4 h-4 text-gray-500" />
              <span class="ml-1 text-gray-500">{@current_label}</span>
            </div>
          </li>
        <% end %>
      </ol>
    </nav>
    """
  end

  # Private helper functions

  defp badge_class_for_type(:transaction, status), do: transaction_type_badge_class(status)
  defp badge_class_for_type(:reservation, status), do: reservation_status_badge_class(status)
  defp badge_class_for_type(:requisition, status), do: requisition_status_badge_class(status)
  defp badge_class_for_type(:fine, status), do: fine_status_badge_class(status)
  defp badge_class_for_type(:general, status), do: status_badge_class(status)
end
