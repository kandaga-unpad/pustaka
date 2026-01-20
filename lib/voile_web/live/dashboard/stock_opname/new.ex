defmodule VoileWeb.Dashboard.StockOpnameLive.New do
  use VoileWeb, :live_view_dashboard

  import Ecto.Query

  alias Voile.Schema.{System, StockOpname}
  alias Voile.Schema.StockOpname.Session
  alias VoileWeb.Auth.StockOpnameAuthorization

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-6 max-w-4xl">
      <div class="mb-6">
        <.link
          navigate={~p"/manage/stock_opname"}
          class="text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300 flex items-center gap-2 mb-4"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Sessions
        </.link>
        <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">
          Create Stock Opname Session
        </h1>

        <p class="text-gray-600 dark:text-gray-400 mt-2">
          Set up a new inventory checking session for your collections.
        </p>
      </div>

      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6">
        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6">
          <%!-- Title --%>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Title <span class="text-red-500 dark:text-red-400">*</span>
            </label>
            <.input
              field={@form[:title]}
              type="text"
              placeholder="e.g., January 2026 Annual Inventory"
              phx-debounce="300"
              required
            />
          </div>
          <%!-- Description --%>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Description
            </label>
            <.input
              field={@form[:description]}
              type="textarea"
              rows="3"
              placeholder="Brief description of this inventory session..."
              phx-debounce="300"
            />
          </div>
          <%!-- Node Selection --%>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Nodes/Locations <span class="text-red-500 dark:text-red-400">*</span>
            </label>
            <p class="text-xs text-gray-500 dark:text-gray-400 mb-2">
              Select one or more nodes to include in this session
            </p>

            <div class="border border-gray-300 dark:border-gray-600 rounded-lg p-4 max-h-48 overflow-y-auto space-y-2">
              <label
                :for={node <- @nodes}
                class="flex items-center gap-2 hover:bg-gray-50 dark:hover:bg-gray-700 p-2 rounded cursor-pointer"
              >
                <input
                  type="checkbox"
                  name="node_ids[]"
                  value={node.id}
                  checked={node.id in @selected_node_ids}
                  phx-click="toggle_node"
                  phx-value-id={node.id}
                  class="rounded border-gray-300 dark:border-gray-600 text-blue-600 focus:ring-blue-500 dark:bg-gray-700"
                />
                <span class="text-sm text-gray-700 dark:text-gray-300">
                  {node.name} ({node.abbr})
                </span>
              </label>
            </div>

            <p :if={@selected_node_ids == []} class="text-sm text-red-600 dark:text-red-400 mt-1">
              At least one node must be selected
            </p>
          </div>
          <%!-- Collection Types --%>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Collection Types <span class="text-red-500 dark:text-red-400">*</span>
            </label>
            <p class="text-xs text-gray-500 dark:text-gray-400 mb-2">
              Select collection types to include in this session
            </p>

            <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
              <label
                :for={{label, value} <- collection_type_options()}
                class="flex items-center gap-2 border border-gray-300 dark:border-gray-600 rounded-lg p-3 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer"
              >
                <input
                  type="checkbox"
                  name="collection_types[]"
                  value={value}
                  checked={value in @selected_collection_types}
                  phx-click="toggle_collection_type"
                  phx-value-type={value}
                  class="rounded border-gray-300 dark:border-gray-600 text-blue-600 focus:ring-blue-500 dark:bg-gray-700"
                /> <span class="text-sm text-gray-700 dark:text-gray-300">{label}</span>
              </label>
            </div>

            <p
              :if={@selected_collection_types == []}
              class="text-sm text-red-600 dark:text-red-400 mt-1"
            >
              At least one collection type must be selected
            </p>
          </div>
          <%!-- Scope Type --%>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Scope <span class="text-red-500 dark:text-red-400">*</span>
            </label>
            <div class="space-y-3">
              <label
                :for={{label, value} <- scope_type_options()}
                class="flex items-start gap-3 border border-gray-300 dark:border-gray-600 rounded-lg p-3 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer"
              >
                <input
                  type="radio"
                  name="scope_type"
                  value={value}
                  checked={@scope_type == value}
                  phx-click="change_scope_type"
                  phx-value-type={value}
                  class="mt-0.5 border-gray-300 dark:border-gray-600 text-blue-600 focus:ring-blue-500 dark:bg-gray-700"
                />
                <div>
                  <span class="text-sm font-medium text-gray-700 dark:text-gray-300">{label}</span>
                  <p class="text-xs text-gray-500 dark:text-gray-400">{scope_description(value)}</p>
                </div>
              </label>
            </div>
          </div>
          <%!-- Collection Selector (if scope is collection) --%>
          <div :if={@scope_type == "collection"}>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Select Collection <span class="text-red-500 dark:text-red-400">*</span>
            </label>
            <div class="relative">
              <.input
                field={@form[:scope_id]}
                type="text"
                placeholder="Search collection by title..."
                phx-keyup="search_collections"
                phx-debounce="300"
                autocomplete="off"
              />
              <div
                :if={@collection_search_results != []}
                class="absolute z-10 w-full mt-1 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg shadow-lg max-h-60 overflow-y-auto"
              >
                <button
                  :for={collection <- @collection_search_results}
                  type="button"
                  phx-click="select_collection"
                  phx-value-id={collection.id}
                  phx-value-title={collection.title}
                  class="w-full text-left px-4 py-2 hover:bg-gray-50 dark:hover:bg-gray-700 border-b border-gray-200 dark:border-gray-700 last:border-b-0"
                >
                  <p class="text-sm font-medium text-gray-900 dark:text-gray-100">
                    {collection.title}
                  </p>

                  <p class="text-xs text-gray-500 dark:text-gray-400">{collection.collection_code}</p>
                </button>
              </div>
            </div>

            <p :if={@selected_collection} class="text-sm text-green-600 dark:text-green-400 mt-1">
              Selected: {@selected_collection.title}
            </p>
          </div>
          <%!-- Location Selector (if scope is location) --%>
          <div :if={@scope_type == "location"}>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Select Location <span class="text-red-500 dark:text-red-400">*</span>
            </label>
            <select
              name="scope_id"
              class="w-full rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200"
              required={@scope_type == "location"}
            >
              <option value="">Choose a location...</option>

              <option :for={location <- @locations} value={location.id}>
                {location.location_name}
              </option>
            </select>
            <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
              Stock opname will only include items in this specific location
            </p>
          </div>
          <%!-- All Scope Info --%>
          <div
            :if={@scope_type == "all"}
            class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4"
          >
            <div class="flex items-center gap-2">
              <.icon name="hero-information-circle" class="w-5 h-5 text-blue-600 dark:text-blue-400" />
              <span class="text-sm font-medium text-blue-900 dark:text-blue-300">
                Full Node Coverage
              </span>
            </div>

            <p class="text-sm text-blue-700 dark:text-blue-400 mt-2">
              Stock opname will include all items in the selected nodes and collection types, without location restrictions.
            </p>
          </div>
          <%!-- Expected Item Count --%>
          <div
            :if={@estimated_items > 0}
            class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4"
          >
            <div class="flex items-center gap-2 mb-2">
              <.icon name="hero-information-circle" class="w-5 h-5 text-blue-600 dark:text-blue-400" />
              <span class="text-sm font-medium text-blue-900 dark:text-blue-300">
                Estimated Items
              </span>
            </div>

            <p class="text-2xl font-bold text-blue-600 dark:text-blue-400">{@estimated_items}</p>

            <p class="text-xs text-blue-700 dark:text-blue-400 mt-1">
              Based on selected nodes, collection types, and scope
            </p>
          </div>
          <%!-- Librarian Assignment --%>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Assign Librarians <span class="text-red-500 dark:text-red-400">*</span>
            </label>
            <p class="text-xs text-gray-500 dark:text-gray-400 mb-2">
              Select librarians who will check items in this session
            </p>

            <div class="border border-gray-300 dark:border-gray-600 rounded-lg p-4 max-h-48 overflow-y-auto space-y-2">
              <label
                :for={user <- @librarians}
                class="flex items-center gap-2 hover:bg-gray-50 dark:hover:bg-gray-700 p-2 rounded cursor-pointer"
              >
                <input
                  type="checkbox"
                  name="librarian_ids[]"
                  value={user.id}
                  checked={user.id in @selected_librarian_ids}
                  phx-click="toggle_librarian"
                  phx-value-id={user.id}
                  class="rounded border-gray-300 dark:border-gray-600 text-blue-600 focus:ring-blue-500 dark:bg-gray-700"
                />
                <div class="flex-1">
                  <span class="text-sm font-medium text-gray-700 dark:text-gray-300">
                    {user.fullname || user.email}
                  </span>
                  <p class="text-xs text-gray-500 dark:text-gray-400">{user.email}</p>
                </div>
              </label>
            </div>

            <p :if={@selected_librarian_ids == []} class="text-sm text-red-600 dark:text-red-400 mt-1">
              At least one librarian must be assigned
            </p>
          </div>
          <%!-- Notes --%>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Notes
            </label>
            <.input
              field={@form[:notes]}
              type="textarea"
              rows="3"
              placeholder="Additional notes or instructions for this session..."
              phx-debounce="300"
            />
          </div>
          <%!-- Actions --%>
          <div class="flex gap-3 pt-4 border-t border-gray-200 dark:border-gray-700">
            <button
              type="submit"
              disabled={!@can_submit}
              phx-disable-with="Creating..."
              class="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-300 dark:disabled:bg-gray-700 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors"
            >
              Create Session
            </button>
            <.link
              navigate={~p"/manage/stock_opname"}
              class="px-4 py-2 bg-gray-200 hover:bg-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 font-medium rounded-lg transition-colors"
            >
              Cancel
            </.link>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Verify permission
    case StockOpnameAuthorization.can_create_session?(current_user) do
      true ->
        all_nodes = System.list_nodes()
        # Filter nodes based on user permissions
        nodes =
          if VoileWeb.Auth.Authorization.is_super_admin?(current_user) do
            all_nodes
          else
            # Only show nodes the user belongs to
            Enum.filter(all_nodes, fn node -> node.id == current_user.node_id end)
          end

        librarians = list_librarians(current_user)
        locations = Voile.Schema.Master.list_mst_locations()

        changeset = Session.changeset(%Session{}, %{})

        socket =
          socket
          |> assign(:page_title, "New Stock Opname Session")
          |> assign(:current_user, current_user)
          |> assign(:form, to_form(changeset))
          |> assign(:nodes, nodes)
          |> assign(:librarians, librarians)
          |> assign(:locations, locations)
          |> assign(:selected_node_ids, [])
          |> assign(:selected_collection_types, [])
          |> assign(:selected_librarian_ids, [])
          |> assign(:scope_type, "all")
          |> assign(:selected_collection, nil)
          |> assign(:collection_search_results, [])
          |> assign(:estimated_items, 0)
          |> assign(:can_submit, false)

        {:ok, socket}

      false ->
        socket =
          socket
          |> put_flash(:error, "You don't have permission to create stock opname sessions.")
          |> redirect(to: ~p"/manage/stock_opname")

        {:ok, socket}
    end
  end

  def handle_event("toggle_node", %{"id" => id}, socket) do
    node_id = String.to_integer(id)
    selected = socket.assigns.selected_node_ids

    new_selected =
      if node_id in selected do
        List.delete(selected, node_id)
      else
        [node_id | selected]
      end

    socket =
      socket
      |> assign(:selected_node_ids, new_selected)
      |> update_estimated_items()
      |> update_submit_status()

    {:noreply, socket}
  end

  def handle_event("toggle_collection_type", %{"type" => type}, socket) do
    selected = socket.assigns.selected_collection_types

    new_selected =
      if type in selected do
        List.delete(selected, type)
      else
        [type | selected]
      end

    socket =
      socket
      |> assign(:selected_collection_types, new_selected)
      |> update_estimated_items()
      |> update_submit_status()

    {:noreply, socket}
  end

  def handle_event("toggle_librarian", %{"id" => id}, socket) do
    selected = socket.assigns.selected_librarian_ids

    new_selected =
      if id in selected do
        List.delete(selected, id)
      else
        [id | selected]
      end

    socket =
      socket
      |> assign(:selected_librarian_ids, new_selected)
      |> update_submit_status()

    {:noreply, socket}
  end

  def handle_event("change_scope_type", %{"type" => type}, socket) do
    socket =
      socket
      |> assign(:scope_type, type)
      |> assign(:selected_collection, nil)
      |> assign(:collection_search_results, [])
      |> update_estimated_items()
      |> update_submit_status()

    {:noreply, socket}
  end

  def handle_event("search_collections", %{"value" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        Voile.Schema.Catalog.search_potential_parent_collections(query, nil, 10)
      else
        []
      end

    {:noreply, assign(socket, :collection_search_results, results)}
  end

  def handle_event("select_collection", %{"id" => id, "title" => title}, socket) do
    socket =
      socket
      |> assign(:selected_collection, %{id: id, title: title})
      |> assign(:collection_search_results, [])
      |> update_estimated_items()
      |> update_submit_status()

    {:noreply, socket}
  end

  def handle_event("validate", params, socket) do
    changeset =
      %Session{}
      |> Session.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", params, socket) do
    require Logger
    attrs = build_session_attrs(params, socket.assigns)

    try do
      case StockOpname.create_session(attrs, socket.assigns.current_user) do
        {:ok, session} ->
          Logger.info("Session created: #{session.id}")

          # Assign librarians
          case StockOpname.assign_librarians(
                 session,
                 socket.assigns.selected_librarian_ids,
                 socket.assigns.current_user
               ) do
            {:ok, updated_session} ->
              Logger.info(
                "Librarians assigned successfully, navigating to session #{updated_session.id}"
              )

              {:noreply,
               socket
               |> put_flash(:info, "Stock opname session created successfully!")
               |> push_navigate(to: ~p"/manage/stock_opname/#{updated_session.id}")}

            {:error, :no_librarians_assigned} ->
              Logger.error("No librarians assigned error")
              {:noreply, put_flash(socket, :error, "At least one librarian must be assigned")}

            {:error, error} ->
              Logger.error("Failed to assign librarians: #{inspect(error)}")

              {:noreply,
               put_flash(socket, :error, "Failed to assign librarians: #{inspect(error)}")}
          end

        {:error, %Ecto.Changeset{} = changeset} ->
          Logger.error("Session creation failed: #{inspect(changeset.errors)}")

          socket =
            socket
            |> assign(:form, to_form(changeset))
            |> put_flash(:error, "Failed to create session. Please check the form for errors.")

          {:noreply, socket}

        {:error, error} ->
          Logger.error("Unexpected error creating session: #{inspect(error)}")
          {:noreply, put_flash(socket, :error, "An unexpected error occurred: #{inspect(error)}")}
      end
    rescue
      e ->
        Logger.error("Exception in save handler: #{inspect(e)}\n#{Exception.format_stacktrace()}")
        {:noreply, put_flash(socket, :error, "An unexpected error occurred: #{inspect(e)}")}
    end
  end

  defp build_session_attrs(params, assigns) do
    session_params = params["session"] || %{}

    scope_id =
      case assigns.scope_type do
        "collection" ->
          if assigns.selected_collection, do: assigns.selected_collection.id, else: nil

        "location" ->
          params["scope_id"]

        _ ->
          nil
      end

    %{
      "title" => session_params["title"],
      "description" => session_params["description"],
      "node_ids" => assigns.selected_node_ids,
      "collection_types" => assigns.selected_collection_types,
      "scope_type" => assigns.scope_type,
      "scope_id" => scope_id,
      "notes" => session_params["notes"]
    }
  end

  defp update_estimated_items(socket) do
    count = estimate_item_count(socket.assigns)
    assign(socket, :estimated_items, count)
  end

  defp estimate_item_count(assigns) do
    if assigns.selected_node_ids == [] or assigns.selected_collection_types == [] do
      0
    else
      # Query items based on selections
      query =
        from i in Voile.Schema.Catalog.Item,
          where: i.unit_id in ^assigns.selected_node_ids,
          join: c in Voile.Schema.Catalog.Collection,
          on: c.id == i.collection_id,
          join: rc in Voile.Schema.Metadata.ResourceClass,
          on: rc.id == c.type_id,
          where: rc.glam_type in ^assigns.selected_collection_types

      query =
        case assigns.scope_type do
          "collection" when not is_nil(assigns.selected_collection) ->
            from i in query, where: i.collection_id == ^assigns.selected_collection.id

          "location" when not is_nil(assigns.scope_id) ->
            from i in query, where: i.item_location_id == ^assigns.scope_id

          _ ->
            query
        end

      Voile.Repo.aggregate(query, :count, :id)
    end
  end

  defp update_submit_status(socket) do
    can_submit =
      socket.assigns.selected_node_ids != [] and
        socket.assigns.selected_collection_types != [] and
        socket.assigns.selected_librarian_ids != [] and
        scope_valid?(socket.assigns)

    assign(socket, :can_submit, can_submit)
  end

  defp scope_valid?(assigns) do
    case assigns.scope_type do
      "all" -> true
      "collection" -> not is_nil(assigns.selected_collection)
      "location" -> true
      _ -> false
    end
  end

  defp list_librarians(current_user) do
    # Get users with eligible roles for stock opname
    eligible_roles = [
      "super_admin",
      "admin",
      "editor",
      "librarian",
      "archivist",
      "gallery_curator",
      "museum_curator"
    ]

    # Fetch users for each role and merge, removing duplicates
    librarians =
      eligible_roles
      |> Enum.flat_map(fn role ->
        VoileWeb.Auth.PermissionManager.list_users_with_role_by_name(role)
      end)
      |> Enum.uniq_by(& &1.id)

    # Filter by node if not super admin
    if VoileWeb.Auth.Authorization.is_super_admin?(current_user) do
      librarians
    else
      # Only show librarians from the same node
      Enum.filter(librarians, fn librarian -> librarian.node_id == current_user.node_id end)
    end
    |> Enum.sort_by(&(&1.fullname || &1.email))
  end

  defp collection_type_options do
    [
      {"Gallery", "Gallery"},
      {"Archive", "Archive"},
      {"Museum", "Museum"},
      {"Library", "Library"}
    ]
  end

  defp scope_type_options do
    [
      {"All Items", "all"},
      {"Specific Collection", "collection"},
      {"Specific Location", "location"}
    ]
  end

  defp scope_description(type) do
    case type do
      "all" -> "Include all items in selected nodes and collection types"
      "collection" -> "Include only items from a specific collection"
      "location" -> "Include only items from a specific location"
      _ -> ""
    end
  end
end
