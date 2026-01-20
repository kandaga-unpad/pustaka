defmodule VoileWeb.Dashboard.Members.Management.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Library.Transaction
  alias Voile.Schema.Library.Fine

  import Ecto.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    member = Repo.get!(User, id) |> Repo.preload([:user_type, :node, :transactions, :fines])

    socket =
      socket
      |> assign(:page_title, "Member Details - #{member.fullname}")
      |> assign(:member, member)
      |> assign(:active_tab, "overview")
      |> load_member_stats()

    {:ok, socket}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
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
                <.button phx-click="suspend_member" class="bg-red-600 hover:bg-red-700 text-white">
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
              active={@active_tab == "activity"}
              phx-click="change_tab"
              phx-value-tab="activity"
            >
              Activity History
            </.tab_button>
            <.tab_button active={@active_tab == "loans"} phx-click="change_tab" phx-value-tab="loans">
              Current Loans
            </.tab_button>
            <.tab_button active={@active_tab == "fines"} phx-click="change_tab" phx-value-tab="fines">
              Fines & Payments
            </.tab_button>
          </nav>
        </div>

        <div class="p-6">
          <%= case @active_tab do %>
            <% "overview" -> %>
              <.overview_tab member={@member} stats={@stats} />
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
end
