defmodule VoileWeb.Dashboard.MetaResource.ResourceTemplateLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Metadata
  alias Voile.Schema.Metadata.ResourceTemplate

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-6 py-12">
      <h1 class="text-2xl font-bold mb-6">
        {if @resource_template.id, do: "Edit Resource Template", else: "Create New Resource Template"}
      </h1>

      <.form
        :let={f}
        for={@form}
        phx-submit="save"
        phx-change="validate"
        phx-debounce="500"
        phx-target={@myself}
        class="space-y-6"
      >
        <!-- Template Name -->
        <div>
          <.label>Template <span class="text-brand">{@resource_template.label}</span></.label>

          <.input
            field={f[:label]}
            type="text"
            label="Label"
            placeholder="e.g., Book Template"
            required_value={true}
          />
          <.input
            field={f[:description]}
            type="textarea"
            label="Description"
            placeholder="Description (optional)"
            required_value={false}
          />
          <.input
            field={f[:resource_class_id]}
            type="select"
            label="Resource Class"
            options={Enum.map(@resource_class, fn res -> {res.label, res.id} end)}
            prompt="Select a resource class"
            required_value={true}
          />
        </div>
        <!-- Property Search -->
        <div class="space-y-2">
          <.label>Add Properties</.label>

          <div class="relative">
            <input
              type="text"
              name="search"
              placeholder="Search properties..."
              autocomplete="off"
              phx-keyup="search"
              phx-debounce="300"
              phx-target={@myself}
              class="default-input"
            />
            <div :if={@loading} class="absolute right-3 top-2.5">
              <.icon name="hero-arrow-path" class="w-5 h-5 animate-spin" />
            </div>
          </div>
          <!-- Search Results -->
          <div class="border rounded max-h-60 overflow-y-auto bg-gray-50">
            <div
              :if={Enum.empty?(@properties) && @search_term != ""}
              class="p-4 text-center text-gray-500"
            >
              <%= case {@loading, @search_term, @properties} do %>
                <% {true, _, _} -> %>
                  Searching for {@search_term}...
                <% {false, term, []} when term != "" -> %>
                  No properties found for "{@search_term}"
                <% {_, _, _} -> %>
                  You can add other properties by searching for them on the search box.
              <% end %>
            </div>

            <%= for property <- @properties do %>
              <div
                class="p-3 hover:bg-gray-100 cursor-pointer border-b"
                phx-click="add_property"
                phx-value-id={property.id}
                phx-target={@myself}
              >
                <div class="font-medium">{property.label}</div>

                <div class="text-sm text-gray-600">{property.local_name}</div>
              </div>
            <% end %>
          </div>
        </div>
        <!-- Selected Properties -->
        <div :if={!Enum.empty?(@selected_properties)} class="space-y-4">
          <.label>Selected Properties</.label>

          <div
            id={"selected-properties-#{@myself}"}
            class="space-y-3"
            phx-hook="DragDrop"
            phx-update="stream"
            data-target={@myself}
          >
            <div
              :for={{dom_id, prop} <- @streams.selected_props}
              id={dom_id}
              class="p-3 border rounded bg-white flex justify-between items-start gap-4"
            >
              <div class="cursor-move pt-1">
                <.icon name="hero-arrows-pointing-in" class="w-5 h-5 text-gray-400" />
              </div>

              <div class="flex-1">
                <div class="font-medium text-gray-900">
                  <%= if is_map(prop) && Map.has_key?(prop, :override_label) do %>
                    {prop.override_label || prop.label}
                  <% else %>
                    {prop.label}
                  <% end %>
                </div>

                <div class="text-sm text-gray-300">{prop.local_name}</div>

                <div class="mt-6">
                  <.label>Custom Label :</.label>

                  <input
                    type="text"
                    value={if is_map(prop), do: prop[:override_label] || "", else: ""}
                    placeholder="Custom label..."
                    phx-blur="update_label"
                    phx-value-id={dom_id}
                    phx-target={@myself}
                    class="default-input"
                  />
                </div>
              </div>

              <button
                type="button"
                class="text-red-500 hover:text-red-700 mt-1"
                phx-click="remove_property"
                phx-value-id={dom_id}
                phx-target={@myself}
              >
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>
        <!-- Submit Button -->
        <div class="flex gap-4">
          <.button
            type="submit"
            phx-disable-with={if @resource_template.id, do: "Updating...", else: "Creating..."}
          >
            {if @resource_template.id, do: "Update Template", else: "Create Template"}
          </.button>
           <.link navigate={@return_to} class="btn btn-secondary">Cancel</.link>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{resource_template: resource_template} = assigns, socket) do
    # Handle both new and edit cases
    {template, changeset, selected_properties} =
      case resource_template do
        %ResourceTemplate{id: nil} ->
          # New template
          changeset = Metadata.change_resource_template(%ResourceTemplate{})
          {%ResourceTemplate{}, changeset, []}

        %ResourceTemplate{} = template ->
          # Edit existing template
          template_with_props = get_resource_template_with_properties(template.id)
          changeset = Metadata.change_resource_template(template_with_props)
          selected_props = build_selected_properties(template_with_props.template_properties)
          {template_with_props, changeset, selected_props}
      end

    resource_class = Metadata.list_resource_class()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:resource_template, template)
     |> assign(:form, to_form(changeset))
     |> assign(:resource_class, resource_class)
     |> assign(:properties, [])
     |> assign(:selected_properties, selected_properties)
     |> assign(:search_term, "")
     |> assign(:loading, false)
     |> assign(:dragging, nil)
     |> assign(:initial_values, build_initial_values(selected_properties))
     |> stream(:selected_props, selected_properties)}
  end

  @impl true
  def update(%{action: :reorder_by_index, params: params}, socket) do
    # Handle forwarded reorder event
    %{"old_index" => old_index, "new_index" => new_index} = params

    IO.inspect({old_index, new_index}, label: "Reorder indices")
    IO.inspect(socket.assigns.selected_properties, label: "Before reorder")

    selected = reorder_by_index(socket.assigns.selected_properties, old_index, new_index)

    IO.inspect(selected, label: "After reorder")

    {:ok,
     socket
     |> assign(:selected_properties, selected)
     |> rebuild_stream(selected)}
  end

  @impl true
  def handle_event("validate", %{"resource_template" => params}, socket) do
    changeset =
      case socket.assigns.resource_template.id do
        nil -> Metadata.change_resource_template(%ResourceTemplate{}, params)
        _id -> Metadata.change_resource_template(socket.assigns.resource_template, params)
      end

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("search", %{"key" => _key, "value" => value}, socket) do
    handle_search(value, socket)
  end

  def handle_event("search", %{"value" => value}, socket) do
    handle_search(value, socket)
  end

  def handle_event("add_property", %{"id" => id}, socket) do
    property = find_property(socket.assigns.properties, id)

    if property && !property_selected?(socket.assigns.selected_properties, id) do
      next_position = length(socket.assigns.selected_properties) + 1

      property_map =
        property
        |> Map.from_struct()
        |> Map.take([:id, :label, :local_name, :information, :type_value])
        |> Map.put(:override_label, property.label)
        |> Map.put(:position, next_position)
        |> Map.put(:template_property_id, nil)

      selected = socket.assigns.selected_properties ++ [property_map]
      initial_values = Map.put(socket.assigns.initial_values, property.id, property.label)

      socket =
        socket
        |> assign(:selected_properties, selected)
        |> assign(:initial_values, initial_values)
        |> assign(:search_term, "")
        |> assign(:properties, [])
        |> assign(:loading, false)
        |> rebuild_stream(selected)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_property", %{"id" => id}, socket) do
    [_id_prefix, id_str] = String.split(id, "-")
    id_int = String.to_integer(id_str)
    selected = Enum.reject(socket.assigns.selected_properties, &(&1.id == id_int))

    socket =
      socket
      |> assign(:selected_properties, selected)
      |> rebuild_stream(selected)

    {:noreply, socket}
  end

  def handle_event("update_label", %{"id" => id, "value" => value}, socket) do
    [_id_prefix, id_str] = String.split(id, "-")
    id_int = String.to_integer(id_str)

    # Get the current override_label for this property
    current_property = Enum.find(socket.assigns.selected_properties, &(&1.id == id_int))
    current_value = current_property && current_property.override_label

    # Only update if the value actually changed
    if current_value != value do
      IO.inspect({id_int, current_value, value}, label: "Label changed")

      # Update the selected_properties list
      selected =
        Enum.map(socket.assigns.selected_properties, fn
          prop when prop.id == id_int ->
            Map.put(prop, :override_label, value)

          prop ->
            prop
        end)

      socket =
        socket
        |> assign(:selected_properties, selected)
        |> rebuild_stream(selected)

      {:noreply, socket}
    else
      # If the value is the same, do nothing and don't log
      {:noreply, socket}
    end
  end

  def handle_event("save", params, socket) do
    resource_template_params = Map.get(params, "resource_template", params)

    owner_id = socket.assigns.current_user.id
    template_properties = build_template_properties(socket.assigns.selected_properties)

    template_params = %{
      label: resource_template_params["label"],
      description: resource_template_params["description"],
      resource_class_id: resource_template_params["resource_class_id"],
      owner_id: owner_id,
      template_properties: template_properties
    }

    result =
      case socket.assigns.resource_template.id do
        nil ->
          Metadata.create_resource_template(template_params)

        _id ->
          Metadata.update_resource_template(socket.assigns.resource_template, template_params)
      end

    case result do
      {:ok, template} ->
        action = if socket.assigns.resource_template.id, do: "updated", else: "created"

        {:noreply,
         socket
         |> put_flash(:info, "Template #{template.label} #{action} successfully!")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset.errors, label: "Changeset errors")
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_async(:search_properties, {:ok, properties}, socket) do
    {:noreply,
     socket
     |> assign(:properties, properties)
     |> assign(:loading, false)}
  end

  def handle_async(:search_properties, {:exit, reason}, socket) do
    IO.puts("Search failed: #{inspect(reason)}")
    {:noreply, assign(socket, :loading, false)}
  end

  # Private helper functions
  defp rebuild_stream(socket, selected_properties) do
    # Clear the stream and rebuild it with correct order
    socket
    |> stream(:selected_props, [], reset: true)
    |> then(fn socket ->
      Enum.reduce(selected_properties, socket, fn prop, acc_socket ->
        stream_insert(acc_socket, :selected_props, prop)
      end)
    end)
  end

  defp get_resource_template_with_properties(id) do
    Metadata.get_resource_template!(id)
    |> Voile.Repo.preload([
      :resource_class,
      template_properties: [:property]
    ])
  end

  defp build_selected_properties(template_properties) do
    template_properties
    |> Enum.sort_by(& &1.position)
    |> Enum.map(fn tp ->
      %{
        id: tp.property.id,
        template_property_id: tp.id,
        label: tp.property.label,
        local_name: tp.property.local_name,
        information: tp.property.information,
        type_value: tp.property.type_value,
        override_label: tp.override_label || tp.property.label,
        position: tp.position
      }
    end)
  end

  defp build_initial_values(selected_properties) do
    Enum.reduce(selected_properties, %{}, fn prop, acc ->
      Map.put(acc, prop.id, prop.override_label)
    end)
  end

  defp handle_search(term, socket) do
    if String.length(term) >= 2 do
      {:noreply,
       socket
       |> assign(:search_term, term)
       |> assign(:loading, true)
       |> start_async(:search_properties, fn -> search_properties(term) end)}
    else
      {:noreply,
       socket
       |> assign(:properties, [])}
    end
  end

  defp search_properties(term) do
    Metadata.search_property(term)
  end

  defp find_property(properties, id) do
    id_int = String.to_integer(id)
    Enum.find(properties, &(&1.id == id_int))
  end

  defp property_selected?(selected, id) do
    id_int = String.to_integer(id)
    Enum.any?(selected, &(&1.id == id_int))
  end

  defp build_template_properties(selected_properties) do
    selected_properties
    # Ensure correct order
    |> Enum.sort_by(& &1.position)
    |> Enum.map(fn property ->
      base_attrs = %{
        position: property.position,
        property_id: property.id,
        override_label: property.override_label
      }

      # Include ID for existing records so Ecto knows to update them
      case property.template_property_id do
        nil ->
          # New property - no ID, Ecto will create it
          base_attrs

        template_property_id when is_binary(template_property_id) ->
          # Existing property - include ID so Ecto will update it
          Map.put(base_attrs, :id, template_property_id)

        template_property_id ->
          # Handle case where template_property_id might be in different format
          Map.put(base_attrs, :id, template_property_id)
      end
    end)
  end

  defp reorder_by_index(properties, old_index, new_index) when old_index != new_index do
    # Remove the item from old position
    {item, remaining} = List.pop_at(properties, old_index)

    # Insert at new position
    reordered = List.insert_at(remaining, new_index, item)

    # Update positions based on new order
    reordered
    |> Enum.with_index(1)
    |> Enum.map(fn {property, new_position} ->
      Map.put(property, :position, new_position)
    end)
  end

  defp reorder_by_index(properties, _old_index, _new_index), do: properties
end
