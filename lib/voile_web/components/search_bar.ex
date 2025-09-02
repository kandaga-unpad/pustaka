defmodule VoileWeb.Components.SearchBar do
  @moduledoc """
  A simple search bar component that matches the Voile dashboard styling
  """

  use Phoenix.Component

  @doc """
  Renders a search bar that can be embedded in the navigation or dashboard

  ## Examples

      <.search_bar placeholder="Search library..." />
      <.search_bar size="large" show_filters />
  """
  attr :placeholder, :string, default: "Search library catalog..."
  # "small", "default", "large"
  attr :size, :string, default: "default"
  attr :show_filters, :boolean, default: false
  attr :value, :string, default: ""
  attr :class, :string, default: ""

  def search_bar(assigns) do
    ~H"""
    <div class={["relative", @class]}>
      <form method="GET" action="/search" class="flex gap-2">
        <div class="relative flex-1">
          <input
            type="text"
            name="q"
            value={@value}
            placeholder={@placeholder}
            class={search_input_class(@size)}
          />
          <!-- Search Icon -->
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <svg
              class="h-5 w-5 text-gray-400 dark:text-gray-500"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
              >
              </path>
            </svg>
          </div>
        </div>
        
        <%= if @show_filters do %>
          <select
            name="type"
            class={select_class(@size)}
          >
            <option value="universal">All</option>
            
            <option value="collections">Collections</option>
            
            <option value="items">Items</option>
          </select>
        <% end %>
        
        <button
          type="submit"
          class={button_class(@size)}
        >
          Search
        </button>
      </form>
    </div>
    """
  end

  # Private helper functions matching your dashboard style

  defp search_input_class("small") do
    "block w-full pl-10 pr-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
  end

  defp search_input_class("large") do
    "block w-full pl-12 pr-4 py-4 text-lg border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
  end

  defp search_input_class(_) do
    "block w-full pl-10 pr-3 py-3 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
  end

  defp select_class("small") do
    "px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
  end

  defp select_class("large") do
    "px-4 py-4 text-lg border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
  end

  defp select_class(_) do
    "px-3 py-3 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
  end

  defp button_class("small") do
    "px-4 py-2 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
  end

  defp button_class("large") do
    "px-6 py-4 text-lg bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
  end

  defp button_class(_) do
    "px-5 py-3 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
  end
end
