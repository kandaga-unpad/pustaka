defmodule VoileWeb.Dashboard.Members.Management.Component do
  use Phoenix.Component

  import VoileWeb.CoreComponents
  import VoileWeb.VoileDashboardComponents

  # Form Component
  attr :form, :map, required: true
  attr :member, :map, default: nil
  attr :action, :atom, required: true
  attr :nodes, :list, default: []
  attr :member_types, :list, default: []
  attr :is_super_admin, :boolean, default: false

  def member_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Breadcrumb --%>
      <.breadcrumb items={[
        %{label: "Manage", path: "/manage"},
        %{label: "Members", path: "/manage/members"},
        %{label: "Management", path: "/manage/members/management"},
        %{label: @member.fullname, path: nil}
      ]} />

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

        <.form for={@form} phx-submit="save" phx-change="validate" class="space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.input field={@form[:fullname]} type="text" label="Full Name" required />
            <.input field={@form[:email]} type="email" label="Email" required />
            <.input field={@form[:username]} type="text" label="Username" required />

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

          <div class="flex items-center gap-4 pt-6 border-t border-gray-200 dark:border-gray-600">
            <.button type="submit" class="bg-voile-primary hover:bg-voile-primary/90 text-white">
              <.icon
                name={if @action == :new, do: "hero-plus", else: "hero-check"}
                class="w-4 h-4 mr-2"
              />
              {if @action == :new, do: "Create Member", else: "Update Member"}
            </.button>

            <.link
              patch="/manage/members/management"
              class="text-gray-600 hover:text-gray-800 dark:text-gray-400 dark:hover:text-gray-200"
            >
              Cancel
            </.link>
          </div>
        </.form>
      </div>
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
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">Email</label>
            <p class="mt-1 text-sm text-gray-900 dark:text-white">{@member.email || "-"}</p>
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
  attr :form, :map, required: true
  attr :nodes, :list, default: []
  attr :member_types, :list, default: []
  attr :is_super_admin, :boolean, default: false

  def edit_member_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">
          Edit Member Information
        </h3>
        <p class="text-gray-600 dark:text-gray-300 mb-6">
          Update {@member.fullname}'s account information.
        </p>
      </div>

      <.form for={@form} phx-submit="update_member" phx-change="validate" class="space-y-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <.input field={@form[:fullname]} type="text" label="Full Name" required />
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:username]} type="text" label="Username" required />

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

        <div class="flex items-center gap-4 pt-6 border-t border-gray-200 dark:border-gray-600">
          <.button type="submit" class="success-btn">
            <.icon name="hero-check" class="w-4 h-4 mr-2" /> Update Member
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
