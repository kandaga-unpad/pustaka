defmodule VoileWeb.Dashboard.Members.Management.Component do
  use Phoenix.Component

  import VoileWeb.CoreComponents
  import VoileWeb.VoileDashboardComponents
  import VoileWeb.Components.ImageUpload

  # Form Component
  attr :form, :map, required: true
  attr :member, :map, default: nil
  attr :action, :atom, required: true
  attr :nodes, :list, default: []
  attr :member_types, :list, default: []
  attr :available_roles, :list, default: []
  attr :selected_role_ids, :list, default: []
  attr :is_super_admin, :boolean, default: false
  attr :tab, :string, default: "upload"
  attr :thumbnail_source, :string, default: nil
  attr :thumbnail_url_input, :string, default: ""
  attr :asset_vault_files, :list, default: []
  attr :shown_images_count, :integer, default: 12
  attr :uploads, :map, default: %{}
  attr :show_header, :boolean, default: true
  attr :show_breadcrumb, :boolean, default: true
  attr :submit_event, :string, default: "save"
  attr :button_text, :string, default: "Save"

  def member_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @show_breadcrumb do %>
        <%!-- Breadcrumb --%>
        <.breadcrumb items={[
          %{label: "Manage", path: "/manage"},
          %{label: "Members", path: "/manage/members"},
          %{label: "Management", path: "/manage/members/management"},
          %{label: @member.fullname || "New Member", path: nil}
        ]} />
      <% end %>

      <%= if @show_header do %>
        <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
          <div class="flex items-center gap-3 mb-6">
            <.icon name="hero-user" class="w-8 h-8 text-voile-primary" />
            <div>
              <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
                {if @action == :new, do: "Add New Member", else: "Edit Member"}
              </h1>
              <p class="text-gray-600 dark:text-gray-300">
                {if @action == :new,
                  do: "Create a new library member account",
                  else: "Update member information"}
              </p>
            </div>
          </div>
        </div>
      <% end %>

      <.form for={@form} phx-submit={@submit_event} phx-change="validate" class="space-y-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <.input field={@form[:fullname]} type="text" label="Full Name" required />
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:username]} type="text" label="Username" required />
          <.input
            field={@form[:identifier]}
            type="text"
            label="Member Identifier"
            placeholder="Member ID or Student Number"
          />

          <%= if @action == :new do %>
            <.input field={@form[:password]} type="password" label="Password" required />
          <% end %>

          <.input field={@form[:phone_number]} type="tel" label="Phone Number" />
          <.input field={@form[:birth_date]} type="date" label="Birth Date" />
          <.input field={@form[:address]} type="textarea" label="Address" />
          <.input field={@form[:organization]} type="text" label="Organization" />

          <%= if @is_super_admin do %>
            <.input
              field={@form[:node_id]}
              type="select"
              label="Node"
              options={Enum.map(@nodes, &{&1.name, &1.id})}
            />
          <% end %>

          <.input
            field={@form[:user_type_id]}
            type="select"
            label="Member Type"
            options={Enum.map(@member_types, &{&1.name, &1.id})}
            required
          />

          <.input field={@form[:registration_date]} type="date" label="Registration Date" />
          <.input field={@form[:expiry_date]} type="date" label="Expiry Date" />
        </div>

        <div class="grid grid-cols-1 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Assign Roles
            </label>
            <div class="space-y-2 grid grid-cols-1 md:grid-cols-3 gap-4">
              <%= for role <- @available_roles do %>
                <label class="flex items-center gap-2 p-3 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600 cursor-pointer">
                  <input
                    type="checkbox"
                    name="user[role_ids][]"
                    value={role.id}
                    checked={role.id in (@selected_role_ids || [])}
                    class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                  <div class="flex-1">
                    <div class="font-medium text-gray-900 dark:text-gray-100 capitalize">
                      {role.name}
                    </div>

                    <%= if role.description do %>
                      <div class="text-sm text-gray-500 dark:text-gray-400">{role.description}</div>
                    <% end %>
                  </div>
                </label>
              <% end %>
            </div>

            <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
              Users can have multiple roles. Role-specific permissions can be managed in the
              <.link navigate="/manage/settings/roles" class="text-blue-600 hover:underline">
                Role Management
              </.link>
              page.
            </p>
          </div>
        </div>

        <div class="mt-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">User Image</label>
          <%= if @member.user_image && @member.user_image != "" do %>
            <div class="space-y-4">
              <div>
                <img
                  src={@member.user_image}
                  class="w-32 h-32 rounded-full object-cover border border-gray-300"
                />
              </div>
              <button
                type="button"
                phx-click="remove_user_image"
                class="text-red-600 hover:text-red-800 text-sm font-medium"
              >
                <.icon name="hero-trash" class="w-4 h-4 inline mr-1" /> Remove Picture
              </button>
            </div>
          <% else %>
            <.image_upload
              form={@form}
              field={:user_image}
              label="Profile Picture"
              upload_name={:user_image}
              tab={@tab || "upload"}
              thumbnail_source={@thumbnail_source}
              thumbnail_url_input={@thumbnail_url_input}
              asset_vault_files={@asset_vault_files || []}
              shown_images_count={@shown_images_count || 12}
              uploads={@uploads}
            />
          <% end %>
        </div>

        <.input field={@form[:user_image]} type="hidden" />

        <fieldset class="border border-gray-300 rounded-lg p-4">
          <legend class="text-sm font-medium text-gray-900 dark:text-gray-100 px-2">
            Social Media
          </legend>

          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 mt-2">
            <.input field={@form[:twitter]} type="text" label="Twitter" placeholder="@username" />
            <.input field={@form[:facebook]} type="text" label="Facebook" placeholder="profile-url" />
            <.input field={@form[:linkedin]} type="text" label="LinkedIn" placeholder="profile-url" />
            <.input field={@form[:instagram]} type="text" label="Instagram" placeholder="@username" />
          </div>

          <div class="mt-4">
            <.input
              field={@form[:website]}
              type="url"
              label="Website"
              placeholder="https://example.com"
            />
          </div>
        </fieldset>

        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <.input
            field={@form[:groups]}
            type="text"
            label="Groups (comma-separated)"
            placeholder="group1, group2, group3"
          />
        </div>

        <div class="flex items-center gap-4 pt-6 border-t border-gray-200 dark:border-gray-600">
          <.button type="submit" class="primary-btn">
            <.icon
              name={if @action == :new, do: "hero-plus", else: "hero-check"}
              class="w-4 h-4 mr-2"
            />
            {@button_text}
          </.button>

          <%= if @show_header do %>
            <.link
              patch="/manage/members/management"
              class="text-gray-600 hover:text-gray-800 dark:text-gray-400 dark:hover:text-gray-200"
            >
              Cancel
            </.link>
          <% else %>
            <.link
              patch="/manage/members/management/#{@member.id}"
              class="text-gray-600 hover:text-gray-800 dark:text-gray-400 dark:hover:text-gray-200"
            >
              Cancel
            </.link>
          <% end %>
        </div>
      </.form>
    </div>
    """
  end

  # Tab Components

  attr :member, :map, required: true
  attr :stats, :map, required: true

  def overview_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Personal Information --%>
      <div>
        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Personal Information</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Full Name
            </label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">{@member.fullname || "-"}</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Username</label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">{@member.username || "-"}</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Member Identifier
            </label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">{@member.identifier || "-"}</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Phone</label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">{@member.phone_number || "-"}</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Birth Date
            </label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">
              {if @member.birth_date,
                do: Calendar.strftime(@member.birth_date, "%B %d, %Y"),
                else: "-"}
            </p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Address</label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">{@member.address || "-"}</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Organization
            </label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">{@member.organization || "-"}</p>
          </div>
        </div>
      </div>

      <%!-- Membership Information --%>
      <div>
        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Membership Information</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Member Type
            </label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">
              {(@member.user_type && @member.user_type.name) || "-"}
            </p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Registration Date
            </label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">
              {if @member.registration_date,
                do: Calendar.strftime(@member.registration_date, "%B %d, %Y"),
                else: "-"}
            </p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Expiry Date
            </label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">
              {if @member.expiry_date,
                do: Calendar.strftime(@member.expiry_date, "%B %d, %Y"),
                else: "-"}
            </p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Node</label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">
              {(@member.node && @member.node.name) || "-"}
            </p>
          </div>
        </div>
      </div>

      <%!-- Roles --%>
      <div>
        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Roles</h3>
        <div class="space-y-2">
          <%= if @member.roles && @member.roles != [] do %>
            <%= for role <- @member.roles do %>
              <div class="flex items-center gap-2 p-3 border border-gray-300 dark:border-gray-600 rounded-lg">
                <div class="flex-1">
                  <div class="font-medium text-gray-900 dark:text-gray-100 capitalize">
                    {role.name}
                  </div>
                  <%= if role.description do %>
                    <div class="text-sm text-gray-500 dark:text-gray-400">{role.description}</div>
                  <% end %>
                </div>
              </div>
            <% end %>
          <% else %>
            <p class="text-sm text-gray-500 dark:text-gray-400">No roles assigned</p>
          <% end %>
        </div>
      </div>

      <%!-- User Image --%>
      <div>
        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">User Image</h3>
        <%= if @member.user_image do %>
          <img src={@member.user_image} class="w-32 h-32 rounded-full object-cover" />
        <% else %>
          <p class="text-sm text-gray-500 dark:text-gray-400">No image uploaded</p>
        <% end %>
      </div>

      <%!-- Social Media --%>
      <div>
        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Social Media</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Twitter</label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">
              {if @member.twitter, do: "@#{@member.twitter}", else: "-"}
            </p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Facebook</label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">{@member.facebook || "-"}</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">LinkedIn</label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">{@member.linkedin || "-"}</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Instagram
            </label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">
              {if @member.instagram, do: "@#{@member.instagram}", else: "-"}
            </p>
          </div>
          <div class="md:col-span-2">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Website</label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">{@member.website || "-"}</p>
          </div>
        </div>
      </div>

      <%!-- Groups --%>
      <div>
        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Groups</h3>
        <p class="text-sm text-gray-900 dark:text-white">
          {if @member.groups && @member.groups != [], do: Enum.join(@member.groups, ", "), else: "-"}
        </p>
      </div>

      <%!-- Statistics Cards --%>
      <div>
        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Statistics</h3>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <.stat_card
            title="Total Loans"
            value={@stats.total_loans}
            icon="hero-book-open"
            color="blue"
          />
          <.stat_card
            title="Active Loans"
            value={@stats.active_loans}
            icon="hero-clock"
            color="orange"
          />
          <.stat_card
            title="Total Fines"
            value={@stats.total_fines}
            icon="hero-currency-dollar"
            color="red"
          />
          <.stat_card
            title="Overdue Items"
            value={@stats.overdue_items}
            icon="hero-exclamation-triangle"
            color="red"
          />
        </div>
      </div>
    </div>
    """
  end

  attr :member, :map, required: true

  def activity_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <h3 class="text-lg font-medium text-gray-900 dark:text-white">Recent Activity</h3>
      <p class="text-gray-600 dark:text-gray-300">Activity history will be displayed here.</p>
    </div>
    """
  end

  attr :member, :map, required: true

  def loans_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <h3 class="text-lg font-medium text-gray-900 dark:text-white">Current Loans</h3>
      <p class="text-gray-600 dark:text-gray-300">Current loans will be displayed here.</p>
    </div>
    """
  end

  attr :member, :map, required: true

  def fines_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <h3 class="text-lg font-medium text-gray-900 dark:text-white">Fines & Payments</h3>
      <p class="text-gray-600 dark:text-gray-300">
        Fines and payment history will be displayed here.
      </p>
    </div>
    """
  end

  attr :member, :map, required: true
  attr :form, :map, required: true

  def extend_membership_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Extend Membership</h3>
        <p class="text-gray-600 dark:text-gray-300 mb-6">
          Extend the membership expiry date for {@member.fullname}.
        </p>
      </div>

      <.form for={@form} phx-submit="extend_membership" class="space-y-6">
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Current Expiry Date
          </label>
          <p class="text-sm text-gray-900 dark:text-white">
            {if @member.expiry_date,
              do: Calendar.strftime(@member.expiry_date, "%B %d, %Y"),
              else: "No expiry date set"}
          </p>
        </div>

        <div>
          <.input
            field={@form[:extend_days]}
            type="number"
            label="Extend by (days)"
            placeholder="30"
            min="1"
            required
          />
        </div>

        <div class="flex items-center gap-4">
          <.button type="submit" class="success-btn">
            <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" /> Extend Membership
          </.button>

          <.link
            patch="/manage/members/management/#{@member.id}"
            class="text-gray-600 hover:text-gray-800 dark:text-gray-400 dark:hover:text-gray-200"
          >
            Cancel
          </.link>
        </div>
      </.form>
    </div>
    """
  end

  attr :member, :map, required: true
  attr :form, :map, required: true

  def change_password_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Change Password</h3>
        <p class="text-gray-600 dark:text-gray-300 mb-6">
          Change the password for {@member.fullname}.
        </p>
      </div>

      <.form for={@form} phx-submit="change_password" class="space-y-6">
        <div>
          <.input
            field={@form[:new_password]}
            type="password"
            label="New Password"
            required
          />
        </div>

        <div>
          <.input
            field={@form[:confirm_password]}
            type="password"
            label="Confirm New Password"
            required
          />
        </div>

        <div class="flex items-center gap-4">
          <.button type="submit" class="warning-btn">
            <.icon name="hero-key" class="w-4 h-4 mr-2" /> Change Password
          </.button>

          <.link
            patch="/manage/members/management/#{@member.id}"
            class="text-gray-600 hover:text-gray-800 dark:text-gray-400 dark:hover:text-gray-200"
          >
            Cancel
          </.link>
        </div>
      </.form>
    </div>
    """
  end

  attr :active, :boolean, required: true
  attr :rest, :global
  slot :inner_block, required: true

  def tab_button(assigns) do
    ~H"""
    <button
      class={"px-6 py-3 text-sm font-medium border-b-2 #{if @active, do: "border-voile-primary text-voile-primary", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :member, :map, required: true

  def delete_member_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-medium text-red-600 dark:text-red-400 mb-4">Delete Member</h3>
        <p class="text-gray-600 dark:text-gray-300 mb-6">
          Permanently delete {@member.fullname}'s account. This action cannot be undone.
        </p>
      </div>

      <div class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-6">
        <div class="flex items-start gap-3">
          <.icon
            name="hero-exclamation-triangle"
            class="w-6 h-6 text-red-600 dark:text-red-400 flex-shrink-0 mt-0.5"
          />
          <div>
            <h4 class="text-sm font-medium text-red-800 dark:text-red-200 mb-2">
              Warning: This action is irreversible
            </h4>
            <p class="text-sm text-red-700 dark:text-red-300 mb-4">
              Deleting this member will permanently remove all their data including:
            </p>
            <ul class="text-sm text-red-700 dark:text-red-300 list-disc list-inside space-y-1 mb-4">
              <li>Account information and login credentials</li>
              <li>Transaction history and current loans</li>
              <li>Fine records and payment history</li>
              <li>Membership and expiry information</li>
            </ul>
            <p class="text-sm font-medium text-red-800 dark:text-red-200">
              Are you sure you want to proceed?
            </p>
          </div>
        </div>
      </div>

      <div class="flex items-center gap-4 pt-6 border-t border-gray-200 dark:border-gray-600">
        <.button
          type="button"
          phx-click="delete_member_confirm"
          class="cancel-btn"
          data-confirm="Are you absolutely sure you want to delete this member? This action cannot be undone."
        >
          <.icon name="hero-trash" class="w-4 h-4 mr-2" /> Delete Member Permanently
        </.button>

        <.link
          patch="/manage/members/management/#{@member.id}"
          class="text-gray-600 hover:text-gray-800 dark:text-gray-400 dark:hover:text-gray-200"
        >
          Cancel
        </.link>
      </div>
    </div>
    """
  end
end
