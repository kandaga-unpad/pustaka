defmodule VoileWeb.SearchExampleLive do
  @moduledoc """
  Example LiveView showing how to use the enhanced main_search component
  with immediate feedback and autocomplete functionality.
  """
  use VoileWeb, :live_view

  alias VoileWeb.VoileComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search_query, "")
     |> assign(:current_glam_type, "quick")
     |> assign(:search_results, [])
     |> assign(:show_suggestions, false)
     |> assign(:loading, false)
     |> assign(:selected_index, -1)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    search_query = Map.get(params, "q", "")
    glam_type = Map.get(params, "glam_type", "quick")

    {:noreply,
     socket
     |> assign(:search_query, search_query)
     |> assign(:current_glam_type, glam_type)
     |> maybe_perform_search(search_query, glam_type)}
  end

  @impl true
  def handle_event("search_change", %{"q" => query, "glam_type" => glam_type}, socket) do
    # Simulate search with debounce
    if String.length(query) >= 2 do
      send(self(), {:perform_autocomplete, query, glam_type})

      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:current_glam_type, glam_type)
       |> assign(:loading, true)
       |> assign(:show_suggestions, true)}
    else
      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:current_glam_type, glam_type)
       |> assign(:search_results, [])
       |> assign(:show_suggestions, false)
       |> assign(:loading, false)}
    end
  end

  @impl true
  def handle_event("search", %{"q" => query, "glam_type" => glam_type}, socket) do
    # Perform full search and redirect
    {:noreply, push_navigate(socket, to: "/search?q=#{query}&glam_type=#{glam_type}")}
  end

  @impl true
  def handle_event("perform_search", %{"query" => query, "glam_type" => glam_type}, socket) do
    # Perform full search and redirect
    {:noreply, push_navigate(socket, to: "/search?q=#{query}&glam_type=#{glam_type}")}
  end

  @impl true
  def handle_event("select_collection", %{"id" => collection_id}, socket) do
    # Navigate to collection detail
    {:noreply, push_navigate(socket, to: "/collections/#{collection_id}")}
  end

  @impl true
  def handle_event("show_suggestions", _params, socket) do
    {:noreply, assign(socket, :show_suggestions, true)}
  end

  @impl true
  def handle_event("hide_suggestions", _params, socket) do
    # Small delay to allow for click events
    Process.send_after(self(), :hide_suggestions_delayed, 150)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:perform_autocomplete, query, glam_type}, socket) do
    # Simulate database search - replace with actual search logic
    results = search_collections(query, glam_type)

    {:noreply,
     socket
     |> assign(:search_results, results)
     |> assign(:loading, false)
     |> assign(:show_suggestions, true)}
  end

  @impl true
  def handle_info(:hide_suggestions_delayed, socket) do
    {:noreply, assign(socket, :show_suggestions, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900 dark:text-white mb-4">Enhanced Search Example</h1>
        
        <p class="text-gray-600 dark:text-gray-400 mb-6">
          This demonstrates the enhanced search component with immediate feedback and autocomplete.
          Start typing to see suggestions appear automatically.
        </p>
        <!-- Enhanced Search Component -->
        <VoileComponents.main_search
          current_glam_type={@current_glam_type}
          search_query={@search_query}
          search_results={@search_results}
          show_suggestions={@show_suggestions}
          loading={@loading}
          live_action={@live_action}
        />
      </div>
      <!-- Search Results Display -->
      <%= if @search_query != "" and not @show_suggestions do %>
        <div class="mt-8">
          <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">
            Search Results for "{@search_query}"
          </h2>
          
          <%= if length(@search_results) > 0 do %>
            <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              <%= for collection <- @search_results do %>
                <VoileComponents.glam_collection_card collection={collection} />
              <% end %>
            </div>
          <% else %>
            <VoileComponents.empty_state
              search_query={@search_query}
              title="No collections found"
              message="Try adjusting your search terms or selecting a different GLAM type."
            />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Private functions

  defp maybe_perform_search(socket, "", _glam_type), do: socket

  defp maybe_perform_search(socket, query, glam_type) do
    results = search_collections(query, glam_type)
    assign(socket, :search_results, results)
  end

  # Mock search function - replace with actual database queries
  defp search_collections(query, glam_type) do
    # Simulate API delay
    Process.sleep(200)

    # Mock data - replace with actual Ecto queries
    mock_collections = [
      %{
        id: 1,
        title: "Medieval Manuscripts Collection",
        description:
          "A comprehensive collection of medieval manuscripts from the 12th to 15th centuries.",
        status: "published",
        thumbnail: nil,
        resource_class: %{
          glam_type: "Library",
          label: "Manuscript",
          information: "Historical manuscripts"
        },
        mst_creator: %{name: "Dr. Sarah Johnson"},
        # 3 items
        items: [%{}, %{}, %{}]
      },
      %{
        id: 2,
        title: "Renaissance Art Gallery",
        description: "Paintings and sculptures from the Renaissance period.",
        status: "published",
        thumbnail: nil,
        resource_class: %{
          glam_type: "Gallery",
          label: "Artwork",
          information: "Renaissance artworks"
        },
        mst_creator: %{name: "Prof. Michael Brown"},
        # 2 items
        items: [%{}, %{}]
      },
      %{
        id: 3,
        title: "Historical Documents Archive",
        description: "Important historical documents and government records.",
        status: "published",
        thumbnail: nil,
        resource_class: %{
          glam_type: "Archive",
          label: "Document",
          information: "Historical documents"
        },
        mst_creator: %{name: "City Archives"},
        # 4 items
        items: [%{}, %{}, %{}, %{}]
      }
    ]

    # Filter by GLAM type if specified
    filtered_collections =
      if glam_type == "quick" do
        mock_collections
      else
        Enum.filter(mock_collections, fn collection ->
          collection.resource_class.glam_type == glam_type
        end)
      end

    # Filter by search query
    Enum.filter(filtered_collections, fn collection ->
      String.contains?(String.downcase(collection.title), String.downcase(query)) ||
        String.contains?(String.downcase(collection.description || ""), String.downcase(query))
    end)
  end
end
