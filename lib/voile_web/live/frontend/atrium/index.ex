defmodule VoileWeb.Frontend.Atrium.Index do
  use VoileWeb, :live_view
  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Accounts
  alias Client.Storage

  @impl true
  def mount(_params, _session, socket) do
    tabs = [:profile, :collections, :settings]

    user = socket.assigns.current_scope.user

    # Profile changeset (biodata + user_image handled as URL field for now)
    profile_changeset = Accounts.change_user(user)
    password_changeset = Accounts.change_user_password(user)

    socket =
      socket
      |> assign(
        active_tab: :profile,
        tabs: tabs,
        loans: [],
        fines: [],
        paying: nil,
        current_password: nil,
        current_email: user.email,
        profile_form: to_form(profile_changeset),
        password_form: to_form(password_changeset),
        trigger_submit: false
      )
      |> allow_upload(:user_image,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        auto_upload: true,
        progress: &handle_progress/3
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    tab_atom =
      case tab do
        "profile" -> :profile
        "collections" -> :collections
        "settings" -> :settings
        _ -> :profile
      end

    {:noreply, assign(socket, :active_tab, tab_atom)}
  end

  @impl true
  def handle_event("navigate_tab", %{"key" => key}, socket) do
    tabs = socket.assigns.tabs
    current = socket.assigns.active_tab
    idx = Enum.find_index(tabs, fn t -> t == current end) || 0
    len = length(tabs)

    new_idx =
      case key do
        "ArrowRight" -> rem(idx + 1, len)
        "ArrowLeft" -> rem(idx - 1 + len, len)
        "Home" -> 0
        "End" -> len - 1
        _ -> idx
      end

    {:noreply, assign(socket, :active_tab, Enum.at(tabs, new_idx))}
  end

  @impl true
  def handle_event("renew_loan", %{"transaction_id" => tx_id}, socket) do
    member = socket.assigns.current_scope.user

    # Verify transaction belongs to current member
    try do
      tx = Circulation.get_transaction!(tx_id)

      if tx.member_id != member.id do
        {:noreply, socket |> put_flash(:error, "You can only renew your own loans")}
      else
        # Attempt to renew via Circulation. Use nil librarian (self-service) and empty attrs.
        case Circulation.renew_transaction(tx_id, nil, %{}) do
          {:ok, _transaction} ->
            loans = Circulation.list_member_active_transactions(member.id)
            {:noreply, socket |> put_flash(:info, "Loan renewed") |> assign(loans: loans)}

          {:error, reason} ->
            {:noreply, socket |> put_flash(:error, "Could not renew loan: #{inspect(reason)}")}
        end
      end
    rescue
      _ ->
        {:noreply, socket |> put_flash(:error, "Transaction not found")}
    end
  end

  @impl true
  def handle_event("pay_fine", %{"fine_id" => fine_id, "amount" => amount}, socket) do
    member = socket.assigns.current_scope.user

    # For now assume cash payment and receipt number nil. The processed_by_id is the member id (self-pay)
    case Decimal.parse(amount) do
      {dec, _rest} when is_map(dec) ->
        # ensure fine belongs to member
        try do
          fine = Circulation.get_fine!(fine_id)

          if fine.member_id != member.id do
            {:noreply, socket |> put_flash(:error, "You can only pay your own fines")}
          else
            case Circulation.pay_fine(fine_id, dec, "cash", member.id, nil) do
              {:ok, _updated} ->
                fines = Circulation.list_member_unpaid_fines(member.id)

                {:noreply,
                 socket |> put_flash(:info, "Fine payment successful") |> assign(fines: fines)}

              {:error, reason} ->
                {:noreply, socket |> put_flash(:error, "Payment failed: #{inspect(reason)}")}
            end
          end
        rescue
          _ ->
            {:noreply, socket |> put_flash(:error, "Fine not found")}
        end

      :error ->
        {:noreply, socket |> put_flash(:error, "Invalid amount")}
    end
  end

  def handle_event("delete_user_image", %{"image" => image}, socket) do
    # Cancel any pending uploads
    uploads = socket.assigns.uploads || %{}

    socket =
      if uploads[:user_image] do
        Enum.reduce(uploads.user_image.entries, socket, fn entry, sock ->
          cancel_upload(sock, :user_image, entry.ref)
        end)
      else
        socket
      end

    user = socket.assigns.current_scope.user

    if image && image != "" do
      # Attempt to delete from storage and clear the user's image
      Storage.delete(image)

      case Accounts.update_profile_user(user, %{"user_image" => nil}) do
        {:ok, user} ->
          changeset = Accounts.change_user(user, %{})

          {:noreply,
           socket
           |> assign(:profile_form, to_form(changeset))
           |> put_flash(:info, "User image deleted successfully")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete user image")}
      end
    else
      # just clear any preview value in the form params
      form_params = Map.put(socket.assigns.profile_form.params || %{}, "user_image", nil)
      changeset = Accounts.change_user(user, form_params)

      {:noreply,
       socket
       |> assign(:profile_form, to_form(changeset))
       |> put_flash(:info, "User image removed")}
    end
  end

  # Profile & password settings handlers (member-level)
  def handle_event("validate_profile", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.current_scope.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, profile_form: to_form(changeset))}
  end

  def handle_event("save_profile", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user

    # Extract profile-specific fields for UserProfile upsert
    user_profile_params = extract_user_profile_params(user_params)

    case Accounts.update_profile_user(user, user_params) do
      {:ok, user} ->
        # Upsert the user_profile record
        case Accounts.upsert_user_profile(user, user_profile_params) do
          {:ok, _profile} ->
            {:noreply,
             socket
             |> put_flash(:info, "Profile updated")
             |> assign(
               profile_form: to_form(Accounts.change_user(user)),
               current_email: user.email
             )}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Profile updated but failed to save extended profile data")
             |> assign(
               profile_form: to_form(Accounts.change_user(user)),
               current_email: user.email
             )}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, profile_form: to_form(changeset))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  defp handle_progress(:user_image, entry, socket) do
    if entry.done? do
      # If there is an existing image in form params, attempt to delete it
      if socket.assigns.profile_form.params && socket.assigns.profile_form.params["user_image"] do
        Storage.delete(socket.assigns.profile_form.params["user_image"])
      end

      result =
        consume_uploaded_entries(socket, :user_image, fn %{path: path}, entry ->
          upload = %Plug.Upload{
            path: path,
            filename: entry.client_name,
            content_type: entry.client_type
          }

          user_id = socket.assigns.current_scope.user && socket.assigns.current_scope.user.id

          Storage.upload(upload, folder: "user_image", generate_filename: true, unit_id: user_id)
        end)

      case result do
        [{:ok, url}] ->
          form_params = Map.put(socket.assigns.profile_form.params || %{}, "user_image", url)
          changeset = Accounts.change_user(socket.assigns.current_scope.user, form_params)

          {:noreply,
           socket
           |> assign(:profile_form, to_form(changeset))}

        [url] when is_binary(url) ->
          form_params = Map.put(socket.assigns.profile_form.params || %{}, "user_image", url)
          changeset = Accounts.change_user(socket.assigns.current_scope.user, form_params)

          {:noreply,
           socket
           |> assign(:profile_form, to_form(changeset))}

        [{:error, err}] ->
          {:noreply, put_flash(socket, :error, err)}

        _ ->
          {:noreply, put_flash(socket, :error, "Unexpected upload result: #{inspect(result)}")}
      end
    else
      {:noreply, socket}
    end
  end

  defp extract_user_profile_params(params) when is_map(params) do
    Map.take(params, [
      "full_name",
      "address",
      "phone_number",
      "birth_date",
      "birth_place",
      "gender",
      "registration_date",
      "expiry_date",
      "photo",
      "organization",
      "department",
      "position"
    ])
  end

  # Safe association helpers - avoid accessing NotLoaded associations directly in templates
  defp role_name(%{user_role: %_{name: name}}), do: name
  defp role_name(%{user_role_id: id}) when not is_nil(id), do: to_string(id)
  defp role_name(_), do: "-"

  defp user_type_name(%{user_type: %_{name: name}}), do: name
  defp user_type_name(%{user_type_id: id}) when not is_nil(id), do: to_string(id)
  defp user_type_name(_), do: "-"

  defp node_name(%{node: %_{name: name}}), do: name
  defp node_name(%{node_id: id}) when not is_nil(id), do: to_string(id)
  defp node_name(_), do: "-"

  @impl true
  def handle_params(_params, _uri, socket) do
    # Load member-specific data when LiveView mounts or params change
    member = socket.assigns.current_scope.user

    loans = Circulation.list_member_active_transactions(member.id)
    fines = Circulation.list_member_unpaid_fines(member.id)

    {:noreply, assign(socket, loans: loans, fines: fines)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center max-w-7xl mx-auto px-5">
        <div class="max-w-4xl mx-auto py-10 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold mb-6 voile-text-gradient">My Atrium</h1>
          
          <div>
            <img
              src={@current_scope.user.user_image || ~p"/images/default_avatar.jpg"}
              alt="User Avatar"
              class="w-24 h-24 rounded-full mx-auto mb-4"
              referrerpolicy="no-referrer"
            />
            <h3 class="text-xl font-semibold mb-4">Hello, {@current_scope.user.fullname}!</h3>
          </div>
          
          <p class="italic text-xs">
            Welcome to the Atrium! This is your central hub for managing and accessing various features of the Voile platform. From here, you can navigate to different sections, manage your profile, and explore the tools available to you.
          </p>
        </div>
      </div>
      
      <div class="text-center max-w-7xl mx-auto px-5">
        <div>
          <div>
            <h5>
              Manage your profile, view your collections, and explore new items all from your Atrium.
            </h5>
            
            <div class="mt-4">
              <nav
                role="tablist"
                aria-label="Atrium navigation"
                class="inline-flex overflow-hidden rounded-md w-full items-center justify-around"
                phx-keydown="navigate_tab"
                tabindex="0"
              >
                <%= for {tab, idx} <- Enum.with_index(@tabs) do %>
                  <% tab_str = Atom.to_string(tab) %> <% label = String.capitalize(tab_str) %> <% last_idx =
                    length(@tabs) - 1 %> <% rounded =
                    cond do
                      idx == 0 -> "rounded-l-md"
                      idx == last_idx -> "rounded-r-md"
                      true -> ""
                    end %>
                  <button
                    type="button"
                    role="tab"
                    aria-selected={@active_tab == tab}
                    phx-click="select_tab"
                    phx-value-tab={tab_str}
                    class={"w-full px-4 py-2 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-indigo-500 border border-brand-300 dark:border-brand-700 " <> (if @active_tab == tab, do: "bg-brand-100 dark:bg-brand-700 text-indigo-600 dark:text-indigo-200 " <> rounded, else: "dark:text-voile-muted hover:bg-voile-surface dark:hover:bg-voile-dark " <> rounded)}
                  >
                    {label}
                  </button>
                <% end %>
              </nav>
            </div>
            <!-- Placeholder tab panels (dummy content to be replaced later) -->
            <div class="mt-6 text-left max-w-7xl mx-auto">
              <h6 class="sr-only">Atrium tab panels</h6>
              
              <div id="atrium-tabpanels" class="space-y-4">
                <%= if @active_tab == :collections do %>
                  <div
                    id="tab-collections"
                    class="p-4 rounded-md shadow-sm border border-voile-light dark:border-voile-dark"
                  >
                    <h4 class="text-lg font-semibold mb-2">Collections (placeholder)</h4>
                    
                    <p class="text-sm">
                      Collections tab content will be added soon. This area will list and manage your collections.
                    </p>
                  </div>
                <% end %>
                
                <%= if @active_tab == :settings do %>
                  <div
                    id="tab-settings"
                    class="p-4 rounded-md shadow-sm border border-voile-light dark:border-voile-dark"
                  >
                    <h4 class="text-lg font-semibold mb-2">Account Settings</h4>
                    
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div class="bg-white dark:bg-gray-700 rounded-lg p-4">
                        <.form
                          for={@profile_form}
                          id="profile_form"
                          phx-submit="save_profile"
                          phx-change="validate_profile"
                        >
                          <.input field={@profile_form[:fullname]} type="text" label="Full name" />
                          <.input field={@profile_form[:username]} type="text" label="Username" />
                          <.input field={@profile_form[:email]} type="email" label="Email" disabled />
                          <label class="block text-sm font-medium text-gray-700 mb-2">
                            Profile image
                          </label>
                          <div phx-drop-target={@uploads.user_image.ref} class="space-y-2">
                            <%= if @profile_form.params["user_image"] && @profile_form.params["user_image"] != "" do %>
                              <div class="flex items-center gap-4">
                                <img
                                  src={@profile_form.params["user_image"]}
                                  class="w-20 h-20 rounded-full object-cover"
                                />
                                <div class="flex-1">
                                  <p class="text-sm text-gray-700">Uploaded</p>
                                  
                                  <.button
                                    type="button"
                                    phx-click="delete_user_image"
                                    phx-value-image={@profile_form.params["user_image"]}
                                    phx-disable-with="Removing..."
                                  >
                                    Remove
                                  </.button>
                                </div>
                              </div>
                            <% else %>
                              <div class="border border-dashed rounded p-4 text-center">
                                <p class="text-sm text-gray-500">PNG, JPG, GIF up to 10MB</p>
                                 <.live_file_input upload={@uploads.user_image} class="hidden" />
                                <label
                                  for={@uploads.user_image.ref}
                                  class="inline-flex items-center px-4 py-2 mt-2 bg-gray-800 text-white rounded cursor-pointer"
                                >
                                  Choose file
                                </label>
                                <%= for entry <- @uploads.user_image.entries do %>
                                  <div class="mt-2 text-sm text-gray-600">
                                    Uploading... {entry.progress}%
                                  </div>
                                <% end %>
                              </div>
                            <% end %>
                          </div>
                           <.input field={@profile_form[:website]} type="url" label="Website" />
                          <.input
                            field={@profile_form[:twitter]}
                            type="text"
                            label="Twitter"
                            placeholder="@username"
                          />
                          <.input
                            field={@profile_form[:facebook]}
                            type="text"
                            label="Facebook"
                            placeholder="profile url"
                          />
                          <.input
                            field={@profile_form[:linkedin]}
                            type="text"
                            label="LinkedIn"
                            placeholder="profile url"
                          />
                          <.input
                            field={@profile_form[:instagram]}
                            type="text"
                            label="Instagram"
                            placeholder="@username"
                          /> <hr class="my-4" />
                          <h5 class="text-sm font-medium mb-2">Member profile details</h5>
                          
                          <div class="text-sm text-gray-600 mb-3">
                            <p>Role: {role_name(@current_scope.user)}</p>
                            
                            <p>Member type: {user_type_name(@current_scope.user)}</p>
                            
                            <p>Node: {node_name(@current_scope.user)}</p>
                            
                            <p>Confirmed at: {@current_scope.user.confirmed_at}</p>
                            
                            <p>
                              Last login: {@current_scope.user.last_login} ({@current_scope.user.last_login_ip})
                            </p>
                          </div>
                          
                          <.input field={@profile_form[:identifier]} type="text" label="Identifier" />
                          <.input
                            field={@profile_form[:groups]}
                            type="text"
                            label="Groups (comma-separated)"
                          /> <.input field={@profile_form[:website]} type="url" label="Website" />
                          <!-- UserProfile fields -->
                          <.input
                            field={@profile_form[:full_name]}
                            type="text"
                            label="Profile full name"
                          /> <.input field={@profile_form[:address]} type="text" label="Address" />
                          <.input
                            field={@profile_form[:phone_number]}
                            type="text"
                            label="Phone number"
                          />
                          <.input field={@profile_form[:birth_date]} type="date" label="Birth date" />
                          <.input field={@profile_form[:birth_place]} type="text" label="Birth place" />
                          <.input field={@profile_form[:gender]} type="text" label="Gender" />
                          <.input
                            field={@profile_form[:registration_date]}
                            type="date"
                            label="Registration date"
                          />
                          <.input field={@profile_form[:expiry_date]} type="date" label="Expiry date" />
                          <.input
                            field={@profile_form[:organization]}
                            type="text"
                            label="Organization"
                          />
                          <.input field={@profile_form[:department]} type="text" label="Department" />
                          <.input field={@profile_form[:position]} type="text" label="Position" />
                          <.button phx-disable-with="Saving...">Save Profile</.button>
                        </.form>
                      </div>
                      
                      <div class="bg-white dark:bg-gray-700 rounded-lg p-4">
                        <.form
                          for={@password_form}
                          id="password_form"
                          action={~p"/users/log_in?_action=password_updated"}
                          method="post"
                          phx-change="validate_password"
                          phx-submit="update_password"
                          phx-trigger-action={@trigger_submit}
                        >
                          <input
                            name={@password_form[:email].name}
                            type="hidden"
                            id="hidden_user_email"
                            value={@current_email}
                          />
                          <.input
                            field={@password_form[:password]}
                            type="password"
                            label="New password"
                            required
                          />
                          <.input
                            field={@password_form[:password_confirmation]}
                            type="password"
                            label="Confirm new password"
                          />
                          <.input
                            field={@password_form[:current_password]}
                            name="current_password"
                            type="password"
                            label="Current password"
                            id="current_password_for_password"
                            value={@current_password}
                            required
                          /> <.button phx-disable-with="Changing...">Change Password</.button>
                        </.form>
                      </div>
                    </div>
                  </div>
                <% end %>
                <!-- Member dashboard panels -->
                <%= if @active_tab == :profile do %>
                  <div class="p-4 rounded-md shadow-sm border border-voile-light dark:border-voile-dark">
                    <h4 class="text-lg font-semibold mb-2">Your Active Loans</h4>
                    
                    <%= if @loans == [] do %>
                      <p class="text-sm">You have no active loans.</p>
                    <% else %>
                      <ul class="space-y-3">
                        <%= for tx <- @loans do %>
                          <li class="flex items-center justify-between p-3 bg-white dark:bg-gray-800 rounded">
                            <div class="text-sm">
                              <div><strong>{tx.item.title || tx.item.item_code}</strong></div>
                              
                              <div class="text-xs text-gray-500">Due: {tx.due_date}</div>
                            </div>
                            
                            <div class="flex items-center gap-2">
                              <.button phx-click="renew_loan" phx-value-transaction_id={tx.id}>
                                Renew
                              </.button>
                            </div>
                          </li>
                        <% end %>
                      </ul>
                    <% end %>
                  </div>
                  
                  <div class="p-4 rounded-md shadow-sm border border-voile-light dark:border-voile-dark mt-4">
                    <h4 class="text-lg font-semibold mb-2">Outstanding Fines</h4>
                    
                    <%= if @fines == [] do %>
                      <p class="text-sm">You have no unpaid fines.</p>
                    <% else %>
                      <ul class="space-y-3">
                        <%= for f <- @fines do %>
                          <li class="flex items-center justify-between p-3 bg-white dark:bg-gray-800 rounded">
                            <div class="text-sm">
                              <div>
                                <strong>{f.description || (f.item && f.item.title) || "Fine"}</strong>
                              </div>
                              
                              <div class="text-xs text-gray-500">Balance: {f.balance}</div>
                            </div>
                            
                            <div class="flex items-center gap-2">
                              <form phx-submit="pay_fine">
                                <input type="hidden" name="fine_id" value={f.id} />
                                <input
                                  type="text"
                                  name="amount"
                                  value={f.balance}
                                  class="px-2 py-1 rounded border"
                                /> <.button type="submit">Pay</.button>
                              </form>
                            </div>
                          </li>
                        <% end %>
                      </ul>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
