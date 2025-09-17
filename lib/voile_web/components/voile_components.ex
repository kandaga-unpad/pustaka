defmodule VoileWeb.VoileComponents do
  @moduledoc """
  Centralized UI components for the Voile frontend
  """

  use Phoenix.Component
  import VoileWeb.CoreComponents, only: [icon: 1]

  alias Phoenix.LiveView.JS

  @doc """
  Main Search Component for GLAM (Gallery, Library, Archive, Museum)

  ## Examples

    <.main_search current_glam_type="quick" search_query="" />

  The component accepts current_glam_type and search_query for state management.
  """
  attr :current_glam_type, :string, default: "quick"
  attr :search_query, :string, default: ""
  attr :form_action, :string, default: "/search"
  attr :live_action, :atom, default: nil
  attr :search_results, :list, default: []
  attr :show_suggestions, :boolean, default: false
  attr :loading, :boolean, default: false

  def main_search(assigns) do
    assigns = assign_glam_tabs(assigns)

    ~H"""
    <div class="relative">
      <div class="search-tab">
        <%= for tab <- @glam_tabs do %>
          <button
            id={"tab-#{tab.type}"}
            tabindex={tab.index}
            class={[
              "search-tab-item",
              if(@current_glam_type == tab.type, do: "active-tab-item", else: "")
            ]}
            phx-click={
              if @live_action do
                JS.patch("/search?glam_type=#{tab.type}&q=#{@search_query}")
              else
                # Dispatch a client-side event so front-end JS can handle tab activation.
                JS.dispatch("voile:set-active-tab",
                  detail: %{selector: "#tab-#{tab.type}", content: "##{tab.type}-search"}
                )
              end
            }
          >
            <.icon name={tab.icon} class="w-4 h-4 mr-2" /> {tab.label}
          </button>
        <% end %>
      </div>
      
      <div class="bg-brand-200 dark:bg-gray-800 p-5 rounded-bl-lg rounded-br-lg">
        <%= if @live_action do %>
          <!-- LiveView Form -->
          <form phx-submit="search" phx-change="search_change" class="flex gap-2">
            <div class="w-full relative">
              <div class="relative">
                <input
                  type="text"
                  name="q"
                  value={@search_query}
                  placeholder={get_search_placeholder(@current_glam_type)}
                  class="input-main-search pr-10"
                  phx-debounce="300"
                  phx-focus="show_suggestions"
                  phx-blur="hide_suggestions"
                  autocomplete="off"
                />
                <%= if @loading do %>
                  <div class="absolute right-3 top-1/2 transform -translate-y-1/2">
                    <.icon name="hero-arrow-path" class="w-5 h-5 text-gray-400 animate-spin" />
                  </div>
                <% end %>
              </div>
               <input type="hidden" name="glam_type" value={@current_glam_type} />
              <!-- Search Suggestions Dropdown -->
              <%= if @show_suggestions and length(@search_results) > 0 do %>
                <.search_suggestions
                  results={@search_results}
                  search_query={@search_query}
                  current_glam_type={@current_glam_type}
                />
              <% end %>
              <!-- No Results Message -->
              <%= if @show_suggestions and @search_query != "" and length(@search_results) == 0 and not @loading do %>
                <div class="absolute top-full left-0 right-0 z-50 mt-1 bg-white dark:bg-voile-neutral-dark rounded-md shadow-lg border border-voile-muted dark:border-voile-dark p-4">
                  <div class="text-center text-gray-500 dark:text-gray-400">
                    <.icon name="hero-magnifying-glass" class="mx-auto h-8 w-8 mb-2" />
                    <p class="text-sm">No collections found for "{@search_query}"</p>
                    
                    <p class="text-xs mt-1">Try different keywords or check another GLAM type</p>
                  </div>
                </div>
              <% end %>
            </div>
            
            <div><button type="submit" class="default-btn">Search</button></div>
          </form>
        <% else %>
          <!-- Regular Form -->
          <form method="GET" action={@form_action} class="flex gap-2">
            <div class="w-full tab-container">
              <%= for tab <- @glam_tabs do %>
                <div class="tab-pane">
                  <input
                    type="text"
                    name="q"
                    value={if(@current_glam_type == tab.type, do: @search_query, else: "")}
                    placeholder={tab.placeholder}
                    class="input-main-search"
                  /> <input type="hidden" name="glam_type" value={tab.type} />
                </div>
              <% end %>
            </div>
            
            <div><button type="submit" class="default-btn">Search</button></div>
          </form>
        <% end %>
        <!-- Search Stats/Info -->
        <%= if @search_query != "" and @current_glam_type != "quick" do %>
          <div class="mt-2 text-xs text-gray-600 dark:text-gray-400">
            Searching in <span class="font-semibold">{get_glam_type_name(@current_glam_type)}</span>
            collections
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Search suggestions dropdown component
  """
  attr :results, :list, required: true
  attr :search_query, :string, default: ""
  attr :current_glam_type, :string, default: "quick"
  attr :max_results, :integer, default: 8

  def search_suggestions(assigns) do
    ~H"""
    <div class="absolute top-full left-0 right-0 z-50 mt-1 bg-white dark:bg-voile-neutral-dark rounded-md shadow-lg border border-voile-muted dark:border-voile-dark max-h-96 overflow-y-auto">
      <!-- Quick Actions Header -->
      <%= if @search_query != "" do %>
        <div class="px-4 py-2 border-b border-voile-light dark:border-voile-dark">
          <button
            phx-click="perform_search"
            phx-value-query={@search_query}
            phx-value-glam_type={@current_glam_type}
            class="flex items-center text-sm text-voile-primary dark:text-voile-primary hover:text-voile-dark dark:hover:text-voile-light font-medium"
          >
            <.icon name="hero-magnifying-glass" class="w-4 h-4 mr-2" />
            Search for "{@search_query}" in {get_glam_type_name(@current_glam_type)}
          </button>
        </div>
      <% end %>
      <!-- Collection Results -->
      <div class="py-2">
        <%= for {collection, index} <- Enum.with_index(Enum.take(@results, @max_results)) do %>
          <button
            phx-click="select_collection"
            phx-value-id={collection.id}
            class="w-full text-left px-4 py-3 hover:bg-voile-surface-dark dark:hover:bg-voile-surface-dark border-b border-voile-extra-light dark:border-voile-dark last:border-b-0 group transition-colors"
          >
            <div class="flex items-start gap-3">
              <!-- Collection Icon/Thumbnail -->
              <div class="flex-shrink-0 mt-1">
                <%= if collection.thumbnail do %>
                  <img
                    src={collection.thumbnail}
                    alt={collection.title}
                    class="w-10 h-10 object-cover rounded"
                  />
                <% else %>
                  <div class="w-10 h-10 bg-voile-surface dark:bg-voile-dark rounded flex items-center justify-center">
                    <%= if collection.resource_class do %>
                      <.icon
                        name={glam_type_icon(collection.resource_class.glam_type)}
                        class="w-5 h-5 text-gray-400"
                      />
                    <% else %>
                      <.icon name="hero-book-open" class="w-5 h-5 text-gray-400" />
                    <% end %>
                  </div>
                <% end %>
              </div>
              <!-- Collection Info -->
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 mb-1">
                  <!-- GLAM Type Badge -->
                  <%= if collection.resource_class do %>
                    <span class={[
                      "inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-full",
                      glam_type_badge_class(collection.resource_class.glam_type)
                    ]}>
                      {collection.resource_class.glam_type}
                    </span>
                  <% end %>
                  <!-- Status Badge -->
                  <span class={[
                    "px-2 py-0.5 text-xs rounded-full",
                    status_badge_class(collection.status)
                  ]}>
                    {String.capitalize(collection.status || "Unknown")}
                  </span>
                </div>
                <!-- Title with highlighting -->
                <h4 class="text-sm font-medium text-gray-900 dark:text-white group-hover:text-voile-primary dark:group-hover:text-voile-primary line-clamp-1">
                  <.highlight_text text={collection.title} query={@search_query} />
                </h4>
                <!-- Description -->
                <%= if collection.description do %>
                  <p class="text-xs text-gray-500 dark:text-gray-400 line-clamp-2 mt-1">
                    <.highlight_text text={collection.description} query={@search_query} />
                  </p>
                <% end %>
                <!-- Metadata -->
                <div class="flex items-center gap-4 mt-2 text-xs text-gray-400">
                  <%= if collection.mst_creator do %>
                    <div class="flex items-center gap-1">
                      <.icon name="hero-user" class="w-3 h-3" />
                      <span>{collection.mst_creator.creator_name}</span>
                    </div>
                  <% end %>
                  
                  <%= if length(collection.items || []) > 0 do %>
                    <div class="flex items-center gap-1">
                      <.icon name="hero-document-duplicate" class="w-3 h-3" />
                      <span>{length(collection.items)} items</span>
                    </div>
                  <% end %>
                </div>
              </div>
              <!-- Arrow Icon -->
              <div class="flex-shrink-0 mt-2">
                <.icon
                  name="hero-arrow-top-right-on-square"
                  class="w-4 h-4 text-gray-400 group-hover:text-voile-primary"
                />
              </div>
            </div>
          </button>
        <% end %>
      </div>
      <!-- Show More Results -->
      <%= if length(@results) > @max_results do %>
        <div class="px-4 py-3 border-t border-voile-light dark:border-voile-dark bg-voile-surface light:bg-voile-surface-dark">
          <button
            phx-click="perform_search"
            phx-value-query={@search_query}
            phx-value-glam_type={@current_glam_type}
            class="text-sm text-voile-primary dark:text-voile-primary hover:text-voile-dark dark:hover:text-voile-light font-medium"
          >
            Show all {length(@results)} results for "{@search_query}" →
          </button>
        </div>
      <% end %>
      <!-- Keyboard Navigation Hint -->
      <div class="px-4 py-2 border-t border-voile-light dark:border-voile-dark bg-voile-surface dark:bg-voile-surface-dark">
        <p class="text-xs text-voile-muted dark:text-voile-muted">
          Press <kbd class="px-1 py-0.5 text-xs bg-voile-surface dark:bg-voile-dark rounded">↑↓</kbd>
          to navigate,
          <kbd class="px-1 py-0.5 text-xs bg-voile-surface dark:bg-voile-dark rounded">Enter</kbd>
          to select,
          <kbd class="px-1 py-0.5 text-xs bg-voile-surface dark:bg-voile-dark rounded">Esc</kbd>
          to close
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Highlights search query within text
  """
  attr :text, :string, required: true
  attr :query, :string, default: ""

  def highlight_text(assigns) do
    highlighted_parts =
      if assigns.query != "" and String.length(assigns.query) >= 2 do
        split_and_highlight(assigns.text, assigns.query)
      else
        [assigns.text]
      end

    assigns = assign(assigns, :highlighted_parts, highlighted_parts)

    ~H"""
    <%= for part <- @highlighted_parts do %>
      <%= if is_map(part) and part.highlight do %>
        <mark class="bg-yellow-200 dark:bg-yellow-800 px-0.5 rounded">{part.text}</mark>
      <% else %>
        {part}
      <% end %>
    <% end %>
    """
  end

  # Helper function to split text and mark highlighted parts
  defp split_and_highlight(text, query) do
    case Regex.split(~r/#{Regex.escape(query)}/i, text, include_captures: true, trim: true) do
      parts ->
        Enum.map(parts, fn part ->
          if String.downcase(part) == String.downcase(query) do
            %{text: part, highlight: true}
          else
            part
          end
        end)
    end
  end

  @doc """
  Compact search suggestions component for better performance
  """
  attr :results, :list, required: true
  attr :search_query, :string, default: ""
  attr :current_glam_type, :string, default: "quick"
  attr :selected_index, :integer, default: -1
  attr :max_results, :integer, default: 6

  def compact_search_suggestions(assigns) do
    ~H"""
    <div class="absolute top-full left-0 right-0 z-50 mt-1 bg-white dark:bg-voile-neutral-dark rounded-md shadow-lg border border-voile-muted dark:border-voile-dark max-h-80 overflow-y-auto">
      <!-- Search Action -->
      <%= if @search_query != "" do %>
        <div class={[
          "px-4 py-3 border-b border-voile-light dark:border-voile-dark cursor-pointer hover:bg-voile-surface-dark dark:hover:bg-voile-surface-dark transition-colors",
          if(@selected_index == -1, do: "bg-voile-info dark:bg-voile-primary/20", else: "")
        ]}>
          <div class="flex items-center gap-3">
            <div class="flex-shrink-0">
              <.icon name="hero-magnifying-glass" class="w-5 h-5 text-voile-primary" />
            </div>
            
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-900 dark:text-white">
                Search for "<span class="text-voile-primary dark:text-voile-primary">{@search_query}</span>"
              </p>
              
              <p class="text-xs text-gray-500 dark:text-gray-400">
                in {get_glam_type_name(@current_glam_type)} collections
              </p>
            </div>
            
            <div class="flex-shrink-0">
              <kbd class="px-2 py-1 text-xs bg-gray-200 dark:bg-gray-600 rounded">Enter</kbd>
            </div>
          </div>
        </div>
      <% end %>
      <!-- Collection Results -->
      <%= for {collection, index} <- Enum.with_index(Enum.take(@results, @max_results)) do %>
        <div
          class={[
            "px-4 py-3 cursor-pointer hover:bg-voile-surface-dark dark:hover:bg-voile-surface-dark transition-colors border-b border-voile-extra-light dark:border-voile-dark last:border-b-0",
            if(@selected_index == index, do: "bg-voile-info dark:bg-voile-primary/20", else: "")
          ]}
          phx-click="select_collection"
          phx-value-id={collection.id}
        >
          <div class="flex items-center gap-3">
            <!-- Collection Icon -->
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-voile-surface dark:bg-voile-dark rounded flex items-center justify-center">
                <%= if collection.resource_class do %>
                  <.icon
                    name={glam_type_icon(collection.resource_class.glam_type)}
                    class="w-4 h-4 text-voile-muted"
                  />
                <% else %>
                  <.icon name="hero-book-open" class="w-4 h-4 text-voile-muted" />
                <% end %>
              </div>
            </div>
            <!-- Collection Info -->
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <!-- GLAM Type Indicator -->
                <%= if collection.resource_class do %>
                  <div class={[
                    "w-2 h-2 rounded-full flex-shrink-0",
                    case collection.resource_class.glam_type do
                      "Gallery" -> "bg-pink-500"
                      "Library" -> "bg-blue-500"
                      "Archive" -> "bg-amber-500"
                      "Museum" -> "bg-emerald-500"
                      _ -> "bg-gray-500"
                    end
                  ]}>
                  </div>
                <% end %>
                
                <h4 class="text-sm font-medium text-voile dark:text-voile-dark truncate">
                  <.highlight_text text={collection.title} query={@search_query} />
                </h4>
              </div>
              
              <div class="flex items-center gap-3 mt-1 text-xs text-voile-muted dark:text-voile-dark">
                <%= if collection.resource_class do %>
                  <span>{collection.resource_class.glam_type}</span>
                <% end %>
                
                <%= if collection.mst_creator do %>
                  <span>• {collection.mst_creator.creator_name}</span>
                <% end %>
                
                <%= if length(collection.items || []) > 0 do %>
                  <span>• {length(collection.items)} items</span>
                <% end %>
              </div>
            </div>
            <!-- Status -->
            <div class="flex-shrink-0">
              <div class={[
                "w-2 h-2 rounded-full",
                case collection.status do
                  "published" -> "bg-voile-success"
                  "draft" -> "bg-voile-warning"
                  "archived" -> "bg-voile-muted"
                  _ -> "bg-voile-extra-light"
                end
              ]}>
              </div>
            </div>
          </div>
        </div>
      <% end %>
      <!-- Show More -->
      <%= if length(@results) > @max_results do %>
        <div class="px-4 py-2 border-t border-voile-light dark:border-voile-dark bg-voile-surface dark:bg-voile-surface-dark">
          <p class="text-xs text-center text-gray-500 dark:text-gray-400">
            Showing {@max_results} of {length(@results)} results
            <button
              phx-click="perform_search"
              phx-value-query={@search_query}
              phx-value-glam_type={@current_glam_type}
              class="ml-2 text-voile-primary dark:text-voile-primary hover:underline"
            >
              View all
            </button>
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Collection card component for displaying collection information.
  """
  attr :collection, :map, required: true

  def collection_card(assigns) do
    ~H"""
    <div class="p-6">
      <!-- Thumbnail -->
      <div class="mb-4">
        <%= if @collection.thumbnail do %>
          <img
            src={@collection.thumbnail}
            class="w-full h-86 object-cover rounded-lg border-1 border-voile-muted dark:border-voile-dark shadow-md"
            alt={@collection.title}
          />
        <% else %>
          <div class="w-full h-86 bg-gray-200 dark:bg-gray-600 rounded-lg flex items-center justify-center border-voile-muted dark:border-voile-dark shadow-md">
            <.icon name="hero-book-open" class="w-8 h-8 text-gray-400" />
          </div>
        <% end %>
      </div>
      <!-- Content -->
      <div class="flex-1">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2 line-clamp-2">
          {@collection.title}
        </h3>
        
        <%= if @collection.description do %>
          <p class="text-sm text-gray-600 dark:text-gray-300 mb-3 line-clamp-2">
            {@collection.description}
          </p>
        <% end %>
        <!-- Metadata -->
        <div class="space-y-2 text-xs text-gray-500 dark:text-gray-400">
          <%= if @collection.mst_creator do %>
            <div class="flex items-center gap-1">
              <.icon name="hero-user" class="w-3 h-3" />
              <span>{@collection.mst_creator.creator_name}</span>
            </div>
          <% end %>
          
          <%= if @collection.node do %>
            <div class="flex items-center">
              <.icon
                name="hero-building-library-solid"
                class="w-3 h-3 mr-2 text-gray-400 dark:text-gray-500"
              />
              <span class="font-medium text-gray-900 dark:text-white">{@collection.node.name}</span>
            </div>
          <% end %>
          
          <%= if length(@collection.items) > 0 do %>
            <div class="flex items-center gap-1">
              <.icon name="hero-document-duplicate" class="w-3 h-3" />
              <span>
                {length(@collection.items)} {if length(@collection.items) == 1,
                  do: "item",
                  else: "items"}
              </span>
            </div>
          <% end %>
        </div>
      </div>
      <!-- Status Badge -->
      <div class="mt-4 flex justify-between items-center">
        <span class={"px-2 py-1 text-xs rounded-full #{status_badge_class(@collection.status)}"}>
          {String.capitalize(@collection.status || "Unknown")}
        </span>
        <.link
          navigate={"/collections/#{@collection.id}"}
          class="text-sm font-medium text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
        >
          View Details →
        </.link>
      </div>
    </div>
    """
  end

  @doc """
  Item card component for displaying item information.
  """
  attr :item, :map, required: true

  def item_card(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-3">
          <div class="flex-shrink-0">
            <.icon name="hero-document-solid" class="w-5 h-5 text-gray-400" />
          </div>
          
          <div class="min-w-0 flex-1">
            <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
              <.link
                navigate={"/items/#{@item.id}"}
                class="hover:text-blue-600 dark:hover:text-blue-400"
              >
                Item Code: {@item.item_code}
              </.link>
            </p>
            
            <p class="text-sm text-gray-500 dark:text-gray-400 truncate">
              Location: {@item.location}
            </p>
          </div>
        </div>
      </div>
      
      <div class="flex items-center gap-4">
        <div class="text-right">
          <span class={"px-2 py-1 text-xs rounded-full #{availability_badge_class(@item.availability)}"}>
            {String.capitalize(@item.availability || "Unknown")}
          </span>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
            {String.capitalize(@item.condition || "Unknown")} condition
          </p>
        </div>
        
        <.link
          navigate={"/items/#{@item.id}"}
          class="text-sm font-medium text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
        >
          View →
        </.link>
      </div>
    </div>
    """
  end

  @doc """
  Item row component for list view display.
  """
  attr :item, :map, required: true

  def item_row(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
      <!-- Main Item Info -->
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-4">
          <div class="flex-shrink-0 mr-3">
            <%= if @item.collection.thumbnail do %>
              <img
                src={@item.collection.thumbnail}
                alt={@item.collection.title}
                class="w-14 h-14 object-cover rounded"
              />
            <% else %>
              <.icon name="hero-document-solid" class="w-14 h-14 text-gray-400" />
            <% end %>
          </div>
          
          <div class="min-w-0 flex-1">
            <h3 class="text-sm font-medium text-gray-900 dark:text-white">
              <.link
                navigate={"/items/#{@item.id}"}
                class="hover:text-blue-600 dark:hover:text-blue-400"
              >
                {@item.item_code}
              </.link>
            </h3>
            
            <div class="mt-1 flex flex-col sm:flex-row sm:flex-wrap sm:space-x-6">
              <div class="mt-2 flex items-center text-sm text-gray-500 dark:text-gray-400">
                <.icon name="hero-map-pin" class="flex-shrink-0 mr-1.5 h-4 w-4 text-gray-400" /> {@item.location}
              </div>
              
              <%= if @item.collection do %>
                <div class="mt-2 flex items-center text-sm text-gray-500 dark:text-gray-400">
                  <.icon name="hero-folder" class="flex-shrink-0 mr-1.5 h-4 w-4 text-gray-400" />
                  <.link
                    navigate={"/collections/#{@item.collection.id}"}
                    class="hover:text-gray-700 dark:hover:text-gray-300"
                  >
                    {@item.collection.title}
                  </.link>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
      <!-- Status and Actions -->
      <div class="flex items-center justify-between lg:flex-col lg:items-end lg:justify-start gap-4">
        <div class="flex flex-col items-start lg:items-end gap-2">
          <span class={"px-2 py-1 text-xs font-medium rounded-full #{availability_badge_class(@item.availability)}"}>
            {String.capitalize(@item.availability || "Unknown")}
          </span>
          <span class={"px-2 py-1 text-xs rounded-full #{condition_badge_class(@item.condition)}"}>
            {String.capitalize(@item.condition || "Unknown")}
          </span>
        </div>
        
        <div class="flex items-center gap-2">
          <.link
            navigate={"/items/#{@item.id}"}
            class="text-sm font-medium text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
          >
            View Details
          </.link>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Related item card component for showing related items.
  """
  attr :item, :map, required: true

  def related_item_card(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <div class="flex-shrink-0">
          <.icon name="hero-document-solid" class="w-5 h-5 text-gray-400" />
        </div>
        
        <div class="min-w-0 flex-1">
          <p class="text-sm font-medium text-gray-900 dark:text-white">
            <.link
              navigate={"/items/#{@item.id}"}
              class="hover:text-blue-600 dark:hover:text-blue-400"
            >
              {@item.item_code}
            </.link>
          </p>
          
          <p class="text-sm text-gray-500 dark:text-gray-400">Location: {@item.location}</p>
        </div>
      </div>
      
      <div class="flex items-center gap-2">
        <span class={"px-2 py-1 text-xs rounded-full #{availability_badge_class(@item.availability)}"}>
          {String.capitalize(@item.availability || "Unknown")}
        </span>
      </div>
    </div>
    """
  end

  @doc """
  Statistics item component for displaying stats with icons.
  """
  attr :icon, :string, required: true
  attr :value, :string, required: true
  attr :label, :string, required: true

  def stat_item(assigns) do
    ~H"""
    <div class="flex items-center">
      <div class="flex-shrink-0">
        <%= case @icon do %>
          <% "document-duplicate" -> %>
            <.icon name="hero-document-duplicate-solid" class="w-5 h-5 text-gray-400" />
          <% "check-circle" -> %>
            <.icon name="hero-check-circle-solid" class="w-5 h-5 text-green-500" />
          <% "clock" -> %>
            <.icon name="hero-clock-solid" class="w-5 h-5 text-yellow-500" />
          <% _ -> %>
            <.icon name="hero-information-circle-solid" class="w-5 h-5 text-gray-400" />
        <% end %>
      </div>
      
      <div class="ml-3 flex-1 min-w-0">
        <p class="text-sm font-medium text-gray-900 dark:text-white">{@value}</p>
        
        <p class="text-xs text-gray-500 dark:text-gray-400">{@label}</p>
      </div>
    </div>
    """
  end

  @doc """
  Empty state component for when no results are found.
  """
  attr :search_query, :string, default: ""
  attr :icon_name, :string, default: "hero-book-open"
  attr :title, :string, default: "No results found"
  attr :message, :string, default: ""

  def empty_state(assigns) do
    ~H"""
    <div class="text-center py-12">
      <.icon name={@icon_name} class="mx-auto h-12 w-12 text-gray-400" />
      <h3 class="mt-2 text-sm font-semibold text-gray-900 dark:text-white">{@title}</h3>
      
      <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
        <%= if @search_query != "" do %>
          No results match your search criteria. Try adjusting your search terms or filters.
        <% else %>
          {@message}
        <% end %>
      </p>
      
      <%= if @search_query != "" do %>
        <div class="mt-6">
          <.link
            patch="/collections"
            class="inline-flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-500"
          >
            Clear Search
          </.link>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Custom pagination component for frontend views (renamed from the original pagination).
  """
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :search_query, :string, default: ""
  attr :filter_unit_id, :string, default: "all"
  attr :filter_status, :string, default: "published"
  attr :socket, :map, default: nil

  def frontend_pagination(assigns) do
    ~H"""
    <div class="flex items-center justify-between border-t border-voile-light bg-white dark:bg-gray-700 px-4 py-3 sm:px-6 rounded-lg">
      <div class="flex flex-1 justify-between sm:hidden">
        <%= if @current_page > 1 do %>
          <.link
            patch={build_page_url(@current_page - 1, @search_query, @filter_unit_id, @filter_status)}
            class="relative inline-flex items-center rounded-md border border-voile-muted bg-white px-4 py-2 text-sm font-medium text-voile hover:bg-voile-surface"
          >
            Previous
          </.link>
        <% end %>
        
        <%= if @current_page < @total_pages do %>
          <.link
            patch={build_page_url(@current_page + 1, @search_query, @filter_unit_id, @filter_status)}
            class="relative ml-3 inline-flex items-center rounded-md border border-voile-muted bg-white px-4 py-2 text-sm font-medium text-voile dark:bg-voile-neutral-dark dark:text-voile-surface dark:hover:bg-voile-surface-dark hover:bg-voile-surface"
          >
            Next
          </.link>
        <% end %>
      </div>
      
      <div class="hidden sm:flex sm:flex-1 sm:items-center sm:justify-between">
        <div>
          <p class="text-sm text-gray-700 dark:text-gray-300">
            Showing page <span class="font-medium">{@current_page}</span>
            of <span class="font-medium">{@total_pages}</span>
          </p>
        </div>
        
        <div>
          <nav class="isolate inline-flex -space-x-px rounded-md shadow-sm" aria-label="Pagination">
            <%= if @current_page > 1 do %>
              <.link
                patch={
                  build_page_url(@current_page - 1, @search_query, @filter_unit_id, @filter_status)
                }
                class="relative inline-flex items-center rounded-l-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0"
              >
                <.icon name="hero-chevron-left" class="h-5 w-5" />
              </.link>
            <% end %>
            
            <%= for page <- frontend_pagination_pages(@current_page, @total_pages) do %>
              <%= if page == :ellipsis do %>
                <span class="relative inline-flex items-center px-4 py-2 text-sm font-semibold text-gray-700 dark:text-gray-300 ring-1 ring-inset ring-gray-300 focus:outline-offset-0">
                  ...
                </span>
              <% else %>
                <.link
                  patch={build_page_url(page, @search_query, @filter_unit_id, @filter_status)}
                  class={[
                    "relative inline-flex items-center px-4 py-2 text-sm font-semibold focus:z-20 focus:outline-offset-0",
                    if(page == @current_page,
                      do:
                        "z-10 bg-blue-600 text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600 ring-1 ring-inset ring-gray-300",
                      else:
                        "text-gray-900 dark:text-gray-300 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-offset-0"
                    )
                  ]}
                >
                  {page}
                </.link>
              <% end %>
            <% end %>
            
            <%= if @current_page < @total_pages do %>
              <.link
                patch={
                  build_page_url(@current_page + 1, @search_query, @filter_unit_id, @filter_status)
                }
                class="relative inline-flex items-center rounded-r-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0"
              >
                <.icon name="hero-chevron-right" class="h-5 w-5" />
              </.link>
            <% end %>
          </nav>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for components

  @doc """
  GLAM type filter component for search results
  """
  attr :current_glam_type, :string, default: "quick"
  attr :search_query, :string, default: ""
  attr :counts, :map, default: %{}

  def glam_type_filter(assigns) do
    assigns = assign_glam_tabs(assigns)

    ~H"""
    <div class="flex flex-wrap gap-2 mb-4">
      <%= for tab <- @glam_tabs do %>
        <.link
          patch={build_search_url(tab.type, @search_query)}
          class={[
            "inline-flex items-center px-3 py-1.5 text-sm font-medium rounded-full transition-colors",
            if(@current_glam_type == tab.type,
              do: "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200",
              else:
                "bg-gray-100 text-gray-700 hover:bg-gray-200 dark:bg-gray-800 dark:text-gray-300 dark:hover:bg-gray-700"
            )
          ]}
        >
          <.icon name={tab.icon} class="w-4 h-4 mr-1.5" /> {tab.label}
          <%= if Map.get(@counts, tab.type, 0) > 0 do %>
            <span class="ml-1.5 bg-gray-200 dark:bg-gray-600 text-gray-800 dark:text-gray-200 text-xs px-1.5 py-0.5 rounded-full">
              {Map.get(@counts, tab.type, 0)}
            </span>
          <% end %>
        </.link>
      <% end %>
    </div>
    """
  end

  @doc """
  GLAM type badge component
  """
  attr :glam_type, :string, required: true
  attr :size, :string, default: "sm"

  def glam_type_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center font-medium rounded-full",
      glam_type_badge_class(@glam_type),
      case @size do
        "xs" -> "px-2 py-0.5 text-xs"
        "sm" -> "px-2.5 py-0.5 text-xs"
        "md" -> "px-3 py-1 text-sm"
        "lg" -> "px-4 py-1.5 text-sm"
      end
    ]}>
      <.icon name={glam_type_icon(@glam_type)} class="w-3 h-3 mr-1" /> {@glam_type}
    </span>
    """
  end

  @doc """
  Collection card with GLAM type support
  """
  attr :collection, :map, required: true
  attr :show_glam_type, :boolean, default: true

  def glam_collection_card(assigns) do
    ~H"""
    <div class="bg-white dark:bg-voile-neutral-dark rounded-lg shadow-sm border border-voile-muted dark:border-voile-dark hover:shadow-md transition-shadow">
      <div class="p-6">
        <!-- Thumbnail -->
        <div class="mb-4">
          <%= if @collection.thumbnail do %>
            <img
              src={@collection.thumbnail}
              class="w-full h-40 object-cover rounded-lg"
              alt={@collection.title}
            />
          <% else %>
            <div class="w-full h-40 bg-gray-200 dark:bg-gray-600 rounded-lg flex items-center justify-center">
              <%= if @collection.resource_class do %>
                <.icon
                  name={glam_type_icon(@collection.resource_class.glam_type)}
                  class="w-8 h-8 text-gray-400"
                />
              <% else %>
                <.icon name="hero-book-open" class="w-8 h-8 text-gray-400" />
              <% end %>
            </div>
          <% end %>
        </div>
        <!-- Content -->
        <div class="flex-1">
          <!-- GLAM Type Badge -->
          <%= if @show_glam_type and @collection.resource_class do %>
            <div class="mb-2">
              <.glam_type_badge glam_type={@collection.resource_class.glam_type} />
            </div>
          <% end %>
          
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2 line-clamp-2">
            {@collection.title}
          </h3>
          
          <%= if @collection.description do %>
            <p class="text-sm text-gray-600 dark:text-gray-300 mb-3 line-clamp-2">
              {@collection.description}
            </p>
          <% end %>
          <!-- Resource Class Information -->
          <%= if @collection.resource_class do %>
            <div class="mb-3">
              <p class="text-xs text-gray-500 dark:text-gray-400">
                <span class="font-medium">{@collection.resource_class.label}</span>
                <%= if @collection.resource_class.information do %>
                  - {@collection.resource_class.information}
                <% end %>
              </p>
            </div>
          <% end %>
          <!-- Metadata -->
          <div class="space-y-2 text-xs text-gray-500 dark:text-gray-400">
            <%= if @collection.mst_creator do %>
              <div class="flex items-center gap-1">
                <.icon name="hero-user" class="w-3 h-3" />
                <span>{@collection.mst_creator.creator_name}</span>
              </div>
            <% end %>
            
            <%= if length(@collection.items || []) > 0 do %>
              <div class="flex items-center gap-1">
                <.icon name="hero-document-duplicate" class="w-3 h-3" />
                <span>{length(@collection.items)} items</span>
              </div>
            <% end %>
          </div>
        </div>
        <!-- Status Badge -->
        <div class="mt-4 flex justify-between items-center">
          <span class={"px-2 py-1 text-xs rounded-full #{status_badge_class(@collection.status)}"}>
            {String.capitalize(@collection.status || "Unknown")}
          </span>
          <.link
            navigate={"/collections/#{@collection.id}"}
            class="text-sm font-medium text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
          >
            View Details →
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp assign_glam_tabs(assigns) do
    glam_tabs = [
      %{
        type: "quick",
        label: "All Collections",
        icon: "hero-magnifying-glass",
        placeholder: "Search across all collections...",
        index: 1
      },
      %{
        type: "Gallery",
        label: "Gallery",
        icon: "hero-photo",
        placeholder: "Find visual arts, images, and exhibitions...",
        index: 2
      },
      %{
        type: "Library",
        label: "Library",
        icon: "hero-book-open",
        placeholder: "Search books, articles, and publications...",
        index: 3
      },
      %{
        type: "Archive",
        label: "Archive",
        icon: "hero-archive-box",
        placeholder: "Explore historical documents and records...",
        index: 4
      },
      %{
        type: "Museum",
        label: "Museum",
        icon: "hero-building-library",
        placeholder: "Discover artifacts and physical objects...",
        index: 5
      }
    ]

    assign(assigns, :glam_tabs, glam_tabs)
  end

  defp get_search_placeholder("quick"), do: "Search across all collections..."
  defp get_search_placeholder("Gallery"), do: "Find visual arts, images, and exhibitions..."
  defp get_search_placeholder("Library"), do: "Search books, articles, and publications..."
  defp get_search_placeholder("Archive"), do: "Explore historical documents and records..."
  defp get_search_placeholder("Museum"), do: "Discover artifacts and physical objects..."
  defp get_search_placeholder(_), do: "Search what you need here..."

  defp get_glam_type_name("Gallery"), do: "Gallery"
  defp get_glam_type_name("Library"), do: "Library"
  defp get_glam_type_name("Archive"), do: "Archive"
  defp get_glam_type_name("Museum"), do: "Museum"
  defp get_glam_type_name("quick"), do: "All"
  defp get_glam_type_name(_), do: "All"

  @doc """
  Builds a search URL with GLAM type and query parameters
  """
  def build_search_url(glam_type \\ "quick", query \\ "", additional_params \\ %{}) do
    base_params = %{
      "glam_type" => glam_type,
      "q" => query
    }

    params =
      base_params
      |> Map.merge(additional_params)
      |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)
      |> Enum.into(%{})

    case Enum.empty?(params) do
      true -> "/search"
      false -> "/search?" <> URI.encode_query(params)
    end
  end

  @doc """
  Returns the appropriate icon for a GLAM type
  """
  def glam_type_icon("Gallery"), do: "hero-photo"
  def glam_type_icon("Library"), do: "hero-book-open"
  def glam_type_icon("Archive"), do: "hero-archive-box"
  def glam_type_icon("Museum"), do: "hero-building-library"
  def glam_type_icon(_), do: "hero-magnifying-glass"

  @doc """
  Returns a human-readable description for each GLAM type
  """
  def glam_type_description("Gallery"), do: "Visual arts, photographs, and artistic collections"
  def glam_type_description("Library"), do: "Books, journals, articles, and published materials"

  def glam_type_description("Archive"),
    do: "Historical documents, records, and institutional materials"

  def glam_type_description("Museum"), do: "Physical artifacts, specimens, and cultural objects"
  def glam_type_description("quick"), do: "Search across all collection types"
  def glam_type_description(_), do: "Mixed collection types"

  def glam_type_badge_class("Gallery"),
    do: "bg-pink-100 text-pink-800 dark:bg-pink-900 dark:text-pink-300"

  def glam_type_badge_class("Library"),
    do: "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"

  def glam_type_badge_class("Archive"),
    do: "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-300"

  def glam_type_badge_class("Museum"),
    do: "bg-emerald-100 text-emerald-800 dark:bg-emerald-900 dark:text-emerald-300"

  def glam_type_badge_class(_),
    do: "bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-300"

  def status_badge_class("published"),
    do: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300"

  def status_badge_class("draft"),
    do: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300"

  def status_badge_class("archived"),
    do: "bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-300"

  def status_badge_class(_), do: "bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-300"

  def access_level_badge_class("public"),
    do: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300"

  def access_level_badge_class("restricted"),
    do: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300"

  def access_level_badge_class("private"),
    do: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300"

  def access_level_badge_class(_),
    do: "bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-300"

  def availability_badge_class("available"),
    do: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300"

  def availability_badge_class("loaned"),
    do: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300"

  def availability_badge_class("reserved"),
    do: "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"

  def availability_badge_class("maintenance"),
    do: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300"

  def availability_badge_class(_),
    do: "bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-300"

  def condition_badge_class("excellent"),
    do: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300"

  def condition_badge_class("good"),
    do: "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"

  def condition_badge_class("fair"),
    do: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300"

  def condition_badge_class("poor"),
    do: "bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-300"

  def condition_badge_class("damaged"),
    do: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300"

  def condition_badge_class(_),
    do: "bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-300"

  def build_page_url(page, search_query, filter_unit_id, filter_status) do
    params =
      %{
        "q" => search_query,
        "unit_id" => filter_unit_id,
        "status" => filter_status,
        "page" => page
      }
      |> Enum.reject(fn {_k, v} -> v == "" or v == "all" end)
      |> Enum.into(%{})

    "/collections?" <> URI.encode_query(params)
  end

  def frontend_pagination_pages(_current_page, total_pages) when total_pages <= 7 do
    1..total_pages |> Enum.to_list()
  end

  def frontend_pagination_pages(current_page, total_pages) do
    cond do
      current_page <= 4 ->
        [1, 2, 3, 4, 5] ++ [:ellipsis] ++ [total_pages]

      current_page >= total_pages - 3 ->
        [1] ++ [:ellipsis] ++ Enum.to_list((total_pages - 4)..total_pages)

      true ->
        [1] ++
          [:ellipsis] ++
          Enum.to_list((current_page - 1)..(current_page + 1)) ++
          [:ellipsis] ++ [total_pages]
    end
    |> Enum.reject(&(&1 == :ellipsis))
  end

  # Helper functions for styling badges
  def availability_badge("available"), do: "bg-green-100 text-green-800"
  def availability_badge("loaned"), do: "bg-yellow-100 text-yellow-800"
  def availability_badge("reserved"), do: "bg-blue-100 text-blue-800"
  def availability_badge("maintenance"), do: "bg-red-100 text-red-800"
  def availability_badge(_), do: "bg-gray-100 text-gray-800"

  def condition_badge("excellent"), do: "bg-green-100 text-green-800"
  def condition_badge("good"), do: "bg-blue-100 text-blue-800"
  def condition_badge("fair"), do: "bg-yellow-100 text-yellow-800"
  def condition_badge("poor"), do: "bg-orange-100 text-orange-800"
  def condition_badge("damaged"), do: "bg-red-100 text-red-800"
  def condition_badge(_), do: "bg-gray-100 text-gray-800"
end
