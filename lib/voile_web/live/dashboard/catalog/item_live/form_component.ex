defmodule VoileWeb.Dashboard.Catalog.ItemLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.System
  alias Voile.Schema.Master
  alias VoileWeb.Auth.GLAMAuthorization

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <.header>
        {@title}
        <:subtitle>{gettext("Use this form to manage item records in your database.")}</:subtitle>
      </.header>

      <div class="bg-white dark:bg-gray-800 p-6 rounded-lg shadow-sm">
        <.form
          for={@form}
          id="item-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
          class="space-y-6"
        >
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <!-- Collection (full row, read-only) -->
            <div class="col-span-full flex items-center gap-3">
              <.input field={@form[:collection_id]} type="hidden" />
              <label class="text-xs font-medium text-gray-700 dark:text-gray-300 w-32">
                {gettext("Collection")}
              </label>
              <div class="flex-1 px-3 py-2 bg-gray-50 dark:bg-gray-700 rounded text-sm text-gray-900 dark:text-white truncate">
                {@collection_name || ""}
              </div>
            </div>
            <!-- Identifiers (editable only for super_admin) -->
            <div class="col-span-full">
              <%= if @editable_identifiers do %>
                <.input field={@form[:item_code]} type="text" label={gettext("Item code")} />
              <% else %>
                <label class="text-xs font-medium text-gray-700 dark:text-gray-300">
                  {gettext("Item code")}
                </label>
                <div class="px-3 py-2 bg-gray-50 dark:bg-gray-700 rounded text-sm text-gray-900 dark:text-white truncate">
                  {@form[:item_code].value || ""}
                </div>
                <.input field={@form[:item_code]} type="hidden" />
              <% end %>
            </div>

            <div class="col-span-full">
              <%= if @editable_identifiers do %>
                <.input field={@form[:inventory_code]} type="text" label={gettext("Inventory code")} />
              <% else %>
                <label class="text-xs font-medium text-gray-700 dark:text-gray-300">
                  {gettext("Inventory code")}
                </label>
                <div class="px-3 py-2 bg-gray-50 dark:bg-gray-700 rounded text-sm text-gray-900 dark:text-white truncate">
                  {@form[:inventory_code].value || ""}
                </div>
                <.input field={@form[:inventory_code]} type="hidden" />
              <% end %>
            </div>

            <div class="col-span-full">
              <%= if @editable_identifiers do %>
                <.input field={@form[:barcode]} type="text" label={gettext("Barcode")} />
              <% else %>
                <label class="text-xs font-medium text-gray-700 dark:text-gray-300">
                  {gettext("Barcode")}
                </label>
                <div class="px-3 py-2 bg-gray-50 dark:bg-gray-700 rounded text-sm text-gray-900 dark:text-white truncate">
                  {@form[:barcode].value || ""}
                </div>
                <.input field={@form[:barcode]} type="hidden" />
              <% end %>
            </div>
            <!-- Relations and small selects (grouped on one row when space allows) -->
            <div>
              <%= if assigns[:lock_unit_id] && @lock_unit_id do %>
                <label class="text-xs font-medium text-gray-700 dark:text-gray-300">
                  {gettext("Unit / Node")}
                </label>
                <div class="px-3 py-2 bg-gray-50 dark:bg-gray-700 rounded text-sm text-gray-900 dark:text-white">
                  {Enum.find(@nodes, fn {_label, id} -> id == @form[:unit_id].value end) |> elem(0)}
                </div>
                <.input field={@form[:unit_id]} type="hidden" />
              <% else %>
                <.input
                  field={@form[:unit_id]}
                  type="select"
                  options={@nodes || []}
                  label={gettext("Unit / Node")}
                />
              <% end %>
            </div>

            <div>
              <.input
                field={@form[:item_location_id]}
                type="select"
                options={@locations || []}
                label={gettext("Location (site)")}
              />
              <%= if (@locations || []) == [] do %>
                <p class="text-xs text-gray-500 mt-1">
                  {gettext("Choose a Unit/Node first to enable location options.")}
                </p>
              <% end %>
            </div>

            <div>
              <.input
                field={@form[:price]}
                type="number"
                label={gettext("Price")}
              />
            </div>
            <!-- Status/Condition/Availability (compact row) -->
            <div>
              <.input
                field={@form[:status]}
                type="select"
                options={Item.status_options()}
                label={gettext("Status")}
              />
            </div>

            <div>
              <.input
                field={@form[:condition]}
                type="select"
                options={Item.condition_options()}
                label={gettext("Condition")}
              />
            </div>

            <div>
              <.input
                field={@form[:availability]}
                type="select"
                options={Item.availability_options()}
                label={gettext("Availability")}
              />
            </div>
            <!-- Location text (full width) -->
            <div class="col-span-full">
              <.input field={@form[:location]} type="text" label={gettext("Location (text)")} />
            </div>
            <!-- Dates and times (compact) -->
            <div>
              <.input
                field={@form[:acquisition_date]}
                type="date"
                label={gettext("Acquisition date")}
              />
            </div>

            <div>
              <.input
                field={@form[:last_inventory_date]}
                type="date"
                label={gettext("Last inventory date")}
              />
            </div>

            <div class="col-span-full">
              <!-- Hidden: last_circulated should not be editable in the form but keep value submitted -->
              <.input field={@form[:last_circulated]} type="hidden" />
            </div>

            <div><.input field={@form[:rfid_tag]} type="text" label={gettext("RFID tag")} /></div>

            <div class="col-span-full">
              <.input
                field={@form[:legacy_item_code]}
                type="text"
                label={gettext("Legacy item code")}
              />
            </div>
          </div>

          <div class="flex items-center gap-3 pt-2">
            <.button phx-disable-with={gettext("Saving...")} class="success-btn">
              <.icon name="hero-check" class="w-4 h-4" /> {gettext("Save")}
            </.button>
            <.link patch={@patch} class="inline-block">
              <.button type="button" class="cancel-btn">{gettext("Cancel")}</.button>
            </.link>
            <div class="ml-auto text-sm text-gray-500">
              {gettext("Tip: edit fields and click Save to persist changes.")}
            </div>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{item: item} = assigns, socket) do
    # Load nodes and locations. Filter locations by the item's unit_id when present.
    nodes = System.list_nodes()
    node_options = Enum.map(nodes, fn n -> {"#{n.name} (#{n.abbr})", n.id} end)

    all_locations = Master.list_mst_locations()
    # Decide which node to use for filtering locations:
    # 1. item.unit_id (when editing)
    # 2. passed in assigns user_node_id (when creating a new item)
    # 3. nil -> no locations shown
    selected_node_id = item.unit_id || assigns[:user_node_id]

    # If a node is selected, show only locations for that node. Otherwise,
    # leave the location options empty until the user selects a node.
    filtered_locations =
      if selected_node_id do
        Enum.filter(all_locations, &(&1.node_id == selected_node_id))
      else
        []
      end

    location_options = Enum.map(filtered_locations, &{&1.location_name, &1.id})

    collection_name =
      case item do
        %{collection: %_{} = coll} ->
          coll.title

        %{collection_id: cid} when not is_nil(cid) ->
          # fallback to empty string; parent LiveView may pass collection_name
          ""

        _ ->
          ""
      end

    # Determine whether identifier fields should be editable by this user.
    # Parent LiveView should pass `:current_user` into the component. If not
    # present, default to non-editable.
    is_super_admin =
      case assigns[:current_user] do
        %_{} = u -> GLAMAuthorization.is_super_admin?(u)
        _ -> false
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:nodes, node_options)
     |> assign(:locations, location_options)
     |> assign(:all_locations, all_locations)
     |> assign_new(:collections, fn -> [] end)
     |> assign(:collection_name, collection_name)
     |> assign(:editable_identifiers, is_super_admin)
     |> assign_new(:lock_unit_id, fn -> false end)
     |> assign_new(:form, fn ->
       to_form(Catalog.change_item(item))
     end)}
  end

  @impl true
  def handle_event("validate", %{"item" => item_params}, socket) do
    changeset = Catalog.change_item(socket.assigns.item, item_params)

    # If unit_id changed AND unit is not locked, update the locations list
    # If unit_id is locked, keep it locked to the current value
    unit_id =
      if socket.assigns[:lock_unit_id] do
        socket.assigns.item.unit_id
      else
        case item_params["unit_id"] do
          nil ->
            socket.assigns.item.unit_id

          "" ->
            nil

          id when is_binary(id) ->
            case Integer.parse(id) do
              {int, _} -> int
              :error -> id
            end

          id ->
            id
        end
      end

    all_locations = socket.assigns[:all_locations] || []

    locations =
      case unit_id do
        nil ->
          # no unit selected -> keep locations empty until node is chosen
          []

        id ->
          all_locations
          |> Enum.filter(&(&1.node_id == id))
          |> Enum.map(&{&1.location_name, &1.id})
      end

    {:noreply,
     socket
     |> assign(:locations, locations)
     |> assign(:form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"item" => item_params}, socket) do
    save_item(socket, socket.assigns.action, item_params)
  end

  defp save_item(socket, :edit, item_params) do
    case Catalog.update_item(socket.assigns.item, item_params) do
      {:ok, item} ->
        notify_parent({:saved, item})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Item updated successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_item(socket, :new, item_params) do
    case Catalog.create_item(item_params) do
      {:ok, item} ->
        notify_parent({:saved, item})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Item created successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
