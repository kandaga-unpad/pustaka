defmodule VoileWeb.Users.ManageLive.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Accounts
  alias VoileWeb.Utils.FormatIndonesiaTime

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Check permission
    authorize!(socket, "users.read")

    user =
      Accounts.get_user!(id) |> Voile.Repo.preload([:roles, :user_type, :node, :suspended_by])

    # Check if manually suspended
    manually_suspended? = Accounts.is_manually_suspended?(user)

    # Check if member privileges are suspended due to fines
    fine_suspended? =
      if user.user_type_id && !manually_suspended? do
        Voile.Schema.Library.Circulation.member_privileges_suspended?(user.id)
      else
        false
      end

    # Get outstanding fine amount
    outstanding_fines =
      if user.user_type_id do
        Voile.Schema.Library.Circulation.get_member_outstanding_fine_amount(user.id)
      else
        Decimal.new("0")
      end

    socket =
      socket
      |> assign(:user, user)
      |> assign(:current_path, "/manage/settings/users/#{id}")
      |> assign(:manually_suspended, manually_suspended?)
      |> assign(:fine_suspended, fine_suspended?)
      |> assign(:suspended, manually_suspended? || fine_suspended?)
      |> assign(:outstanding_fines, outstanding_fines)
      |> assign(:suspend_modal_visible, false)
      |> assign(:suspend_form, to_form(%{}))
      |> assign(:can_suspend, can_suspend_user?(socket.assigns.current_scope.user, user))
      |> assign(:password_modal_visible, false)
      |> assign(:password_form, to_form(%{}))

    {:ok, socket}
  end

  # Helper to determine if current user can suspend the target user
  defp can_suspend_user?(current_user, target_user) do
    cond do
      # Cannot suspend yourself
      current_user.id == target_user.id -> false
      # Cannot suspend super admins
      is_super_admin?(target_user) -> false
      # Otherwise, allow if user has permission
      true -> true
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        User Profile
        <:subtitle>Personal and account information</:subtitle>
      </.header>

      <div class="flex gap-4">
        <div class="w-full max-w-64">
          <.dashboard_settings_sidebar
            current_user={@current_scope.user}
            current_path={@current_path}
          />
        </div>

        <div class="w-full bg-white dark:bg-gray-700 p-6 rounded-lg">
          <div class="flex items-center justify-between mb-4">
            <.back navigate={~p"/manage/settings/users"}>Back to Users</.back>

            <div class="flex gap-2">
              <%= if can?(@current_scope.user, "users.update") do %>
                <%= if @manually_suspended do %>
                  <button
                    phx-click="unsuspend_user"
                    class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
                  >
                    <.icon name="hero-check-circle" class="w-4 h-4 mr-2" /> Unsuspend Account
                  </button>
                <% else %>
                  <%= if @can_suspend do %>
                    <button
                      phx-click="show_suspend_modal"
                      class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                    >
                      <.icon name="hero-no-symbol" class="w-4 h-4 mr-2" /> Suspend Account
                    </button>
                  <% end %>
                <% end %>
              <% end %>
              <%!-- Change Password Button (Super Admin Only) --%>
              <%= if is_super_admin?(@current_scope.user) && @user.id != @current_scope.user.id do %>
                <button
                  phx-click="show_password_modal"
                  class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  <.icon name="hero-key" class="w-4 h-4 mr-2" /> Change Password
                </button>
              <% end %>

              <%= if can?(@current_scope.user, "users.update") do %>
                <.link patch={~p"/manage/settings/users/#{@user.id}/show/edit"} class="primary-btn">
                  Edit
                </.link>
              <% end %>
            </div>
          </div>

          <div class="bg-white dark:bg-gray-900 shadow-xl rounded-xl p-8">
            <div class="flex flex-col items-center">
              <div class="mb-4">
                <%= if @user.user_image do %>
                  <img
                    src={"#{@user.user_image}"}
                    alt={@user.fullname || @user.username}
                    class="w-32 h-32 rounded-full object-cover border-4 border-indigo-200 shadow"
                    referrerpolicy="no-referrer"
                  />
                <% else %>
                  <div class="w-32 h-32 rounded-full bg-gray-200 flex items-center justify-center text-4xl font-bold text-gray-500 border-4 border-indigo-100">
                    {String.first(@user.fullname || @user.username) |> String.upcase()}
                  </div>
                <% end %>
              </div>

              <h2 class="text-2xl font-bold mb-1">{@user.fullname || @user.username}</h2>

              <div class="flex flex-wrap gap-2 mb-4 justify-center">
                <%= if Ecto.assoc_loaded?(@user.roles) and length(@user.roles) > 0 do %>
                  <%= for role <- @user.roles do %>
                    <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-indigo-100 text-indigo-800 capitalize">
                      {role.name}
                    </span>
                  <% end %>
                <% else %>
                  <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-gray-100 text-gray-600">
                    No roles assigned
                  </span>
                <% end %>

                <%= if @user.confirmed_at do %>
                  <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800">
                    Active
                  </span>
                <% else %>
                  <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-800">
                    Pending
                  </span>
                <% end %>
                <%!-- Suspension Status Badge --%>
                <%= if @user.user_type_id do %>
                  <%= if @suspended do %>
                    <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-800">
                      <.icon name="hero-exclamation-triangle" class="w-3 h-3 mr-1" /> Suspended
                    </span>
                  <% else %>
                    <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800">
                      <.icon name="hero-check-circle" class="w-3 h-3 mr-1" /> Good Standing
                    </span>
                  <% end %>
                <% end %>
              </div>

              <div class="w-full mt-4 grid grid-cols-1 md:grid-cols-2 gap-6">
                <%!-- Manual Suspension Alert --%>
                <%= if @manually_suspended do %>
                  <div class="col-span-2 bg-red-50 border-l-4 border-red-400 p-4 rounded">
                    <div class="flex items-start">
                      <div class="flex-shrink-0">
                        <.icon name="hero-no-symbol" class="h-5 w-5 text-red-400" />
                      </div>

                      <div class="ml-3 flex-1">
                        <h3 class="text-sm font-medium text-red-800">Account Manually Suspended</h3>

                        <div class="mt-2 text-sm text-red-700">
                          <p class="font-semibold">Reason:</p>

                          <p class="mt-1 italic">{@user.suspension_reason || "No reason provided"}</p>

                          <div class="mt-3 grid grid-cols-2 gap-4">
                            <%= if @user.suspended_at do %>
                              <div>
                                <span class="font-semibold">Suspended On:</span>
                                <div>
                                  {Calendar.strftime(@user.suspended_at, "%B %d, %Y at %I:%M %p")}
                                </div>
                              </div>
                            <% end %>

                            <%= if @user.suspended_by_id do %>
                              <div>
                                <span class="font-semibold">Suspended By:</span>
                                <div>
                                  {@user.suspended_by.fullname || @user.suspended_by.username}
                                </div>
                              </div>
                            <% end %>

                            <%= if @user.suspension_ends_at do %>
                              <div class="col-span-2">
                                <span class="font-semibold">Suspension Ends:</span>
                                <div>
                                  {Calendar.strftime(
                                    @user.suspension_ends_at,
                                    "%B %d, %Y at %I:%M %p"
                                  )}
                                </div>
                              </div>
                            <% else %>
                              <div class="col-span-2">
                                <span class="font-semibold text-red-900">Indefinite Suspension</span>
                              </div>
                            <% end %>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
                <%!-- Fine-Based Suspension Warning Alert --%>
                <%= if @user.user_type_id && @fine_suspended do %>
                  <div class="col-span-2 bg-red-50 border-l-4 border-red-400 p-4 rounded">
                    <div class="flex items-start">
                      <div class="flex-shrink-0">
                        <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-red-400" />
                      </div>

                      <div class="ml-3">
                        <h3 class="text-sm font-medium text-red-800">
                          Member Privileges Suspended (Outstanding Fines)
                        </h3>

                        <div class="mt-2 text-sm text-red-700">
                          <p>
                            This member cannot borrow items due to outstanding fines exceeding the maximum limit.
                          </p>

                          <div class="mt-2 flex items-center gap-4">
                            <div>
                              <span class="font-semibold">Outstanding Fines:</span>
                              <span class="text-red-900 font-bold">
                                Rp {Decimal.to_string(@outstanding_fines)}
                              </span>
                            </div>

                            <%= if @user.user_type && @user.user_type.max_fine do %>
                              <div>
                                <span class="font-semibold">Maximum Allowed:</span>
                                <span>Rp {Decimal.to_string(@user.user_type.max_fine)}</span>
                              </div>
                            <% end %>
                          </div>

                          <div class="mt-3">
                            <.link
                              navigate={~p"/manage/glam/library/ledger"}
                              class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                            >
                              <.icon name="hero-banknotes" class="w-4 h-4 mr-1" />
                              Manage Fines & Payments
                            </.link>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
                <%!-- Fine Status Info (Good Standing) --%>
                <%= if @user.user_type_id && !@suspended && Decimal.compare(@outstanding_fines, Decimal.new("0")) == :gt do %>
                  <div class="col-span-2 bg-yellow-50 border-l-4 border-yellow-400 p-4 rounded">
                    <div class="flex items-start">
                      <div class="flex-shrink-0">
                        <.icon name="hero-information-circle" class="h-5 w-5 text-yellow-400" />
                      </div>

                      <div class="ml-3">
                        <h3 class="text-sm font-medium text-yellow-800">Outstanding Fines</h3>

                        <div class="mt-2 text-sm text-yellow-700">
                          <p>Member has outstanding fines but is still within the allowed limit.</p>

                          <div class="mt-2 flex items-center gap-4">
                            <div>
                              <span class="font-semibold">Current Balance:</span>
                              <span class="text-yellow-900 font-bold">
                                Rp {Decimal.to_string(@outstanding_fines)}
                              </span>
                            </div>

                            <%= if @user.user_type && @user.user_type.max_fine do %>
                              <div>
                                <span class="font-semibold">Maximum Allowed:</span>
                                <span>Rp {Decimal.to_string(@user.user_type.max_fine)}</span>
                              </div>
                            <% end %>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>

                <div>
                  <div class="text-gray-500 text-xs uppercase mb-1">Email</div>

                  <div class="font-medium">{@user.email}</div>
                </div>

                <div>
                  <div class="text-gray-500 text-xs uppercase mb-1">Username</div>

                  <div class="font-medium">{@user.username}</div>
                </div>

                <%= if @user.identifier do %>
                  <div>
                    <div class="text-gray-500 text-xs uppercase mb-1">Identifier</div>

                    <div class="font-medium">{@user.identifier}</div>
                  </div>
                <% end %>

                <%= if Ecto.assoc_loaded?(@user.user_type) && @user.user_type do %>
                  <div>
                    <div class="text-gray-500 text-xs uppercase mb-1">User Type</div>

                    <div class="font-medium">{@user.user_type.name}</div>
                  </div>
                <% end %>

                <%= if @user.groups && @user.groups != [] do %>
                  <div class="col-span-2">
                    <div class="text-gray-500 text-xs uppercase mb-1">Groups</div>

                    <div class="flex flex-wrap gap-2">
                      <%= for group <- @user.groups do %>
                        <span class="inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded">
                          {group}
                        </span>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <%= if @user.node_id do %>
                  <div>
                    <div class="text-gray-500 text-xs uppercase mb-1">Node ID</div>

                    <div class="font-medium">{@user.node.name}</div>
                  </div>
                <% end %>

                <div>
                  <div class="text-gray-500 text-xs uppercase mb-1">Last Login</div>

                  <div class="font-medium">
                    <%= if @user.last_login do %>
                      {FormatIndonesiaTime.format_utc_to_jakarta(@user.last_login)}
                    <% else %>
                      <span class="text-gray-400">Never</span>
                    <% end %>
                  </div>
                </div>

                <div>
                  <div class="text-gray-500 text-xs uppercase mb-1">Last Login IP</div>

                  <div class="font-medium">{@user.last_login_ip || "-"}</div>
                </div>
              </div>

              <div class="w-full mt-8">
                <div class="text-gray-500 text-xs uppercase mb-2">Social & Links</div>

                <div class="flex flex-wrap gap-4">
                  <%= if @user.twitter do %>
                    <a href={@user.twitter} class="text-blue-400 hover:underline" target="_blank">
                      Twitter
                    </a>
                  <% end %>

                  <%= if @user.facebook do %>
                    <a href={@user.facebook} class="text-blue-600 hover:underline" target="_blank">
                      Facebook
                    </a>
                  <% end %>

                  <%= if @user.linkedin do %>
                    <a href={@user.linkedin} class="text-blue-700 hover:underline" target="_blank">
                      LinkedIn
                    </a>
                  <% end %>

                  <%= if @user.instagram do %>
                    <a href={@user.instagram} class="text-pink-500 hover:underline" target="_blank">
                      Instagram
                    </a>
                  <% end %>

                  <%= if @user.website do %>
                    <a href={@user.website} class="text-gray-700 hover:underline" target="_blank">
                      Website
                    </a>
                  <% end %>
                </div>
              </div>

              <div class="w-full mt-8 text-xs text-gray-400 text-center">
                User ID: {@user.id} &middot; Created: {Calendar.strftime(
                  @user.inserted_at,
                  "%Y-%m-%d %H:%M"
                )} &middot; Updated: {Calendar.strftime(@user.updated_at, "%Y-%m-%d %H:%M")}
              </div>
            </div>
          </div>
        </div>
      </div>

      <.modal
        :if={@live_action in [:new, :edit]}
        id="user-modal"
        show
        on_cancel={JS.patch(~p"/manage/settings/users/#{@user.id}")}
      >
        <.live_component
          module={VoileWeb.Users.ManageLive.FormComponent}
          id={@user.id || :new}
          title={@page_title}
          action={@live_action}
          node_list={@node_list}
          user_type_options={@user_type_options}
          user={@user}
          current_scope={@current_scope}
          patch={~p"/manage/settings/users/#{@user.id}"}
        />
      </.modal>
      <%!-- Suspend Modal --%>
      <.modal
        :if={@suspend_modal_visible}
        id="suspend-modal"
        show
        on_cancel={JS.push("cancel_suspend")}
      >
        <div class="space-y-4">
          <div class="flex items-center justify-center space-x-3">
            <div class="p-2 rounded-full bg-red-100 text-red-600 flex items-center justify-center">
              <.icon name="hero-no-symbol" class="w-6 h-6" />
            </div>

            <div>
              <h3 class="text-lg font-semibold">Suspend User Account</h3>

              <p class="text-sm">
                This will prevent the user from borrowing items. You must provide a reason for the suspension.
              </p>
            </div>
          </div>

          <.form :let={f} for={@suspend_form} id="suspend-form" phx-submit="confirm_suspend">
            <div class="space-y-4">
              <.input
                field={f[:suspension_reason]}
                name="suspension_reason"
                type="textarea"
                label="Suspension Reason"
                placeholder="Enter the reason for suspending this account..."
                required
                rows="4"
              />
              <.input
                field={f[:suspension_ends_at]}
                name="suspension_ends_at"
                type="datetime-local"
                label="Suspension End Date (Optional - leave empty for indefinite)"
              />
            </div>

            <div class="mt-6 flex justify-end items-center space-x-3">
              <button type="button" phx-click="cancel_suspend" class="primary-btn">Cancel</button>
              <button type="submit" class="cancel-btn">Confirm Suspension</button>
            </div>
          </.form>
        </div>
      </.modal>
      <%!-- Change Password Modal --%>
      <.modal
        :if={@password_modal_visible}
        id="password-modal"
        show
        on_cancel={JS.push("cancel_password_change")}
      >
        <div class="space-y-4">
          <div class="flex items-center justify-center space-x-3">
            <div class="p-2 rounded-full bg-indigo-100 text-indigo-600 flex items-center justify-center">
              <.icon name="hero-key" class="w-6 h-6" />
            </div>

            <div>
              <h3 class="text-lg font-semibold">Change User Password</h3>

              <p class="text-sm text-gray-600">
                Set a new password for {@user.fullname || @user.username}
              </p>
            </div>
          </div>

          <.form :let={f} for={@password_form} id="password-form" phx-submit="confirm_password_change">
            <div class="space-y-4">
              <.input
                field={f[:new_password]}
                name="new_password"
                type="password"
                label="New Password"
                placeholder="Enter new password"
                required
                autocomplete="new-password"
              />
              <.input
                field={f[:password_confirmation]}
                name="password_confirmation"
                type="password"
                label="Confirm New Password"
                placeholder="Confirm new password"
                required
                autocomplete="new-password"
              />
            </div>

            <div class="mt-6 flex justify-end items-center space-x-3">
              <button type="button" phx-click="cancel_password_change" class="cancel-btn">
                Cancel
              </button>

              <button type="submit" class="primary-btn" phx-disable-with="Changing...">
                Change Password
              </button>
            </div>
          </.form>
        </div>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("show_suspend_modal", _params, socket) do
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

    case Accounts.suspend_user(socket.assigns.user, attrs) do
      {:ok, user} ->
        user = Voile.Repo.preload(user, [:roles, :user_type, :node, :suspended_by], force: true)

        {:noreply,
         socket
         |> assign(:user, user)
         |> assign(:manually_suspended, true)
         |> assign(:suspended, true)
         |> assign(:suspend_modal_visible, false)
         |> put_flash(:info, "User account has been suspended")}

      {:error, %Ecto.Changeset{} = changeset} ->
        require Logger
        Logger.error("Failed to suspend user: #{inspect(changeset.errors)}")

        error_message =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
          |> Enum.join(", ")

        {:noreply,
         socket
         |> assign(:suspend_form, to_form(changeset))
         |> put_flash(:error, "Failed to suspend user account: #{error_message}")}
    end
  end

  @impl true
  def handle_event("show_password_modal", _params, socket) do
    {:noreply, assign(socket, :password_modal_visible, true)}
  end

  @impl true
  def handle_event("cancel_password_change", _params, socket) do
    {:noreply, assign(socket, :password_modal_visible, false)}
  end

  @impl true
  def handle_event("confirm_password_change", params, socket) do
    # Only super admins can change passwords
    unless VoileWeb.Auth.Authorization.is_super_admin?(socket) do
      {:noreply, put_flash(socket, :error, "Only super admins can change user passwords")}
    else
      new_password = params["new_password"]
      password_confirmation = params["password_confirmation"]

      cond do
        new_password != password_confirmation ->
          {:noreply, put_flash(socket, :error, "Passwords do not match")}

        String.length(new_password) < 8 ->
          {:noreply, put_flash(socket, :error, "Password must be at least 8 characters long")}

        true ->
          case Accounts.admin_update_user_password(socket.assigns.user, %{
                 "password" => new_password,
                 "password_confirmation" => password_confirmation
               }) do
            {:ok, _user} ->
              {:noreply,
               socket
               |> assign(:password_modal_visible, false)
               |> put_flash(:info, "Password changed successfully")}

            {:error, %Ecto.Changeset{} = changeset} ->
              require Logger
              Logger.error("Failed to change password: #{inspect(changeset.errors)}")

              error_message =
                changeset.errors
                |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
                |> Enum.join(", ")

              {:noreply,
               socket
               |> assign(:password_form, to_form(changeset))
               |> put_flash(:error, "Failed to change password: #{error_message}")}
          end
      end
    end
  end

  @impl true
  def handle_event("unsuspend_user", _params, socket) do
    case Accounts.unsuspend_user(socket.assigns.user) do
      {:ok, user} ->
        user = Voile.Repo.preload(user, [:roles, :user_type, :node, :suspended_by], force: true)

        # Recalculate fine-based suspension
        fine_suspended? =
          if user.user_type_id do
            Voile.Schema.Library.Circulation.member_privileges_suspended?(user.id)
          else
            false
          end

        {:noreply,
         socket
         |> assign(:user, user)
         |> assign(:manually_suspended, false)
         |> assign(:fine_suspended, fine_suspended?)
         |> assign(:suspended, fine_suspended?)
         |> put_flash(:info, "User account suspension has been lifted")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to unsuspend user account")}
    end
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    user =
      Accounts.get_user!(id) |> Voile.Repo.preload([:roles, :user_type, :node, :suspended_by])

    # When the live action is :edit or :new (modal open), ensure the
    # component props expected by the modal are present in assigns so
    # rendering doesn't crash with missing keys like :page_title.
    socket =
      case socket.assigns.live_action do
        :edit ->
          node_list = Voile.Schema.System.list_nodes()
          user_type_options = Voile.Schema.Master.list_mst_member_types()

          socket
          |> assign(user: user)
          |> assign(:page_title, "Edit User")
          |> assign(:node_list, node_list)
          |> assign(:user_type_options, user_type_options)

        :new ->
          node_list = Voile.Schema.System.list_nodes()
          user_type_options = Voile.Schema.Master.list_mst_member_types()

          socket
          |> assign(user: user)
          |> assign(:page_title, "New User")
          |> assign(:node_list, node_list)
          |> assign(:user_type_options, user_type_options)

        _ ->
          assign(socket, user: user)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({VoileWeb.Users.ManageLive.FormComponent, {:saved, user}}, socket) do
    # Reload user with all associations after save
    user =
      Accounts.get_user!(user.id)
      |> Voile.Repo.preload([:roles, :user_type, :node, :suspended_by])

    {:noreply, assign(socket, :user, user)}
  end
end
