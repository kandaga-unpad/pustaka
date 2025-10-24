defmodule VoileWeb.Frontend.Atrium.Index do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts
  alias Voile.Schema.Library.Circulation
  alias Client.Storage

  @impl true
  def mount(_params, _session, socket) do
    tabs = [:circulation, :collections, :settings]

    user = socket.assigns.current_scope.user

    # Profile changeset (biodata + user_image handled as URL field for now)
    profile_changeset = Accounts.change_user(user)
    password_changeset = Accounts.change_user_password(user)

    # prepare a changeset/form for user profile and set `as: :user` so inputs submit as user[...] params
    user_profile_changeset = Accounts.change_user(user)
    user_profile_form = to_form(user_profile_changeset, as: :user)

    # Load first page of loans and fines for the member
    {loans, loans_total_pages} =
      Circulation.list_member_active_transactions_paginated(user.id, 1, 10)

    {fines, fines_total_pages} = Circulation.list_member_unpaid_fines_paginated(user.id, 1, 10)

    total_loans = Circulation.count_list_active_transactions(user.id)
    total_unpaid_fines = Circulation.count_member_unpaid_fines(user.id)

    socket =
      socket
      |> assign(
        active_tab: :circulation,
        tabs: tabs,
        loans: loans,
        loans_page: 1,
        loans_total_pages: loans_total_pages,
        fines: fines,
        fines_page: 1,
        fines_total_pages: fines_total_pages,
        total_loans: total_loans,
        total_unpaid_fines: total_unpaid_fines,
        paying: nil,
        current_password: nil,
        current_email: user.email,
        profile_form: to_form(profile_changeset),
        user_profile_form: user_profile_form,
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
  def handle_event("loans_prev", _params, socket) do
    member = socket.assigns.current_scope.user
    page = max((socket.assigns.loans_page || 1) - 1, 1)
    {loans, total} = Circulation.list_member_active_transactions_paginated(member.id, page, 10)
    {:noreply, assign(socket, loans: loans, loans_page: page, loans_total_pages: total)}
  end

  def handle_event("loans_next", _params, socket) do
    member = socket.assigns.current_scope.user
    page = min((socket.assigns.loans_page || 1) + 1, socket.assigns.loans_total_pages || 1)
    {loans, total} = Circulation.list_member_active_transactions_paginated(member.id, page, 10)
    {:noreply, assign(socket, loans: loans, loans_page: page, loans_total_pages: total)}
  end

  def handle_event("fines_prev", _params, socket) do
    member = socket.assigns.current_scope.user
    page = max((socket.assigns.fines_page || 1) - 1, 1)
    {fines, total} = Circulation.list_member_unpaid_fines_paginated(member.id, page, 10)
    {:noreply, assign(socket, fines: fines, fines_page: page, fines_total_pages: total)}
  end

  def handle_event("fines_next", _params, socket) do
    member = socket.assigns.current_scope.user
    page = min((socket.assigns.fines_page || 1) + 1, socket.assigns.fines_total_pages || 1)
    {fines, total} = Circulation.list_member_unpaid_fines_paginated(member.id, page, 10)
    {:noreply, assign(socket, fines: fines, fines_page: page, fines_total_pages: total)}
  end

  @impl true
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    tab_atom =
      case tab do
        "circulation" -> :circulation
        "collections" -> :collections
        "settings" -> :settings
        _ -> :circulation
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
    # Quick client-side friendly checks based on member type entitlements so
    # the user gets immediate feedback without an unnecessary server call.
    user_type = Map.get(member, :user_type)
    get_admin_id = Circulation.get_admin_id_for_self_renewal()

    case can_renew_transaction_precheck(tx_id, member, user_type) do
      {:error, msg} ->
        {:noreply, socket |> put_flash(:error, msg)}

      {:ok} ->
        # Verify transaction belongs to current member and attempt renewal.
        case Circulation.get_transaction(tx_id) do
          nil ->
            {:noreply, socket |> put_flash(:error, "Transaction not found")}

          tx ->
            if tx.member_id != member.id do
              {:noreply, socket |> put_flash(:error, "You can only renew your own loans")}
            else
              # Attempt to renew via Circulation. Use admin id (if found) or nil for self-service.
              case Circulation.renew_transaction(tx_id, get_admin_id, %{}) do
                {:ok, _transaction} ->
                  {loans, loans_total_pages} =
                    Circulation.list_member_active_transactions_paginated(
                      member.id,
                      socket.assigns.loans_page || 1,
                      10
                    )

                  {:noreply,
                   socket
                   |> put_flash(:info, "Loan renewed")
                   |> assign(loans: loans, loans_total_pages: loans_total_pages)}

                {:error, reason} ->
                  {:noreply,
                   socket |> put_flash(:error, "Could not renew loan: #{inspect(reason)}")}
              end
            end
        end
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
                {fines, fines_total_pages} =
                  Circulation.list_member_unpaid_fines_paginated(
                    member.id,
                    socket.assigns.fines_page || 1,
                    10
                  )

                {:noreply,
                 socket
                 |> put_flash(:info, "Fine payment successful")
                 |> assign(fines: fines, fines_total_pages: fines_total_pages)}

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

  def handle_event("request_payment_link", %{"fine_id" => fine_id}, socket) do
    member = socket.assigns.current_scope.user

    # Check if payment link already exists
    case Circulation.get_pending_payment_for_fine(fine_id) do
      {:ok, _payment} ->
        # Reload fines to show payment status
        {fines, fines_total_pages} =
          Circulation.list_member_unpaid_fines_paginated(
            member.id,
            socket.assigns.fines_page || 1,
            10
          )

        {:noreply,
         socket
         |> assign(fines: fines, fines_total_pages: fines_total_pages)
         |> put_flash(
           :info,
           "Payment link already exists. Check your email or contact library staff."
         )}

      {:error, :not_found} ->
        # Create new payment link
        case Circulation.create_payment_link_for_fine(
               fine_id,
               member.id,
               success_redirect_url: url(~p"/atrium?payment=success"),
               failure_redirect_url: url(~p"/atrium?payment=failed")
             ) do
          {:ok, _payment} ->
            {fines, fines_total_pages} =
              Circulation.list_member_unpaid_fines_paginated(
                member.id,
                socket.assigns.fines_page || 1,
                10
              )

            {:noreply,
             socket
             |> assign(fines: fines, fines_total_pages: fines_total_pages, payment_link: nil)
             |> put_flash(:info, "Payment link created! You can now proceed to pay online.")}

          {:error, reason} ->
            {:noreply,
             socket |> put_flash(:error, "Failed to create payment link: #{inspect(reason)}")}
        end
    end
  end

  def handle_event("open_payment_link", %{"fine_id" => fine_id}, socket) do
    case Circulation.get_pending_payment_for_fine(fine_id) do
      {:ok, payment} ->
        # The actual redirect will be handled by JS on client side
        {:noreply, socket |> push_event("redirect", %{url: payment.payment_url})}

      {:error, _} ->
        {:noreply, socket |> put_flash(:error, "Payment link not found")}
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

    # If an uploaded image URL exists in the profile_form params (set by handle_progress),
    # ensure it's included in the submitted user params so the User record gets updated.
    uploaded_image =
      socket.assigns.profile_form.params && socket.assigns.profile_form.params["user_image"]

    user_params =
      if uploaded_image, do: Map.put(user_params, "user_image", uploaded_image), else: user_params

    case Accounts.update_profile_user(user, user_params) do
      {:ok, user} ->
        # Update assigns so the UI (header/profile) reflects the saved user immediately
        socket =
          socket
          |> put_flash(:info, "Profile updated")
          |> assign(profile_form: to_form(Accounts.change_user(user)), current_email: user.email)
          |> assign(current_scope: Map.put(socket.assigns.current_scope, :user, user))

        {:noreply, socket}

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

          # Update the preview form and also update current_scope user so header reflects new image
          new_user = Map.put(socket.assigns.current_scope.user, :user_image, cache_bust(url))

          {:noreply,
           socket
           |> assign(:profile_form, to_form(changeset))
           |> assign(current_scope: Map.put(socket.assigns.current_scope, :user, new_user))}

        [url] when is_binary(url) ->
          form_params = Map.put(socket.assigns.profile_form.params || %{}, "user_image", url)
          changeset = Accounts.change_user(socket.assigns.current_scope.user, form_params)

          new_user = Map.put(socket.assigns.current_scope.user, :user_image, cache_bust(url))

          {:noreply,
           socket
           |> assign(:profile_form, to_form(changeset))
           |> assign(current_scope: Map.put(socket.assigns.current_scope, :user, new_user))}

        [{:error, err}] ->
          {:noreply, put_flash(socket, :error, err)}

        _ ->
          {:noreply, put_flash(socket, :error, "Unexpected upload result: #{inspect(result)}")}
      end
    else
      {:noreply, socket}
    end
  end

  # Quick precheck for renewals to provide immediate UI feedback.
  # Returns true if we should proceed to call Circulation.renew_transaction/3.
  defp can_renew_transaction_precheck(_transaction_id, _member, nil) do
    # If we don't have the member type preloaded on the user, let server do
    # authoritative checks.
    {:ok}
  end

  defp can_renew_transaction_precheck(transaction_id, _member, %{} = user_type) do
    # First check if member type allows renewals
    if not Map.get(user_type, :can_renew, true) do
      {:error, "Your member type does not allow renewing items"}
    else
      # Try to fetch transaction quickly and check renewal_count vs max_renewals.
      case Circulation.get_transaction(transaction_id) do
        nil ->
          # Let server-side handle missing transaction
          {:ok}

        tx ->
          max_renewals = Map.get(user_type, :max_renewals, 0) || 0

          if tx.renewal_count >= max_renewals do
            {:error, "Maximum renewals (#{max_renewals}) reached for your member type"}
          else
            {:ok}
          end
      end
    end
  end

  # Safe association helpers - avoid accessing NotLoaded associations directly in templates
  # Return the primary role name (prefer loaded `roles`, then `user_role_assignments`),
  # or fallback to any id fields, or "-" if nothing available.
  # role_name helper prefers loaded roles then assignments. Fallthrough to "-".
  defp role_name(%{roles: [%{name: name} | _]}), do: to_string(name)

  defp role_name(%{user_role_assignments: [%{role: %{name: name}} | _]}), do: to_string(name)

  defp role_name(_), do: "-"

  # User type helper: prefer loaded struct then id
  defp user_type_name(%{user_type: %{name: name}}), do: name
  defp user_type_name(%{user_type_id: id}) when not is_nil(id), do: to_string(id)
  defp user_type_name(_), do: "-"

  # Node helper: prefer loaded node struct then node_id
  defp node_name(%{node: %{name: name}}), do: name
  defp node_name(%{node_id: id}) when not is_nil(id), do: to_string(id)
  defp node_name(_), do: "-"

  @impl true
  def handle_params(params, _uri, socket) do
    # Load member-specific data when LiveView mounts or params change
    member = socket.assigns.current_scope.user

    # Respect already assigned pagination state (set in mount) or default to page 1
    loans_page = socket.assigns[:loans_page] || 1
    fines_page = socket.assigns[:fines_page] || 1
    per_page = 10

    {loans, loans_total_pages} =
      Circulation.list_member_active_transactions_paginated(member.id, loans_page, per_page)

    {fines, fines_total_pages} =
      Circulation.list_member_unpaid_fines_paginated(member.id, fines_page, per_page)

    # Check for payment status in URL params
    socket =
      case params["payment"] do
        "success" ->
          socket
          |> put_flash(:info, "Payment successful! Your fine has been paid.")
          |> assign(:active_tab, :circulation)

        "failed" ->
          socket
          |> put_flash(:error, "Payment failed. Please try again or contact library staff.")
          |> assign(:active_tab, :circulation)

        _ ->
          socket
      end

    {:noreply,
     assign(socket,
       loans: loans,
       loans_page: loans_page,
       loans_total_pages: loans_total_pages,
       fines: fines,
       fines_page: fines_page,
       fines_total_pages: fines_total_pages
     )}
  end

  defp cache_bust(url) do
    ts = System.system_time(:millisecond)

    if String.contains?(url, "?"),
      do: url <> "&t=" <> Integer.to_string(ts),
      else: url <> "?t=" <> Integer.to_string(ts)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
        <header class="bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-500 rounded-xl text-white shadow-lg p-6 mb-8">
          <div class="flex items-center justify-center gap-6">
            <img
              src={@current_scope.user.user_image || ~p"/images/default_avatar.jpg"}
              alt="User Avatar"
              class="w-20 h-20 rounded-full ring-4 ring-white object-cover shadow-md"
              referrerpolicy="no-referrer"
            />
            <div>
              <h1 class="text-2xl font-semibold">Welcome back, {@current_scope.user.fullname}</h1>

              <p class="mt-1 text-sm opacity-90">
                This is your Atrium — a personalized member dashboard.
              </p>

              <div class="mt-3 flex items-center gap-3 text-sm">
                <span class="px-3 py-1 bg-white/20 rounded-full">
                  Loans: <strong class="ml-1">{length(@loans || [])}</strong>
                </span>
                <span class="px-3 py-1 bg-white/20 rounded-full">
                  Unpaid fines: <strong class="ml-1">{length(@fines || [])}</strong>
                </span>
              </div>
            </div>
          </div>
        </header>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Left column: profile card -->
          <div class="lg:col-span-1">
            <div class="bg-white dark:bg-gray-800 rounded-xl shadow-md p-6 sticky top-6">
              <div class="flex items-center gap-4">
                <img
                  src={@current_scope.user.user_image || ~p"/images/default_avatar.jpg"}
                  class="w-16 h-16 rounded-full object-cover"
                  alt="avatar"
                />
                <div>
                  <div class="text-lg font-medium">{@current_scope.user.fullname}</div>

                  <div class="text-sm mt-1">{role_name(@current_scope.user)}</div>
                </div>
              </div>

              <div class="mt-4 text-sm space-y-2">
                <div><strong>Email:</strong> {@current_scope.user.email}</div>

                <div><strong>Member type:</strong> {user_type_name(@current_scope.user)}</div>

                <div><strong>Node:</strong> {node_name(@current_scope.user)}</div>
              </div>

              <div class="mt-6">
                <h6 class="text-sm font-medium text-voile-muted mb-3">Circulation Summary</h6>

                <div class="grid grid-cols-2 gap-3">
                  <div class="p-3 bg-voile-neutral rounded-lg text-center">
                    <div class="text-xs text-voile-muted">Active Loans</div>

                    <div class="text-lg font-semibold">{@total_loans}</div>
                  </div>

                  <div class="p-3 bg-voile-neutral rounded-lg text-center">
                    <div class="text-xs text-voile-muted">Unpaid Fines</div>

                    <div class="text-lg font-semibold">{@total_unpaid_fines}</div>
                  </div>
                </div>

                <div class="mt-4">
                  <.button
                    type="button"
                    phx-click="select_tab"
                    phx-value-tab="circulation"
                    class="w-full primary-btn"
                  >
                    View Circulation
                  </.button>
                </div>
              </div>
            </div>
          </div>
          <!-- Right column: tabs and panels -->
          <div class="lg:col-span-2">
            <div class="bg-white dark:bg-gray-800 rounded-xl shadow p-6">
              <nav
                role="tablist"
                aria-label="Atrium navigation"
                class="flex space-x-2 mb-6"
                phx-keydown="navigate_tab"
                tabindex="0"
              >
                <%= for {tab, idx} <- Enum.with_index(@tabs) do %>
                  <% tab_str = Atom.to_string(tab) %> <% label = String.capitalize(tab_str) %>
                  <button
                    type="button"
                    role="tab"
                    aria-selected={@active_tab == tab}
                    phx-click="select_tab"
                    phx-value-tab={tab_str}
                    class={"px-4 py-2 text-sm font-medium rounded-lg focus:outline-none " <> (if @active_tab == tab, do: "bg-indigo-50 text-indigo-700 dark:bg-indigo-900/40 dark:text-indigo-200 shadow-sm", else: "text-voile-muted hover:bg-voile-surface dark:hover:bg-voile-dark")}
                  >
                    {label}
                  </button>
                <% end %>
              </nav>

              <div id="atrium-tabpanels" class="space-y-6">
                <%= if @active_tab == :collections do %>
                  <div
                    id="tab-collections"
                    class="p-4 rounded-md border border-voile-light dark:border-voile-dark"
                  >
                    <h4 class="text-lg font-semibold mb-2">Collections</h4>

                    <p class="text-sm">
                      Your collections will be shown here — curated and simple to browse.
                    </p>
                  </div>
                <% end %>

                <%= if @active_tab == :settings do %>
                  <div
                    id="tab-settings"
                    class="p-4 rounded-md border border-voile-light dark:border-voile-dark"
                  >
                    <h4 class="text-lg font-semibold mb-4">Account Settings</h4>

                    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
                      <div class="space-y-4">
                        <.form
                          for={@profile_form}
                          id="profile_form"
                          phx-submit="save_profile"
                          phx-change="validate_profile"
                        >
                          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                            <.input field={@profile_form[:fullname]} type="text" label="Full name" />
                            <.input
                              field={@profile_form[:username]}
                              type="text"
                              label="Username"
                              disabled
                            />
                          </div>

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
                                  <p class="text-sm text-voile-muted">Uploaded</p>

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
                                <p class="text-sm text-voile-muted">PNG, JPG, GIF up to 10MB</p>
                                <.live_file_input upload={@uploads.user_image} class="hidden" />
                                <label
                                  for={@uploads.user_image.ref}
                                  class="inline-flex items-center px-4 py-2 mt-2 bg-indigo-600 text-white rounded cursor-pointer"
                                >
                                  Choose file
                                </label>
                                <%= for entry <- @uploads.user_image.entries do %>
                                  <div class="mt-2 text-sm text-voile-muted">
                                    Uploading... {entry.progress}%
                                  </div>
                                <% end %>
                              </div>
                            <% end %>
                          </div>

                          <div class="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-3">
                            <.input field={@profile_form[:website]} type="url" label="Website" />
                            <.input
                              field={@profile_form[:twitter]}
                              type="text"
                              label="Twitter"
                              placeholder="@username"
                            />
                          </div>

                          <div class="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-3">
                            <.input
                              field={@user_profile_form[:fullname]}
                              type="text"
                              label="Full name"
                            />
                            <.input
                              field={@user_profile_form[:phone_number]}
                              type="text"
                              label="Phone number"
                            />
                            <.input field={@user_profile_form[:address]} type="text" label="Address" />
                            <.input
                              field={@user_profile_form[:birth_date]}
                              type="date"
                              label="Birth date"
                            />
                            <.input
                              field={@user_profile_form[:birth_place]}
                              type="text"
                              label="Birth place"
                            />
                            <.input field={@user_profile_form[:gender]} type="text" label="Gender" />
                            <.input
                              field={@user_profile_form[:registration_date]}
                              type="date"
                              label="Registration date"
                              disabled
                            />
                            <.input
                              field={@user_profile_form[:expiry_date]}
                              type="date"
                              label="Expiry date"
                              disabled
                            />
                            <.input
                              field={@user_profile_form[:organization]}
                              type="text"
                              label="Organization"
                            />
                            <.input
                              field={@user_profile_form[:department]}
                              type="text"
                              label="Department"
                            />
                            <.input
                              field={@user_profile_form[:position]}
                              type="text"
                              label="Position"
                            />
                          </div>
                          <hr class="my-4" />
                          <h5 class="text-sm font-medium mb-2">Member profile details</h5>

                          <div class="text-sm text-voile-muted mb-3 space-y-1">
                            <p>Role: {role_name(@current_scope.user)}</p>

                            <p>Member type: {user_type_name(@current_scope.user)}</p>

                            <p>Node: {node_name(@current_scope.user)}</p>

                            <p>Confirmed at: {@current_scope.user.confirmed_at}</p>

                            <p>
                              Last login: {@current_scope.user.last_login} ({@current_scope.user.last_login_ip})
                            </p>
                          </div>

                          <div class="mt-3 grid grid-cols-1 gap-2">
                            <.button phx-disable-with="Saving...">Save Profile</.button>
                          </div>
                        </.form>
                      </div>

                      <div>
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
                          />
                          <div class="mt-3">
                            <.button phx-disable-with="Changing...">Change Password</.button>
                          </div>
                        </.form>
                      </div>
                    </div>
                  </div>
                <% end %>
                <!-- Member dashboard panels -->
                <%= if @active_tab == :circulation do %>
                  <div class="space-y-6">
                    <!-- Loans card -->
                    <div class="p-4 rounded-md border border-voile-light dark:border-voile-dark bg-white/60 dark:bg-gray-800/60">
                      <div class="flex items-start justify-between">
                        <div>
                          <h4 class="text-lg font-semibold">Your Active Loans</h4>

                          <div class="text-sm text-voile-muted mt-1">
                            Active loans: <strong>{length(@loans || [])}</strong>
                          </div>
                        </div>

                        <div class="flex items-center gap-3">
                          <div class="text-sm text-voile-muted">
                            Page {@loans_page || 1} of {@loans_total_pages || 1}
                          </div>

                          <.button
                            phx-click="loans_prev"
                            disabled={@loans_page <= 1}
                            class="px-2 py-1"
                          >
                            Prev
                          </.button>
                          <.button
                            phx-click="loans_next"
                            disabled={@loans_page >= @loans_total_pages}
                            class="px-2 py-1"
                          >
                            Next
                          </.button>
                        </div>
                      </div>

                      <div class="mt-4">
                        <%= if @loans == [] do %>
                          <p class="text-sm text-voile-muted">You have no active loans.</p>
                        <% else %>
                          <ul class="space-y-3">
                            <%= for tx <- @loans do %>
                              <li class="flex items-center gap-4 p-3 bg-white dark:bg-gray-800 rounded-lg shadow-sm">
                                <div class="w-12 h-12 shrink-0 rounded overflow-hidden bg-voile-neutral">
                                  <%= if tx.item && tx.item.collection && tx.item.collection.thumbnail do %>
                                    <img
                                      src={tx.item.collection.thumbnail}
                                      class="w-full h-full object-cover"
                                    />
                                  <% else %>
                                    <div class="w-full h-full flex items-center justify-center text-xs text-voile-muted text-center">
                                      No image
                                    </div>
                                  <% end %>
                                </div>

                                <div class="flex-1 text-sm">
                                  <div class="font-medium">
                                    {if tx.collection && tx.collection.title,
                                      do: tx.collection.title,
                                      else: tx.item.item_code}
                                  </div>

                                  <div class="text-xs text-voile-muted">Due: {tx.due_date}</div>
                                </div>

                                <div class="flex-shrink-0">
                                  <% can_renew_type =
                                    @current_scope.user.user_type &&
                                      @current_scope.user.user_type.can_renew %> <% max_renewals =
                                    (@current_scope.user.user_type &&
                                       @current_scope.user.user_type.max_renewals) || 0 %> <% renew_disabled =
                                    not can_renew_type or tx.renewal_count >= max_renewals %>
                                  <.button
                                    class="primary-btn text-xs"
                                    phx-click="renew_loan"
                                    phx-value-transaction_id={tx.id}
                                    disabled={renew_disabled}
                                  >
                                    Renew
                                  </.button>
                                </div>
                              </li>
                            <% end %>
                          </ul>
                        <% end %>
                      </div>
                    </div>
                    <!-- Fines card -->
                    <div class="p-4 rounded-md border border-voile-light dark:border-voile-dark bg-white/60 dark:bg-gray-800/60">
                      <div class="flex items-start justify-between">
                        <div>
                          <h4 class="text-lg font-semibold">Outstanding Fines</h4>

                          <div class="text-sm text-voile-muted mt-1">
                            Unpaid fines: <strong>{length(@fines || [])}</strong>
                          </div>
                        </div>

                        <div class="flex items-center gap-3">
                          <div class="text-sm text-voile-muted">
                            Page {@fines_page || 1} of {@fines_total_pages || 1}
                          </div>

                          <.button
                            phx-click="fines_prev"
                            disabled={@fines_page <= 1}
                            class="px-2 py-1"
                          >
                            Prev
                          </.button>
                          <.button
                            phx-click="fines_next"
                            disabled={@fines_page >= @fines_total_pages}
                            class="px-2 py-1"
                          >
                            Next
                          </.button>
                        </div>
                      </div>

                      <div class="mt-4">
                        <%= if @fines == [] do %>
                          <p class="text-sm text-voile-muted">You have no unpaid fines.</p>
                        <% else %>
                          <ul class="space-y-3">
                            <%= for f <- @fines do %>
                              <% pending_payment =
                                case Circulation.get_pending_payment_for_fine(f.id) do
                                  {:ok, payment} -> payment
                                  _ -> nil
                                end %>
                              <li class="flex items-start gap-4 p-4 bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700">
                                <div class="w-12 h-12 shrink-0 rounded overflow-hidden bg-voile-neutral flex items-center justify-center text-xs text-voile-muted">
                                  <%= if f.item && f.item.collection && f.item.collection.thumbnail do %>
                                    <img
                                      src={f.item.collection.thumbnail}
                                      class="w-full h-full object-cover"
                                    />
                                  <% else %>
                                    <.icon name="hero-currency-dollar" class="w-6 h-6" />
                                  <% end %>
                                </div>

                                <div class="flex-1 text-sm space-y-2">
                                  <div class="font-medium text-gray-900 dark:text-gray-100">
                                    {f.description ||
                                      (f.item && f.item.collection && f.item.collection.title) ||
                                      "Library Fine"}
                                  </div>

                                  <div class="flex items-center gap-4 text-xs text-voile-muted">
                                    <span>
                                      Type:
                                      <strong class="text-gray-700 dark:text-gray-300">
                                        {String.upcase(f.fine_type || "")}
                                      </strong>
                                    </span>
                                    <span>
                                      Balance:
                                      <strong class="text-red-600 dark:text-red-400">
                                        Rp {f.balance}
                                      </strong>
                                    </span>
                                    <%= if f.fine_date do %>
                                      <span>Date: {Calendar.strftime(f.fine_date, "%Y-%m-%d")}</span>
                                    <% end %>
                                  </div>

                                  <%= if pending_payment do %>
                                    <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded p-2 mt-2">
                                      <div class="flex items-center justify-between">
                                        <div class="text-xs text-blue-800 dark:text-blue-200">
                                          <.icon name="hero-link" class="w-4 h-4 inline mr-1" />
                                          Payment link available
                                        </div>
                                        <a
                                          href={pending_payment.payment_url}
                                          target="_blank"
                                          class="text-xs bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 rounded"
                                        >
                                          Pay Now
                                          <.icon
                                            name="hero-arrow-top-right-on-square"
                                            class="w-3 h-3 inline ml-1"
                                          />
                                        </a>
                                      </div>
                                    </div>
                                  <% end %>
                                </div>

                                <div class="flex-shrink-0 flex flex-col gap-2">
                                  <%= if pending_payment do %>
                                    <a
                                      href={pending_payment.payment_url}
                                      target="_blank"
                                      class="px-4 py-2 bg-green-600 hover:bg-green-700 text-white text-sm rounded text-center"
                                    >
                                      <.icon name="hero-credit-card" class="w-4 h-4 inline mr-1" />
                                      Pay Online
                                    </a>
                                  <% else %>
                                    <button
                                      phx-click="request_payment_link"
                                      phx-value-fine_id={f.id}
                                      class="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm rounded"
                                    >
                                      <.icon name="hero-link" class="w-4 h-4 inline mr-1" />
                                      Get Payment Link
                                    </button>
                                  <% end %>

                                  <div class="text-xs text-center text-gray-500 dark:text-gray-400 mt-1">
                                    or pay in person at library
                                  </div>
                                </div>
                              </li>
                            <% end %>
                          </ul>
                        <% end %>
                      </div>
                    </div>
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
