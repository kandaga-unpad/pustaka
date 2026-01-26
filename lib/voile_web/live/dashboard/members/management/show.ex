defmodule VoileWeb.Dashboard.Members.Management.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Accounts
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Library.Transaction
  alias Voile.Schema.Library.Fine
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.System.Node
  alias VoileWeb.Auth.Authorization

  import Ecto.Query
  import VoileWeb.Dashboard.Members.Management.Component

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
      |> assign(:suspend_modal_visible, false)
      |> assign(:suspend_form, to_form(%{"suspension_reason" => "", "suspension_ends_at" => ""}))
      |> load_member_stats()
      |> load_filters()

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    tab = params["tab"] || action_to_tab(socket.assigns.live_action)
    allowed = allowed_tabs(socket)
    tab = if tab in allowed, do: tab, else: "overview"
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
    allowed = allowed_tabs(socket)

    if tab in allowed do
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
    else
      {:noreply, put_flash(socket, :error, "Access denied")}
    end
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
      case Accounts.admin_update_user_password(member, %{
             "password" => new_password,
             "password_confirmation" => confirm_password
           }) do
        {:ok, _updated_member} ->
          socket =
            socket
            |> put_flash(:info, "Password changed successfully")

          {:noreply, push_patch(socket, to: ~p"/manage/members/management/#{member.id}")}

        {:error, %Ecto.Changeset{} = changeset} ->
          error_message =
            changeset.errors
            |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
            |> Enum.join(", ")

          {:noreply, put_flash(socket, :error, "Failed to change password: #{error_message}")}
      end
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = User.changeset(socket.assigns.member, user_params)
    {:noreply, assign(socket, edit_form: to_form(changeset, action: :validate))}
  end

  def handle_event("update_member", %{"user" => user_params}, socket) do
    case Accounts.admin_update_user(socket.assigns.member, user_params) do
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
    {:noreply, assign(socket, :suspend_modal_visible, true)}
  end

  @impl true
  def handle_event("cancel_suspend", _params, socket) do
    {:noreply, assign(socket, :suspend_modal_visible, false)}
  end

  @impl true
  def handle_event("confirm_suspend", params, socket) do
    reason = params["suspension_reason"]
    ends_at_str = params["suspension_ends_at"]

    ends_at =
      if ends_at_str && ends_at_str != "" do
        case NaiveDateTime.from_iso8601(ends_at_str) do
          {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC")
          _ -> nil
        end
      else
        nil
      end

    attrs = %{
      suspension_reason: reason,
      suspended_by_id: socket.assigns.current_scope.user.id,
      suspension_ends_at: ends_at
    }

    case Accounts.suspend_user(socket.assigns.member, attrs) do
      {:ok, member} ->
        member = Voile.Repo.preload(member, [:user_type, :node, :suspended_by], force: true)

        {:noreply,
         socket
         |> assign(:member, member)
         |> assign(:suspend_modal_visible, false)
         |> put_flash(:info, "Member account has been suspended")}

      {:error, %Ecto.Changeset{} = changeset} ->
        require Logger
        Logger.error("Failed to suspend member: #{inspect(changeset.errors)}")

        error_message =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
          |> Enum.join(", ")

        {:noreply,
         socket
         |> assign(:suspend_form, to_form(changeset))
         |> put_flash(:error, "Failed to suspend member account: #{error_message}")}
    end
  end

  @impl true
  def handle_event("unsuspend_member", _params, socket) do
    case Accounts.unsuspend_user(socket.assigns.member) do
      {:ok, member} ->
        member = Voile.Repo.preload(member, [:user_type, :node, :suspended_by], force: true)

        {:noreply,
         socket
         |> assign(:member, member)
         |> put_flash(:info, "Member account suspension has been lifted")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to unsuspend member account")}
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
                  class="warning-btn"
                >
                  <.icon name="hero-play" class="w-4 h-4 mr-2" /> Unsuspend
                </.button>
              <% else %>
                <.button phx-click="suspend_member" class="cancel-btn">
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

      <%!-- Suspension Modal --%>
      <.modal
        :if={@suspend_modal_visible}
        id="suspend-modal"
        show
        on_cancel={JS.push("cancel_suspend")}
      >
        <div class="p-6">
          <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">
            Suspend Member Account
          </h3>
          <p class="text-gray-600 dark:text-gray-300 mb-6">
            Suspending {@member.fullname}'s account will prevent them from accessing the system.
          </p>

          <.form for={@suspend_form} phx-submit="confirm_suspend" class="space-y-6">
            <div>
              <.input
                field={@suspend_form[:suspension_reason]}
                type="textarea"
                label="Suspension Reason"
                placeholder="Reason for suspension..."
                required
              />
            </div>

            <div>
              <.input
                field={@suspend_form[:suspension_ends_at]}
                type="datetime-local"
                label="Suspension Ends At (Optional)"
                placeholder="Leave empty for indefinite suspension"
              />
            </div>

            <div class="flex items-center gap-4 pt-6 border-t border-gray-200 dark:border-gray-600">
              <.button type="submit" class="bg-red-600 hover:bg-red-700 text-white">
                <.icon name="hero-exclamation-triangle" class="w-4 h-4 mr-2" /> Suspend Account
              </.button>

              <.button
                type="button"
                phx-click="cancel_suspend"
                class="text-gray-600 hover:text-gray-800 dark:text-gray-400 dark:hover:text-gray-200"
              >
                Cancel
              </.button>
            </div>
          </.form>
        </div>
      </.modal>

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
            <%= if can?(@current_scope.user, "users.update") do %>
              <.tab_button
                active={@active_tab == "edit"}
                phx-click="change_tab"
                phx-value-tab="edit"
              >
                Edit Member
              </.tab_button>
            <% end %>
            <%= if can?(@current_scope.user, "users.update") do %>
              <.tab_button
                active={@active_tab == "extend"}
                phx-click="change_tab"
                phx-value-tab="extend"
              >
                Extend Membership
              </.tab_button>
            <% end %>
            <%= if can?(@current_scope.user, "users.update") do %>
              <.tab_button
                active={@active_tab == "change_password"}
                phx-click="change_tab"
                phx-value-tab="change_password"
              >
                Change Password
              </.tab_button>
            <% end %>
            <%= if @is_super_admin do %>
              <.tab_button
                active={@active_tab == "delete"}
                phx-click="change_tab"
                phx-value-tab="delete"
              >
                Delete Member
              </.tab_button>
            <% end %>
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

  # Private functions

  defp allowed_tabs(socket) do
    user = socket.assigns.current_scope.user
    is_super_admin = socket.assigns.is_super_admin

    base_tabs = ["overview", "activity", "loans", "fines"]

    update_tabs =
      if can?(user, "users.update"), do: ["edit", "extend", "change_password"], else: []

    delete_tabs = if is_super_admin, do: ["delete"], else: []

    base_tabs ++ update_tabs ++ delete_tabs
  end
end
