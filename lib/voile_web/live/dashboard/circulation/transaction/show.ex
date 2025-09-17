defmodule VoileWeb.Dashboard.Circulation.Transaction.Show do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Circulation.Helpers
  import VoileWeb.Dashboard.Circulation.Components

  alias Voile.Schema.Library.Circulation

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    transaction = Circulation.get_transaction!(id)

    fine =
      case Circulation.get_fine_by_transaction(transaction.id) do
        {:ok, f} -> f
        _ -> nil
      end

    socket =
      socket
      |> assign(:transaction, transaction)
      |> assign(:transaction_fine, fine)
      |> assign(:page_title, "Transaction Details")
      |> assign(:return_modal_visible, false)
      |> assign(:return_transaction_id, nil)
      |> assign(:predicted_fine, Decimal.new("0"))
      |> assign(:payment_method, "cash")
      |> assign(:renew_modal_visible, false)
      |> assign(:renew_transaction_id, nil)
      |> assign(:renew_transaction, nil)
      |> assign(:recommended_renew_days, nil)
      |> assign(:preview_due_date, nil)
      |> assign(:remaining_renewals, 0)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("return", %{"id" => id}, socket) do
    current_user_id = socket.assigns.current_scope.user.id

    case Circulation.return_item(id, current_user_id) do
      {:ok, transaction} ->
        fine =
          case Circulation.get_fine_by_transaction(transaction.id) do
            {:ok, f} -> f
            _ -> nil
          end

        socket =
          socket
          |> assign(:transaction, transaction)
          |> assign(:transaction_fine, fine)
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
  def handle_event("renew", %{"id" => id}, socket) do
    current_user_id = socket.assigns.current_scope.user.id

    case Circulation.renew_transaction(id, current_user_id) do
      {:ok, transaction} ->
        socket =
          socket
          |> assign(:transaction, transaction)
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
  def handle_event("show_return_modal", %{"id" => id}, socket) do
    transaction = Circulation.get_transaction!(id)

    # load member with user_type
    member = Voile.Schema.Accounts.get_user!(transaction.member_id)

    predicted_fine =
      if Voile.Schema.Library.Transaction.overdue?(transaction) do
        days = Voile.Schema.Library.Transaction.days_overdue(transaction)
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
    member = Voile.Schema.Accounts.get_user!(transaction.member_id)

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
            |> assign(:transaction, transaction)
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
          |> assign(:transaction, transaction)

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

  defp extract_error_message(changeset) do
    changeset
    |> Map.get(:errors, [])
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end
end
