defmodule VoileWeb.Dashboard.Members.Management.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Library.Transaction
  alias Voile.Schema.Library.Fine
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.System.Node
  alias VoileWeb.Auth.Authorization

  import Ecto.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    member = Repo.get!(User, id) |> Repo.preload([:user_type, :node, :transactions, :fines])

    user = socket.assigns.current_scope.user
    is_super_admin = Authorization.is_super_admin?(user)

    socket =
      socket
      |> assign(:page_title, "Member Details - #{member.fullname}")
      |> assign(:member, member)
      |> assign(:active_tab, "overview")
      |> assign(:is_super_admin, is_super_admin)
      |> load_member_stats()
      |> load_filters()

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    tab = params["tab"] || action_to_tab(socket.assigns.live_action)
    member = Repo.get!(User, id) |> Repo.preload([:user_type, :node, :transactions, :fines])

    socket =
      socket
      |> assign(:member, member)
      |> assign(:active_tab, tab)
      |> assign_edit_form_if_needed()
      |> assign_extend_form_if_needed()
      |> assign_password_form_if_needed()
      |> load_member_stats()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    socket = assign(socket, :active_tab, tab)

    # Initialize forms when switching to specific tabs
    socket =
      case tab do
        "edit" ->
          assign(socket, :edit_form, to_form(User.changeset(socket.assigns.member, %{})))

        "extend" ->
          assign(socket, :extend_form, to_form(%{"extend_days" => "30"}))

        "change_password" ->
          assign(
            socket,
            :password_form,
            to_form(%{"new_password" => "", "confirm_password" => ""})
          )

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("extend_membership", %{"extend_days" => extend_days}, socket) do
    member = socket.assigns.member

    {days, _} = Integer.parse(extend_days)
    new_expiry_date = Date.add(member.expiry_date || Date.utc_today(), days)

    changeset = Ecto.Changeset.change(member, %{expiry_date: new_expiry_date})

    case Repo.update(changeset) do
      {:ok, updated_member} ->
        socket =
          socket
          |> assign(:member, updated_member)
          |> put_flash(:info, "Membership extended successfully by #{days} days")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to extend membership")}
    end
  end

  @impl true
  def handle_event(
        "change_password",
        %{"new_password" => new_password, "confirm_password" => confirm_password},
        socket
      ) do
    member = socket.assigns.member

    if new_password != confirm_password do
      {:noreply, put_flash(socket, :error, "Passwords do not match")}
    else
      changeset = User.changeset(member, %{password: new_password})

      case Repo.update(changeset) do
        {:ok, _updated_member} ->
          socket =
            socket
            |> put_flash(:info, "Password changed successfully")

          {:noreply, push_patch(socket, to: ~p"/manage/members/management/#{member.id}")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to change password")}
      end
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = User.changeset(socket.assigns.member, user_params)
    {:noreply, assign(socket, edit_form: to_form(changeset, action: :validate))}
  end

  def handle_event("update_member", %{"user" => user_params}, socket) do
    case Repo.update(User.changeset(socket.assigns.member, user_params)) do
      {:ok, updated_member} ->
        socket =
          socket
          |> assign(:member, updated_member)
          |> put_flash(:info, "Member updated successfully")

        {:noreply, push_patch(socket, to: ~p"/manage/members/management/#{updated_member.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, edit_form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete_member_confirm", _params, socket) do
    member = socket.assigns.member

    case Repo.delete(member) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Member deleted successfully")

        {:noreply, push_navigate(socket, to: ~p"/manage/members/management")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete member")}
    end
  end

  @impl true
  def handle_event("suspend_member", _params, socket) do
    member = socket.assigns.member

    changeset =
      User.changeset(member, %{
        manually_suspended: true,
        suspension_reason: "Suspended by admin",
        suspended_at: DateTime.utc_now(),
        suspended_by_id: socket.assigns.current_scope.user.id
      })

    case Repo.update(changeset) do
      {:ok, updated_member} ->
        socket =
          socket
          |> assign(:member, updated_member)
          |> put_flash(:info, "Member suspended successfully")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to suspend member")}
    end
  end

  @impl true
  def handle_event("unsuspend_member", _params, socket) do
    member = socket.assigns.member

    changeset =
      User.changeset(member, %{
        manually_suspended: false,
        suspension_reason: nil,
        suspended_at: nil,
        suspended_by_id: nil
      })

    case Repo.update(changeset) do
      {:ok, updated_member} ->
        socket =
          socket
          |> assign(:member, updated_member)
          |> put_flash(:info, "Member unsuspended successfully")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to unsuspend member")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Breadcrumb --%>
      <.breadcrumb items={[
        %{label: "Manage", path: ~p"/manage"},
        %{label: "Members", path: ~p"/manage/members"},
        %{label: "Management", path: ~p"/manage/members/management"},
        %{label: @member.fullname, path: nil}
      ]} />

      <%!-- Member Header --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-4">
            <div class="flex-shrink-0 h-16 w-16">
              <div class="h-16 w-16 rounded-full bg-voile-light flex items-center justify-center">
                <span class="text-xl font-medium text-gray-700">
                  {String.first(@member.fullname || "?")}
                </span>
              </div>
            </div>
            <div>
              <h1 class="text-2xl font-bold text-gray-900 dark:text-white">{@member.fullname}</h1>
              <p class="text-gray-600 dark:text-gray-300">{@member.email}</p>
              <p class="text-sm text-gray-500 dark:text-gray-400">@{@member.username}</p>
            </div>
          </div>

          <div class="flex items-center gap-3">
            <span class={"inline-flex px-3 py-1 text-sm font-semibold rounded-full #{status_badge_class(@member)}"}>
              {member_status(@member)}
            </span>

            <%= if can?(@current_scope.user, "users.update") do %>
              <%= if @member.manually_suspended do %>
                <.button
                  phx-click="unsuspend_member"
                  class="bg-green-600 hover:bg-green-700 text-white"
                >
                  <.icon name="hero-play" class="w-4 h-4 mr-2" /> Unsuspend
                </.button>
              <% else %>
                <.button phx-click="suspend_member" class="final-btn">
                  <.icon name="hero-pause" class="w-4 h-4 mr-2" /> Suspend
                </.button>
              <% end %>
            <% end %>

            <%= if can?(@current_scope.user, "users.update") do %>
              <.link
                patch={~p"/manage/members/management/#{@member.id}/edit"}
                class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md"
              >
                <.icon name="hero-pencil" class="w-4 h-4 mr-2" /> Edit
              </.link>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Tabs --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg">
        <div class="border-b border-gray-200 dark:border-gray-600">
          <nav class="flex">
            <.tab_button
              active={@active_tab == "overview"}
              phx-click="change_tab"
              phx-value-tab="overview"
            >
              Overview
            </.tab_button>
            <.tab_button
              active={@active_tab == "edit"}
              phx-click="change_tab"
              phx-value-tab="edit"
            >
              Edit Member
            </.tab_button>
            <.tab_button
              active={@active_tab == "extend"}
              phx-click="change_tab"
              phx-value-tab="extend"
            >
              Extend Membership
            </.tab_button>
            <.tab_button
              active={@active_tab == "change_password"}
              phx-click="change_tab"
              phx-value-tab="change_password"
            >
              Change Password
            </.tab_button>
            <.tab_button
              active={@active_tab == "delete"}
              phx-click="change_tab"
              phx-value-tab="delete"
            >
              Delete Member
            </.tab_button>
            <.tab_button
              active={@active_tab == "activity"}
              phx-click="change_tab"
              phx-value-tab="activity"
            >
              Activity History
            </.tab_button>
            <.tab_button
              active={@active_tab == "loans"}
              phx-click="change_tab"
              phx-value-tab="loans"
            >
              Current Loans
            </.tab_button>
            <.tab_button
              active={@active_tab == "fines"}
              phx-click="change_tab"
              phx-value-tab="fines"
            >
              Fines & Payments
            </.tab_button>
          </nav>
        </div>

        <div class="p-6">
          <%= case @active_tab do %>
            <% "overview" -> %>
              <.overview_tab member={@member} stats={@stats} />
            <% "edit" -> %>
              <.edit_member_tab
                member={@member}
                form={@edit_form}
                nodes={@nodes}
                member_types={@member_types}
                is_super_admin={@is_super_admin}
              />
            <% "extend" -> %>
              <.extend_membership_tab member={@member} form={@extend_form} />
            <% "change_password" -> %>
              <.change_password_tab member={@member} form={@password_form} />
            <% "delete" -> %>
              <.delete_member_tab member={@member} />
            <% "activity" -> %>
              <.activity_tab member={@member} />
            <% "loans" -> %>
              <.loans_tab member={@member} />
            <% "fines" -> %>
              <.fines_tab member={@member} />
          <% end %>
        </div>
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
          <.button type="submit" class="bg-green-600 hover:bg-green-700 text-white">
            <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" /> Extend Membership
          </.button>

          <.link
            patch={~p"/manage/members/management/#{@member.id}"}
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
          <.button type="submit" class="bg-orange-600 hover:bg-orange-700 text-white">
            <.icon name="hero-key" class="w-4 h-4 mr-2" /> Change Password
          </.button>

          <.link
            patch={~p"/manage/members/management/#{@member.id}"}
            class="text-gray-600 hover:text-gray-800 dark:text-gray-400 dark:hover:text-gray-200"
          >
            Cancel
          </.link>
        </div>
      </.form>
    </div>
    """
  end

  # Private functions

  defp load_member_stats(socket) do
    member = socket.assigns.member

    # Calculate stats
    total_loans =
      Repo.aggregate(from(t in Transaction, where: t.member_id == ^member.id), :count, :id)

    active_loans =
      Repo.aggregate(
        from(t in Transaction,
          where: t.member_id == ^member.id and is_nil(t.return_date)
        ),
        :count,
        :id
      )

    total_fines = Repo.aggregate(from(f in Fine, where: f.member_id == ^member.id), :count, :id)

    overdue_items =
      Repo.aggregate(
        from(t in Transaction,
          where:
            t.member_id == ^member.id and
              is_nil(t.return_date) and
              fragment("DATE(?) < ?", t.due_date, ^Date.utc_today())
        ),
        :count,
        :id
      )

    stats = %{
      total_loans: total_loans,
      active_loans: active_loans,
      total_fines: total_fines,
      overdue_items: overdue_items
    }

    assign(socket, :stats, stats)
  end

  # Helper functions

  defp load_filters(socket) do
    member_types = Repo.all(from(mt in MemberType, order_by: mt.name))

    nodes =
      if socket.assigns.is_super_admin, do: Repo.all(from(n in Node, order_by: n.name)), else: []

    socket
    |> assign(:member_types, member_types)
    |> assign(:nodes, nodes)
  end

  defp action_to_tab(action) do
    case action do
      :change_password -> "change_password"
      _ -> "overview"
    end
  end

  defp assign_extend_form_if_needed(socket) do
    if socket.assigns.active_tab == "extend" do
      assign(socket, :extend_form, to_form(%{"extend_days" => "30"}))
    else
      socket
    end
  end

  defp assign_password_form_if_needed(socket) do
    if socket.assigns.active_tab == "change_password" do
      assign(socket, :password_form, to_form(%{"new_password" => "", "confirm_password" => ""}))
    else
      socket
    end
  end

  defp assign_edit_form_if_needed(socket) do
    if socket.assigns.active_tab == "edit" do
      assign(socket, :edit_form, to_form(User.changeset(socket.assigns.member, %{})))
    else
      socket
    end
  end

  defp member_status(member) do
    cond do
      member.manually_suspended -> "Suspended"
      member.expiry_date && Date.before?(member.expiry_date, Date.utc_today()) -> "Expired"
      true -> "Active"
    end
  end

  defp status_badge_class(member) do
    case member_status(member) do
      "Active" -> "bg-green-100 text-green-800"
      "Suspended" -> "bg-red-100 text-red-800"
      "Expired" -> "bg-orange-100 text-orange-800"
      _ -> "bg-gray-100 text-gray-800"
    end
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
          <.button type="submit" class="bg-voile-primary hover:bg-voile-primary/90 text-white">
            <.icon name="hero-check" class="w-4 h-4 mr-2" /> Update Member
          </.button>

          <.link
            patch={~p"/manage/members/management/#{@member.id}"}
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
          class="bg-red-600 hover:bg-red-700 text-white"
          data-confirm="Are you absolutely sure you want to delete this member? This action cannot be undone."
        >
          <.icon name="hero-trash" class="w-4 h-4 mr-2" /> Delete Member Permanently
        </.button>

        <.link
          patch={~p"/manage/members/management/#{@member.id}"}
          class="text-gray-600 hover:text-gray-800 dark:text-gray-400 dark:hover:text-gray-200"
        >
          Cancel
        </.link>
      </div>
    </div>
    """
  end
end
