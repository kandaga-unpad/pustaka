defmodule VoileWeb.Dashboard.Catalog.CollectionLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Catalog
  alias Ecto.Changeset

  import VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if msg = @flash["error"] do %>
        <.flash kind={:error} class="mb-4">{msg}</.flash>
      <% end %>
      
      <%= if msg = @flash["info"] do %>
        <.flash kind={:info} class="mb-4">{msg}</.flash>
      <% end %>
      
      <.modal id="col_field_delete_confirmation">
        <div class="text-center">
          <h5>
            Are you sure want to delete {(@chosen_collection_field && @chosen_collection_field.label) ||
              ""} ?
          </h5>
          
          <p class="text-sm text-gray-500">
            This action cannot be undone. Please confirm your action.
          </p>
          
          <p class="text-sm italic font-semibold text-red-500">You will delete this property :</p>
          
          <div class="my-4">
            <h6 class="text-brand">
              {(@chosen_collection_field && @chosen_collection_field.label) || ""}
            </h6>
            
            <p class="text-xs">with value :</p>
            
            <h6 class="font-bold text-gray-500">
              {(@chosen_collection_field && @chosen_collection_field.value) || ""}
            </h6>
          </div>
          
          <div class="flex items-center w-full my-5 gap-5">
            <.button
              class="w-full warning-btn"
              phx-click={
                JS.push("delete_existed_field") |> hide_modal("col_field_delete_confirmation")
              }
              phx-value-id={@delete_confirmation_id}
              phx-target={@myself}
            >
              Delete
            </.button>
            <.button
              class="w-full"
              phx-click={hide_modal("col_field_delete_confirmation")}
              phx-target={@myself}
            >
              Cancel
            </.button>
          </div>
        </div>
      </.modal>
      
      <.modal id="item_delete_confirmation">
        <div class="text-center">
          <h5>Are you sure want to delete this item data?</h5>
          
          <p class="text-sm text-gray-500">
            This action cannot be undone. Please confirm your action.
          </p>
          
          <div class="my-4">
            <p class="text-xs">with value :</p>
            
            <h6 class="text-brand">{(@chosen_item_field && @chosen_item_field.item_code) || ""}</h6>
          </div>
        </div>
        
        <div class="flex items-center w-full my-5 gap-5">
          <.button
            class="w-full warning-btn"
            phx-click={JS.push("delete_existing_item") |> hide_modal("item_delete_confirmation")}
            phx-value-id={@delete_confirmation_id}
            phx-target={@myself}
          >
            Delete
          </.button>
          <.button
            class="w-full"
            phx-click={hide_modal("item_delete_confirmation")}
            phx-target={@myself}
          >
            Cancel
          </.button>
        </div>
      </.modal>
      
      <.header>
        {@title}
        <:subtitle>Use this form to manage collection records in your database.</:subtitle>
      </.header>
      
      <.simple_form
        for={@form}
        id="collection-form-1"
        phx-target={@myself}
        phx-change="validate"
        phx-debounce="300"
        phx-submit="save"
      >
        <%= if @step == 1 do %>
          <.input field={@form[:id]} type="hidden" />
          <.input
            field={@form[:type_id]}
            label="Collection Type"
            type="select"
            options={Enum.map(@collection_type, fn ct -> {ct.label, ct.id} end)}
            prompt="Select Collection Type"
            required_value={true}
          />
          <.input
            field={@form[:unit_id]}
            label="Collection Location"
            type="select"
            options={Enum.map(@node_list, fn node -> {node.name, node.id} end)}
            prompt="Select Collection Location"
            required_value={true}
          /> <.input field={@form[:title]} type="text" label="Title" required_value={true} />
          <.input
            type="text"
            name="creator"
            value={
              (@collection.mst_creator && @collection.mst_creator.creator_name) || @creator_input
            }
            label="Creator"
            disabled={@creator_input != "" and @collection.creator_id !== nil}
            required_value={true}
            autocomplete="off"
          />
          <%= if @creator_input != "" and @creator_suggestions != [] and @form[:creator_id] != nil and @collection.creator_id == nil do %>
            <ul class="absolute z-10 bg-white dark:bg-gray-800 border -mt-4 rounded shadow max-h-64 overflow-y-auto max-w-full">
              <%= for creator <- @creator_suggestions do %>
                <li
                  phx-click="select_creator"
                  phx-value-id={creator.id}
                  phx-target={@myself}
                  class="px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer"
                >
                  {creator.creator_name}
                </li>
              <% end %>
            </ul>
          <% end %>
          
          <%= if @creator_input != nil and @creator_suggestions == [] and @collection.creator_id == nil do %>
            <.button
              type="button"
              phx-click="create_new_creator"
              phx-value-creator={@creator_input}
              phx-target={@myself}
            >
              Create {@creator_input}
            </.button>
            <%= for {_msg, _opts} <- Keyword.get_values(@form.errors, :creator_id) do %>
              <p class="text-red-500 text-sm mt-2">Please choose Creator or click Create!</p>
            <% end %>
          <% end %>
          
          <%= if @collection.creator_id != nil do %>
            <.button type="button" phx-click="delete_creator" phx-target={@myself} class="warning-btn">
              Delete Author
            </.button>
          <% end %>
          
          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            required_value={true}
          />
          <.input
            field={@form[:status]}
            type="select"
            label="Status"
            options={[
              {"Draft", "draft"},
              {"Pending", "pending"},
              {"Published", "published"},
              {"Archived", "archived"}
            ]}
            required_value={true}
          />
          <.input
            field={@form[:access_level]}
            type="select"
            label="Access Level"
            options={[
              {"Public", "public"},
              {"Private", "private"},
              {"Restricted", "restricted"}
            ]}
            required_value={true}
          /> <.input field={@form[:thumbnail]} type="text" label="Thumbnail" disabled="true" />
          <input
            name={@form[:creator_id].name}
            value={@form[:creator_id].value || @current_scope.user.id}
            type="hidden"
            disabled
          />
          <input
            name={@form[:id].name}
            value={@form[:id].value || Ecto.UUID.generate()}
            type="hidden"
            disabled
          />
          <div class="p-6">
            <%= if @form[:thumbnail].value == nil or @form[:thumbnail].value == "" do %>
              <!-- Upload Area (when no thumbnail) -->
              <div
                class="border-2 border-dashed border-gray-300 rounded-xl p-8 text-center hover:border-blue-400 hover:bg-blue-50 transition-all duration-300 cursor-pointer group"
                phx-drop-target={@uploads.thumbnail.ref}
              >
                <div class="space-y-4">
                  <div class="mx-auto w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center group-hover:bg-blue-200 transition-colors">
                    <svg
                      class="w-8 h-8 text-blue-500"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
                      >
                      </path>
                    </svg>
                  </div>
                  
                  <div>
                    <p class="text-gray-700 font-medium">Click to upload or drag and drop</p>
                    
                    <p class="text-gray-500 text-sm mt-1">PNG, JPG, GIF up to 10MB</p>
                  </div>
                  
                  <div class="mt-4">
                    <.live_file_input upload={@uploads.thumbnail} class="hidden" />
                    <label
                      for={@uploads.thumbnail.ref}
                      class="inline-flex items-center px-6 py-3 bg-gradient-to-r from-blue-500 to-purple-600 text-white font-medium rounded-lg hover:from-blue-600 hover:to-purple-700 transition-all duration-200 cursor-pointer shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
                    >
                      <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 6v6m0 0v6m0-6h6m-6 0H6"
                        >
                        </path>
                      </svg>
                      Choose File
                    </label>
                  </div>
                </div>
              </div>
            <% end %>
            
            <%= for entry <- @uploads.thumbnail.entries do %>
              <div class="space-y-4">
                <div class="flex items-center space-x-3">
                  <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                    <svg
                      class="w-6 h-6 text-blue-500"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                      >
                      </path>
                    </svg>
                  </div>
                  
                  <div class="flex-1">
                    <p class="text-gray-700 font-medium text-sm">{entry.client_name}</p>
                    
                    <div class="mt-2 bg-gray-200 rounded-full h-2">
                      <div
                        class="bg-gradient-to-r from-blue-500 to-purple-500 h-2 rounded-full transition-all duration-300"
                        style={"width: #{entry.progress}%"}
                      >
                      </div>
                    </div>
                    
                    <p class="text-gray-500 text-xs mt-1">Uploading... {entry.progress}%</p>
                  </div>
                </div>
              </div>
            <% end %>
            
            <%= if @form[:thumbnail].value != nil and @form[:thumbnail].value != "" do %>
              <div class="space-y-4">
                <div class="relative group w-full max-w-96">
                  <img
                    src={@form[:thumbnail].value}
                    alt="Collection thumbnail"
                    class="w-96 object-cover rounded-xl shadow-md"
                  />
                  <div class="absolute inset-0 bg-black/30 group-hover:bg-black/50 rounded-xl transition-opacity duration-300 flex items-center justify-center pointer-events-none">
                  </div>
                </div>
                
                <div class="flex items-center justify-between w-full max-w-96">
                  <div class="flex items-center space-x-2 text-green-600">
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                      <path
                        fill-rule="evenodd"
                        d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                        clip-rule="evenodd"
                      >
                      </path>
                    </svg> <span class="text-sm font-medium">Thumbnail uploaded</span>
                  </div>
                  
                  <.button
                    type="button"
                    phx-click="delete_thumbnail"
                    phx-value-thumbnail={@form[:thumbnail].value}
                    phx-target={@myself}
                    class="warning-btn"
                    phx-disable-with="Removing..."
                  >
                    <svg
                      class="w-4 h-4 inline mr-1"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                      >
                      </path>
                    </svg>
                    Remove
                  </.button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
        
        <%= if @step == 2 do %>
          <div class="flex items-start gap-5">
            <div class="sticky top-0 w-full max-w-72">
              <h5>Collection Properties</h5>
              
              <div class="w-full h-[512px] border border-1 border-violet-100 overflow-y-auto overflow-x-hidden rounded-xl mt-2 p-4">
                <p class="text-xs italic mb-4 max-w-48">
                  You can click each category below and pick any necessary property for your collection.
                </p>
                
                <div>
                  <.input
                    type="text"
                    name="property_search"
                    label="Search Property"
                    value={@property_search}
                    placeholder="Search property..."
                    phx-keyup="search_properties"
                    phx-target={@myself}
                    phx-debounce="300"
                  />
                </div>
                
                <%= if Enum.empty?(@filtered_properties) do %>
                  <p class="text-red-500 text-sm mt-2">No property found.</p>
                <% else %>
                  <%= for {id, props} <- @filtered_properties do %>
                    <div>
                      <h6
                        class="mb-4 border border-1 border-violet-100 rounded-xl p-2 hover:text-brand cursor-pointer transition-all duration-1000"
                        phx-click={
                          JS.toggle(
                            to: "##{id |> String.downcase() |> String.replace(" ", "-")}",
                            in: "block scale-y-100 transition transform duration-300 ease-out",
                            out: "hidden scale-y-0 transition transform duration-300 ease-in",
                            display: "block"
                          )
                        }
                      >
                        {id}
                        <%= if length(props) > 0 do %>
                          (<span class="text-brand">{length(props)}</span>)
                        <% end %>
                      </h6>
                      
                      <div
                        id={id |> String.downcase() |> String.replace(" ", "-")}
                        class={
                          if @property_search != "",
                            do:
                              "block scale-y-100 origin-top overflow-hidden transition-transform duration-300",
                            else:
                              "hidden scale-y-0 origin-top overflow-hidden transition-transform duration-300"
                        }
                      >
                        <div class="flex flex-col gap-3">
                          <%= for prop <- props do %>
                            <button
                              type="button"
                              phx-click="select_props"
                              phx-value-id={prop.id}
                              phx-target={@myself}
                              class="btn text-left hover-btn ml-3"
                            >
                              {prop.label}
                            </button>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
            
            <div class="w-full">
              <%= if @form[:collection_fields] == nil or Enum.empty?(@form[:collection_fields].value || []) do %>
                <p class="text-red-500 text-sm mt-2">No collection fields added yet.</p>
              <% else %>
                <div>
                  <.inputs_for :let={col_field} field={@form[:collection_fields]}>
                    <h6 class="bg-violet-500 px-4 py-1 rounded-t-xl text-white">
                      {col_field[:label].value}
                    </h6>
                    
                    <div class="flex flex-col w-full bg-gray-100 dark:bg-gray-600 p-4 rounded-b-xl mb-4">
                      <p class="text-gray-500 italic mb-4">{col_field[:information].value}</p>
                      
                      <input
                        type="hidden"
                        name={col_field[:label].name}
                        value={col_field[:label].value}
                      />
                      <input
                        type="hidden"
                        name={col_field[:property_id].name}
                        value={col_field[:property_id].value}
                      />
                      <input
                        type="hidden"
                        name={col_field[:name].name}
                        value={col_field[:name].value}
                      />
                      <input
                        type="hidden"
                        name={col_field[:information].name}
                        value={col_field[:information].value}
                      />
                      <input
                        type="hidden"
                        name={col_field[:sort_order].name}
                        value={col_field[:sort_order].value || col_field.index + 1}
                      />
                      <input
                        type="hidden"
                        name={col_field[:type_value].name}
                        value={col_field[:type_value].value}
                      />
                      <div class="grid grid-cols-5 items-start gap-2 -mt-6">
                        <.input
                          field={col_field[:value_lang]}
                          type="select"
                          label="Language"
                          options={[
                            {"Indonesia", "id"},
                            {"English", "en"}
                          ]}
                        />
                        <div class="col-span-4">
                          <.input
                            field={col_field[:value]}
                            type={col_field[:type_value].value}
                            label="Value"
                          />
                        </div>
                      </div>
                      
                      <div class="w-full flex items-center gap-3 mt-2">
                        <%= if col_field[:id].value != nil do %>
                          <.button
                            type="button"
                            phx-click={
                              JS.push("delete_confirmation")
                              |> show_modal("col_field_delete_confirmation")
                            }
                            phx-target={@myself}
                            phx-value-id={col_field[:id].value}
                            class="warning-btn w-full"
                          >
                            <.icon name="hero-trash-solid" class="w-4 h-4" /> Delete Property
                          </.button>
                        <% else %>
                          <.button
                            type="button"
                            phx-click="delete_unsaved_field"
                            phx-target={@myself}
                            phx-value-index={col_field.index}
                            class="warning-btn w-full"
                          >
                            <.icon name="hero-x-circle-solid" class="w-4 h-4" /> Remove Field
                          </.button>
                        <% end %>
                      </div>
                    </div>
                  </.inputs_for>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
        
        <%= if @step == 3 do %>
          <div class="flex items-center justify-between mb-5">
            <h5>The Items Data</h5>
            
            <div class="flex items-center gap-5">
              <.button
                type="button"
                phx-click="add_item_data"
                phx-target={@myself}
                class="primary-btn"
              >
                <.icon name="hero-plus-circle-solid" class="w-4 h-4" /> Add Item Data
              </.button>
            </div>
          </div>
          
          <div class="">
            <%= if @form[:items] == nil or Enum.empty?(@form[:items].value || []) do %>
              <p class="text-red-500 text-sm mt-2">
                No items is added yet. Create at least 1 item for each collection.
              </p>
            <% else %>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5 my-10">
                <.inputs_for :let={item_field} field={@form[:items]}>
                  <div class="bg-gray-600 rounded-lg p-5">
                    <div class="w-full flex items-center gap-3 mt-2">
                      <%= if item_field[:id].value != nil do %>
                        <.button
                          type="button"
                          phx-click={
                            JS.push("delete_confirmation")
                            |> show_modal("item_delete_confirmation")
                          }
                          phx-target={@myself}
                          phx-value-id={item_field[:id].value}
                          class="warning-btn w-full"
                        >
                          <.icon name="hero-trash-solid" class="w-4 h-4" /> Delete Property
                        </.button>
                      <% else %>
                        <.button
                          type="button"
                          phx-click="delete_unsaved_item"
                          phx-target={@myself}
                          phx-value-index={item_field.index}
                          class="warning-btn w-full"
                        >
                          <.icon name="hero-x-circle-solid" class="w-4 h-4" /> Remove Field
                        </.button>
                      <% end %>
                    </div>
                    
                    <.input
                      field={item_field[:item_code]}
                      type="text"
                      label="Item Code"
                      required_value={true}
                    />
                    <.input
                      field={item_field[:inventory_code]}
                      type="text"
                      label="Inventory Code"
                      required_value={true}
                    />
                    <.input
                      field={item_field[:location]}
                      type="text"
                      label="Location"
                      required_value={true}
                    />
                    <.input
                      field={item_field[:unit_id]}
                      type="select"
                      label="Unit Location"
                      required_value={true}
                      options={Enum.map(@node_list, fn node -> {node.name, node.id} end)}
                      disabled={true}
                    />
                    <.input
                      field={item_field[:status]}
                      type="select"
                      label="Status"
                      required_value={true}
                      options={[
                        {"Active", "active"},
                        {"Inactive", "inactive"},
                        {"Lost", "lost"},
                        {"Damaged", "damaged"}
                      ]}
                    />
                    <.input
                      field={item_field[:condition]}
                      type="select"
                      label="Condition"
                      required_value={true}
                      options={[
                        {"New", "new"},
                        {"Good", "good"},
                        {"Fair", "fair"},
                        {"Poor", "poor"}
                      ]}
                    />
                    <.input
                      field={item_field[:availability]}
                      type="select"
                      label="Availability"
                      required_value={true}
                      options={[
                        {"Available", "available"},
                        {"Checked Out", "checked_out"},
                        {"Reserved", "reserved"},
                        {"Maintenance", "maintenance"}
                      ]}
                    />
                  </div>
                </.inputs_for>
              </div>
            <% end %>
          </div>
        <% end %>
        
        <:actions>
          <div class="mt-12 w-full flex justify-between items-center gap-5">
            <%= if @step > 1 do %>
              <.button
                type="button"
                phx-click="prev_step"
                phx-target={@myself}
                class="primary-btn w-full"
              >
                &leftarrow; Back
              </.button>
            <% end %>
            
            <%= if @step == 3 do %>
              <.button type="submit" phx-disable-with="Saving..." class="success-btn w-full">
                Save
              </.button>
            <% else %>
              <.button
                type="button"
                phx-click="next_step"
                phx-target={@myself}
                class="primary-btn w-full"
              >
                Next &rightarrow;
              </.button>
            <% end %>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{collection: collection} = assigns, socket) do
    type_options =
      assigns.collection_type
      |> Enum.map(fn type -> {type.label, type.id} end)

    {original_collection, _changeset} =
      case assigns.action do
        :edit ->
          # Fetch fresh collection with preloads
          coll =
            Catalog.get_collection!(collection.id)
            |> Voile.Repo.preload(collection_fields: [:metadata_properties])

          {coll, Catalog.change_collection(coll)}

        :new ->
          coll =
            collection
            |> Catalog.change_collection(%{})

          {nil, coll}
      end

    seed_source = if assigns.action == :edit, do: original_collection, else: collection

    seed_params =
      (seed_source.collection_fields || [])
      |> Enum.with_index()
      |> Enum.into(%{}, fn {field, idx} ->
        {to_string(idx),
         %{
           "id" => field.id,
           "label" => field.label,
           "information" => field.metadata_properties.information,
           "type_value" => field.type_value,
           "value_lang" => field.value_lang,
           "value" => field.value,
           "sort_order" => field.sort_order
         }}
      end)

    item_params =
      (seed_source.items || [])
      |> Enum.with_index()
      |> Enum.into(%{}, fn {item, idx} ->
        {to_string(idx),
         %{
           "item_code" => item.item_code,
           "inventory_code" => item.inventory_code,
           "location" => item.location,
           "unit_id" => item.unit_id,
           "status" => item.status,
           "condition" => item.condition,
           "availability" => item.availability
         }}
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:original_collection, original_collection)
     |> assign(:creator_input, nil)
     |> assign(:creator_list, assigns.creator_list)
     |> assign(:creator_suggestions, [])
     |> assign(:step2_params, nil)
     |> assign(:step3_params, nil)
     |> assign(:type_options, type_options)
     |> assign(:uploaded_files, [])
     |> assign(:delete_confirmation_id, nil)
     |> assign(:chosen_collection_field, nil)
     |> assign(:chosen_item_field, nil)
     |> assign(:property_search, "")
     |> assign(:filtered_properties, assigns.collection_properties)
     |> allow_upload(:thumbnail,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> assign_new(:form, fn ->
       # Build form with all initial params
       initial_params =
         Map.merge(
           %{"collection_fields" => seed_params, "items" => item_params},
           %{
             "id" => collection.id || Ecto.UUID.generate(),
             "title" => collection.title || "",
             "description" => collection.description || "",
             "status" => collection.status || "draft",
             "access_level" => collection.access_level || "public",
             "type_id" => collection.type_id || nil,
             "unit_id" => collection.unit_id || nil,
             "creator_id" => collection.creator_id || nil,
             "thumbnail" => collection.thumbnail || ""
           }
         )

       to_form(Catalog.change_collection(collection, initial_params))
     end)}
  end

  @impl true
  def handle_event(
        "validate",
        %{"collection" => collection_params, "creator" => creator_input},
        socket
      ) do
    suggestions =
      Enum.filter(socket.assigns.creator_list, fn creator ->
        String.contains?(String.downcase(creator.creator_name), String.downcase(creator_input))
      end)

    current_params = socket.assigns.form.params || %{}
    updated_params = Map.merge(current_params, collection_params)

    changeset =
      Catalog.change_collection(socket.assigns.collection, updated_params)

    socket =
      socket
      |> assign(:creator_input, creator_input)
      |> assign(:creator_suggestions, suggestions)
      |> assign(:form, to_form(changeset, action: :validate))

    {:noreply, socket}
  end

  def handle_event("validate", %{"collection" => collection_params}, socket) do
    current_params = socket.assigns.form.params || %{}
    updated_params = Map.merge(current_params, collection_params)

    changeset =
      Catalog.change_collection(socket.assigns.collection, updated_params)

    socket =
      socket
      |> assign(:form, to_form(changeset, action: :validate))

    {:noreply, socket}
  end

  def handle_event("validate", %{"property_search" => _value}, socket) do
    # Update assigns or do something with `value`
    {:noreply, socket}
  end

  def handle_event("select_creator", %{"id" => id}, socket) do
    {:noreply, assign_selected_creator(id, socket)}
  end

  def handle_event("create_new_creator", %{"creator" => creator}, socket) do
    case create_or_select_creator(creator, socket) do
      {:ok, socket} -> {:noreply, socket}
      {:error, socket} -> {:noreply, socket}
    end
  end

  def handle_event("delete_creator", _params, socket) do
    {:noreply, clear_selected_creator(socket)}
  end

  def handle_event("next_step", _params, socket) do
    current_params = socket.assigns.form.params

    changeset =
      socket.assigns.collection
      |> Catalog.change_collection(current_params)
      |> Map.put(:action, :validate)

    if changeset.valid? do
      collection = Changeset.apply_changes(changeset)

      socket =
        socket
        |> assign(:step, socket.assigns.step + 1)
        |> assign(:collection, collection)
        |> assign(:changeset, changeset)
        |> assign(:form, to_form(changeset))

      {:noreply, socket}
    else
      socket =
        socket
        |> put_flash(:error, "Please fill in all required fields.")
        |> assign(:form, to_form(changeset, action: :validate))

      {:noreply, socket}
    end
  end

  def handle_event("prev_step", _params, socket) do
    socket =
      socket
      |> assign(:step, socket.assigns.step - 1)

    {:noreply, socket}
  end

  def handle_event("select_props", %{"id" => prop_id}, socket) do
    {:noreply, add_property_to_form(prop_id, socket)}
  end

  def handle_event("add_item_data", _params, socket) do
    {:noreply, add_item_to_form(socket)}
  end

  def handle_event("delete_unsaved_field", %{"index" => idx_str}, socket) do
    {:noreply, delete_unsaved_field_at(idx_str, socket)}
  end

  def handle_event("delete_existed_field", %{"id" => id}, socket) do
    {:noreply, delete_existing_field(id, socket)}
  end

  def handle_event("delete_unsaved_item", %{"index" => idx_str}, socket) do
    {:noreply, delete_unsaved_item_at(idx_str, socket)}
  end

  def handle_event("delete_existing_item", %{"id" => id}, socket) do
    {:noreply, delete_existing_item(id, socket)}
  end

  def handle_event("delete_confirmation", %{"id" => id}, socket) do
    {:noreply, confirm_field_deletion(id, socket)}
  end

  def handle_event("search_properties", %{"value" => query}, socket) do
    {:noreply, search_properties(query, socket)}
  end

  def handle_event("save", _params, socket) do
    collection_params = socket.assigns.form.params

    cond do
      # Check if collection fields are empty
      is_nil(collection_params["collection_fields"]) ||
        collection_params["collection_fields"] == %{} ||
          Enum.empty?(collection_params["collection_fields"]) ->
        {:noreply,
         socket
         |> clear_flash(:error)
         |> assign(:step, 2)
         |> put_flash(:error, "Please add at least one collection property.")
         |> assign(:form, to_form(socket.assigns.form, action: :validate))}

      # Check if items are empty
      is_nil(collection_params["items"]) ||
        collection_params["items"] == %{} ||
          Enum.empty?(collection_params["items"]) ->
        {:noreply,
         socket
         |> clear_flash(:error)
         |> assign(:step, 3)
         |> put_flash(:error, "Please add at least one item to the collection.")
         |> assign(:form, to_form(socket.assigns.form, action: :validate))}

      # Proceed with save if all checks pass
      true ->
        save_collection(socket, socket.assigns.action, collection_params)
    end
  end

  def handle_event("delete_thumbnail", %{"thumbnail" => thumbnail_path}, socket) do
    handle_delete_thumbnail(%{"thumbnail" => thumbnail_path}, socket)
  end

  def handle_event("progress", %{"upload_config" => "thumbnail"}, socket) do
    {:noreply, socket}
  end

  defp handle_progress(:thumbnail, entry, socket) do
    handle_thumbnail_progress(:thumbnail, entry, socket)
  end

  # defp error_to_string(:too_large), do: "Too large"
  # defp error_to_string(:too_many_files), do: "You have selected too many files"
  # defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
