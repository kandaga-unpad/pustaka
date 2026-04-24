defmodule VoileWeb.Frontend.Atrium.Index do
  use VoileWeb, :live_view
  use Gettext, backend: VoileWeb.Gettext

  alias Voile.Schema.Accounts
  alias Voile.Schema.Library.Circulation
  alias Client.Storage
  alias VoileWeb.Frontend.Atrium.AtriumHelper
  alias Voile.Notifications.LoanReminderNotifier
  alias VoileWeb.Utils.FormatIndonesiaTime

  @impl true
  def mount(_params, _session, socket) do
    tabs = [:circulation, :fines, :fine_history, :loan_history, :settings]

    user = socket.assigns.current_scope.user

    # Subscribe to loan reminder notifications if connected
    if connected?(socket) do
      LoanReminderNotifier.subscribe_to_member_notifications(user.id)
    end

    # Profile changeset (biodata + user_image handled as URL field for now)
    profile_changeset = Accounts.change_user(user)
    password_changeset = Accounts.change_user_password(user)

    # Check if user has a password set (for OAuth users or admin-created accounts)
    has_password = Accounts.has_password?(user)

    # prepare a changeset/form for user profile and set `as: :user` so inputs submit as user[...] params
    user_profile_changeset = Accounts.change_user(user)
    user_profile_form = to_form(user_profile_changeset, as: :user)

    # Load first page of loans and fines for the member
    {loans, loans_total_pages, _} =
      Circulation.list_member_active_transactions_paginated(user.id, 1, 10)

    {fines, fines_total_pages, _} = Circulation.list_member_unpaid_fines_paginated(user.id, 1, 10)

    total_loans = Circulation.count_list_active_transactions(user.id)
    total_unpaid_fines = Circulation.count_member_unpaid_fines(user.id)
    total_unpaid_fines_amount = Circulation.sum_member_unpaid_fines(user.id)

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
        total_unpaid_fines_amount: total_unpaid_fines_amount,
        loan_history: [],
        loan_history_page: 1,
        loan_history_total_pages: 0,
        fine_history: [],
        fine_history_page: 1,
        fine_history_total_pages: 0,
        paying: nil,
        renewing_loan_id: nil,
        show_renewal_modal: false,
        renewal_transaction: nil,
        current_password: nil,
        current_email: user.email,
        profile_form: to_form(profile_changeset),
        user_profile_form: user_profile_form,
        password_form: to_form(password_changeset),
        trigger_submit: false,
        has_password: has_password,
        show_payment_modal: false,
        payment_link_data: nil,
        payment_processing: false,
        # Loan reminder notification assigns
        loan_reminders: [],
        show_notification_badge: false
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
    {loans, total, _} = Circulation.list_member_active_transactions_paginated(member.id, page, 10)
    {:noreply, assign(socket, loans: loans, loans_page: page, loans_total_pages: total)}
  end

  def handle_event("loans_next", _params, socket) do
    member = socket.assigns.current_scope.user
    page = min((socket.assigns.loans_page || 1) + 1, socket.assigns.loans_total_pages || 1)
    {loans, total, _} = Circulation.list_member_active_transactions_paginated(member.id, page, 10)
    {:noreply, assign(socket, loans: loans, loans_page: page, loans_total_pages: total)}
  end

  def handle_event("fines_prev", _params, socket) do
    member = socket.assigns.current_scope.user
    page = max((socket.assigns.fines_page || 1) - 1, 1)
    {fines, total, _} = Circulation.list_member_unpaid_fines_paginated(member.id, page, 10)
    {:noreply, assign(socket, fines: fines, fines_page: page, fines_total_pages: total)}
  end

  def handle_event("fines_next", _params, socket) do
    member = socket.assigns.current_scope.user
    page = min((socket.assigns.fines_page || 1) + 1, socket.assigns.fines_total_pages || 1)
    {fines, total, _} = Circulation.list_member_unpaid_fines_paginated(member.id, page, 10)
    {:noreply, assign(socket, fines: fines, fines_page: page, fines_total_pages: total)}
  end

  def handle_event("loan_history_prev", _params, socket) do
    member = socket.assigns.current_scope.user
    page = max((socket.assigns.loan_history_page || 1) - 1, 1)

    {history, total, _} =
      Circulation.list_member_transaction_history_paginated(member.id, page, 10)

    {:noreply,
     assign(socket,
       loan_history: history,
       loan_history_page: page,
       loan_history_total_pages: total
     )}
  end

  def handle_event("loan_history_next", _params, socket) do
    member = socket.assigns.current_scope.user

    page =
      min(
        (socket.assigns.loan_history_page || 1) + 1,
        socket.assigns.loan_history_total_pages || 1
      )

    {history, total, _} =
      Circulation.list_member_transaction_history_paginated(member.id, page, 10)

    {:noreply,
     assign(socket,
       loan_history: history,
       loan_history_page: page,
       loan_history_total_pages: total
     )}
  end

  def handle_event("fine_history_prev", _params, socket) do
    member = socket.assigns.current_scope.user
    page = max((socket.assigns.fine_history_page || 1) - 1, 1)
    {history, total, _} = Circulation.list_member_paid_fines_paginated(member.id, page, 10)

    {:noreply,
     assign(socket,
       fine_history: history,
       fine_history_page: page,
       fine_history_total_pages: total
     )}
  end

  def handle_event("fine_history_next", _params, socket) do
    member = socket.assigns.current_scope.user

    page =
      min(
        (socket.assigns.fine_history_page || 1) + 1,
        socket.assigns.fine_history_total_pages || 1
      )

    {history, total, _} = Circulation.list_member_paid_fines_paginated(member.id, page, 10)

    {:noreply,
     assign(socket,
       fine_history: history,
       fine_history_page: page,
       fine_history_total_pages: total
     )}
  end

  @impl true
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    member = socket.assigns.current_scope.user

    tab_atom =
      case tab do
        "circulation" -> :circulation
        "fines" -> :fines
        "fine_history" -> :fine_history
        "loan_history" -> :loan_history
        "settings" -> :settings
        _ -> :circulation
      end

    # Load data when switching to history tabs
    socket =
      case tab_atom do
        :loan_history ->
          {loan_history, loan_history_total_pages, _} =
            Circulation.list_member_transaction_history_paginated(member.id, 1, 10)

          assign(socket,
            loan_history: loan_history,
            loan_history_page: 1,
            loan_history_total_pages: loan_history_total_pages
          )

        :fine_history ->
          {fine_history, fine_history_total_pages, _} =
            Circulation.list_member_paid_fines_paginated(member.id, 1, 10)

          assign(socket,
            fine_history: fine_history,
            fine_history_page: 1,
            fine_history_total_pages: fine_history_total_pages
          )

        _ ->
          socket
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
  def handle_event("open_renewal_modal", %{"transaction_id" => tx_id}, socket) do
    member = socket.assigns.current_scope.user
    user_type = Map.get(member, :user_type)

    case AtriumHelper.can_renew_transaction_precheck(tx_id, member, user_type) do
      {:error, msg} ->
        {:noreply, socket |> put_flash(:error, msg)}

      {:ok} ->
        case Circulation.get_transaction(tx_id) do
          nil ->
            {:noreply, socket |> put_flash(:error, gettext("Transaction not found"))}

          tx ->
            if tx.member_id != member.id do
              {:noreply,
               socket |> put_flash(:error, gettext("You can only renew your own loans"))}
            else
              {:noreply,
               socket
               |> assign(:show_renewal_modal, true)
               |> assign(:renewal_transaction, tx)}
            end
        end
    end
  end

  def handle_event("close_renewal_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_renewal_modal, false)
     |> assign(:renewal_transaction, nil)}
  end

  def handle_event("confirm_renew_loan", _params, socket) do
    tx = socket.assigns.renewal_transaction

    if tx do
      member = socket.assigns.current_scope.user
      get_admin_id = Circulation.get_admin_id_for_self_renewal()

      # Set renewing state
      socket =
        socket
        |> assign(:renewing_loan_id, tx.id)
        |> assign(:show_renewal_modal, false)
        |> assign(:renewal_transaction, nil)

      # Attempt to renew via Circulation
      case Circulation.renew_transaction(tx.id, get_admin_id, %{}) do
        {:ok, updated_transaction} ->
          {loans, loans_total_pages, _} =
            Circulation.list_member_active_transactions_paginated(
              member.id,
              socket.assigns.loans_page || 1,
              10
            )

          # Format the new due date for user-friendly display
          new_due_date =
            if updated_transaction.due_date do
              FormatIndonesiaTime.format_full_indonesian_date(updated_transaction.due_date)
            else
              "N/A"
            end

          {:noreply,
           socket
           |> assign(:renewing_loan_id, nil)
           |> put_flash(
             :info,
             gettext("Loan renewed successfully! New due date: %{new_due_date}",
               new_due_date: new_due_date
             )
           )
           |> assign(loans: loans, loans_total_pages: loans_total_pages)}

        {:error, reason} ->
          error_message =
            case reason do
              :max_renewals_reached ->
                gettext("Maximum renewals reached for this item")

              :overdue ->
                gettext("Cannot renew overdue items. Please return or contact library staff")

              :has_holds ->
                gettext("Cannot renew - this item has pending reservations")

              _ ->
                gettext("Could not renew loan: %{reason}", reason: inspect(reason))
            end

          {:noreply, socket |> assign(:renewing_loan_id, nil) |> put_flash(:error, error_message)}
      end
    else
      {:noreply, socket |> put_flash(:error, gettext("Transaction not found"))}
    end
  end

  @impl true
  def handle_event("renew_loan", %{"transaction_id" => tx_id}, socket) do
    # This event is now just a redirect to open the modal
    send(self(), {:open_renewal_modal, tx_id})
    {:noreply, socket}
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
            {:noreply, socket |> put_flash(:error, gettext("You can only pay your own fines"))}
          else
            case Circulation.pay_fine(fine_id, dec, "cash", member.id, nil) do
              {:ok, _updated} ->
                {fines, fines_total_pages, _} =
                  Circulation.list_member_unpaid_fines_paginated(
                    member.id,
                    socket.assigns.fines_page || 1,
                    10
                  )

                {:noreply,
                 socket
                 |> put_flash(:info, gettext("Fine payment successful"))
                 |> assign(fines: fines, fines_total_pages: fines_total_pages)}

              {:error, reason} ->
                {:noreply,
                 socket
                 |> put_flash(
                   :error,
                   gettext("Payment failed: %{reason}", reason: inspect(reason))
                 )}
            end
          end
        rescue
          _ ->
            {:noreply, socket |> put_flash(:error, gettext("Fine not found"))}
        end

      :error ->
        {:noreply, socket |> put_flash(:error, gettext("Invalid amount"))}
    end
  end

  def handle_event("request_payment_link", %{"fine_id" => fine_id}, socket) do
    member = socket.assigns.current_scope.user

    # Check if payment link already exists
    case Circulation.get_pending_payment_for_fine(fine_id) do
      {:ok, payment} ->
        # Show existing payment link
        {fines, fines_total_pages, _} =
          Circulation.list_member_unpaid_fines_paginated(
            member.id,
            socket.assigns.fines_page || 1,
            10
          )

        {:noreply,
         socket
         |> assign(
           fines: fines,
           fines_total_pages: fines_total_pages,
           show_payment_modal: true,
           payment_link_data: %{
             payment_url: payment.payment_url,
             amount: payment.amount,
             fine_id: fine_id,
             status: payment.status
           }
         )}

      {:error, :not_found} ->
        # Create new payment link
        case Circulation.create_payment_link_for_fine(
               fine_id,
               member.id,
               success_redirect_url: url(~p"/atrium?payment=success"),
               failure_redirect_url: url(~p"/atrium?payment=failed")
             ) do
          {:ok, payment} ->
            {fines, fines_total_pages, _} =
              Circulation.list_member_unpaid_fines_paginated(
                member.id,
                socket.assigns.fines_page || 1,
                10
              )

            {:noreply,
             socket
             |> assign(
               fines: fines,
               fines_total_pages: fines_total_pages,
               show_payment_modal: true,
               payment_link_data: %{
                 payment_url: payment.payment_url,
                 amount: payment.amount,
                 fine_id: fine_id,
                 status: payment.status
               }
             )
             |> put_flash(:info, gettext("Payment link created successfully!"))}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               gettext("Failed to create payment link: %{reason}", reason: inspect(reason))
             )}
        end
    end
  end

  def handle_event("close_payment_modal", _params, socket) do
    {:noreply, assign(socket, show_payment_modal: false, payment_link_data: nil)}
  end

  def handle_event("copy_payment_link", _params, socket) do
    {:noreply, put_flash(socket, :info, gettext("Payment link copied to clipboard!"))}
  end

  def handle_event("dismiss_notification_badge", _params, socket) do
    {:noreply, assign(socket, show_notification_badge: false)}
  end

  def handle_event("clear_reminders", _params, socket) do
    {:noreply, assign(socket, loan_reminders: [], show_notification_badge: false)}
  end

  def handle_event("open_payment_link", %{"fine_id" => fine_id}, socket) do
    case Circulation.get_pending_payment_for_fine(fine_id) do
      {:ok, payment} ->
        # The actual redirect will be handled by JS on client side
        {:noreply, socket |> push_event("redirect", %{url: payment.payment_url})}

      {:error, _} ->
        {:noreply, socket |> put_flash(:error, gettext("Payment link not found"))}
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
      try do
        Storage.delete(image)
      rescue
        _ -> :ok
      end

      case Accounts.update_profile_user(user, %{"user_image" => nil}) do
        {:ok, updated_user} ->
          changeset = Accounts.change_user(updated_user, %{})

          {:noreply,
           socket
           |> assign(:profile_form, to_form(changeset))
           |> assign(current_scope: Map.put(socket.assigns.current_scope, :user, updated_user))
           |> put_flash(:info, gettext("User image deleted successfully"))}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to delete user image"))}
      end
    else
      # just clear any preview value in the form params
      form_params = Map.put(socket.assigns.profile_form.params || %{}, "user_image", nil)
      changeset = Accounts.change_user(user, form_params)

      {:noreply,
       socket
       |> assign(:profile_form, to_form(changeset))
       |> put_flash(:info, gettext("User image removed"))}
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

    case Accounts.update_profile_user(user, user_params) do
      {:ok, updated_user} ->
        # Update assigns so the UI (header/profile) reflects the saved user immediately
        socket =
          socket
          |> put_flash(:info, gettext("Profile updated"))
          |> assign(
            profile_form: to_form(Accounts.change_user(updated_user)),
            current_email: updated_user.email
          )
          |> assign(current_scope: Map.put(socket.assigns.current_scope, :user, updated_user))

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

  def handle_event("request_password_reset", _params, socket) do
    user = socket.assigns.current_scope.user

    # Send password reset email
    Accounts.deliver_user_reset_password_instructions(
      user,
      &url(~p"/users/reset_password/#{&1}")
    )

    {:noreply,
     socket
     |> put_flash(
       :info,
       "Password reset instructions have been sent to #{user.email}. Please check your inbox."
     )}
  end

  @impl true
  def handle_info({:open_renewal_modal, tx_id}, socket) do
    member = socket.assigns.current_scope.user
    user_type = Map.get(member, :user_type)

    case AtriumHelper.can_renew_transaction_precheck(tx_id, member, user_type) do
      {:error, msg} ->
        {:noreply, socket |> put_flash(:error, msg)}

      {:ok} ->
        case Circulation.get_transaction(tx_id) do
          nil ->
            {:noreply, socket |> put_flash(:error, "Transaction not found")}

          tx ->
            if tx.member_id != member.id do
              {:noreply, socket |> put_flash(:error, "You can only renew your own loans")}
            else
              {:noreply,
               socket
               |> assign(:show_renewal_modal, true)
               |> assign(:renewal_transaction, tx)}
            end
        end
    end
  end

  def handle_info(:reload_after_payment, socket) do
    member = socket.assigns.current_scope.user
    fines_page = socket.assigns[:fines_page] || 1

    # Reload fines after webhook should have processed
    {fines, fines_total_pages, _} =
      Circulation.list_member_unpaid_fines_paginated(member.id, fines_page, 10)

    total_unpaid_fines = Circulation.count_member_unpaid_fines(member.id)
    total_unpaid_fines_amount = Circulation.sum_member_unpaid_fines(member.id)

    {:noreply,
     socket
     |> assign(
       fines: fines,
       fines_total_pages: fines_total_pages,
       total_unpaid_fines: total_unpaid_fines,
       total_unpaid_fines_amount: total_unpaid_fines_amount,
       payment_processing: false
     )
     |> put_flash(:info, "✅ Payment confirmed! Your fine has been updated.")}
  end

  @impl true
  def handle_info({:loan_reminder, data}, socket) do
    # Handle loan reminder notifications from PubSub
    %{
      collection_title: collection_title,
      item_code: item_code,
      due_date: due_date,
      days_until_due: days_until_due
    } = data

    message =
      "📚 Reminder: \"#{collection_title}\" (#{item_code}) is due in #{days_until_due} day(s) on #{FormatIndonesiaTime.format_full_indonesian_date(due_date)}"

    # Add to reminders list and show badge
    reminders = [data | socket.assigns.loan_reminders]

    {:noreply,
     socket
     |> assign(loan_reminders: reminders, show_notification_badge: true)
     |> put_flash(:info, message)}
  end

  @impl true
  def handle_info({:loan_overdue, data}, socket) do
    # Handle overdue loan notifications from PubSub
    %{
      collection_title: collection_title,
      item_code: item_code,
      due_date: due_date,
      days_overdue: days_overdue
    } = data

    message =
      "⚠️ Overdue: \"#{collection_title}\" (#{item_code}) was due on #{FormatIndonesiaTime.format_full_indonesian_date(due_date)} and is now #{days_overdue} day(s) overdue!"

    # Add to reminders list and show badge
    reminders = [data | socket.assigns.loan_reminders]

    {:noreply,
     socket
     |> assign(loan_reminders: reminders, show_notification_badge: true)
     |> put_flash(:error, message)}
  end

  @impl true
  def handle_info({:manual_reminder, data}, socket) do
    # Handle manual reminder from librarian
    %{
      collection_title: collection_title,
      item_code: item_code,
      due_date: due_date,
      days_until_due: days_until_due
    } = data

    message =
      "📬 Library Notice: Please remember to return \"#{collection_title}\" (#{item_code}) by #{FormatIndonesiaTime.format_full_indonesian_date(due_date)} (#{days_until_due} day(s) remaining)"

    # Add to reminders list and show badge
    reminders = [data | socket.assigns.loan_reminders]

    {:noreply,
     socket
     |> assign(loan_reminders: reminders, show_notification_badge: true)
     |> put_flash(:info, message)}
  end

  defp handle_progress(:user_image, entry, socket) do
    if entry.done? do
      # If there is an existing image in form params, attempt to delete it
      if socket.assigns.profile_form.params && socket.assigns.profile_form.params["user_image"] do
        try do
          Storage.delete(socket.assigns.profile_form.params["user_image"])
        rescue
          _ -> :ok
        end
      end

      result =
        consume_uploaded_entries(socket, :user_image, fn %{path: path}, entry ->
          upload = %Plug.Upload{
            path: path,
            filename: entry.client_name,
            content_type: entry.client_type
          }

          user_id = socket.assigns.current_scope.user && socket.assigns.current_scope.user.id

          try do
            Storage.upload(upload,
              folder: "user_image",
              generate_filename: true,
              unit_id: user_id
            )
          rescue
            _ -> {:error, "Failed to upload image"}
          end
        end)

      case result do
        [{:ok, url}] ->
          user = socket.assigns.current_scope.user
          old_image = user.user_image

          case Accounts.update_profile_user(user, %{"user_image" => url}) do
            {:ok, updated_user} ->
              # If the old image looks like an upload path, attempt to delete it
              if old_image && is_binary(old_image) && old_image != updated_user.user_image &&
                   String.starts_with?(old_image, "/uploads") do
                try do
                  Storage.delete(old_image)
                rescue
                  _ -> :ok
                end
              end

              form_params = Map.put(socket.assigns.profile_form.params || %{}, "user_image", url)
              changeset = Accounts.change_user(updated_user, form_params)

              {:noreply,
               socket
               |> assign(:profile_form, to_form(changeset))
               |> assign(
                 current_scope: Map.put(socket.assigns.current_scope, :user, updated_user)
               )
               |> put_flash(:info, gettext("Profile image uploaded"))}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to save profile image")}
          end

        [url] when is_binary(url) ->
          user = socket.assigns.current_scope.user
          old_image = user.user_image

          case Accounts.update_profile_user(user, %{"user_image" => url}) do
            {:ok, updated_user} ->
              # If the old image looks like an upload path, attempt to delete it
              if old_image && is_binary(old_image) && old_image != updated_user.user_image &&
                   String.starts_with?(old_image, "/uploads") do
                try do
                  Storage.delete(old_image)
                rescue
                  _ -> :ok
                end
              end

              form_params = Map.put(socket.assigns.profile_form.params || %{}, "user_image", url)
              changeset = Accounts.change_user(updated_user, form_params)

              {:noreply,
               socket
               |> assign(:profile_form, to_form(changeset))
               |> assign(
                 current_scope: Map.put(socket.assigns.current_scope, :user, updated_user)
               )
               |> put_flash(:info, gettext("Profile image uploaded"))}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to save profile image")}
          end

        [{:error, err}] ->
          {:noreply, put_flash(socket, :error, err)}

        _ ->
          {:noreply, put_flash(socket, :error, "Unexpected upload result: #{inspect(result)}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Load member-specific data when LiveView mounts or params change
    member = socket.assigns.current_scope.user

    # Respect already assigned pagination state (set in mount) or default to page 1
    loans_page = socket.assigns[:loans_page] || 1
    fines_page = socket.assigns[:fines_page] || 1
    per_page = 10

    {loans, loans_total_pages, _} =
      Circulation.list_member_active_transactions_paginated(member.id, loans_page, per_page)

    {fines, fines_total_pages, _} =
      Circulation.list_member_unpaid_fines_paginated(member.id, fines_page, per_page)

    # Reload totals
    total_loans = Circulation.count_list_active_transactions(member.id)
    total_unpaid_fines = Circulation.count_member_unpaid_fines(member.id)
    total_unpaid_fines_amount = Circulation.sum_member_unpaid_fines(member.id)

    # Check for payment status in URL params
    socket =
      case params["payment"] do
        "success" ->
          # Give webhook a moment to process, then reload after mount
          Process.send_after(self(), :reload_after_payment, 2000)

          socket
          |> put_flash(
            :info,
            "🎉 Payment completed! Please wait a moment while we confirm your payment..."
          )
          |> assign(active_tab: :fines, payment_processing: true)

        "failed" ->
          socket
          |> put_flash(
            :error,
            "Payment failed or was cancelled. Please try again or contact library staff."
          )
          |> assign(active_tab: :fines, payment_processing: false)

        _ ->
          assign(socket, payment_processing: false)
      end

    {:noreply,
     assign(socket,
       loans: loans,
       loans_page: loans_page,
       loans_total_pages: loans_total_pages,
       fines: fines,
       fines_page: fines_page,
       fines_total_pages: fines_total_pages,
       total_loans: total_loans,
       total_unpaid_fines: total_unpaid_fines,
       total_unpaid_fines_amount: total_unpaid_fines_amount
     )}
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
                {gettext("This is your Atrium — a personalized member dashboard.")}
              </p>

              <div class="mt-3 flex items-center gap-3 text-sm">
                <span class="px-3 py-1 bg-white/20 rounded-full">
                  {gettext("Fines:")}
                  <strong class="ml-1">
                    Rp {AtriumHelper.format_currency(@total_unpaid_fines_amount)}
                  </strong>
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

                  <div class="text-sm mt-1">{@current_scope.user.identifier}</div>
                </div>
              </div>

              <div class="mt-4 text-sm space-y-2">
                <div><strong>{gettext("Email:")}</strong> {@current_scope.user.email}</div>

                <div>
                  <strong>{gettext("Member type:")}</strong> {AtriumHelper.user_type_name(
                    @current_scope.user
                  )}
                </div>

                <div>
                  <strong>{gettext("Location Node:")}</strong> {AtriumHelper.node_name(
                    @current_scope.user
                  )}
                </div>
              </div>

              <div class="mt-6">
                <h6 class="text-sm font-medium text-voile-muted mb-3">
                  {gettext("Circulation Summary")}
                </h6>

                <div class="grid grid-cols-2 gap-3">
                  <div class="p-3 bg-voile-neutral rounded-lg text-center">
                    <div class="text-xs text-voile-muted">{gettext("Active Loans")}</div>

                    <div class="text-lg font-semibold">{@total_loans}</div>
                  </div>

                  <div class="p-3 bg-voile-neutral rounded-lg text-center">
                    <div class="text-xs text-voile-muted">{gettext("Unpaid Fines")}</div>

                    <div class="text-lg font-semibold">
                      Rp {AtriumHelper.format_currency(@total_unpaid_fines_amount)}
                    </div>

                    <div class="text-xs text-voile-muted mt-1">
                      {@total_unpaid_fines} {gettext("fine(s)")}
                    </div>
                  </div>
                </div>

                <div class="mt-4 flex flex-col gap-2">
                  <.button
                    type="button"
                    phx-click="select_tab"
                    phx-value-tab="circulation"
                    class="w-full primary-btn"
                  >
                    {gettext("View Circulation")}
                  </.button>
                  <.link
                    navigate={~p"/atrium/requisitions/new"}
                    class="w-full inline-flex items-center justify-center gap-2 px-4 py-2 text-sm font-medium rounded-lg bg-indigo-100 hover:bg-indigo-200 dark:bg-indigo-900/40 dark:hover:bg-indigo-900/60 text-indigo-700 dark:text-indigo-300 transition-colors"
                  >
                    <.icon name="hero-clipboard-document-list" class="w-4 h-4" />
                    {gettext("Requisition Form")}
                  </.link>
                  <.link
                    navigate={~p"/atrium/clearance"}
                    class="w-full inline-flex items-center justify-center gap-2 px-4 py-2 text-sm font-medium rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white transition-colors"
                  >
                    <.icon name="hero-document-check" class="w-4 h-4" />
                    {gettext("Bebas Pustaka")}
                  </.link>
                </div>
              </div>
            </div>
          </div>
          <!-- Right column: tabs and panels -->
          <div class="lg:col-span-2">
            <div class="bg-white dark:bg-gray-800 rounded-xl shadow p-4 sm:p-6">
              <nav
                role="tablist"
                aria-label="Atrium navigation"
                class="flex flex-col sm:flex-row sm:flex-wrap gap-2 sm:gap-2 mb-6 overflow-x-auto scrollbar-thin scrollbar-thumb-gray-300 dark:scrollbar-thumb-gray-600"
                phx-keydown="navigate_tab"
                tabindex="0"
              >
                <%= for {tab, idx} <- Enum.with_index(@tabs) do %>
                  <% tab_str = Atom.to_string(tab) %> <% label =
                    case tab do
                      :fine_history -> gettext("Fine History")
                      :loan_history -> gettext("Loan History")
                      _ -> String.capitalize(tab_str)
                    end %>
                  <button
                    type="button"
                    role="tab"
                    aria-selected={@active_tab == tab}
                    phx-click="select_tab"
                    phx-value-tab={tab_str}
                    class={"w-full sm:w-auto px-4 py-2.5 sm:py-2 text-sm font-medium rounded-lg focus:outline-none transition-colors whitespace-nowrap " <> (if @active_tab == tab, do: "bg-indigo-50 text-indigo-700 dark:bg-indigo-900/40 dark:text-indigo-200 shadow-sm border-2 border-indigo-200 dark:border-indigo-700", else: "text-voile-muted hover:bg-voile-surface dark:hover:bg-voile-dark border border-gray-200 dark:border-gray-700")}
                  >
                    {label}
                  </button>
                <% end %>
              </nav>

              <div id="atrium-tabpanels" class="space-y-6">
                <%= if @active_tab == :settings do %>
                  <div
                    id="tab-settings"
                    class="p-4 rounded-md border border-voile-light dark:border-voile-dark"
                  >
                    <h4 class="text-lg font-semibold mb-4">{gettext("Account Settings")}</h4>

                    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
                      <div class="space-y-4">
                        <.form
                          for={@profile_form}
                          id="profile_form"
                          phx-submit="save_profile"
                          phx-change="validate_profile"
                        >
                          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                            <.input
                              field={@profile_form[:fullname]}
                              type="text"
                              label={gettext("Full name")}
                            />
                            <.input
                              field={@profile_form[:username]}
                              type="text"
                              label={gettext("Username")}
                              disabled
                            />
                          </div>

                          <.input
                            field={@profile_form[:email]}
                            type="email"
                            label={gettext("Email")}
                            disabled
                          />
                          <label class="block text-sm font-medium text-gray-700 mb-2">
                            {gettext("Profile image")}
                          </label>
                          <div phx-drop-target={@uploads.user_image.ref} class="space-y-2">
                            <%= if @current_scope.user.user_image do %>
                              <div class="flex items-center gap-4">
                                <img
                                  src={AtriumHelper.cache_bust(@current_scope.user.user_image)}
                                  class="w-20 h-20 rounded-full object-cover"
                                />
                                <div class="flex-1">
                                  <p class="text-sm text-voile-muted">Current profile image</p>

                                  <.button
                                    type="button"
                                    phx-click="delete_user_image"
                                    phx-value-image={@current_scope.user.user_image}
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
                            <.input
                              field={@profile_form[:website]}
                              type="url"
                              label={gettext("Website")}
                            />
                            <.input
                              field={@profile_form[:twitter]}
                              type="text"
                              label={gettext("Twitter")}
                              placeholder="@username"
                            />
                          </div>

                          <div class="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-3">
                            <.input
                              field={@user_profile_form[:fullname]}
                              type="text"
                              label={gettext("Full name")}
                            />
                            <.input
                              field={@user_profile_form[:phone_number]}
                              type="text"
                              label={gettext("Phone number")}
                            />
                            <.input
                              field={@user_profile_form[:address]}
                              type="text"
                              label={gettext("Address")}
                            />
                            <.input
                              field={@user_profile_form[:birth_date]}
                              type="date"
                              label={gettext("Birth date")}
                            />
                            <.input
                              field={@user_profile_form[:birth_place]}
                              type="text"
                              label={gettext("Birth place")}
                            />
                            <.input
                              field={@user_profile_form[:gender]}
                              type="text"
                              label={gettext("Gender")}
                            />
                            <.input
                              field={@user_profile_form[:registration_date]}
                              type="date"
                              label={gettext("Registration date")}
                              disabled
                            />
                            <.input
                              field={@user_profile_form[:expiry_date]}
                              type="date"
                              label={gettext("Expiry date")}
                              disabled
                            />
                            <.input
                              field={@user_profile_form[:organization]}
                              type="text"
                              label={gettext("Organization")}
                            />
                            <.input
                              field={@user_profile_form[:department]}
                              type="text"
                              label={gettext("Department")}
                            />
                            <.input
                              field={@user_profile_form[:position]}
                              type="text"
                              label={gettext("Position")}
                            />
                          </div>
                          <hr class="my-4" />
                          <h5 class="text-sm font-medium mb-2">
                            {gettext("Member profile details")}
                          </h5>

                          <div class="text-sm text-voile-muted mb-3 space-y-1">
                            <p>{gettext("Role:")} {AtriumHelper.role_name(@current_scope.user)}</p>

                            <p>
                              {gettext("Member type:")} {AtriumHelper.user_type_name(
                                @current_scope.user
                              )}
                            </p>

                            <p>{gettext("Node:")} {AtriumHelper.node_name(@current_scope.user)}</p>

                            <p>{gettext("Confirmed at:")} {@current_scope.user.confirmed_at}</p>

                            <p>
                              {gettext("Last login:")} {@current_scope.user.last_login} ({@current_scope.user.last_login_ip})
                            </p>
                          </div>

                          <div class="mt-3 grid grid-cols-1 gap-2">
                            <.button phx-disable-with="Saving...">{gettext("Save Profile")}</.button>
                          </div>
                        </.form>
                      </div>

                      <div>
                        <%= if @has_password do %>
                          <%!-- Change Password Form (for users with existing password) --%>
                          <h5 class="text-lg font-semibold mb-4">{gettext("Change Password")}</h5>

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
                              label={gettext("New password")}
                              required
                            />
                            <.input
                              field={@password_form[:password_confirmation]}
                              type="password"
                              label={gettext("Confirm new password")}
                            />
                            <.input
                              field={@password_form[:current_password]}
                              name="current_password"
                              type="password"
                              label={gettext("Current password")}
                              id="current_password_for_password"
                              value={@current_password}
                              required
                            />
                            <div class="mt-3">
                              <.button phx-disable-with="Changing...">
                                {gettext("Change Password")}
                              </.button>
                            </div>
                          </.form>

                          <div class="mt-6 pt-6 border-t border-gray-200 dark:border-gray-700">
                            <div class="text-sm text-gray-600 dark:text-gray-400 mb-3">
                              <strong>{gettext("Forgot your current password?")}</strong>
                            </div>

                            <.button
                              type="button"
                              phx-click="request_password_reset"
                            >
                              <.icon name="hero-envelope" class="w-5 h-5 mr-2" /> {gettext(
                                "Request Password Reset Email"
                              )}
                            </.button>
                            <p class="mt-2 text-xs text-gray-500 dark:text-gray-400">
                              {gettext(
                                "We'll send you a secure link to reset your password via email."
                              )}
                            </p>
                          </div>
                        <% else %>
                          <%!-- Password Reset Request (for OAuth users or admin-created accounts) --%>
                          <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4 mb-4">
                            <div class="flex gap-3">
                              <.icon
                                name="hero-information-circle"
                                class="w-5 h-5 text-blue-600 dark:text-blue-400 shrink-0 mt-0.5"
                              />
                              <div class="text-sm text-blue-800 dark:text-blue-200">
                                <p class="font-medium mb-1">{gettext("No Password Set")}</p>

                                <p>
                                  {gettext(
                                    "You currently don't have a password for your account. You can set one by requesting a password reset link via email."
                                  )}
                                </p>
                              </div>
                            </div>
                          </div>

                          <h5 class="text-lg font-semibold mb-4">{gettext("Set Up Password")}</h5>

                          <div class="space-y-4">
                            <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-6">
                              <div class="flex items-start gap-4">
                                <div class="flex-shrink-0">
                                  <div class="w-12 h-12 bg-indigo-100 dark:bg-indigo-900/30 rounded-full flex items-center justify-center">
                                    <.icon
                                      name="hero-shield-check"
                                      class="w-6 h-6 text-indigo-600 dark:text-indigo-400"
                                    />
                                  </div>
                                </div>

                                <div class="flex-1">
                                  <h6 class="font-medium text-gray-900 dark:text-gray-100 mb-2">
                                    {gettext("Secure Password Setup")}
                                  </h6>

                                  <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
                                    {gettext("For security reasons, we'll send you a secure link to")}
                                    <strong>{@current_email}</strong> {gettext(
                                      "where you can safely set up your password."
                                    )}
                                  </p>

                                  <.button
                                    type="button"
                                    phx-click="request_password_reset"
                                    class="w-full"
                                  >
                                    <.icon name="hero-envelope" class="w-5 h-5 mr-2" /> {gettext(
                                      "Send Password Setup Link"
                                    )}
                                  </.button>
                                </div>
                              </div>
                            </div>

                            <div class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg p-4">
                              <div class="flex gap-3">
                                <.icon
                                  name="hero-light-bulb"
                                  class="w-5 h-5 text-amber-600 dark:text-amber-400 shrink-0 mt-0.5"
                                />
                                <div class="text-xs text-amber-800 dark:text-amber-200 space-y-1">
                                  <p class="font-medium">Why use email for password setup?</p>

                                  <ul class="list-disc list-inside space-y-0.5 text-amber-700 dark:text-amber-300">
                                    <li>Verifies you have access to your registered email</li>

                                    <li>Provides a secure, time-limited link</li>

                                    <li>Prevents unauthorized password changes</li>

                                    <li>Industry-standard security practice</li>
                                  </ul>
                                </div>
                              </div>
                            </div>
                          </div>
                        <% end %>
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
                          <h4 class="text-lg font-semibold">{gettext("Your Active Loans")}</h4>

                          <div class="text-sm text-voile-muted mt-1">
                            {gettext("Showing")} {length(@loans || [])} {gettext("of")}
                            <strong>{@total_loans}</strong> {gettext("active loans")}
                          </div>
                        </div>

                        <%= if @loans_total_pages > 1 do %>
                          <div class="flex items-center gap-3">
                            <div class="text-sm text-voile-muted">
                              Page {@loans_page || 1} of {@loans_total_pages || 1}
                            </div>

                            <.button
                              phx-click="loans_prev"
                              disabled={@loans_page <= 1}
                            >
                              {gettext("Prev")}
                            </.button>
                            <.button
                              phx-click="loans_next"
                              disabled={@loans_page >= @loans_total_pages}
                            >
                              {gettext("Next")}
                            </.button>
                          </div>
                        <% end %>
                      </div>

                      <div class="mt-4">
                        <%= if @loans == [] do %>
                          <p class="text-sm text-voile-muted">
                            {gettext("You have no active loans.")}
                          </p>
                        <% else %>
                          <ul class="space-y-3">
                            <%= for tx <- @loans do %>
                              <% can_renew_type =
                                @current_scope.user.user_type &&
                                  @current_scope.user.user_type.can_renew %> <% max_renewals =
                                (@current_scope.user.user_type &&
                                   @current_scope.user.user_type.max_renewals) || 0 %> <% days_until_due =
                                if tx.due_date do
                                  Date.diff(tx.due_date, Date.utc_today())
                                else
                                  nil
                                end %> <% is_overdue = days_until_due && days_until_due < 0 %> <% is_due_soon =
                                days_until_due && days_until_due >= 0 && days_until_due <= 3 %> <% in_renewal_window =
                                days_until_due && days_until_due >= 2 && days_until_due <= 3 %> <% too_early_to_renew =
                                days_until_due && days_until_due > 3 %> <% too_late_to_renew =
                                days_until_due && days_until_due <= 1 %> <% renew_disabled =
                                not can_renew_type or tx.renewal_count >= max_renewals or
                                  too_early_to_renew or too_late_to_renew or is_overdue %> <% is_renewing =
                                @renewing_loan_id == tx.id %>
                              <li class={"flex items-center gap-4 p-3 rounded-lg shadow-sm transition-all " <> (if is_overdue, do: "bg-red-50 dark:bg-red-900/20 border-2 border-red-200 dark:border-red-800", else: if(is_due_soon, do: "bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800", else: "bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700"))}>
                                <div class="w-16 h-20 shrink-0 rounded overflow-hidden bg-voile-neutral shadow-sm">
                                  <%= if tx.item && tx.item.collection && tx.item.collection.thumbnail do %>
                                    <img
                                      src={tx.item.collection.thumbnail}
                                      class="w-full h-full object-cover"
                                      alt="Book cover"
                                    />
                                  <% else %>
                                    <div class="w-full h-full flex items-center justify-center text-xs text-voile-muted text-center p-2">
                                      <.icon name="hero-book-open" class="w-8 h-8" />
                                    </div>
                                  <% end %>
                                </div>

                                <div class="flex-1 min-w-0">
                                  <div class="font-medium text-gray-900 dark:text-gray-100 mb-1">
                                    {if tx.collection && tx.collection.title,
                                      do: tx.collection.title,
                                      else: tx.item.item_code}
                                  </div>

                                  <div class="flex flex-wrap items-center gap-3 text-xs">
                                    <%= cond do %>
                                      <% is_overdue -> %>
                                        <span class="inline-flex items-center px-2 py-1 rounded-full bg-red-100 dark:bg-red-900/40 text-red-800 dark:text-red-200 font-medium">
                                          <.icon name="hero-exclamation-circle" class="w-3 h-3 mr-1" /> {gettext(
                                            "Overdue by"
                                          )} {abs(days_until_due)} {gettext("day(s)")}
                                        </span>
                                      <% is_due_soon -> %>
                                        <span class="inline-flex items-center px-2 py-1 rounded-full bg-amber-100 dark:bg-amber-900/40 text-amber-800 dark:text-amber-200 font-medium">
                                          <.icon name="hero-clock" class="w-3 h-3 mr-1" /> {gettext(
                                            "Due in"
                                          )} {days_until_due} {gettext("day(s)")}
                                        </span>
                                      <% true -> %>
                                        <span class="text-voile-muted">
                                          <.icon
                                            name="hero-calendar"
                                            class="w-3 h-3 inline mr-1"
                                          /> {gettext("Due:")} {FormatIndonesiaTime.format_full_indonesian_date(
                                            tx.due_date
                                          )}
                                        </span>
                                    <% end %>

                                    <span class="text-voile-muted">
                                      <.icon name="hero-arrow-path" class="w-3 h-3 inline mr-1" /> {gettext(
                                        "Renewed:"
                                      )} {tx.renewal_count}/{max_renewals}
                                    </span>
                                    <%= if tx.transaction_date do %>
                                      <span class="text-voile-muted">
                                        {gettext("Borrowed:")} {FormatIndonesiaTime.format_full_indonesian_date(
                                          tx.transaction_date
                                        )}
                                      </span>
                                    <% end %>
                                  </div>

                                  <%= if renew_disabled do %>
                                    <div class="mt-2 text-xs text-gray-600 dark:text-gray-400">
                                      <%= cond do %>
                                        <% is_overdue -> %>
                                          <span class="inline-flex items-center text-red-600 dark:text-red-400">
                                            <.icon name="hero-x-circle" class="w-3 h-3 mr-1" /> {gettext(
                                              "Cannot renew overdue items"
                                            )}
                                          </span>
                                        <% not can_renew_type -> %>
                                          <span class="inline-flex items-center text-gray-500">
                                            <.icon name="hero-no-symbol" class="w-3 h-3 mr-1" /> {gettext(
                                              "Renewals not available for your member type"
                                            )}
                                          </span>
                                        <% tx.renewal_count >= max_renewals -> %>
                                          <span class="inline-flex items-center text-gray-500">
                                            <.icon name="hero-no-symbol" class="w-3 h-3 mr-1" /> {gettext(
                                              "Maximum renewals reached"
                                            )}
                                          </span>
                                        <% too_late_to_renew -> %>
                                          <span class="inline-flex items-center text-amber-600 dark:text-amber-400">
                                            <.icon name="hero-clock" class="w-3 h-3 mr-1" /> {gettext(
                                              "Too late to renew (must renew at least 1 day before due)"
                                            )}
                                            <br /> {gettext(
                                              "Please contact library staff for assistance."
                                            )}
                                          </span>
                                        <% too_early_to_renew -> %>
                                          <span class="inline-flex items-center text-blue-600 dark:text-blue-400">
                                            <.icon
                                              name="hero-information-circle"
                                              class="w-3 h-3 mr-1"
                                            /> {gettext("Available for renewal in")} {days_until_due -
                                              3} {gettext("day(s)")}
                                          </span>
                                        <% true -> %>
                                          <span>{gettext("Cannot renew this item")}</span>
                                      <% end %>
                                    </div>
                                  <% else %>
                                    <%= if in_renewal_window do %>
                                      <div class="mt-2 text-xs text-green-600 dark:text-green-400">
                                        <span class="inline-flex items-center">
                                          <.icon name="hero-check-circle" class="w-3 h-3 mr-1" /> {gettext(
                                            "Renewal available now"
                                          )}
                                        </span>
                                      </div>
                                    <% end %>
                                  <% end %>
                                </div>

                                <div class="flex-shrink-0">
                                  <%= if is_renewing do %>
                                    <button
                                      disabled
                                      class="inline-flex items-center px-4 py-2 text-sm font-medium rounded-lg bg-indigo-100 dark:bg-indigo-900/40 text-indigo-600 dark:text-indigo-300 cursor-not-allowed"
                                    >
                                      <svg
                                        class="animate-spin -ml-1 mr-2 h-4 w-4"
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

                                        <path
                                          class="opacity-75"
                                          fill="currentColor"
                                          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                                        >
                                        </path>
                                      </svg>
                                      Renewing...
                                    </button>
                                  <% else %>
                                    <button
                                      phx-click="renew_loan"
                                      phx-value-transaction_id={tx.id}
                                      disabled={renew_disabled}
                                      class={"inline-flex items-center px-4 py-2 text-sm font-medium rounded-lg transition-colors " <> (if renew_disabled, do: "bg-gray-100 dark:bg-gray-800 text-gray-400 dark:text-gray-600 cursor-not-allowed", else: "bg-indigo-600 hover:bg-indigo-700 text-white shadow-sm hover:shadow-md")}
                                    >
                                      <.icon name="hero-arrow-path" class="w-4 h-4 mr-1.5" /> {gettext(
                                        "Renew"
                                      )}
                                    </button>
                                  <% end %>
                                </div>
                              </li>
                            <% end %>
                          </ul>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% end %>
                <%!-- Fines Tab --%>
                <%= if @active_tab == :fines do %>
                  <div class="space-y-6">
                    <%= if @payment_processing do %>
                      <div class="bg-blue-50 dark:bg-blue-900/30 border-2 border-blue-300 dark:border-blue-700 rounded-lg p-4 animate-pulse">
                        <div class="flex items-center gap-3">
                          <svg
                            class="animate-spin h-5 w-5 text-blue-600 dark:text-blue-400"
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

                            <path
                              class="opacity-75"
                              fill="currentColor"
                              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                            >
                            </path>
                          </svg>
                          <div class="flex-1">
                            <div class="text-sm font-medium text-blue-900 dark:text-blue-100">
                              {gettext("Processing your payment...")}
                            </div>

                            <div class="text-xs text-blue-700 dark:text-blue-300 mt-0.5">
                              {gettext(
                                "Please wait while we confirm your payment with the payment gateway."
                              )}
                            </div>
                          </div>
                        </div>
                      </div>
                    <% end %>

                    <div class="p-4 rounded-md border border-voile-light dark:border-voile-dark bg-white/60 dark:bg-gray-800/60">
                      <div class="flex items-start justify-between">
                        <div>
                          <h4 class="text-lg font-semibold">{gettext("Outstanding Fines")}</h4>

                          <div class="text-sm text-voile-muted mt-1">
                            {gettext("Showing")} {length(@fines || [])} {gettext("of")}
                            <strong>{@total_unpaid_fines}</strong> {gettext("unpaid fines")}
                          </div>
                        </div>

                        <%= if @fines_total_pages > 1 do %>
                          <div class="flex items-center gap-3">
                            <div class="text-sm text-voile-muted">
                              Page {@fines_page || 1} of {@fines_total_pages || 1}
                            </div>

                            <.button
                              phx-click="fines_prev"
                              disabled={@fines_page <= 1}
                            >
                              Prev
                            </.button>
                            <.button
                              phx-click="fines_next"
                              disabled={@fines_page >= @fines_total_pages}
                            >
                              Next
                            </.button>
                          </div>
                        <% end %>
                      </div>

                      <div class="mt-4">
                        <%= if @fines == [] do %>
                          <div class="text-center py-12">
                            <.icon
                              name="hero-check-circle"
                              class="w-16 h-16 mx-auto text-green-500 mb-4"
                            />
                            <p class="text-lg font-medium text-gray-900 dark:text-gray-100">
                              {gettext("No Outstanding Fines")}
                            </p>

                            <p class="text-sm text-voile-muted mt-1">
                              {gettext("You're all clear! 🎉")}
                            </p>
                          </div>
                        <% else %>
                          <ul class="space-y-3">
                            <%= for f <- @fines do %>
                              <% pending_payment =
                                case Circulation.get_pending_payment_for_fine(f.id) do
                                  {:ok, payment} -> payment
                                  _ -> nil
                                end %>
                              <li class="flex items-start gap-4 p-4 bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700">
                                <div class="w-16 h-20 shrink-0 rounded overflow-hidden bg-voile-neutral flex items-center justify-center text-xs text-voile-muted">
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
                                      {gettext("Type:")}
                                      <strong class="text-gray-700 dark:text-gray-300">
                                        {String.upcase(f.fine_type || "")}
                                      </strong>
                                    </span>
                                    <span>
                                      {gettext("Balance:")}
                                      <strong class="text-red-600 dark:text-red-400">
                                        Rp {f.balance}
                                      </strong>
                                    </span>
                                    <%= if f.fine_date do %>
                                      <span>
                                        {gettext("Date:")} {FormatIndonesiaTime.format_full_indonesian_date(
                                          f.fine_date
                                        )}
                                      </span>
                                    <% end %>
                                  </div>

                                  <%= if pending_payment do %>
                                    <div class="bg-gradient-to-r from-green-50 to-emerald-50 dark:from-green-900/20 dark:to-emerald-900/20 border-2 border-green-300 dark:border-green-700 rounded-lg p-3 mt-2">
                                      <div class="flex items-center justify-between gap-3">
                                        <div class="flex items-center gap-2">
                                          <div class="flex-shrink-0">
                                            <div class="w-8 h-8 rounded-full bg-green-100 dark:bg-green-900/50 flex items-center justify-center">
                                              <.icon
                                                name="hero-check-circle"
                                                class="w-5 h-5 text-green-600 dark:text-green-400"
                                              />
                                            </div>
                                          </div>

                                          <div>
                                            <div class="text-xs font-semibold text-green-800 dark:text-green-300">
                                              {gettext("Payment Link Ready")}
                                            </div>

                                            <div class="text-xs text-green-700 dark:text-green-400">
                                              {gettext("Click to view or pay online")}
                                            </div>
                                          </div>
                                        </div>

                                        <button
                                          phx-click="request_payment_link"
                                          phx-value-fine_id={f.id}
                                          class="px-4 py-2 bg-green-600 hover:bg-green-700 text-white text-xs font-medium rounded-lg transition-colors shadow-sm hover:shadow-md"
                                        >
                                          <.icon
                                            name="hero-arrow-top-right-on-square"
                                            class="w-4 h-4 inline mr-1"
                                          /> {gettext("View Link")}
                                        </button>
                                      </div>
                                    </div>
                                  <% end %>
                                </div>

                                <div class="flex-shrink-0 flex flex-col gap-2">
                                  <%= if pending_payment do %>
                                    <button
                                      phx-click="request_payment_link"
                                      phx-value-fine_id={f.id}
                                      class="px-4 py-2 bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-700 hover:to-emerald-700 text-white text-sm rounded-lg font-medium shadow-md hover:shadow-lg transition-all"
                                    >
                                      <.icon name="hero-credit-card" class="w-4 h-4 inline mr-1" /> {gettext(
                                        "Pay Online"
                                      )}
                                    </button>
                                  <% else %>
                                    <button
                                      phx-click="request_payment_link"
                                      phx-value-fine_id={f.id}
                                      class="px-4 py-2 bg-gradient-to-r from-indigo-600 to-blue-600 hover:from-indigo-700 hover:to-blue-700 text-white text-sm rounded-lg font-medium shadow-md hover:shadow-lg transition-all"
                                    >
                                      <.icon name="hero-link" class="w-4 h-4 inline mr-1" /> {gettext(
                                        "Generate Payment"
                                      )}
                                    </button>
                                  <% end %>

                                  <div class="text-xs text-center text-gray-500 dark:text-gray-400 mt-1">
                                    {gettext("or pay in person at library")}
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
                <%!-- Fine History Tab --%>
                <%= if @active_tab == :fine_history do %>
                  <div class="space-y-6">
                    <div class="p-4 rounded-md border border-voile-light dark:border-voile-dark bg-white/60 dark:bg-gray-800/60">
                      <div class="flex items-start justify-between mb-4">
                        <div>
                          <h4 class="text-lg font-semibold">{gettext("Fine Payment History")}</h4>

                          <div class="text-sm text-voile-muted mt-1">
                            {gettext("Showing")} {length(@fine_history || [])} {gettext(
                              "paid/waived fines"
                            )}
                          </div>
                        </div>

                        <%= if @fine_history_total_pages > 1 do %>
                          <div class="flex items-center gap-3">
                            <div class="text-sm text-voile-muted">
                              Page {@fine_history_page || 1} of {@fine_history_total_pages || 1}
                            </div>

                            <.button phx-click="fine_history_prev" disabled={@fine_history_page <= 1}>
                              Prev
                            </.button>
                            <.button
                              phx-click="fine_history_next"
                              disabled={@fine_history_page >= @fine_history_total_pages}
                            >
                              Next
                            </.button>
                          </div>
                        <% end %>
                      </div>

                      <%= if @fine_history == [] do %>
                        <div class="text-center py-12">
                          <.icon name="hero-inbox" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
                          <p class="text-lg font-medium text-gray-900 dark:text-gray-100">
                            {gettext("No Fine History")}
                          </p>

                          <p class="text-sm text-voile-muted mt-1">
                            {gettext("You haven't paid any fines yet.")}
                          </p>
                        </div>
                      <% else %>
                        <ul class="space-y-3">
                          <%= for fine <- @fine_history do %>
                            <li class="flex items-start gap-4 p-4 bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700">
                              <div class="w-12 h-12 shrink-0 rounded overflow-hidden bg-voile-neutral flex items-center justify-center text-xs text-voile-muted">
                                <%= if fine.item && fine.item.collection && fine.item.collection.thumbnail do %>
                                  <img
                                    src={fine.item.collection.thumbnail}
                                    class="w-full h-full object-cover"
                                  />
                                <% else %>
                                  <.icon name="hero-currency-dollar" class="w-6 h-6" />
                                <% end %>
                              </div>

                              <div class="flex-1 text-sm space-y-2">
                                <div class="font-medium text-gray-900 dark:text-gray-100">
                                  {fine.description ||
                                    (fine.item && fine.item.collection && fine.item.collection.title) ||
                                    "Library Fine"}
                                </div>

                                <div class="flex items-center gap-4 text-xs text-voile-muted">
                                  <span>
                                    {gettext("Type:")}
                                    <strong class="text-gray-700 dark:text-gray-300">
                                      {String.upcase(fine.fine_type || "")}
                                    </strong>
                                  </span>
                                  <span>
                                    {gettext("Amount:")}
                                    <strong class="text-green-600 dark:text-green-400">
                                      Rp {Decimal.to_string(fine.amount)}
                                    </strong>
                                  </span>
                                  <%= if fine.payment_date do %>
                                    <span>
                                      {gettext("Paid:")} {FormatIndonesiaTime.format_full_indonesian_date(
                                        fine.payment_date
                                      )}
                                    </span>
                                  <% end %>
                                </div>

                                <div class="flex items-center gap-2">
                                  <span class={[
                                    "inline-flex px-2 py-1 text-xs font-medium rounded",
                                    case fine.fine_status do
                                      "paid" ->
                                        "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300"

                                      "waived" ->
                                        "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300"

                                      _ ->
                                        "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
                                    end
                                  ]}>
                                    {String.upcase(fine.fine_status)}
                                  </span>
                                  <%= if fine.payment_method do %>
                                    <span class="text-xs text-gray-600 dark:text-gray-400">
                                      {gettext("via")} {String.upcase(fine.payment_method)}
                                    </span>
                                  <% end %>
                                </div>
                              </div>

                              <div class="flex-shrink-0">
                                <.link
                                  navigate={~p"/atrium/fine_detail/#{fine.id}"}
                                  class="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm rounded-lg font-medium shadow-sm hover:shadow-md transition-all"
                                >
                                  <.icon name="hero-eye" class="w-4 h-4 inline mr-1" /> {gettext(
                                    "View Details"
                                  )}
                                </.link>
                              </div>
                            </li>
                          <% end %>
                        </ul>
                      <% end %>
                    </div>
                  </div>
                <% end %>
                <%!-- Loan History Tab --%>
                <%= if @active_tab == :loan_history do %>
                  <div class="space-y-6">
                    <div class="p-4 rounded-md border border-voile-light dark:border-voile-dark bg-white/60 dark:bg-gray-800/60">
                      <div class="flex items-start justify-between mb-4">
                        <div>
                          <h4 class="text-lg font-semibold">{gettext("Loan History")}</h4>

                          <div class="text-sm text-voile-muted mt-1">
                            {gettext("Showing")} {length(@loan_history || [])} {gettext(
                              "completed loans"
                            )}
                          </div>
                        </div>

                        <%= if @loan_history_total_pages > 1 do %>
                          <div class="flex items-center gap-3">
                            <div class="text-sm text-voile-muted">
                              Page {@loan_history_page || 1} of {@loan_history_total_pages || 1}
                            </div>

                            <.button phx-click="loan_history_prev" disabled={@loan_history_page <= 1}>
                              Prev
                            </.button>
                            <.button
                              phx-click="loan_history_next"
                              disabled={@loan_history_page >= @loan_history_total_pages}
                            >
                              Next
                            </.button>
                          </div>
                        <% end %>
                      </div>

                      <%= if @loan_history == [] do %>
                        <div class="text-center py-12">
                          <.icon name="hero-inbox" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
                          <p class="text-lg font-medium text-gray-900 dark:text-gray-100">
                            {gettext("No Loan History")}
                          </p>

                          <p class="text-sm text-voile-muted mt-1">
                            {gettext("You haven't returned any books yet.")}
                          </p>
                        </div>
                      <% else %>
                        <ul class="space-y-3">
                          <%= for tx <- @loan_history do %>
                            <li class="flex items-start gap-4 p-4 bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700">
                              <div class="w-12 h-16 shrink-0 rounded overflow-hidden bg-voile-neutral flex items-center justify-center text-xs text-voile-muted">
                                <%= if tx.item && tx.item.collection && tx.item.collection.thumbnail do %>
                                  <img
                                    src={tx.item.collection.thumbnail}
                                    class="w-full h-full object-cover"
                                  />
                                <% else %>
                                  <.icon name="hero-book-open" class="w-6 h-6" />
                                <% end %>
                              </div>

                              <div class="flex-1 text-sm space-y-2">
                                <div class="font-medium text-gray-900 dark:text-gray-100">
                                  {if tx.collection && tx.collection.title,
                                    do: tx.collection.title,
                                    else: tx.item && tx.item.item_code}
                                </div>

                                <div class="flex items-center gap-4 text-xs text-voile-muted">
                                  <%= if tx.transaction_date do %>
                                    <span>
                                      {gettext("Borrowed:")} {FormatIndonesiaTime.format_full_indonesian_date(
                                        tx.transaction_date
                                      )}
                                    </span>
                                  <% end %>

                                  <%= if tx.return_date do %>
                                    <span>
                                      {gettext("Returned:")} {FormatIndonesiaTime.format_full_indonesian_date(
                                        tx.return_date
                                      )}
                                    </span>
                                  <% end %>
                                </div>

                                <span class={[
                                  "inline-flex px-2 py-1 text-xs font-medium rounded",
                                  case tx.status do
                                    "returned" ->
                                      "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300"

                                    "lost" ->
                                      "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300"

                                    "damaged" ->
                                      "bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-300"

                                    _ ->
                                      "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
                                  end
                                ]}>
                                  {String.upcase(tx.status)}
                                </span>
                              </div>
                            </li>
                          <% end %>
                        </ul>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
      <%!-- Payment Link Modal --%>
      <.modal
        :if={@show_payment_modal && @payment_link_data}
        id="payment-link-modal"
        show
        on_cancel={JS.push("close_payment_modal")}
      >
        <div class="space-y-6">
          <!-- Header -->
          <div class="text-center">
            <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-green-100 dark:bg-green-900/30 mb-4">
              <.icon name="hero-check-circle" class="h-10 w-10 text-green-600 dark:text-green-400" />
            </div>

            <h3 class="text-2xl font-semibold text-gray-900 dark:text-gray-100 mb-2">
              {gettext("Payment Link Ready!")}
            </h3>

            <p class="text-sm text-gray-600 dark:text-gray-400">
              {gettext("Your payment link has been created. Use it to pay your fine online.")}
            </p>
          </div>
          <!-- Amount -->
          <div class="bg-gradient-to-br from-indigo-50 to-blue-50 dark:from-indigo-900/20 dark:to-blue-900/20 rounded-lg p-6 text-center border border-indigo-200 dark:border-indigo-800">
            <div class="text-sm text-gray-600 dark:text-gray-400 mb-1">
              {gettext("Amount to Pay")}
            </div>

            <div class="text-3xl font-bold text-indigo-600 dark:text-indigo-400">
              Rp {@payment_link_data.amount}
            </div>
          </div>
          <!-- Payment Link with Copy Button -->
          <div class="space-y-3">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              {gettext("Payment Link")}
            </label>
            <div class="flex gap-2">
              <input
                type="text"
                readonly
                id="payment-url-input"
                value={@payment_link_data.payment_url}
                class="flex-1 px-4 py-2 bg-gray-50 dark:bg-gray-900 border border-gray-300 dark:border-gray-700 rounded-lg text-sm text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-indigo-500"
                onclick="this.select()"
              />
              <button
                type="button"
                phx-click={
                  JS.dispatch("phx:copy", to: "#payment-url-input")
                  |> JS.push("copy_payment_link")
                }
                class="px-4 py-2 bg-gray-200 hover:bg-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 rounded-lg text-sm font-medium transition-colors"
              >
                <.icon name="hero-clipboard-document" class="w-5 h-5" />
              </button>
            </div>

            <p class="text-xs text-gray-500 dark:text-gray-400">
              <.icon name="hero-information-circle" class="w-4 h-4 inline mr-1" /> {gettext(
                "Click the link to copy it to your clipboard"
              )}
            </p>
          </div>
          <!-- Action Buttons -->
          <div class="flex gap-3">
            <button
              type="button"
              phx-click="close_payment_modal"
              class="flex-1 px-6 py-3 bg-gray-200 hover:bg-gray-300 dark:bg-gray-800 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 rounded-lg font-medium transition-colors"
            >
              {gettext("Close")}
            </button>
            <a
              href={@payment_link_data.payment_url}
              target="_blank"
              class="flex-1 px-6 py-3 bg-gradient-to-r from-indigo-600 to-blue-600 hover:from-indigo-700 hover:to-blue-700 text-white rounded-lg font-medium transition-all shadow-lg hover:shadow-xl text-center"
            >
              <.icon name="hero-arrow-top-right-on-square" class="w-5 h-5 inline mr-2" /> {gettext(
                "Pay Now"
              )}
            </a>
          </div>
          <!-- Additional Info -->
          <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
            <div class="flex gap-3">
              <.icon
                name="hero-information-circle"
                class="w-5 h-5 text-blue-600 dark:text-blue-400 shrink-0 mt-0.5"
              />
              <div class="text-sm text-blue-800 dark:text-blue-200 space-y-1">
                <p class="font-medium">{gettext("Important Notes:")}</p>

                <ul class="list-disc list-inside space-y-1 text-xs">
                  <li>{gettext("This payment link is valid for 24 hours")}</li>

                  <li>{gettext("You can access this link anytime from the Fines tab")}</li>

                  <li>{gettext("Payment will be processed by Xendit (secure payment gateway)")}</li>

                  <li>
                    {gettext("Your fine status will update automatically after successful payment")}
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </.modal>
      <%!-- Renewal Confirmation Modal --%>
      <.modal
        :if={@show_renewal_modal && @renewal_transaction}
        id="renewal-modal"
        show
        on_cancel={JS.push("close_renewal_modal")}
      >
        <% tx = @renewal_transaction %> <% member = @current_scope.user %> <% current_due =
          if tx.due_date do
            case tx.due_date do
              %Date{} = date -> date
              %DateTime{} = datetime -> DateTime.to_date(datetime)
              _ -> Date.utc_today()
            end
          else
            Date.utc_today()
          end %> <% new_due = AtriumHelper.calculate_new_due_date(current_due, member) %> <% loan_period_days =
          if member.user_type && member.user_type.max_days,
            do: member.user_type.max_days,
            else: 21 %> <% days_until_current_due = Date.diff(current_due, Date.utc_today()) %>
        <!-- Header -->
        <div class="mb-6">
          <h3 class="text-2xl font-semibold text-gray-900 dark:text-gray-100">
            {gettext("Confirm Loan Renewal")}
          </h3>

          <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
            {gettext("Please review the details before confirming")}
          </p>
        </div>
        <!-- Book Info -->
        <div class="mb-6 p-4 bg-gray-50 dark:bg-gray-900/50 rounded-lg">
          <div class="flex gap-4">
            <div class="w-20 h-28 shrink-0 rounded overflow-hidden bg-gray-200 dark:bg-gray-700 shadow-md">
              <%= if tx.item && tx.item.collection && tx.item.collection.thumbnail do %>
                <img
                  src={tx.item.collection.thumbnail}
                  class="w-full h-full object-cover"
                  alt="Book cover"
                />
              <% else %>
                <div class="w-full h-full flex items-center justify-center">
                  <.icon name="hero-book-open" class="w-8 h-8 text-gray-400" />
                </div>
              <% end %>
            </div>

            <div class="flex-1">
              <h4 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
                {if tx.collection && tx.collection.title,
                  do: tx.collection.title,
                  else: tx.item && tx.item.item_code}
              </h4>

              <div class="space-y-1 text-sm text-gray-600 dark:text-gray-400">
                <%= if tx.item do %>
                  <p><span class="font-medium">{gettext("Item Code:")}</span> {tx.item.item_code}</p>

                  <%= if tx.item.location do %>
                    <p><span class="font-medium">{gettext("Location:")}</span> {tx.item.location}</p>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>
        </div>
        <!-- Renewal Details -->
        <div class="mb-6 space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <!-- Current Due Date -->
            <div class="p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg">
              <div class="text-xs font-medium text-red-600 dark:text-red-400 mb-1">
                {gettext("Current Due Date")}
              </div>

              <div class="text-lg font-semibold text-red-700 dark:text-red-300">
                {FormatIndonesiaTime.format_full_indonesian_date(current_due)}
              </div>

              <div class="text-xs text-red-600 dark:text-red-400 mt-1">
                <%= if days_until_current_due > 0 do %>
                  {days_until_current_due} {gettext("days remaining")}
                <% else %>
                  {gettext("Due today")}
                <% end %>
              </div>
            </div>
            <!-- New Due Date -->
            <div class="p-4 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg">
              <div class="text-xs font-medium text-green-600 dark:text-green-400 mb-1">
                {gettext("New Due Date")}
              </div>

              <div class="text-lg font-semibold text-green-700 dark:text-green-300">
                {FormatIndonesiaTime.format_full_indonesian_date(new_due)}
              </div>

              <div class="text-xs text-green-600 dark:text-green-400 mt-1">
                +{loan_period_days} {gettext("days extension")}
              </div>
            </div>
          </div>

          <div class="p-4 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg">
            <h5 class="text-sm font-semibold text-blue-900 dark:text-blue-100 mb-3">
              {gettext("Transaction Details")}
            </h5>

            <div class="grid grid-cols-2 gap-3 text-sm">
              <div>
                <span class="text-blue-600 dark:text-blue-400">{gettext("Transaction Date:")}</span>
                <div class="font-medium text-blue-900 dark:text-blue-100">
                  {FormatIndonesiaTime.format_full_indonesian_date(tx.transaction_date)}
                </div>
              </div>

              <div>
                <span class="text-blue-600 dark:text-blue-400">{gettext("Renewal Count:")}</span>
                <div class="font-medium text-blue-900 dark:text-blue-100">
                  {tx.renewal_count} / {(member.user_type && member.user_type.max_renewals) || 0}
                </div>
              </div>

              <div>
                <span class="text-blue-600 dark:text-blue-400">{gettext("Status:")}</span>
                <div class="font-medium text-blue-900 dark:text-blue-100 capitalize">{tx.status}</div>
              </div>

              <div>
                <span class="text-blue-600 dark:text-blue-400">{gettext("Member Type:")}</span>
                <div class="font-medium text-blue-900 dark:text-blue-100">
                  {(member.user_type && member.user_type.name) || "Standard"}
                </div>
              </div>
            </div>
          </div>
        </div>
        <!-- Important Notice -->
        <div class="mb-6 p-4 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg">
          <div class="flex gap-3">
            <.icon
              name="hero-information-circle"
              class="w-5 h-5 text-amber-600 dark:text-amber-400 shrink-0 mt-0.5"
            />
            <div class="text-sm text-amber-800 dark:text-amber-200">
              <p class="font-medium mb-1">{gettext("Important Information:")}</p>

              <ul class="list-disc list-inside space-y-1 text-amber-700 dark:text-amber-300">
                <li>
                  {gettext("This renewal will extend your loan period by")} {loan_period_days} {gettext(
                    "days"
                  )}
                </li>

                <li>
                  {gettext("You will have")} {(member.user_type &&
                                                 member.user_type.max_renewals - tx.renewal_count - 1) ||
                    0} {gettext("renewal(s) left after this")}
                </li>

                <li>{gettext("Late returns may result in fines")}</li>

                <li>{gettext("This action cannot be undone")}</li>
              </ul>
            </div>
          </div>
        </div>
        <!-- Actions -->
        <div class="mt-6 flex gap-3 justify-end">
          <.button type="button" phx-click="close_renewal_modal">{gettext("Cancel")}</.button>
          <.button type="button" phx-click="confirm_renew_loan">
            <.icon name="hero-check-circle" class="w-5 h-5 mr-2" /> {gettext("Confirm Renewal")}
          </.button>
        </div>
      </.modal>
    </Layouts.app>
    """
  end
end
