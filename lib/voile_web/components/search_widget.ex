defmodule VoileWeb.Components.SearchWidget do
  @moduledoc """
  Reusable search widget component for embedding in other pages
  """

  use VoileWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:search_query, "")
     |> assign(:suggestions, [])
     |> assign(:show_suggestions, false)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("search_input", %{"value" => query}, socket) do
    trimmed_query = String.trim(query)

    socket = assign(socket, :search_query, query)

    if String.length(trimmed_query) >= 2 do
      # Spawn an async task to fetch suggestions so we don't block the socket.
      # We send the final `:suggestions_fetched` message directly so the
      # parent LiveView doesn't receive an intermediate `:fetch_suggestions`
      # message it doesn't handle (which produced the warning).
      # Indicate loading, perform synchronous fetch, then update state.
      socket = assign(socket, :loading, true)
      user_role = Voile.Utils.SearchHelper.get_user_role(socket)

      suggestions = Voile.Utils.SearchHelper.fetch_suggestions(trimmed_query, user_role)

      socket =
        socket
        |> assign(:suggestions, suggestions)
        |> assign(:show_suggestions, length(suggestions) > 0)
        |> assign(:loading, false)

      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:suggestions, [])
        |> assign(:show_suggestions, false)
        |> assign(:loading, false)

      {:noreply, socket}
    end
  end

  # ...existing code...

  @impl true
  def handle_event("select_suggestion", %{"title" => title}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, title)
     |> assign(:show_suggestions, false)
     |> push_navigate(to: "/search?q=#{URI.encode(title)}")}
  end

  @impl true
  def handle_event("submit_search", %{"search" => %{"query" => query}}, socket) do
    if String.trim(query) != "" do
      {:noreply, push_navigate(socket, to: "/search?q=#{URI.encode(query)}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("hide_suggestions", _params, socket) do
    {:noreply, assign(socket, :show_suggestions, false)}
  end

  # Handle suggestions fetched from parent LiveView
  def handle_info({:suggestions_fetched, component_id, suggestions}, socket) do
    if socket.assigns.id == component_id do
      {:noreply,
       socket
       |> assign(:suggestions, suggestions)
       |> assign(:show_suggestions, length(suggestions) > 0)
       |> assign(:loading, false)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :size, fn -> "default" end)
    assigns = assign_new(assigns, :placeholder, fn -> "Search library catalog..." end)

    ~H"""
    <div class="relative" phx-target={@myself}>
      <form phx-submit="submit_search" phx-target={@myself}>
        <div class="relative">
          <input
            name="search[query]"
            type="text"
            value={@search_query}
            placeholder={@placeholder}
            class={search_input_class(@size)}
            phx-keyup="search_input"
            phx-target={@myself}
            phx-debounce="300"
            autocomplete="off"
            phx-blur="hide_suggestions"
          />
          <!-- Search Icon -->
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
              >
              </path>
            </svg>
          </div>
          <!-- Loading Indicator -->
          <%= if @loading do %>
            <div class="absolute inset-y-0 right-0 pr-3 flex items-center">
              <svg
                class="animate-spin h-4 w-4 text-blue-600"
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
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                >
                </path>
              </svg>
            </div>
          <% end %>
        </div>
      </form>
      <!-- Suggestions Dropdown -->
      <%= if @show_suggestions and length(@suggestions) > 0 do %>
        <div class="absolute z-50 w-full mt-1 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-md shadow-lg max-h-64 overflow-y-auto">
          <%= for suggestion <- @suggestions do %>
            <div
              class="px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer flex items-center justify-between"
              phx-click="select_suggestion"
              phx-value-title={suggestion.title}
              phx-target={@myself}
            >
              <span class="flex-1 text-sm text-gray-900 dark:text-white">{suggestion.title}</span>
              <span class={"px-2 py-1 text-xs rounded-full #{type_badge_class(suggestion.type)}"}>
                {String.capitalize(suggestion.type)}
              </span>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Private helper functions

  defp search_input_class("small") do
    "block w-full pl-10 pr-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-md leading-5 bg-white dark:bg-gray-800 placeholder-gray-500 dark:placeholder-gray-400 text-gray-900 dark:text-white focus:outline-none focus:placeholder-gray-400 dark:focus:placeholder-gray-500 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
  end

  defp search_input_class("large") do
    "block w-full pl-12 pr-4 py-4 text-lg border border-gray-300 dark:border-gray-600 rounded-lg leading-6 bg-white dark:bg-gray-800 placeholder-gray-500 dark:placeholder-gray-400 text-gray-900 dark:text-white focus:outline-none focus:placeholder-gray-400 dark:focus:placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
  end

  defp search_input_class(_) do
    "block w-full pl-10 pr-3 py-3 border border-gray-300 dark:border-gray-600 rounded-md leading-5 bg-white dark:bg-gray-800 placeholder-gray-500 dark:placeholder-gray-400 text-gray-900 dark:text-white focus:outline-none focus:placeholder-gray-400 dark:focus:placeholder-gray-500 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
  end

  defp type_badge_class("collection"), do: "bg-blue-100 text-blue-800"
  defp type_badge_class("item"), do: "bg-green-100 text-green-800"
  defp type_badge_class(_), do: "bg-gray-100 text-gray-800"
end
