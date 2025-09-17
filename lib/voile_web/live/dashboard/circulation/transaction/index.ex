defmodule VoileWeb.Dashboard.Circulation.Transaction.Index do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Circulation.Helpers
  import VoileWeb.Dashboard.Circulation.Components

  alias Voile.Schema.Catalog
  alias Voile.Schema.Accounts
  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Library.Transaction

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    per_page = 15
    {transactions, total_pages} = Circulation.list_transactions_paginated(page, per_page)

    count_active_collection = Circulation.count_of_collection_based_on_status("active")
    count_overdue_collection = Circulation.count_of_collection_based_on_status("overdue")
    count_returned_collection = Circulation.count_of_collection_based_on_status("returned")

    checkout_changeset = Transaction.changeset(%Transaction{}, %{})

    socket =
      socket
      |> stream(:transactions, transactions)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:search_query, "")
      |> assign(:filter_status, "all")
      |> assign(:checkout_changeset, checkout_changeset)
      |> assign(:transaction, nil)
      |> assign(:renew_transaction, nil)
      |> assign(:count_active_collection, count_active_collection)
      |> assign(:count_overdue_collection, count_overdue_collection)
      |> assign(:count_returned_collection, count_returned_collection)
      |> assign(:return_modal_visible, false)
      |> assign(:return_transaction_id, nil)
      |> assign(:predicted_fine, Decimal.new("0"))
      |> assign(:payment_method, "cash")
      |> assign(:renew_modal_visible, false)
      |> assign(:renew_transaction_id, nil)
      |> assign(:recommended_renew_days, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Library Transactions")
    |> assign(:checkout_changeset, Transaction.changeset(%Transaction{}, %{}))
  end

  defp apply_action(socket, :checkout, _params) do
    socket
    |> assign(:page_title, "New Checkout")
    |> assign(:transaction, %Transaction{})
    |> assign(:checkout_changeset, Transaction.changeset(%Transaction{}, %{}))
  end

  defp apply_action(socket, :return, %{"id" => id}) do
    transaction = Circulation.get_transaction!(id)

    socket
    |> assign(:page_title, "Return Item")
    |> assign(:transaction, transaction)
  end

  defp apply_action(socket, :renew, %{"id" => id}) do
    transaction = Circulation.get_transaction!(id)

    socket
    |> assign(:page_title, "Renew Item")
    |> assign(:transaction, transaction)
  end

  @impl true
  def handle_event("checkout", params, socket) do
    # Support both nested params under "transaction" (from the form)
    # and flat params sent directly as %{"member_id" => ..., "item_id" => ...}.
    transaction = Map.get(params, "transaction", params)
    member_id = Map.get(transaction, "member_id")
    item_id = Map.get(transaction, "item_id")

    cond do
      is_nil(member_id) or member_id == "" ->
        socket = put_flash(socket, :error, "Member identifier is required")
        {:noreply, socket}

      is_nil(item_id) or item_id == "" ->
        socket = put_flash(socket, :error, "Item ID is required")
        {:noreply, socket}

      true ->
        case Accounts.get_user_by_identifier(member_id) do
          nil ->
            socket = put_flash(socket, :error, "Member not found")
            {:noreply, socket}

          member ->
            item = Catalog.get_item_by_code!(item_id)
            librarian = socket.assigns.current_scope.user.id

            case Circulation.checkout_item(member.id, item.id, librarian) do
              {:ok, transaction} ->
                socket =
                  socket
                  |> stream_insert(:transactions, transaction, at: 0)
                  |> put_flash(:info, "Item checked out successfully")

                {:noreply, socket}

              {:error, changeset} ->
                socket =
                  socket
                  |> put_flash(
                    :error,
                    "Failed to checkout item: #{extract_error_message(changeset)}"
                  )

                {:noreply, socket}
            end
        end
    end
  end

  @impl true
  def handle_event("return", %{"id" => id}, socket) do
    current_user_id = socket.assigns.current_scope.user.id

    case Circulation.return_item(id, current_user_id) do
      {:ok, transaction} ->
        socket =
          socket
          |> stream_insert(:transactions, transaction)
          |> put_flash(:info, "Item returned successfully")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to return item: #{extract_error_message(changeset)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_return_modal", %{"id" => id}, socket) do
    transaction = Circulation.get_transaction!(id)

    # load member with user_type
    member = Accounts.get_user!(transaction.member_id)

    predicted_fine =
      if Transaction.overdue?(transaction) do
        days = Transaction.days_overdue(transaction)
        daily = member.user_type.fine_per_day || Decimal.new("1.00")
        Decimal.mult(Decimal.new(days), daily)
      else
        Decimal.new("0")
      end

    socket =
      socket
      |> assign(:return_modal_visible, true)
      |> assign(:return_transaction_id, id)
      |> assign(:predicted_fine, predicted_fine)

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_renew_modal", %{"id" => id}, socket) do
    transaction = Circulation.get_transaction!(id)

    # load member and member type
    member = Accounts.get_user!(transaction.member_id)

    recommended_days =
      case member.user_type do
        %{} = ut -> ut.max_days || nil
        _ -> nil
      end

    # compute preview due date based on recommended days (if available)
    preview_due_date =
      if is_integer(recommended_days) and not is_nil(transaction.due_date) do
        DateTime.add(transaction.due_date, recommended_days * 24 * 60 * 60, :second)
      else
        nil
      end

    # compute remaining renewals based on member type max_renewals
    remaining_renewals =
      case member.user_type do
        %{} = ut ->
          max = ut.max_renewals || 0
          max - (transaction.renewal_count || 0)

        _ ->
          0
      end

    socket =
      socket
      |> assign(:renew_modal_visible, true)
      |> assign(:renew_transaction_id, id)
      |> assign(:renew_transaction, transaction)
      |> assign(:recommended_renew_days, recommended_days)
      |> assign(:preview_due_date, preview_due_date)
      |> assign(:remaining_renewals, remaining_renewals)

    {:noreply, socket}
  end

  @impl true
  def handle_event("renew_days_change", %{"renew_days" => renew_days}, socket) do
    transaction =
      socket.assigns.renew_transaction ||
        if socket.assigns.renew_transaction_id,
          do: Circulation.get_transaction!(socket.assigns.renew_transaction_id),
          else: nil

    preview_due_date =
      cond do
        transaction && renew_days && renew_days != "" ->
          case Integer.parse(to_string(renew_days)) do
            {n, _} when n > 0 -> DateTime.add(transaction.due_date, n * 24 * 60 * 60, :second)
            _ -> nil
          end

        # fallback to recommended preview already set
        socket.assigns.preview_due_date ->
          socket.assigns.preview_due_date

        true ->
          nil
      end

    socket = assign(socket, :preview_due_date, preview_due_date)
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_renew", _params, socket) do
    socket =
      socket
      |> assign(:renew_modal_visible, false)
      |> assign(:renew_transaction_id, nil)
      |> assign(:recommended_renew_days, nil)
      |> assign(:renew_transaction, nil)
      |> assign(:preview_due_date, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_renew", params, socket) do
    transaction_id = params["transaction_id"] || socket.assigns.renew_transaction_id
    renew_days = params["renew_days"]
    current_user_id = socket.assigns.current_scope.user.id
    remaining = Map.get(socket.assigns, :remaining_renewals, nil)

    if remaining != nil and remaining <= 0 do
      socket = put_flash(socket, :error, "No remaining renewals available for this member")
      {:noreply, socket}
    else
      attrs =
        cond do
          renew_days && renew_days != "" ->
            case Integer.parse(to_string(renew_days)) do
              {n, _} when n > 0 ->
                transaction = Circulation.get_transaction!(transaction_id)
                custom_due = DateTime.add(transaction.due_date, n * 24 * 60 * 60, :second)
                %{"due_date" => custom_due}

              _ ->
                %{}
            end

          socket.assigns.preview_due_date ->
            %{"due_date" => socket.assigns.preview_due_date}

          true ->
            %{}
        end

      case Circulation.renew_transaction(transaction_id, current_user_id, attrs) do
        {:ok, transaction} ->
          socket =
            socket
            |> stream_insert(:transactions, transaction)
            |> put_flash(:info, "Item renewed successfully")
            |> assign(:renew_modal_visible, false)
            |> assign(:renew_transaction_id, nil)
            |> assign(:recommended_renew_days, nil)

          {:noreply, socket}

        {:error, changeset} ->
          socket =
            put_flash(socket, :error, "Failed to renew item: #{extract_error_message(changeset)}")

          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("cancel_return", _params, socket) do
    socket =
      socket
      |> assign(:return_modal_visible, false)
      |> assign(:return_transaction_id, nil)
      |> assign(:predicted_fine, Decimal.new("0"))

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_return", params, socket) do
    transaction_id = params["transaction_id"] || socket.assigns.return_transaction_id
    payment_amount = params["payment_amount"] || "0"
    payment_method = params["payment_method"] || "cash"
    current_user_id = socket.assigns.current_scope.user.id

    # parse payment amount to Decimal
    payment_amount_decimal =
      case Decimal.parse(payment_amount) do
        {dec, _rest} when is_struct(dec) -> dec
        :error -> Decimal.new("0")
      end

    case Circulation.return_item(transaction_id, current_user_id) do
      {:ok, transaction} ->
        # After return, check if a fine exists for the transaction
        fine =
          case Circulation.get_fine_by_transaction(transaction.id) do
            {:ok, f} -> f
            _ -> nil
          end

        socket =
          socket
          |> stream_insert(:transactions, transaction)

        # If there's a fine and payment amount > 0, attempt payment
        socket =
          if fine && Decimal.compare(payment_amount_decimal, Decimal.new("0")) == :gt do
            case Circulation.pay_fine(
                   fine.id,
                   payment_amount_decimal,
                   payment_method,
                   current_user_id
                 ) do
              {:ok, _updated_fine} ->
                put_flash(socket, :info, "Item returned and fine paid successfully")

              {:error, changeset} ->
                put_flash(
                  socket,
                  :error,
                  "Returned, but failed to pay fine: #{inspect(changeset)}"
                )
            end
          else
            put_flash(socket, :info, "Item returned successfully")
          end

        socket =
          socket
          |> assign(:return_modal_visible, false)
          |> assign(:return_transaction_id, nil)
          |> assign(:predicted_fine, Decimal.new("0"))

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          put_flash(socket, :error, "Failed to return item: #{extract_error_message(changeset)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("renew", %{"id" => id}, socket) do
    current_user_id = socket.assigns.current_scope.user.id

    case Circulation.renew_transaction(id, current_user_id) do
      {:ok, transaction} ->
        socket =
          socket
          |> stream_insert(:transactions, transaction)
          |> put_flash(:info, "Item renewed successfully")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to renew item: #{extract_error_message(changeset)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    socket =
      socket
      |> assign(:filter_status, status)
      |> reload_transactions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> reload_transactions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 15

    {transactions, total_pages} = Circulation.list_transactions_paginated(page, per_page)

    socket =
      socket
      |> stream(:transactions, transactions, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end

  defp reload_transactions(socket) do
    page = 1
    per_page = 15
    filter_status = Map.get(socket.assigns, :filter_status, "all")
    search_query = Map.get(socket.assigns, :search_query, "")
    filters = %{status: filter_status, query: search_query}

    {transactions, total_pages} =
      Voile.Schema.Library.Circulation.list_transaction_paginated_with_filter(
        page,
        per_page,
        filters
      )

    socket
    |> stream(:transactions, transactions, reset: true)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
  end

  defp extract_error_message(changeset) do
    changeset
    |> Map.get(:errors, [])
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  defp limit_string(string, max_length) do
    if String.length(string) > max_length do
      String.slice(string, 0..(max_length - 1)) <> "..."
    else
      string
    end
  end
end
