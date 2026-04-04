defmodule VoileWeb.Dashboard.Catalog.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog

  # A small list of Tailwind color classes to pick from
  @node_colors [
    "from-blue-400 to-blue-600",
    "from-green-400 to-green-600",
    "from-indigo-400 to-indigo-600",
    "from-purple-400 to-purple-600",
    "from-pink-400 to-pink-600",
    "from-yellow-400 to-yellow-600",
    "from-red-400 to-red-600",
    "from-teal-400 to-teal-600"
  ]

  defp pick_node_color(id) do
    # phash2 returns 0..(range-1), so safe to use with Enum.at
    idx = :erlang.phash2(id, length(@node_colors))
    Enum.at(@node_colors, idx)
  end

  defp collection_status_class("published"),
    do: "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300"

  defp collection_status_class("pending"),
    do: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/40 dark:text-yellow-300"

  defp collection_status_class("draft"),
    do: "bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300"

  defp collection_status_class("archived"),
    do: "bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300"

  defp collection_status_class(_),
    do: "bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400"

  defp item_availability_class("available"),
    do: "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300"

  defp item_availability_class("loaned"),
    do: "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300"

  defp item_availability_class("reserved"),
    do: "bg-indigo-100 text-indigo-800 dark:bg-indigo-900/40 dark:text-indigo-300"

  defp item_availability_class("missing"),
    do: "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300"

  defp item_availability_class("in_processing"),
    do: "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-300"

  defp item_availability_class("maintenance"),
    do: "bg-orange-100 text-orange-800 dark:bg-orange-900/40 dark:text-orange-300"

  defp item_availability_class("conservation"),
    do: "bg-teal-100 text-teal-800 dark:bg-teal-900/40 dark:text-teal-300"

  defp item_availability_class("exhibition"),
    do: "bg-pink-100 text-pink-800 dark:bg-pink-900/40 dark:text-pink-300"

  defp item_availability_class("restricted"),
    do: "bg-red-200 text-red-900 dark:bg-red-900/60 dark:text-red-200"

  defp item_availability_class("in_transit"),
    do: "bg-cyan-100 text-cyan-800 dark:bg-cyan-900/40 dark:text-cyan-300"

  defp item_availability_class("quarantine"),
    do: "bg-orange-200 text-orange-900 dark:bg-orange-900/60 dark:text-orange-200"

  defp item_availability_class("reference_only"),
    do: "bg-purple-100 text-purple-800 dark:bg-purple-900/40 dark:text-purple-300"

  defp item_availability_class("non_circulating"),
    do: "bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300"

  defp item_availability_class(_),
    do: "bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400"

  def render(assigns) do
    ~H"""
    <section class="flex flex-col gap-4">
      <div class="flex flex-col gap-4 p-4 rounded-lg shadow-md bg-white dark:bg-gray-800">
        <h1 class="text-2xl font-bold">{gettext("Catalog")}</h1>

        <div class="w-full">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div class="rounded-lg p-4 bg-gray-50 dark:bg-gray-700 shadow flex items-center gap-4">
              <div class="p-3 rounded-md bg-blue-50 dark:bg-blue-900/30">
                <!-- GLAM icon small -->
                <svg
                  class="h-6 w-6 text-blue-600 dark:text-blue-300"
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                >
                  <path d="M3 10l9-6 9 6" stroke-linecap="round" stroke-linejoin="round" />
                  <path
                    d="M5 10v6M9 10v6M13 10v6M17 10v6"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  /> <path d="M3 18h18" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
              </div>

              <div class="flex-1">
                <div class="text-sm text-gray-500 dark:text-gray-300 font-semibold">
                  {gettext("Total Collections")}
                </div>

                <div class="mt-1 flex items-center gap-3">
                  <div class="text-2xl font-bold text-gray-800 dark:text-gray-100">
                    <%= if is_nil(@count_collections) do %>
                      <span class="inline-flex items-center gap-2">
                        <svg
                          class="animate-spin h-5 w-5 text-blue-600 dark:text-blue-300"
                          xmlns="http://www.w3.org/2000/svg"
                          viewBox="0 0 24 24"
                          fill="none"
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
                        <span class="text-sm text-gray-500 dark:text-gray-300">
                          {gettext("Loading")}
                        </span>
                      </span>
                    <% else %>
                      {@count_collections}
                    <% end %>
                  </div>

                  <div class="text-xs text-gray-500 dark:text-gray-400">
                    {gettext("collections across nodes")}
                  </div>
                </div>
                <%!-- Collection status breakdown --%>
                <%= if !is_nil(@collection_status_counts) do %>
                  <div class="mt-2 flex flex-wrap gap-1">
                    <%= for {status, cnt} <- [
                      {"published", Map.get(@collection_status_counts, "published", 0)},
                      {"pending", Map.get(@collection_status_counts, "pending", 0)},
                      {"draft", Map.get(@collection_status_counts, "draft", 0)},
                      {"archived", Map.get(@collection_status_counts, "archived", 0)}
                    ], cnt > 0 do %>
                      <span class={[
                        "px-2 py-0.5 rounded text-xs font-medium",
                        collection_status_class(status)
                      ]}>
                        {String.capitalize(status)}: {cnt}
                      </span>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>

            <div class="rounded-lg p-4 bg-gray-50 dark:bg-gray-700 shadow flex items-center gap-4">
              <div class="p-3 rounded-md bg-green-50 dark:bg-green-900/30">
                <!-- gallery small icon -->
                <svg
                  class="h-6 w-6 text-green-600 dark:text-green-300"
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                >
                  <rect x="3" y="4" width="18" height="16" rx="2" ry="2" class="fill-none" />
                  <path d="M7 15l3-4 4 5 3-4" stroke-linecap="round" stroke-linejoin="round" />
                  <circle cx="17" cy="8" r="1.5" />
                </svg>
              </div>

              <div class="flex-1">
                <div class="text-sm text-gray-500 dark:text-gray-300 font-semibold">
                  {gettext("Items")}
                </div>

                <div class="mt-1 flex items-center gap-3">
                  <div class="text-2xl font-bold text-gray-800 dark:text-gray-100">
                    <%= if is_nil(@count_items) do %>
                      <span class="inline-flex items-center gap-2">
                        <svg
                          class="animate-spin h-5 w-5 text-green-600 dark:text-green-300"
                          xmlns="http://www.w3.org/2000/svg"
                          viewBox="0 0 24 24"
                          fill="none"
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
                        <span class="text-sm text-gray-500 dark:text-gray-300">
                          {gettext("Loading")}
                        </span>
                      </span>
                    <% else %>
                      {@count_items}
                    <% end %>
                  </div>

                  <div class="text-xs text-gray-500 dark:text-gray-400">
                    {gettext("items across nodes")}
                  </div>
                </div>
                <%!-- Item availability breakdown --%>
                <%= if !is_nil(@item_availability_counts) do %>
                  <div class="mt-2 flex flex-wrap gap-1">
                    <%= for {avail, cnt} <- Enum.sort(@item_availability_counts), cnt > 0 do %>
                      <span class={[
                        "px-2 py-0.5 rounded text-xs font-medium",
                        item_availability_class(avail)
                      ]}>
                        {avail
                        |> String.split("_")
                        |> Enum.map(&String.capitalize/1)
                        |> Enum.join(" ")}: {cnt}
                      </span>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
        <hr class="my-4 text-gray-200 dark:text-gray-700" />
        <div class="w-full">
          <h3 class="text-lg font-semibold mb-2">{gettext("Per Node Statistics")}</h3>

          <%= if @count_all_nodes == [] do %>
            <div class="flex items-center justify-center p-4">
              <svg
                class="animate-spin h-8 w-8 text-gray-600 dark:text-gray-300"
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
              <span class="ml-2 text-gray-600 dark:text-gray-300">{gettext("Loading nodes...")}</span>
            </div>
          <% else %>
            <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
              <%= for node <- @count_all_nodes do %>
                <div class="rounded-lg overflow-hidden shadow hover:shadow-lg transform hover:-translate-y-1 transition-all bg-white dark:bg-gray-400">
                  <div class={"px-4 py-3 bg-gradient-to-r " <> node.color}>
                    <h4 class="text-sm font-medium text-white truncate">{node.name}</h4>
                  </div>

                  <div class="p-4 space-y-3 bg-white dark:bg-gray-600">
                    <%!-- Collections stat --%>
                    <div>
                      <div class="flex items-center justify-between gap-2">
                        <div class="flex items-center gap-2">
                          <div class="p-1.5 rounded-md bg-gray-100 dark:bg-gray-900">
                            <svg
                              class="h-4 w-4 text-gray-600 dark:text-gray-300"
                              xmlns="http://www.w3.org/2000/svg"
                              viewBox="0 0 24 24"
                              fill="none"
                              stroke="currentColor"
                              stroke-width="1.5"
                            >
                              <path d="M3 10l9-6 9 6" stroke-linecap="round" stroke-linejoin="round" />
                              <path
                                d="M5 10v6M9 10v6M13 10v6M17 10v6"
                                stroke-linecap="round"
                                stroke-linejoin="round"
                              /> <path d="M3 18h18" stroke-linecap="round" stroke-linejoin="round" />
                            </svg>
                          </div>
                          <span class="text-xs font-medium text-gray-500 dark:text-gray-300">
                            {gettext("Collections")}
                          </span>
                        </div>
                        <div class="text-lg font-semibold text-gray-800 dark:text-gray-100">
                          <%= if is_nil(node.count_collections) do %>
                            <svg
                              class="animate-spin h-4 w-4 text-gray-400"
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
                          <% else %>
                            {node.count_collections}
                          <% end %>
                        </div>
                      </div>
                      <%= if !is_nil(node.collection_status_counts) do %>
                        <div class="mt-1 flex flex-wrap gap-1">
                          <%= for {status, cnt} <- [
                            {"published", Map.get(node.collection_status_counts, "published", 0)},
                            {"pending", Map.get(node.collection_status_counts, "pending", 0)},
                            {"draft", Map.get(node.collection_status_counts, "draft", 0)},
                            {"archived", Map.get(node.collection_status_counts, "archived", 0)}
                          ], cnt > 0 do %>
                            <span class={[
                              "px-1.5 py-0.5 rounded text-xs font-medium",
                              collection_status_class(status)
                            ]}>
                              {String.capitalize(status)}: {cnt}
                            </span>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                    <div class="border-t border-gray-100 dark:border-gray-500"></div>
                    <%!-- Items stat --%>
                    <div>
                      <div class="flex items-center justify-between gap-2">
                        <div class="flex items-center gap-2">
                          <div class="p-1.5 rounded-md bg-gray-100 dark:bg-gray-900">
                            <svg
                              class="h-4 w-4 text-gray-600 dark:text-gray-300"
                              xmlns="http://www.w3.org/2000/svg"
                              viewBox="0 0 24 24"
                              fill="none"
                              stroke="currentColor"
                              stroke-width="1.5"
                            >
                              <rect
                                x="3"
                                y="4"
                                width="18"
                                height="16"
                                rx="2"
                                ry="2"
                                class="fill-none"
                              />
                              <path
                                d="M7 15l3-4 4 5 3-4"
                                stroke-linecap="round"
                                stroke-linejoin="round"
                              />
                              <circle cx="17" cy="8" r="1.5" />
                            </svg>
                          </div>
                          <span class="text-xs font-medium text-gray-500 dark:text-gray-300">
                            {gettext("Items")}
                          </span>
                        </div>
                        <div class="text-lg font-semibold text-gray-800 dark:text-gray-100">
                          <%= if is_nil(node.count_items) do %>
                            <svg
                              class="animate-spin h-4 w-4 text-gray-400"
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
                          <% else %>
                            {node.count_items}
                          <% end %>
                        </div>
                      </div>
                      <%= if !is_nil(node.item_availability_counts) do %>
                        <div class="mt-1 flex flex-wrap gap-1">
                          <%= for {avail, cnt} <- Enum.sort(node.item_availability_counts), cnt > 0 do %>
                            <span class={[
                              "px-1.5 py-0.5 rounded text-xs font-medium",
                              item_availability_class(avail)
                            ]}>
                              {avail
                              |> String.split("_")
                              |> Enum.map(&String.capitalize/1)
                              |> Enum.join(" ")}: {cnt}
                            </span>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  def mount(_params, _session, socket) do
    # Initially assign nils so template shows spinners/placeholders
    socket =
      socket
      |> assign(:count_collections, nil)
      |> assign(:count_items, nil)
      |> assign(:collection_status_counts, nil)
      |> assign(:item_availability_counts, nil)
      |> assign(:count_all_nodes, [])
      |> assign(:page_title, gettext("Catalog Dashboard"))

    # Defer loading counts to handle_info so UI mounts fast
    if connected?(socket), do: send(self(), :load_counts)

    {:ok, socket}
  end

  def handle_info(:load_counts, socket) do
    count_collections = Catalog.count_collections()
    count_items = Catalog.count_items()
    collection_status_counts = Catalog.count_collections_by_status()
    item_availability_counts = Catalog.count_items_by_availability()
    get_nodes = Voile.Schema.System.list_nodes()

    # Prepare nodes with deterministic color and nil counts initially,
    # then populate counts so UI shows spinners first per node.
    count_all_nodes =
      Enum.map(get_nodes, fn node ->
        color = pick_node_color(node.id)

        %{
          id: node.id,
          name: node.name,
          color: color,
          count_collections: nil,
          count_items: nil,
          collection_status_counts: nil,
          item_availability_counts: nil
        }
      end)

    # Assign the placeholder nodes first so the template can render spinners per node,
    # then fetch counts and update the assigns.
    socket = assign(socket, :count_all_nodes, count_all_nodes)

    # Fetch counts for nodes and update entries (synchronously here; can be async later)
    count_all_nodes =
      Enum.map(count_all_nodes, fn node ->
        node
        |> Map.put(:count_collections, Catalog.count_collections(node.id))
        |> Map.put(:count_items, Catalog.count_items(node.id))
        |> Map.put(:collection_status_counts, Catalog.count_collections_by_status(node.id))
        |> Map.put(:item_availability_counts, Catalog.count_items_by_availability(node.id))
      end)

    socket =
      socket
      |> assign(:count_collections, count_collections)
      |> assign(:count_items, count_items)
      |> assign(:collection_status_counts, collection_status_counts)
      |> assign(:item_availability_counts, item_availability_counts)
      |> assign(:count_all_nodes, count_all_nodes)

    {:noreply, socket}
  end
end
