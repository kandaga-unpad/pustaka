defmodule VoileWeb.Dashboard.Catalog.CollectionLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Metadata
  alias Voile.Schema.Master
  alias Ecto.Changeset

  import VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper
  import VoileWeb.Components.ImageUpload

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
          <h5>{gettext("Are you sure want to delete this field ?")}</h5>

          <p class="text-sm text-voile-dark">
            {gettext("This action cannot be undone. Please confirm your action.")}
          </p>

          <p class="text-sm italic font-semibold text-voile-error">
            {gettext("You will delete this property :")}
          </p>

          <div class="my-4">
            <h6 class="text-voile-primary">
              {(@chosen_collection_field && @chosen_collection_field.label) || ""}
            </h6>

            <p class="text-xs">{gettext("with value :")}</p>

            <h5 class="font-bold text-voile-dark dark:text-voile">
              {(@chosen_collection_field && @chosen_collection_field.value) || ""}
            </h5>

            <p class="text-xs">{gettext("from this collection :")}</p>

            <h6 class="text-voile-warning">{@collection.title}</h6>
          </div>

          <div class="flex items-center w-full my-5 gap-5">
            <.button
              class="w-full cancel-btn"
              phx-click={
                JS.push("delete_existed_field") |> hide_modal("col_field_delete_confirmation")
              }
              phx-value-id={@delete_field_confirmation_id}
              phx-target={@myself}
            >
              {gettext("Delete")}
            </.button>
            <.button
              class="w-full warning-btn"
              phx-click={hide_modal("col_field_delete_confirmation")}
              phx-target={@myself}
            >
              {gettext("Cancel")}
            </.button>
          </div>
        </div>
      </.modal>

      <.modal id="item_delete_confirmation">
        <div class="text-center">
          <h5>{gettext("Are you sure want to delete this item data?")}</h5>

          <p class="text-sm text-voile-dark">
            {gettext(
              "This action cannot be undone. Please confirm your action and make sure this item is not in use."
            )}
          </p>

          <div class="my-4">
            <p class="text-xs">{gettext("Item Code :")}</p>

            <h6 class="text-voile-primary">
              {(@chosen_item_field && @chosen_item_field.item_code) || ""}
            </h6>
          </div>

          <p class="text-sm">{gettext("will be deleted forever from this collection :")}</p>

          <h6 class="text-voile-warning">{@collection.title}</h6>
        </div>

        <div class="flex items-center w-full my-5 gap-5">
          <.button
            class="w-full cancel-btn"
            phx-click={JS.push("delete_existing_item") |> hide_modal("item_delete_confirmation")}
            phx-value-id={@delete_item_confirmation_id}
            phx-target={@myself}
          >
            {gettext("Delete")}
          </.button>
          <.button
            class="w-full warning-btn"
            phx-click={hide_modal("item_delete_confirmation")}
            phx-target={@myself}
          >
            {gettext("Cancel")}
          </.button>
        </div>
      </.modal>

      <.header>
        {@title}
        <:subtitle>
          {gettext("Use this form to manage collection records in your database.")}
        </:subtitle>
      </.header>

      <div class="text-xs italic">
        {if @action == :edit, do: gettext("Edit Collection"), else: gettext("New Collection")} - {gettext(
          "Step %{step} of 3", step: @step)}
      </div>

      <div class="mb-12">
        <%= case @step do %>
          <% 1 -> %>
            <p class="font-bold">{gettext("Step 1: Basic Information")}</p>
          <% 2 -> %>
            <p class="font-bold">
              {gettext("Step 2: Additional Collection Fields")}
            </p>
          <% 3 -> %>
            <p class="font-bold">
              {gettext("Step 3: Item Data and Attachments")}
            </p>
        <% end %>
      </div>

      <.form
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
            field={@form[:template_id]}
            label={gettext("Resource Template (Optional)")}
            type="select"
            options={Enum.map(@resource_templates, fn rt -> {rt.label, rt.id} end)}
            prompt={gettext("Select Resource Template")}
            phx-change="select_template"
            phx-target={@myself}
          />
          <.input
            field={@form[:type_id]}
            label={gettext("Resource Type")}
            type="select"
            options={
              @collection_type
              |> Enum.group_by(& &1.glam_type)
              |> Enum.sort_by(fn {group, _} -> group end)
              |> Enum.map(fn {group, items} ->
                sorted_items =
                  items |> Enum.sort_by(& &1.label) |> Enum.map(fn ct -> {ct.label, ct.id} end)

                {group, sorted_items}
              end)
            }
            prompt={gettext("Select Collection Type")}
            required_value={true}
          />
          
    <!-- Hierarchical Fields - Searchable Parent Collection -->
          <div class="mb-4">
            <label class="block text-sm font-medium mb-2 label">
              {gettext("Parent Collection (Optional)")}
            </label>
            <div class="relative">
              <.input
                type="text"
                name="parent_search"
                value={@parent_search || ""}
                placeholder={gettext("Search for parent collection...")}
                class="block w-full px-3 py-2 border border-voile-muted rounded-md shadow-sm focus:outline-none focus:ring-voile-primary focus:border-voile-primary"
                phx-change="search_parent"
                phx-target={@myself}
                phx-debounce="300"
                autocomplete="off"
              />
              <input
                type="hidden"
                name="collection[parent_id]"
                value={@form.params["parent_id"] || ""}
              />
              <%= if @parent_search_results && length(@parent_search_results) > 0 do %>
                <div class="absolute z-10 w-full mt-1 bg-voile-surface border border-voile-muted rounded-md shadow-lg max-h-60 overflow-auto">
                  <%= for collection <- @parent_search_results do %>
                    <div
                      class="px-4 py-2 hover:bg-voile-surface cursor-pointer border-b border-voile-light last:border-b-0"
                      phx-click="select_parent"
                      phx-target={@myself}
                      phx-value-id={collection.id}
                      phx-value-title={collection.title}
                    >
                      <div class="font-medium text-voile">{collection.title}</div>

                      <div class="text-sm text-voile-muted">
                        {gettext("by %{creator}",
                          creator:
                            (collection.mst_creator && collection.mst_creator.creator_name) ||
                              gettext("Unknown")
                        )}
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <%= if @form.params["parent_id"] && @form.params["parent_id"] != "" do %>
                <div class="mt-2 px-3 py-2 bg-voile-info border border-voile-light rounded-md flex items-center justify-between">
                  <span class="text-sm text-voile-primary">
                    {gettext("Selected: %{title}",
                      title: @selected_parent_title || gettext("Loading...")
                    )}
                  </span>
                  <button
                    type="button"
                    class="text-voile-primary hover:text-voile"
                    phx-click="clear_parent"
                    phx-target={@myself}
                  >
                    ✕
                  </button>
                </div>
              <% end %>
            </div>
          </div>

          <.input
            field={@form[:collection_type]}
            label={gettext("Collection Type")}
            type="select"
            options={Voile.Schema.Catalog.Collection.collection_type_options()}
            prompt={gettext("Select collection type")}
          />
          <.input
            field={@form[:sort_order]}
            label={gettext("Sort Order")}
            type="number"
            placeholder="1"
          />
          <%= if can_select_unit?(@current_scope) do %>
            <.input
              field={@form[:unit_id]}
              label={gettext("Collection Location")}
              type="select"
              options={Enum.map(@node_list, fn node -> {node.name, node.id} end)}
              prompt={gettext("Select Collection Location")}
              required_value={true}
            />
          <% else %>
            <input type="hidden" name={@form[:unit_id].name} value={@current_scope.user.node_id} />
            <div>
              <label class="block text-sm font-medium mb-2 label">
                {gettext("Collection Location (Your Unit)")}
              </label>
              <div class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400">
                {Enum.find(@node_list, fn n -> n.id == @current_scope.user.node_id end)
                |> then(fn n -> if n, do: n.name, else: gettext("Unknown") end)}
              </div>
            </div>
          <% end %>
          <.input field={@form[:title]} type="text" label={gettext("Title")} required_value={true} />
          <div class="relative" phx-hook="SearchDropdown" id={"creator-search-#{@form[:id].value}"}>
            <.input
              type="text"
              name="creator"
              value={@creator_input || ""}
              label={gettext("Creator")}
              disabled={@creator_input not in [nil, ""] and @form[:creator_id].value not in [nil, ""]}
              required_value={true}
              autocomplete="off"
              phx-change="search_creator"
              phx-debounce="300"
              phx-target={@myself}
            />
            <input
              type="hidden"
              name={@form[:creator_id].name}
              value={@form[:creator_id].value || ""}
            />
            <%= if @creator_searching do %>
              <div
                class="absolute right-3 top-10"
                aria-label={gettext("Searching creators")}
                role="status"
              >
                <svg
                  class="animate-spin h-5 w-5 text-voile-primary"
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

                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z">
                  </path>
                </svg>
              </div>
            <% end %>

            <%= if @creator_input not in [nil, ""] and (@form[:creator_id].value == nil or @form[:creator_id].value == "") do %>
              <div class="absolute z-10 w-full mt-1 bg-voile-surface border border-voile-muted rounded-md shadow-lg max-h-60 overflow-auto">
                <ul role="listbox" aria-label={gettext("Creator suggestions")}>
                  <%= for creator <- @creator_suggestions do %>
                    <li
                      role="option"
                      class="px-4 py-2 hover:bg-voile-primary/10 cursor-pointer border-b border-voile-light last:border-b-0 transition-colors"
                      phx-click="select_creator"
                      phx-target={@myself}
                      phx-value-id={creator.id}
                    >
                      <div class="font-medium">{creator.creator_name}</div>

                      <div class="text-xs text-voile-muted">{Map.get(creator, :affiliation, "")}</div>
                    </li>
                  <% end %>
                </ul>
                <%= if @creator_suggestions != [] and not @creator_suggestions_done do %>
                  <div class="px-4 py-2 border-t border-voile-light">
                    <.button
                      type="button"
                      phx-click="load_more_creator"
                      phx-target={@myself}
                      class="w-full text-sm text-voile-primary hover:text-voile-primary/80 font-medium"
                    >
                      {gettext("Load More")}
                    </.button>
                  </div>
                <% end %>
                <div class="px-4 py-2 border-t border-voile-light">
                  <.button
                    type="button"
                    phx-click="create_new_creator"
                    phx-value-creator={@creator_input}
                    phx-target={@myself}
                    class="w-full text-sm text-voile-warning hover:text-voile-warning/80 font-medium"
                  >
                    {gettext("Create \"%{creator}\" Author", creator: @creator_input)}
                  </.button>
                </div>
              </div>
            <% end %>
          </div>

          <%= if @form[:creator_id].value not in [nil, ""] do %>
            <.button type="button" phx-click="delete_creator" phx-target={@myself} class="cancel-btn">
              {gettext("Delete Author")}
            </.button>
          <% end %>

          <.input
            field={@form[:description]}
            type="textarea"
            label={gettext("Description")}
            rows="15"
            cols="33"
            required_value={true}
          />
          <%= if is_super_admin?(@current_scope.user) do %>
            <.input
              field={@form[:status]}
              type="select"
              label={gettext("Status")}
              options={get_status_options(@current_scope)}
              required_value={true}
            />
            <.input
              field={@form[:access_level]}
              type="select"
              label={gettext("Access Level")}
              options={[
                {gettext("Public"), "public"},
                {gettext("Private"), "private"},
                {gettext("Restricted"), "restricted"}
              ]}
              required_value={true}
            />
          <% else %>
            <input type="hidden" name={@form[:status].name} value={@form[:status].value || "pending"} />
            <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
              <strong>{gettext("Note:")}</strong>
              {gettext(
                "Click \"Save Collection\" to submit for review (pending), or \"Save as Draft\" to save without submitting."
              )}
            </p>
            <input type="hidden" name={@form[:access_level].name} value="private" />
            <.input
              field={@form[:access_level]}
              type="select"
              label={gettext("Access Level (Auto-set to Private)")}
              options={[{gettext("Private"), "private"}]}
              required_value={true}
              disabled={true}
            />
          <% end %>
          <.input field={@form[:thumbnail]} type="text" label={gettext("Thumbnail")} readonly />
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
            <.image_upload
              form={@form}
              field={:thumbnail}
              label="Thumbnail"
              upload_name={:thumbnail}
              tab={@tab}
              thumbnail_source={@thumbnail_source}
              thumbnail_url_input={@thumbnail_url_input}
              asset_vault_files={@asset_vault_files}
              shown_images_count={@shown_images_count}
              target={@myself}
              uploads={@uploads}
            />
          </div>
        <% end %>

        <%= if @step == 2 do %>
          <div>
            <div class="flex items-start gap-5">
              <div class="sticky top-0 w-full h-full max-w-72">
                <h5>{gettext("Collection Properties")}</h5>

                <div class="w-full h-full max-h-screen border border-1 border-voile-muted overflow-y-auto overflow-x-hidden rounded-xl mt-2 p-4">
                  <p class="text-xs italic mb-4 max-w-48">
                    {gettext(
                      "You can click each category below and pick any necessary property for your collection."
                    )}
                  </p>

                  <div>
                    <.input
                      type="text"
                      name="property_search"
                      label={gettext("Search Property")}
                      value={@property_search}
                      placeholder={gettext("Search property...")}
                      phx-keyup="search_properties"
                      phx-target={@myself}
                      phx-debounce="300"
                    />
                  </div>

                  <%= if Enum.empty?(@filtered_properties) do %>
                    <p class="text-red-500 text-sm mt-2">{gettext("No property found.")}</p>
                  <% else %>
                    <%= for {id, props} <- @filtered_properties do %>
                      <div class="my-5">
                        <h6
                          class="mb-4 border border-1 border-voile-muted rounded-xl p-2 hover:text-voile-primary cursor-pointer transition-all duration-1000"
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
                                class="btn hover-btn py-5 ml-3"
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
                  <p class="text-red-500 text-sm mt-2">
                    {gettext("No collection fields added yet.")}
                  </p>
                <% else %>
                  <div>
                    <.inputs_for :let={col_field} field={@form[:collection_fields]}>
                      <h6 class="bg-voile-primary px-4 py-1 rounded-t-xl text-white">
                        {col_field[:label].value}
                      </h6>

                      <div class="flex flex-col w-full bg-gray-100 dark:bg-gray-600 p-4 rounded-b-xl mb-4">
                        <p class="text-gray-500 dark:text-white italic pb-4">
                          <% mp = Map.get(col_field.data, :metadata_properties) %> {cond do
                            col_field[:information].value not in [nil, ""] ->
                              col_field[:information].value

                            mp && not match?(%Ecto.Association.NotLoaded{}, mp) ->
                              mp.information

                            true ->
                              ""
                          end}
                        </p>

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
                        <div class="grid grid-cols-5 items-start gap-2">
                          <.input
                            field={col_field[:value_lang]}
                            type="select"
                            label={gettext("Language")}
                            options={[
                              {gettext("Indonesia"), "id"},
                              {gettext("English"), "en"}
                            ]}
                          />
                          <div class="col-span-4">
                            <.input
                              field={col_field[:value]}
                              type={col_field[:type_value].value}
                              label={gettext("Value")}
                            />
                          </div>
                        </div>

                        <div class="w-full flex items-center gap-3 mt-2">
                          <%= if col_field[:id].value != nil do %>
                            <.button
                              type="button"
                              phx-click={
                                JS.push("delete_field_confirmation")
                                |> show_modal("col_field_delete_confirmation")
                              }
                              phx-target={@myself}
                              phx-value-id={col_field[:id].value}
                              class="cancel-btn w-full"
                            >
                              <.icon name="hero-trash-solid" class="w-4 h-4" /> {gettext(
                                "Delete Property"
                              )}
                            </.button>
                          <% else %>
                            <.button
                              type="button"
                              phx-click="delete_unsaved_field"
                              phx-target={@myself}
                              phx-value-index={col_field.index}
                              class="warning-btn w-full"
                            >
                              <.icon name="hero-x-circle-solid" class="w-4 h-4" /> {gettext(
                                "Remove Field"
                              )}
                            </.button>
                          <% end %>
                        </div>
                      </div>
                    </.inputs_for>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @step == 3 do %>
          <div>
            <div class="flex items-center justify-between mb-5">
              <h5>{gettext("The Items Data")}</h5>

              <div class="flex items-center gap-5">
                <.button
                  type="button"
                  phx-click="add_item_data"
                  phx-target={@myself}
                  class="primary-btn"
                >
                  <.icon name="hero-plus-circle-solid" class="w-4 h-4" /> {gettext("Add Item Data")}
                </.button>
              </div>
            </div>

            <div class="">
              <%= if @form[:items] == nil or Enum.empty?(@form[:items].value || []) do %>
                <p class="text-red-500 text-sm mt-2">
                  {gettext("No items is added yet. Create at least 1 item for each collection.")}
                </p>
              <% else %>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5 my-10">
                  <.inputs_for :let={item_field} field={@form[:items]}>
                    <div class="bg-gray-200 dark:bg-gray-600 rounded-lg p-5">
                      <div class="w-full flex items-center gap-3 mt-2">
                        <%= if item_field[:id].value != nil do %>
                          <.button
                            type="button"
                            phx-click={
                              JS.push("delete_item_confirmation")
                              |> show_modal("item_delete_confirmation")
                            }
                            phx-target={@myself}
                            phx-value-id={item_field[:id].value}
                            class="cancel-btn w-full"
                          >
                            <.icon name="hero-trash-solid" class="w-4 h-4" /> {gettext("Delete Item")}
                          </.button>
                        <% else %>
                          <.button
                            type="button"
                            phx-click="delete_unsaved_item"
                            phx-target={@myself}
                            phx-value-index={item_field.index}
                            class="warning-btn w-full"
                          >
                            <.icon name="hero-x-circle-solid" class="w-4 h-4" /> {gettext(
                              "Remove Item"
                            )}
                          </.button>
                        <% end %>
                      </div>

                      <.input
                        field={item_field[:item_code]}
                        type="text"
                        label={gettext("Item Code")}
                        required_value={true}
                      />
                      <.input
                        field={item_field[:inventory_code]}
                        type="text"
                        label={gettext("Inventory Code")}
                        required_value={true}
                      />
                      <input
                        type="hidden"
                        name={item_field[:barcode].name}
                        value={item_field[:barcode].value}
                      />
                      <.input
                        field={item_field[:barcode]}
                        type="text"
                        label={gettext("Barcode")}
                        required_value={true}
                        disabled
                      />
                      <.input
                        field={item_field[:legacy_item_code]}
                        type="text"
                        label={gettext("Legacy Item Code")}
                      />
                      <.input
                        field={item_field[:item_location_id]}
                        type="select"
                        label="Location"
                        options={
                          unit_id_int =
                            case item_field[:unit_id].value do
                              nil ->
                                nil

                              "" ->
                                nil

                              val when is_binary(val) ->
                                case Integer.parse(val) do
                                  {int, _} -> int
                                  :error -> nil
                                end

                              val ->
                                val
                            end

                          Enum.filter(@all_locations, &(&1.node_id == unit_id_int))
                          |> Enum.map(&{&1.location_name, &1.id})
                        }
                        prompt={gettext("Select Location")}
                      />
                      <.input
                        field={item_field[:location]}
                        type="text"
                        label={gettext("Location Details")}
                      />
                      <%= if can_select_unit?(@current_scope) do %>
                        <.input
                          field={item_field[:unit_id]}
                          type="select"
                          label={gettext("Unit Location")}
                          required_value={true}
                          options={Enum.map(@node_list, fn node -> {node.name, node.id} end)}
                        />
                      <% else %>
                        <input
                          type="hidden"
                          name={item_field[:unit_id].name}
                          value={item_field[:unit_id].value}
                        />
                        <div>
                          <label class="block text-sm font-medium mb-2 label">
                            {gettext("Unit Location")}
                          </label>
                          <div class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400">
                            {Enum.find(@node_list, fn n -> n.id == item_field[:unit_id].value end)
                            |> then(fn n -> if n, do: n.name, else: gettext("Unknown") end)}
                          </div>
                        </div>
                      <% end %>
                      <.input
                        field={item_field[:status]}
                        type="select"
                        label={gettext("Status")}
                        required_value={true}
                        options={[
                          {gettext("Active"), "active"},
                          {gettext("Inactive"), "inactive"},
                          {gettext("Lost"), "lost"},
                          {gettext("Damaged"), "damaged"},
                          {gettext("Discarded"), "discarded"}
                        ]}
                      />
                      <.input
                        field={item_field[:condition]}
                        type="select"
                        label={gettext("Condition")}
                        required_value={true}
                        options={[
                          {gettext("Excellent"), "excellent"},
                          {gettext("Good"), "good"},
                          {gettext("Fair"), "fair"},
                          {gettext("Poor"), "poor"},
                          {gettext("Damaged"), "damaged"}
                        ]}
                      />
                      <.input
                        field={item_field[:availability]}
                        type="select"
                        label="Availability"
                        required_value={true}
                        options={Item.availability_options()}
                      />
                    </div>
                  </.inputs_for>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <div class="mt-12 w-full flex justify-between items-center gap-5">
          <%= if @step > 1 do %>
            <.button
              type="button"
              phx-click="prev_step"
              phx-target={@myself}
              class="primary-btn w-full"
            >
              &leftarrow; {gettext("Back")}
            </.button>
          <% end %>

          <%= if @step == 3 do %>
            <.button
              type="button"
              phx-click="save_as_draft"
              phx-target={@myself}
              phx-disable-with="Saving as draft..."
              class="warning-btn w-full"
            >
              <.icon name="hero-document-text-solid" class="w-4 h-4" /> {gettext("Save as Draft")}
            </.button>
            <.button type="submit" phx-disable-with="Saving..." class="success-btn w-full">
              <.icon name="hero-check-circle-solid" class="w-4 h-4" /> {gettext("Save")}
            </.button>
          <% else %>
            <.button
              type="button"
              phx-click="save_as_draft"
              phx-target={@myself}
              phx-disable-with="Saving as draft..."
              class="warning-btn w-full"
            >
              <.icon name="hero-document-text-solid" class="w-4 h-4" /> {gettext("Save as Draft")}
            </.button>
            <.button
              type="button"
              phx-click="next_step"
              phx-target={@myself}
              class="primary-btn w-full"
            >
              {gettext("Next")} &rightarrow;
            </.button>
          <% end %>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{collection: collection} = assigns, socket) do
    type_options =
      assigns.collection_type
      |> Enum.map(fn type -> {type.label, type.id} end)

    # Load resource templates for selection
    resource_templates =
      Metadata.list_resource_template() |> Voile.Repo.preload([:resource_class, :owner])

    # Load all locations for item location selection
    all_locations = Master.list_mst_locations()

    # Don't load all potential parents on mount to avoid performance issues
    # Instead, we'll load them on search

    {original_collection, _changeset} =
      case assigns.action do
        :edit ->
          # Fetch fresh collection with preloads
          coll =
            Catalog.get_collection!(collection.id)
            |> Voile.Repo.preload([
              :mst_creator,
              :resource_template,
              collection_fields: [:metadata_properties]
            ])

          {coll, Catalog.change_collection(coll)}

        :new ->
          coll =
            collection
            |> Catalog.change_collection(%{})

          {nil, coll}
      end

    seed_source = if assigns.action == :edit, do: original_collection, else: collection

    # Initialize creator_input based on existing data
    initial_creator_input =
      case assigns.action do
        :edit when not is_nil(original_collection.mst_creator) ->
          original_collection.mst_creator.creator_name

        _ ->
          nil
      end

    seed_params =
      (seed_source.collection_fields || [])
      |> Enum.with_index()
      |> Enum.into(%{}, fn {field, idx} ->
        {to_string(idx),
         %{
           "id" => field.id,
           "label" => field.label,
           "information" =>
             case Map.get(field, :metadata_properties) do
               %Ecto.Association.NotLoaded{} -> ""
               nil -> ""
               mp -> mp.information
             end,
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
           "id" => item.id,
           "item_code" => item.item_code,
           "inventory_code" => item.inventory_code,
           "location" => item.location,
           "item_location_id" => item.item_location_id,
           "unit_id" => item.unit_id,
           "status" => item.status,
           "condition" => item.condition,
           "availability" => item.availability,
           "legacy_item_code" => item.legacy_item_code
         }}
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:original_collection, original_collection)
     |> assign(:resource_templates, resource_templates)
     |> assign(:parent_search, "")
     |> assign(:parent_search_results, [])
     |> assign(:selected_parent_title, get_selected_parent_title(collection))
     |> assign(:creator_input, initial_creator_input)
     |> assign(:creator_list, assigns.creator_list)
     |> assign(:creator_suggestions, [])
     |> assign(:creator_suggestions_offset, 0)
     |> assign(:creator_suggestions_done, false)
     |> assign(:creator_searching, false)
     |> assign(:step2_params, nil)
     |> assign(:step3_params, nil)
     |> assign(:type_options, type_options)
     |> assign(:uploaded_files, [])
     |> assign(:delete_field_confirmation_id, nil)
     |> assign(:delete_item_confirmation_id, nil)
     |> assign(:chosen_collection_field, nil)
     |> assign(:chosen_item_field, nil)
     |> assign(:property_search, "")
     |> assign(:all_locations, all_locations)
     |> assign(:filtered_properties, assigns.collection_properties)
     |> assign(:tab, "upload")
     |> assign(:thumbnail_source, nil)
     |> assign(:thumbnail_attachment_id, nil)
     |> assign(:thumbnail_url_input, "")
     |> assign(:asset_vault_files, Catalog.list_all_attachments("image"))
     |> assign(:shown_images_count, 12)
     |> allow_upload(:thumbnail,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> assign_new(:form, fn ->
       # Build form with all initial params
       # For new collections by non-super_admin, force their unit_id
       unit_id =
         case assigns.action do
           :new ->
             get_allowed_unit_id(assigns.current_scope, collection)

           :edit ->
             collection.unit_id
         end

       # RBAC: Default status - pending for librarians (submit for review), super_admin can choose
       default_status =
         if is_super_admin?(assigns.current_scope.user) do
           collection.status || "draft"
         else
           # For librarians, default to pending (will be set to draft if they click "Save as Draft")
           collection.status || "pending"
         end

       default_access_level =
         case assigns.action do
           :edit ->
             # For edit, use the existing value from database (or default to private if null)
             collection.access_level || "private"

           :new ->
             # For new collections, super_admin defaults to public, others to private
             if is_super_admin?(assigns.current_scope.user) do
               "public"
             else
               "private"
             end
         end

       initial_params =
         Map.merge(
           %{"collection_fields" => seed_params, "items" => item_params},
           %{
             "id" => collection.id || Ecto.UUID.generate(),
             "title" => collection.title || "",
             "description" => collection.description || "",
             "status" => default_status,
             "access_level" => default_access_level,
             "type_id" => collection.type_id || nil,
             "template_id" => collection.template_id || nil,
             "unit_id" => unit_id,
             "creator_id" => collection.creator_id || nil,
             "thumbnail" => collection.thumbnail || "",
             "thumbnail_source" => nil,
             "thumbnail_attachment_id" => nil,
             "parent_id" => collection.parent_id || nil,
             "collection_type" => collection.collection_type || nil,
             "sort_order" => collection.sort_order || 1
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
    # Keep validate focused on form validation only; suggestions are fetched via `search_creator`
    suggestions = socket.assigns.creator_suggestions || []

    current_params = socket.assigns.form.params || %{}
    updated_params = Map.merge(current_params, collection_params)

    # RBAC: Force unit_id for non-super_admin users
    updated_params =
      if can_select_unit?(socket.assigns.current_scope) do
        updated_params
      else
        Map.put(updated_params, "unit_id", socket.assigns.current_scope.user.node_id)
      end

    # RBAC: Force status and access_level for non-super admin users
    updated_params =
      if is_super_admin?(socket.assigns.current_scope.user) do
        updated_params
      else
        updated_params
        |> Map.put("status", "draft")
        |> Map.put("access_level", "private")
      end

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

    # RBAC: Force unit_id for non-super_admin users
    updated_params =
      if can_select_unit?(socket.assigns.current_scope) do
        updated_params
      else
        Map.put(updated_params, "unit_id", socket.assigns.current_scope.user.node_id)
      end

    # RBAC: Force access_level for non-super admin users, but allow draft/pending status
    updated_params =
      if is_super_admin?(socket.assigns.current_scope.user) do
        updated_params
      else
        updated_params
        |> Map.put("access_level", "private")
      end

    changeset =
      Catalog.change_collection(socket.assigns.collection, updated_params)

    # Preserve creator_input if creator_id is set (creator was already selected)
    # We rely on creator_input since mst_creator is not always loaded
    creator_input =
      if updated_params["creator_id"] && updated_params["creator_id"] != "" &&
           socket.assigns.creator_input do
        socket.assigns.creator_input
      else
        socket.assigns.creator_input
      end

    socket =
      socket
      |> assign(:creator_input, creator_input)
      |> assign(:form, to_form(changeset, action: :validate))

    {:noreply, socket}
  end

  def handle_event("validate", %{"property_search" => _value}, socket) do
    # Update assigns or do something with `value`
    {:noreply, socket}
  end

  def handle_event("search_creator", %{"value" => query}, socket) do
    # Don't search if a creator has already been selected
    creator_id = socket.assigns.form[:creator_id].value

    if creator_id not in [nil, ""] do
      {:noreply, socket}
    else
      # Mark searching true so UI can show a loading indicator
      socket = assign(socket, :creator_searching, true)

      suggestions =
        try do
          Voile.Schema.Master.search_mst_creator_names(query, 10, 0)
        rescue
          _ ->
            # Fallback to in-memory filtering
            Enum.filter(socket.assigns.creator_list || [], fn creator ->
              String.contains?(String.downcase(creator.creator_name), String.downcase(query))
            end)
        end

      done = length(suggestions) < 10

      socket =
        socket
        |> assign(:creator_searching, false)
        |> assign(:creator_input, query)
        |> assign(:creator_suggestions, suggestions)
        |> assign(:creator_suggestions_offset, 10)
        |> assign(:creator_suggestions_done, done)

      {:noreply, socket}
    end
  end

  # Accept `creator` param name (from phx-change on input) and forward to the same logic
  def handle_event("search_creator", %{"creator" => query}, socket) do
    handle_event("search_creator", %{"value" => query}, socket)
  end

  def handle_event("load_more_creator", _params, socket) do
    query = socket.assigns.creator_input
    offset = socket.assigns.creator_suggestions_offset

    more =
      try do
        Voile.Schema.Master.search_mst_creator_names(query, 10, offset)
      rescue
        _ ->
          # Fallback: since in-memory, just return empty (no more)
          []
      end

    done = length(more) < 10

    socket =
      socket
      |> assign(:creator_suggestions, socket.assigns.creator_suggestions ++ more)
      |> assign(:creator_suggestions_offset, offset + 10)
      |> assign(:creator_suggestions_done, done)

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

    dbg(changeset)

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
        |> put_flash(:error, gettext("Please fill in all required fields."))
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

  def handle_event("delete_field_confirmation", %{"id" => id}, socket) do
    {:noreply, confirm_field_deletion(id, socket)}
  end

  def handle_event("delete_item_confirmation", %{"id" => id}, socket) do
    {:noreply, confirm_item_deletion(id, socket)}
  end

  def handle_event("search_properties", %{"value" => query}, socket) do
    {:noreply, search_properties(query, socket)}
  end

  def handle_event("save", _params, socket) do
    collection_params = socket.assigns.form.params

    # RBAC: For librarians, save button submits for review (pending status)
    collection_params =
      if is_super_admin?(socket.assigns.current_scope.user) do
        collection_params
      else
        collection_params
        |> Map.put("status", "pending")
        |> Map.put("access_level", "private")
      end

    cond do
      # Check if collection fields are empty
      is_nil(collection_params["collection_fields"]) ||
        collection_params["collection_fields"] == %{} ||
          Enum.empty?(collection_params["collection_fields"]) ->
        {:noreply,
         socket
         |> clear_flash(:error)
         |> assign(:step, 2)
         |> put_flash(:error, gettext("Please add at least one collection property."))
         |> assign(:form, to_form(socket.assigns.form, action: :validate))}

      # Check if items are empty
      is_nil(collection_params["items"]) ||
        collection_params["items"] == %{} ||
          Enum.empty?(collection_params["items"]) ->
        {:noreply,
         socket
         |> clear_flash(:error)
         |> assign(:step, 3)
         |> put_flash(:error, gettext("Please add at least one item to the collection."))
         |> assign(:form, to_form(socket.assigns.form, action: :validate))}

      # Proceed with save if all checks pass
      true ->
        save_collection(socket, socket.assigns.action, collection_params)
    end
  end

  def handle_event("save_as_draft", _params, socket) do
    collection_params = socket.assigns.form.params

    # RBAC: Force status to draft and access_level to private for non-super admin users
    collection_params =
      if is_super_admin?(socket.assigns.current_scope.user) do
        Map.put(collection_params, "status", "draft")
      else
        collection_params
        |> Map.put("status", "draft")
        |> Map.put("access_level", "private")
      end

    save_collection_as_draft(socket, socket.assigns.action, collection_params)
  end

  def handle_event("load_more_images", _params, socket) do
    {:noreply, assign(socket, :shown_images_count, socket.assigns.shown_images_count + 12)}
  end

  # Parent collection search events
  def handle_event("search_parent", %{"parent_search" => search_term}, socket) do
    results =
      if String.trim(search_term) != "" do
        collection_id = socket.assigns.collection.id
        Catalog.search_potential_parent_collections(search_term, collection_id, 10)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:parent_search, search_term)
     |> assign(:parent_search_results, results)}
  end

  def handle_event("select_parent", %{"id" => parent_id, "title" => title}, socket) do
    current_params = socket.assigns.form.params || %{}
    updated_params = Map.put(current_params, "parent_id", parent_id)
    changeset = Catalog.change_collection(socket.assigns.collection, updated_params)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset, action: :validate))
     |> assign(:parent_search, "")
     |> assign(:parent_search_results, [])
     |> assign(:selected_parent_title, title)}
  end

  def handle_event("clear_parent", _params, socket) do
    current_params = socket.assigns.form.params || %{}
    updated_params = Map.put(current_params, "parent_id", nil)
    changeset = Catalog.change_collection(socket.assigns.collection, updated_params)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset, action: :validate))
     |> assign(:selected_parent_title, nil)}
  end

  def handle_event("select_template", %{"collection" => %{"template_id" => template_id}}, socket) do
    if template_id && template_id != "" do
      # Fetch the selected template with properties
      template =
        Metadata.get_resource_template!(template_id)
        |> Voile.Repo.preload([:resource_class, template_properties: [:property]])

      # Build collection fields from template properties
      template_fields =
        template.template_properties
        |> Enum.sort_by(& &1.position)
        |> Enum.with_index()
        |> Enum.into(%{}, fn {tp, idx} ->
          {to_string(idx),
           %{
             "id" => nil,
             "label" => tp.override_label || tp.property.label,
             "information" => tp.property.information,
             "type_value" => tp.property.type_value,
             "value_lang" => "en",
             "value" => tp.property.label,
             "sort_order" => tp.position,
             "property_id" => tp.property.id,
             "name" => tp.property.local_name || tp.property.label
           }}
        end)

      # Update form params with template fields and resource type
      current_params = socket.assigns.form.params || %{}

      updated_params =
        current_params
        |> Map.put("collection_fields", template_fields)
        |> Map.put("type_id", template.resource_class_id)

      changeset = Catalog.change_collection(socket.assigns.collection, updated_params)

      socket =
        socket
        |> assign(:form, to_form(changeset, action: :validate))
        |> put_flash(
          :info,
          gettext(
            "Template '%{template}' applied. Resource type and collection fields have been populated.",
            template: template.label
          )
        )

      {:noreply, socket}
    else
      # Clear template fields and resource type if no template selected
      current_params = socket.assigns.form.params || %{}

      updated_params =
        current_params
        |> Map.put("collection_fields", %{})
        |> Map.put("type_id", nil)

      changeset = Catalog.change_collection(socket.assigns.collection, updated_params)

      socket =
        socket
        |> assign(:form, to_form(changeset, action: :validate))

      {:noreply, socket}
    end
  end

  # Image upload event handlers
  def handle_event("switch_image_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  def handle_event("update_image_url", %{"image_url" => url}, socket) do
    {:noreply, assign(socket, :thumbnail_url_input, url)}
  end

  def handle_event("add_image_from_url", %{"url" => url}, socket) do
    # TODO: Implement URL image fetching
    # For now, just set the URL directly
    form_params = (socket.assigns.form.params || %{}) |> Map.put("thumbnail", url)

    socket =
      socket
      |> assign(:form, %{socket.assigns.form | params: form_params})
      |> assign(:thumbnail_source, "url")

    {:noreply, socket}
  end

  def handle_event("select_image_from_vault", %{"attachment_id" => attachment_id}, socket) do
    attachment = Catalog.get_attachment!(attachment_id)

    form_params =
      (socket.assigns.form.params || %{})
      |> Map.put("thumbnail", attachment.file_path)

    socket =
      socket
      |> assign(:form, %{socket.assigns.form | params: form_params})
      |> assign(:thumbnail_source, "vault")

    {:noreply, socket}
  end

  def handle_event("cancel_image_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :thumbnail, ref)}
  end

  def handle_event("delete_image", %{"image" => _image_path}, socket) do
    form_params = (socket.assigns.form.params || %{}) |> Map.put("thumbnail", "")

    socket =
      socket
      |> assign(:form, %{socket.assigns.form | params: form_params})
      |> assign(:thumbnail_source, nil)

    {:noreply, socket}
  end

  defp get_selected_parent_title(collection) do
    case collection do
      %{parent_id: parent_id} when not is_nil(parent_id) ->
        try do
          parent = Catalog.get_collection!(parent_id)
          parent.title
        rescue
          _ -> nil
        end

      _ ->
        nil
    end
  end

  # RBAC: Get status options for super admin
  defp get_status_options(_current_scope) do
    [
      {"Draft", "draft"},
      {"Pending", "pending"},
      {"Published", "published"},
      {"Archived", "archived"}
    ]
  end

  # RBAC: Check if user can select any unit (only super_admin)
  defp can_select_unit?(current_scope) do
    is_super_admin?(current_scope.user)
  end

  # RBAC: Get the unit_id that should be used for the collection
  defp get_allowed_unit_id(current_scope, collection) do
    cond do
      # Super admin can use any unit (from collection or nil)
      can_select_unit?(current_scope) ->
        collection.unit_id

      # Other users must use their own unit_id (from node_id field)
      true ->
        current_scope.user.node_id
    end
  end

  def handle_progress(:thumbnail, entry, socket) do
    if entry.done? do
      # Consume the upload and save using Client.Storage for preview
      [uploaded_path] =
        consume_uploaded_entries(socket, :thumbnail, fn meta, entry ->
          # Use Client.Storage to upload the file to asset_vault folder
          file_params = %{
            path: meta.path,
            filename: entry.client_name,
            content_type: entry.client_type,
            size: entry.client_size
          }

          {:ok, url} =
            Client.Storage.upload(file_params,
              folder: "asset_vault",
              generate_filename: true,
              create_attachment: true,
              attachable_id: socket.assigns.form.params["id"],
              attachable_type: "asset_vault",
              access_level: "restricted",
              file_type: "image"
            )

          {:ok, url}
        end)

      form_params = (socket.assigns.form.params || %{}) |> Map.put("thumbnail", uploaded_path)

      socket =
        socket
        |> assign(:form, %{socket.assigns.form | params: form_params})
        |> assign(:thumbnail_source, "local")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
end
