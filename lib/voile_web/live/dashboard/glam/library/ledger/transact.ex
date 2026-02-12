defmodule VoileWeb.Dashboard.Glam.Library.Ledger.Transact do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Library.{Circulation, Transaction}
  alias Voile.Schema.Catalog.{Item, Collection}
  alias Voile.Schema.Catalog
  alias VoileWeb.Auth.Authorization

  import Ecto.Query
  import VoileWeb.Dashboard.Glam.Library.Circulation.Components

  @impl true
  def mount(_params, _session, socket) do
    # Check basic circulation permission
    unless Authorization.can?(socket, "circulation.checkout") do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access circulation transactions")
        |> push_navigate(to: ~p"/manage/glam/library")

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"id" => member_id}, _uri, socket) do
    case load_member_data(member_id) do
      {:ok, member} ->
        librarian_id = socket.assigns.current_scope.user.id

        socket =
          socket
          |> assign(:page_title, "Collection Circulation / Books Ledger")
          |> assign(:member, member)
          |> assign(:member_id, member_id)
          |> assign(:librarian_id, librarian_id)
          |> assign(:active_tab, "loan")
          |> assign(:temp_loans, [])
          |> assign(:temp_reservations, [])
          |> assign(:item_search_query, "")
          |> assign(:use_legacy_code, false)
          |> assign(:collection_search_query, "")
          |> assign(:current_loans, load_current_loans(member_id))
          |> assign(:unpaid_fines, load_unpaid_fines(member_id))
          |> assign(:total_unpaid_fines, calculate_total_unpaid_fines(member_id))
          |> assign(:loan_history, load_loan_history(member_id))
          |> assign(:fine_history, load_fine_history(member_id))
          |> assign(:show_modal, nil)
          |> assign(:modal_data, %{})
          |> assign(:pending_item, nil)
          |> assign(:return_modal_visible, false)
          |> assign(:return_transaction_id, nil)
          |> assign(:return_transaction, nil)
          |> assign(:predicted_fine, Decimal.new("0"))
          |> assign(:payment_method, "cash")
          |> assign(:renew_modal_visible, false)
          |> assign(:renew_transaction_id, nil)
          |> assign(:renew_transaction, nil)
          |> assign(:recommended_renew_days, nil)
          |> assign(:preview_due_date, nil)
          |> assign(:remaining_renewals, 0)

        {:noreply, socket}

      {:error, _reason} ->
        socket =
          socket
          |> put_flash(:error, "Member not found")
          |> push_navigate(to: ~p"/manage/glam/library/ledger")

        {:noreply, socket}
    end
  end

  # Event handlers
  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("toggle_legacy_code", params, socket) do
    use_legacy = Map.has_key?(params, "value")
    {:noreply, assign(socket, :use_legacy_code, use_legacy)}
  end

  # Loan tab events
  def handle_event("search_item", %{"item_code" => item_code}, socket) do
    unless Authorization.can?(socket, "circulation.checkout") do
      {:noreply, put_flash(socket, :error, "You don't have permission to checkout items")}
    else
      item_code = String.trim(item_code)

      if item_code == "" do
        {:noreply, put_flash(socket, :error, "Please enter an item code")}
      else
        case find_item_by_code(item_code, socket.assigns.use_legacy_code) do
          nil ->
            code_type =
              if socket.assigns.use_legacy_code, do: "legacy item code", else: "item code"

            {:noreply,
             put_flash(socket, :error, "Item not found with #{code_type}: #{item_code}")}

          item ->
            # Check if item is already in temp_loans
            if Enum.any?(socket.assigns.temp_loans, fn loan -> loan.item.id == item.id end) do
              {:noreply, put_flash(socket, :error, "Item already added to loan list")}
            else
              # Check if item is from different unit location
              if socket.assigns.temp_loans != [] &&
                   has_different_unit?(item, socket.assigns.temp_loans) do
                # Show warning modal
                socket =
                  socket
                  |> assign(:show_modal, "different_unit_warning")
                  |> assign(:pending_item, item)
                  |> assign(:modal_data, %{
                    item: item,
                    existing_units: get_existing_units(socket.assigns.temp_loans)
                  })

                {:noreply, socket}
              else
                # Add to temporary loans directly
                socket = add_item_to_temp_loans(socket, item)
                {:noreply, socket}
              end
            end
        end
      end
    end
  end

  def handle_event("remove_temp_loan", %{"item_id" => item_id}, socket) do
    temp_loans =
      Enum.reject(socket.assigns.temp_loans, fn loan -> loan.item.id == item_id end)

    {:noreply, assign(socket, :temp_loans, temp_loans)}
  end

  def handle_event("confirm_add_different_unit", _params, socket) do
    case socket.assigns.pending_item do
      nil ->
        {:noreply, put_flash(socket, :error, "No pending item to add")}

      item ->
        socket =
          socket
          |> add_item_to_temp_loans(item)
          |> assign(:show_modal, nil)
          |> assign(:pending_item, nil)

        {:noreply, socket}
    end
  end

  def handle_event("cancel_add_different_unit", _params, socket) do
    socket =
      socket
      |> assign(:show_modal, nil)
      |> assign(:pending_item, nil)
      |> put_flash(:info, "Item not added to loan list")

    {:noreply, socket}
  end

  # Current Loans tab events
  def handle_event("show_return_modal", %{"transaction_id" => transaction_id}, socket) do
    unless Authorization.can?(socket, "circulation.return") do
      {:noreply, put_flash(socket, :error, "You don't have permission to return items")}
    else
      transaction = Enum.find(socket.assigns.current_loans, fn t -> t.id == transaction_id end)

      # load member with user_type
      member = socket.assigns.member

      predicted_fine =
        if Transaction.overdue?(transaction) do
          # Use the same calculation logic as actual fine calculation
          skip_holidays = Circulation.should_skip_holidays_in_fines?()
          days = Transaction.calculate_days_overdue(transaction, skip_holidays)
          daily = member.user_type.fine_per_day || Decimal.new("1.00")
          fine_amount = Decimal.mult(Decimal.new(days), daily)

          # Apply max fine limit if configured (same as actual calculation)
          if is_nil(member.user_type.max_fine) or
               Decimal.compare(member.user_type.max_fine, Decimal.new("0")) == :eq do
            fine_amount
          else
            Decimal.min(fine_amount, member.user_type.max_fine)
          end
        else
          Decimal.new("0")
        end

      socket =
        socket
        |> assign(:return_modal_visible, true)
        |> assign(:return_transaction_id, transaction_id)
        |> assign(:return_transaction, transaction)
        |> assign(:predicted_fine, predicted_fine)
        |> assign(:show_modal, nil)

      {:noreply, socket}
    end
  end

  def handle_event("cancel_return", _params, socket) do
    socket =
      socket
      |> assign(:return_modal_visible, false)
      |> assign(:return_transaction_id, nil)
      |> assign(:predicted_fine, Decimal.new("0"))

    {:noreply, socket}
  end

  def handle_event("confirm_return", params, socket) do
    unless Authorization.can?(socket, "circulation.return") do
      {:noreply, put_flash(socket, :error, "You don't have permission to return items")}
    else
      transaction_id = params["transaction_id"] || socket.assigns.return_transaction_id
      payment_amount = params["payment_amount"] || "0"
      payment_method = params["payment_method"] || "cash"

      # parse payment amount to Decimal
      payment_amount_decimal =
        case Decimal.parse(payment_amount) do
          {dec, _rest} when is_struct(dec) -> dec
          :error -> Decimal.new("0")
        end

      transaction = Circulation.get_transaction!(transaction_id) |> Repo.preload(item: :node)

      case Circulation.return_item(transaction_id, socket.assigns.librarian_id, %{
             node: transaction.item.node
           }) do
        {:ok, transaction} ->
          # After return, check if a fine exists for the transaction
          fine =
            case Circulation.get_fine_by_transaction(transaction.id) do
              {:ok, f} -> f
              _ -> nil
            end

          socket =
            socket
            |> assign(:current_loans, load_current_loans(socket.assigns.member_id))
            |> assign(:unpaid_fines, load_unpaid_fines(socket.assigns.member_id))
            |> assign(:total_unpaid_fines, calculate_total_unpaid_fines(socket.assigns.member_id))
            |> assign(:loan_history, load_loan_history(socket.assigns.member_id))

          # If there's a fine and payment amount > 0, attempt payment
          socket =
            if fine && Decimal.compare(payment_amount_decimal, Decimal.new("0")) == :gt do
              case Circulation.pay_fine(
                     fine.id,
                     payment_amount_decimal,
                     payment_method,
                     socket.assigns.librarian_id
                   ) do
                {:ok, _updated_fine} ->
                  put_flash(socket, :info, "Item returned and fine paid successfully")

                {:error, _changeset} ->
                  put_flash(
                    socket,
                    :error,
                    "Returned, but failed to pay fine"
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
            |> assign(:show_modal, nil)

          {:noreply, socket}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to return item: #{inspect(reason)}")}
      end
    end
  end

  def handle_event("show_extend_modal", %{"transaction_id" => transaction_id}, socket) do
    unless Authorization.can?(socket, "circulation.renew") do
      {:noreply, put_flash(socket, :error, "You don't have permission to renew items")}
    else
      transaction = Enum.find(socket.assigns.current_loans, fn t -> t.id == transaction_id end)

      # load member and member type
      member = socket.assigns.member

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
        |> assign(:renew_transaction_id, transaction_id)
        |> assign(:renew_transaction, transaction)
        |> assign(:recommended_renew_days, recommended_days)
        |> assign(:preview_due_date, preview_due_date)
        |> assign(:remaining_renewals, remaining_renewals)
        |> assign(:show_modal, nil)

      {:noreply, socket}
    end
  end

  def handle_event("renew_days_change", %{"renew_days" => renew_days}, socket) do
    transaction =
      socket.assigns.renew_transaction ||
        if socket.assigns.renew_transaction_id,
          do:
            Enum.find(socket.assigns.current_loans, fn t ->
              t.id == socket.assigns.renew_transaction_id
            end),
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

  def handle_event("confirm_renew", params, socket) do
    unless Authorization.can?(socket, "circulation.renew") do
      {:noreply, put_flash(socket, :error, "You don't have permission to renew items")}
    else
      transaction_id = params["transaction_id"] || socket.assigns.renew_transaction_id
      renew_days = params["renew_days"]
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
                  transaction =
                    Enum.find(socket.assigns.current_loans, fn t -> t.id == transaction_id end)

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

        case Circulation.renew_transaction(transaction_id, socket.assigns.librarian_id, attrs) do
          {:ok, _transaction} ->
            socket =
              socket
              |> assign(:current_loans, load_current_loans(socket.assigns.member_id))
              |> assign(:renew_modal_visible, false)
              |> assign(:renew_transaction_id, nil)
              |> assign(:recommended_renew_days, nil)
              |> assign(:show_modal, nil)
              |> put_flash(:info, "Loan renewed successfully")

            {:noreply, socket}

          {:error, reason} ->
            socket =
              put_flash(socket, :error, "Failed to renew loan: #{inspect(reason)}")

            {:noreply, socket}
        end
      end
    end
  end

  # Reserve tab events
  def handle_event("search_collection", %{"query" => query}, socket) do
    {:noreply, assign(socket, :collection_search_query, query)}
  end

  def handle_event("add_reservation", %{"collection_id" => collection_id}, socket) do
    unless Authorization.can?(socket, "circulation.manage_reservations") do
      {:noreply, put_flash(socket, :error, "You don't have permission to manage reservations")}
    else
      collection = Repo.get!(Collection, collection_id)

      # Check if already in temp reservations
      if Enum.any?(socket.assigns.temp_reservations, fn r -> r.collection.id == collection_id end) do
        {:noreply, put_flash(socket, :error, "Collection already in reservation list")}
      else
        temp_reservation = %{
          collection: collection,
          item_code: nil,
          reserve_date: Date.utc_today()
        }

        updated_temp_reservations = socket.assigns.temp_reservations ++ [temp_reservation]

        socket =
          socket
          |> assign(:temp_reservations, updated_temp_reservations)
          |> put_flash(:info, "Collection added to reservation list")

        {:noreply, socket}
      end
    end
  end

  def handle_event("remove_temp_reservation", %{"collection_id" => collection_id}, socket) do
    temp_reservations =
      Enum.reject(socket.assigns.temp_reservations, fn r -> r.collection.id == collection_id end)

    {:noreply, assign(socket, :temp_reservations, temp_reservations)}
  end

  # Fines tab events
  def handle_event("show_add_fine_modal", _params, socket) do
    unless Authorization.can?(socket, "circulation.manage_fines") do
      {:noreply, put_flash(socket, :error, "You don't have permission to manage fines")}
    else
      socket =
        socket
        |> assign(:show_modal, "add_fine")
        |> assign(:modal_data, %{
          fine_form:
            to_form(%{
              "description" => "",
              "amount" => "",
              "fine_type" => "processing"
            })
        })

      {:noreply, socket}
    end
  end

  def handle_event("create_fine", params, socket) do
    fine_attrs = %{
      member_id: socket.assigns.member_id,
      fine_type: params["fine_type"],
      description: params["description"],
      amount: params["amount"],
      fine_date: DateTime.utc_now(),
      fine_status: "pending",
      processed_by_id: socket.assigns.librarian_id
    }

    case Circulation.create_fine(fine_attrs) do
      {:ok, _fine} ->
        socket =
          socket
          |> assign(:unpaid_fines, load_unpaid_fines(socket.assigns.member_id))
          |> assign(:total_unpaid_fines, calculate_total_unpaid_fines(socket.assigns.member_id))
          |> assign(:show_modal, nil)
          |> put_flash(:info, "Fine created successfully")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create fine")}
    end
  end

  def handle_event("show_waive_fine_modal", %{"fine_id" => fine_id}, socket) do
    unless Authorization.can?(socket, "circulation.manage_fines") do
      {:noreply, put_flash(socket, :error, "You don't have permission to manage fines")}
    else
      fine = Enum.find(socket.assigns.unpaid_fines, fn f -> f.id == fine_id end)

      socket =
        socket
        |> assign(:show_modal, "waive_fine")
        |> assign(:modal_data, %{fine: fine})

      {:noreply, socket}
    end
  end

  def handle_event("confirm_waive_fine", params, socket) do
    fine_id = params["fine_id"]
    reason = params["reason"]

    case Circulation.waive_fine(fine_id, reason, socket.assigns.librarian_id) do
      {:ok, _} ->
        socket =
          socket
          |> assign(:unpaid_fines, load_unpaid_fines(socket.assigns.member_id))
          |> assign(:total_unpaid_fines, calculate_total_unpaid_fines(socket.assigns.member_id))
          |> assign(:show_modal, nil)
          |> put_flash(:info, "Fine waived successfully")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to waive fine")}
    end
  end

  def handle_event("show_pay_fine_modal", %{"fine_id" => fine_id}, socket) do
    fine = Enum.find(socket.assigns.unpaid_fines, fn f -> f.id == fine_id end)

    # Check if there's an existing pending payment link
    pending_payment =
      case Circulation.get_pending_payment_for_fine(fine_id) do
        {:ok, payment} -> payment
        _ -> nil
      end

    socket =
      socket
      |> assign(:show_modal, "pay_fine")
      |> assign(:modal_data, %{
        fine: fine,
        pending_payment: pending_payment,
        payment_form:
          to_form(%{
            "amount" => to_string(fine.balance),
            "payment_method" => "cash"
          })
      })

    {:noreply, socket}
  end

  def handle_event("confirm_pay_fine", %{"fine_id" => fine_id} = params, socket) do
    payment_amount = Decimal.new(params["amount"])
    payment_method = params["payment_method"]

    case Circulation.pay_fine(
           fine_id,
           payment_amount,
           payment_method,
           socket.assigns.librarian_id
         ) do
      {:ok, _fine} ->
        socket =
          socket
          |> assign(:unpaid_fines, load_unpaid_fines(socket.assigns.member_id))
          |> assign(:total_unpaid_fines, calculate_total_unpaid_fines(socket.assigns.member_id))
          |> assign(:show_modal, nil)
          |> put_flash(:info, "Payment processed successfully")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Payment failed: #{reason}")}
    end
  end

  def handle_event("generate_payment_link", %{"fine_id" => fine_id}, socket) do
    # Generate Xendit payment link
    case Circulation.create_payment_link_for_fine(
           fine_id,
           socket.assigns.librarian_id,
           success_redirect_url: ~p"/atrium?payment=success",
           failure_redirect_url: ~p"/atrium?payment=failed"
         ) do
      {:ok, payment} ->
        fine = Enum.find(socket.assigns.unpaid_fines, fn f -> f.id == fine_id end)

        socket =
          socket
          |> assign(:show_modal, "pay_fine")
          |> assign(:modal_data, %{
            fine: fine,
            pending_payment: payment,
            payment_form:
              to_form(%{"amount" => to_string(fine.balance), "payment_method" => "cash"})
          })
          |> put_flash(:info, "Payment link generated successfully")

        {:noreply, socket}

      {:error, :api_key_not_configured} ->
        {:noreply, put_flash(socket, :error, "Xendit API key not configured")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Failed to generate payment link: #{inspect(reason)}")}
    end
  end

  def handle_event("copy_payment_link", %{"url" => _url}, socket) do
    # Client-side will handle the actual copy
    {:noreply, put_flash(socket, :info, "Payment link copied to clipboard")}
  end

  # Finish transaction
  def handle_event("show_finish_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, "finish_transaction")}
  end

  def handle_event("finish_transaction", _params, socket) do
    unless Authorization.can?(socket, "circulation.checkout") do
      {:noreply, put_flash(socket, :error, "You don't have permission to complete transactions")}
    else
      # Process all temporary loans
      loan_results =
        Enum.map(socket.assigns.temp_loans, fn temp_loan ->
          # Ensure item has node preloaded for rule resolution
          item = Repo.preload(temp_loan.item, :node)

          Circulation.checkout_item(
            socket.assigns.member_id,
            item.id,
            socket.assigns.librarian_id,
            %{node: item.node}
          )
        end)

      # Process all temporary reservations
      reservation_results =
        Enum.map(socket.assigns.temp_reservations, fn temp_res ->
          Circulation.create_collection_reservation(
            socket.assigns.member_id,
            temp_res.collection.id
          )
        end)

      # Check results
      loan_successes =
        Enum.count(loan_results, fn
          {:ok, _} -> true
          _ -> false
        end)

      reservation_successes =
        Enum.count(reservation_results, fn
          {:ok, _} -> true
          _ -> false
        end)

      socket =
        socket
        |> assign(:temp_loans, [])
        |> assign(:temp_reservations, [])
        |> assign(:current_loans, load_current_loans(socket.assigns.member_id))
        |> assign(:loan_history, load_loan_history(socket.assigns.member_id))
        |> assign(:show_modal, nil)
        |> push_navigate(to: ~p"/manage/glam/library/ledger")
        |> put_flash(
          :info,
          "Transaction completed: #{loan_successes} loans, #{reservation_successes} reservations"
        )

      {:noreply, socket}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, nil)}
  end

  # Helper functions
  defp load_member_data(member_id) do
    case Repo.get(User, member_id) |> Repo.preload([:user_type, :node]) do
      nil -> {:error, :not_found}
      member -> {:ok, member}
    end
  end

  defp find_item_by_code(item_code, use_legacy_code) do
    # If using legacy code, query by legacy_item_code
    if use_legacy_code do
      Item
      |> where([i], i.legacy_item_code == ^item_code)
      |> where([i], i.status == "active" and i.availability == "available")
      |> preload([:collection, :node])
      |> limit(1)
      |> Repo.one()
    else
      # Use the new barcode finder that supports both full item_code and shortened barcode
      case Catalog.find_item_by_barcode(item_code) do
        nil ->
          nil

        item ->
          # Preload if not already loaded, and check availability
          item = Repo.preload(item, [:collection, :node])

          if item.status == "active" and item.availability == "available" do
            item
          else
            nil
          end
      end
    end
  end

  defp load_current_loans(member_id) do
    Circulation.list_member_active_transactions(member_id)
  end

  defp load_unpaid_fines(member_id) do
    Circulation.list_member_unpaid_fines(member_id)
  end

  defp calculate_total_unpaid_fines(member_id) do
    Circulation.get_member_outstanding_fine_amount(member_id)
  end

  defp load_loan_history(member_id) do
    Circulation.get_member_history(member_id)
    |> Enum.filter(fn h -> h.event_type in ["loan", "return"] end)
    |> Enum.take(20)
  end

  defp load_fine_history(member_id) do
    Circulation.list_member_all_fines(member_id)
  end

  defp calculate_due_date(member) do
    days = (member.user_type && member.user_type.max_days) || 14
    Date.add(Date.utc_today(), days)
  end

  defp has_different_unit?(item, temp_loans) do
    existing_node_ids =
      temp_loans
      |> Enum.map(fn loan -> loan.item.unit_id end)
      |> Enum.uniq()

    !Enum.member?(existing_node_ids, item.unit_id)
  end

  defp get_existing_units(temp_loans) do
    temp_loans
    |> Enum.map(fn loan -> loan.item.node.name end)
    |> Enum.uniq()
    |> Enum.join(", ")
  end

  defp add_item_to_temp_loans(socket, item) do
    temp_loan = %{
      item: item,
      loan_date: Date.utc_today(),
      due_date: calculate_due_date(socket.assigns.member)
    }

    updated_temp_loans = socket.assigns.temp_loans ++ [temp_loan]

    socket
    |> assign(:temp_loans, updated_temp_loans)
    |> assign(:item_search_query, "")
    |> put_flash(:info, "Item added to loan list")
  end

  defp format_currency(amount) when is_struct(amount, Decimal) do
    # Convert Decimal to integer for formatting
    amount_int =
      amount
      |> Decimal.to_string()
      |> String.split(".")
      |> List.first()
      |> String.to_integer()

    # Format with thousand separators
    amount_str = Integer.to_string(amount_int)
    formatted = format_with_separators(amount_str)
    "Rp #{formatted}"
  end

  defp format_currency(_), do: "Rp 0"

  defp format_with_separators(str) do
    str
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(".")
    |> String.reverse()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.breadcrumb items={[
      %{label: gettext("Manage"), path: ~p"/manage"},
      %{label: gettext("GLAM"), path: ~p"/manage/glam"},
      %{label: gettext("Library"), path: ~p"/manage/glam/library"},
      %{label: gettext("Ledgers"), path: ~p"/manage/glam/library/ledger"},
      %{label: gettext("Transaction"), path: nil}
    ]} />
    <div class="space-y-6">
      <%!-- Header with Finish Button --%>
      <div class="flex items-center justify-between">
        <div>
          <.back navigate="/manage/glam/library/ledger">{gettext("Back to Search")}</.back>

          <h1 class="text-3xl font-bold mt-4">{gettext("Collection Circulation / Books Ledger")}</h1>
        </div>

        <.button
          phx-click="show_finish_modal"
          class="bg-green-600 hover:bg-green-700 text-white font-semibold py-3 px-6 rounded-lg"
        >
          <.icon name="hero-check-circle" class="w-5 h-5 mr-2" /> {gettext("Finish Transaction")}
        </.button>
      </div>
      <%!-- Member Biodata --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <h2 class="text-xl font-semibold mb-4 text-gray-900 dark:text-white">
          {gettext("Member Information")}
        </h2>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">{gettext("Full Name")}</p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {@member.fullname || gettext("N/A")}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">
              {gettext("Identifier")}
            </p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {if @member.identifier, do: Decimal.to_string(@member.identifier), else: gettext("N/A")}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">{gettext("Email")}</p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {@member.email || gettext("N/A")}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">
              {gettext("Member Type")}
            </p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {if @member.user_type, do: @member.user_type.name, else: gettext("N/A")}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">{gettext("Phone")}</p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {@member.phone_number || gettext("N/A")}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">
              {gettext("Unit Location")}
            </p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {if @member.node, do: @member.node.name, else: gettext("N/A")}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">
              {gettext("Registration Date")}
            </p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {if @member.registration_date,
                do: Calendar.strftime(@member.registration_date, "%B %d, %Y"),
                else: gettext("N/A")}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">
              {gettext("Expiry Date")}
            </p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {if @member.expiry_date,
                do: Calendar.strftime(@member.expiry_date, "%B %d, %Y"),
                else: gettext("N/A")}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">{gettext("Address")}</p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {@member.address || gettext("N/A")}
            </p>
          </div>
        </div>
      </div>
      <%!-- Tabs --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow">
        <%!-- Tab Headers --%>
        <div class="border-b border-gray-200 dark:border-gray-700">
          <nav class="flex -mb-px">
            <button
              phx-click="change_tab"
              phx-value-tab="loan"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "loan",
                  do: "border-indigo-500 text-indigo-600 dark:text-indigo-400",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              {gettext("Loan")}
            </button>
            <button
              phx-click="change_tab"
              phx-value-tab="current_loans"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "current_loans",
                  do: "border-indigo-500 text-indigo-600 dark:text-indigo-400",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              {gettext("Current Loans")} ({length(@current_loans)})
            </button>
            <button
              phx-click="change_tab"
              phx-value-tab="reserve"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "reserve",
                  do: "border-indigo-500 text-indigo-600 dark:text-indigo-400",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              {gettext("Reserve")}
            </button>
            <button
              phx-click="change_tab"
              phx-value-tab="fines"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "fines",
                  do: "border-indigo-500 text-indigo-600 dark:text-indigo-400",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              {gettext("Fines")} ({length(@unpaid_fines)})
            </button>
            <button
              phx-click="change_tab"
              phx-value-tab="history"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "history",
                  do: "border-indigo-500 text-indigo-600 dark:text-indigo-400",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              {gettext("Loan History")}
            </button>
            <button
              phx-click="change_tab"
              phx-value-tab="fine_history"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "fine_history",
                  do: "border-indigo-500 text-indigo-600 dark:text-indigo-400",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              {gettext("Fine History")}
            </button>
          </nav>
        </div>
        <%!-- Tab Content --%>
        <div class="p-6">
          <%= if @active_tab == "loan" do %>
            {render_loan_tab(assigns)}
          <% end %>

          <%= if @active_tab == "current_loans" do %>
            {render_current_loans_tab(assigns)}
          <% end %>

          <%= if @active_tab == "reserve" do %>
            {render_reserve_tab(assigns)}
          <% end %>

          <%= if @active_tab == "fines" do %>
            {render_fines_tab(assigns)}
          <% end %>

          <%= if @active_tab == "history" do %>
            {render_history_tab(assigns)}
          <% end %>

          <%= if @active_tab == "fine_history" do %>
            {render_fine_history_tab(assigns)}
          <% end %>
        </div>
      </div>
    </div>
    <%!-- Modals --%>
    <%= if @show_modal do %>
      {render_modal(assigns)}
    <% end %>

    <.return_modal
      return_modal_visible={assigns[:return_modal_visible] || false}
      transaction={assigns[:return_transaction] || nil}
      predicted_fine={assigns[:predicted_fine] || Decimal.new("0")}
      payment_method={assigns[:payment_method] || "cash"}
      return_transaction_id={assigns[:return_transaction_id] || nil}
    />
    <.renew_modal
      renew_modal_visible={assigns[:renew_modal_visible] || false}
      transaction={assigns[:renew_transaction] || nil}
      recommended_renew_days={assigns[:recommended_renew_days]}
      preview_due_date={assigns[:preview_due_date]}
      remaining_renewals={assigns[:remaining_renewals] || 0}
      renew_transaction_id={assigns[:renew_transaction_id] || nil}
      current_user={@current_scope.user}
    />
    """
  end

  def render_loan_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          {gettext("Search Item by Code")}
        </label>
        <form phx-submit="search_item" class="space-y-3">
          <div class="flex gap-2">
            <input
              type="text"
              name="item_code"
              value={@item_search_query}
              class="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-indigo-500 dark:bg-gray-700 dark:text-white"
              placeholder={gettext("Enter item code...")}
            />
            <.button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-2">
              {gettext("Loan")}
            </.button>
          </div>

          <div class="flex items-center gap-2">
            <input
              type="checkbox"
              id="use-legacy-code"
              phx-click="toggle_legacy_code"
              checked={@use_legacy_code}
              class="w-4 h-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500 dark:border-gray-600 dark:bg-gray-700"
            />
            <label
              for="use-legacy-code"
              class="text-sm text-gray-700 dark:text-gray-300 cursor-pointer"
            >
              {gettext("Use Legacy Item Code?")}
            </label>
          </div>
        </form>
      </div>

      <div>
        <h3 class="text-lg font-semibold mb-4 text-gray-900 dark:text-white">
          {gettext("Items to Loan")} ({length(@temp_loans)})
        </h3>

        <%= if @temp_loans == [] do %>
          <div class="text-center py-12 text-gray-500 dark:text-gray-400">
            <.icon name="hero-book-open" class="w-16 h-16 mx-auto mb-4 opacity-50" />
            <p>{gettext("No items added yet. Search and add items above.")}</p>
          </div>
        <% else %>
          <div
            class="overflow-x-auto overflow-y-visible scrollbar-visible border border-gray-200 dark:border-gray-700 rounded-lg"
            style="scrollbar-width: thin;"
          >
            <table class="min-w-full table-fixed divide-y divide-gray-200 dark:divide-gray-700">
              <colgroup>
                <col class="w-20" /> <col class="w-1/5" /> <col class="w-1/5" /> <col class="w-1/5" />
                <col class="w-1/5" /> <col class="w-1/5" />
              </colgroup>

              <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-semibold text-gray-700 dark:text-gray-200 uppercase tracking-wider border-r border-gray-300 dark:border-gray-600">
                    {gettext("Remove")}
                  </th>

                  <th class="px-4 py-3 text-left text-xs font-semibold text-gray-700 dark:text-gray-200 uppercase tracking-wider border-r border-gray-300 dark:border-gray-600">
                    {gettext("Item Code")}
                  </th>

                  <th class="px-4 py-3 text-left text-xs font-semibold text-gray-700 dark:text-gray-200 uppercase tracking-wider border-r border-gray-300 dark:border-gray-600">
                    {gettext("Title")}
                  </th>

                  <th class="px-4 py-3 text-left text-xs font-semibold text-gray-700 dark:text-gray-200 uppercase tracking-wider border-r border-gray-300 dark:border-gray-600">
                    {gettext("Unit Location")}
                  </th>

                  <th class="px-4 py-3 text-left text-xs font-semibold text-gray-700 dark:text-gray-200 uppercase tracking-wider border-r border-gray-300 dark:border-gray-600">
                    {gettext("Loan Date")}
                  </th>

                  <th class="px-4 py-3 text-left text-xs font-semibold text-gray-700 dark:text-gray-200 uppercase tracking-wider">
                    {gettext("Due Date")}
                  </th>
                </tr>
              </thead>

              <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                <tr
                  :for={loan <- @temp_loans}
                  class="hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
                >
                  <td class="px-4 py-3 border-r border-gray-200 dark:border-gray-700">
                    <button
                      phx-click="remove_temp_loan"
                      phx-value-item_id={loan.item.id}
                      class="text-red-600 hover:text-red-900 dark:hover:text-red-400"
                    >
                      <.icon name="hero-trash" class="w-5 h-5" />
                    </button>
                  </td>

                  <td
                    class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100 break-words border-r border-gray-200 dark:border-gray-700 font-mono"
                    title={loan.item.item_code}
                  >
                    {loan.item.item_code}
                  </td>

                  <td
                    class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100 break-words border-r border-gray-200 dark:border-gray-700 font-medium"
                    title={loan.item.collection.title}
                  >
                    {loan.item.collection.title}
                  </td>

                  <td
                    class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100 break-words border-r border-gray-200 dark:border-gray-700"
                    title={loan.item.node.name}
                  >
                    {loan.item.node.name || "N/A"}
                  </td>

                  <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100 break-words border-r border-gray-200 dark:border-gray-700 whitespace-nowrap">
                    {Calendar.strftime(loan.loan_date, "%B %d, %Y")}
                  </td>

                  <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100 break-words whitespace-nowrap">
                    {Calendar.strftime(loan.due_date, "%B %d, %Y")}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def render_current_loans_tab(assigns) do
    ~H"""
    <div>
      <%= if @current_loans == [] do %>
        <div class="text-center py-12 text-gray-500 dark:text-gray-400">
          <.icon name="hero-inbox" class="w-16 h-16 mx-auto mb-4 opacity-50" />
          <p>{gettext("No active loans for this member.")}</p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead class="bg-gray-50 dark:bg-gray-700">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Actions")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Item Code")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Title")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Loan Date")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Due Date")}
                </th>
              </tr>
            </thead>

            <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              <tr :for={transaction <- @current_loans}>
                <td class="px-6 py-4 flex gap-2">
                  <button
                    phx-click="show_return_modal"
                    phx-value-transaction_id={transaction.id}
                    class="bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded text-sm"
                  >
                    {gettext("Return")}
                  </button>
                  <button
                    phx-click="show_extend_modal"
                    phx-value-transaction_id={transaction.id}
                    class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 rounded text-sm"
                  >
                    {gettext("Extend")}
                  </button>
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {transaction.item.item_code}
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {transaction.item.collection.title}
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {Calendar.strftime(transaction.transaction_date, "%B %d, %Y")}
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {Calendar.strftime(transaction.due_date, "%B %d, %Y")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  def render_reserve_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          {gettext("Search Collection")}
        </label>
        <form phx-submit="search_collection" class="flex gap-2">
          <input
            type="text"
            name="query"
            value={@collection_search_query}
            class="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-indigo-500 dark:bg-gray-700 dark:text-white"
            placeholder={gettext("Search collections...")}
          />
          <.button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-2">
            {gettext("Search")}
          </.button>
        </form>
      </div>

      <div>
        <h3 class="text-lg font-semibold mb-4 text-gray-900 dark:text-white">
          {gettext("Temporary Reservations")} ({length(@temp_reservations)})
        </h3>

        <%= if @temp_reservations == [] do %>
          <div class="text-center py-12 text-gray-500 dark:text-gray-400">
            <.icon name="hero-bookmark" class="w-16 h-16 mx-auto mb-4 opacity-50" />
            <p>{gettext("No reservations added yet.")}</p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    {gettext("Remove")}
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    {gettext("Title")}
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    {gettext("Item Code")}
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    {gettext("Reserve Date")}
                  </th>
                </tr>
              </thead>

              <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                <tr :for={reservation <- @temp_reservations}>
                  <td class="px-6 py-4">
                    <button
                      phx-click="remove_temp_reservation"
                      phx-value-collection_id={reservation.collection.id}
                      class="text-red-600 hover:text-red-900 dark:hover:text-red-400"
                    >
                      <.icon name="hero-trash" class="w-5 h-5" />
                    </button>
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {reservation.collection.title}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {reservation.item_code || gettext("Any available")}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {Calendar.strftime(reservation.reserve_date, "%B %d, %Y")}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def render_fines_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex gap-2">
        <.button phx-click="show_add_fine_modal" class="primary-btn">
          {gettext("Add New Fine")}
        </.button>
      </div>

      <div class="bg-blue-50 dark:bg-blue-900/20 rounded-lg p-4">
        <p class="text-sm font-medium text-blue-900 dark:text-blue-100">
          {gettext("Total Unpaid Fines:")}
          <span class="text-lg font-bold">{format_currency(@total_unpaid_fines)}</span>
        </p>
      </div>

      <div>
        <%= if @unpaid_fines == [] do %>
          <div class="text-center py-12 text-gray-500 dark:text-gray-400">
            <.icon name="hero-currency-dollar" class="w-16 h-16 mx-auto mb-4 opacity-50" />
            <p>{gettext("No unpaid fines.")}</p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    {gettext("Actions")}
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    {gettext("Description")}
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    {gettext("Fine Date")}
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    {gettext("Amount")}
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    {gettext("Paid")}
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    {gettext("Balance")}
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    {gettext("Status")}
                  </th>
                </tr>
              </thead>

              <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                <tr :for={fine <- @unpaid_fines}>
                  <td class="px-6 py-4 flex gap-2">
                    <button
                      phx-click="show_waive_fine_modal"
                      phx-value-fine_id={fine.id}
                      class="text-orange-600 hover:text-orange-900"
                      title={gettext("Waive")}
                    >
                      <.icon name="hero-x-circle" class="w-5 h-5" />
                    </button>
                    <button
                      phx-click="show_pay_fine_modal"
                      phx-value-fine_id={fine.id}
                      class="text-green-600 hover:text-green-900"
                      title={gettext("Pay")}
                    >
                      <.icon name="hero-currency-dollar" class="w-5 h-5" />
                    </button>
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {fine.description || fine.fine_type}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {Calendar.strftime(fine.fine_date, "%B %d, %Y")}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {format_currency(fine.amount)}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {format_currency(fine.paid_amount)}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {format_currency(fine.balance)}
                  </td>

                  <td class="px-6 py-4">
                    <span class={[
                      "px-2 py-1 text-xs rounded-full",
                      case fine.fine_status do
                        "pending" -> "bg-yellow-100 text-yellow-800"
                        "partial_paid" -> "bg-blue-100 text-blue-800"
                        "paid" -> "bg-green-100 text-green-800"
                        _ -> "bg-gray-100 text-gray-800"
                      end
                    ]}>
                      {Gettext.gettext(VoileWeb.Gettext, fine.fine_status)}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def render_history_tab(assigns) do
    ~H"""
    <div>
      <%= if @loan_history == [] do %>
        <div class="text-center py-12 text-gray-500 dark:text-gray-400">
          <.icon name="hero-clock" class="w-16 h-16 mx-auto mb-4 opacity-50" />
          <p>{gettext("No loan history available.")}</p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead class="bg-gray-50 dark:bg-gray-700">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Item Code")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Title")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Event")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Date")}
                </th>
              </tr>
            </thead>

            <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              <tr :for={history <- @loan_history}>
                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {(history.item && history.item.item_code) || gettext("N/A")}
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {(history.item && history.item.collection && history.item.collection.title) ||
                    gettext("N/A")}
                </td>

                <td class="px-6 py-4">
                  <span class={[
                    "px-2 py-1 text-xs rounded-full",
                    case history.event_type do
                      "loan" -> "bg-blue-100 text-blue-800"
                      "return" -> "bg-green-100 text-green-800"
                      _ -> "bg-gray-100 text-gray-800"
                    end
                  ]}>
                    {Gettext.gettext(VoileWeb.Gettext, history.event_type)}
                  </span>
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {Calendar.strftime(history.event_date, "%B %d, %Y %H:%M")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  def render_fine_history_tab(assigns) do
    ~H"""
    <div>
      <%= if @fine_history == [] do %>
        <div class="text-center py-12 text-gray-500 dark:text-gray-400">
          <.icon name="hero-currency-dollar" class="w-16 h-16 mx-auto mb-4 opacity-50" />
          <p>{gettext("No fine history available.")}</p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead class="bg-gray-50 dark:bg-gray-700">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Fine Type")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Description")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Fine Date")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Amount")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Paid")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Balance")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Status")}
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  {gettext("Processed By")}
                </th>
              </tr>
            </thead>

            <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              <tr :for={fine <- @fine_history}>
                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  <span class="capitalize">{String.replace(fine.fine_type, "_", " ")}</span>
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {fine.description || "-"}
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {Calendar.strftime(fine.fine_date, "%B %d, %Y")}
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {format_currency(fine.amount)}
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {format_currency(fine.paid_amount)}
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {format_currency(fine.balance)}
                </td>

                <td class="px-6 py-4">
                  <span class={[
                    "px-2 py-1 text-xs rounded-full",
                    case fine.fine_status do
                      "pending" -> "bg-yellow-100 text-yellow-800"
                      "partial_paid" -> "bg-blue-100 text-blue-800"
                      "paid" -> "bg-green-100 text-green-800"
                      "waived" -> "bg-orange-100 text-orange-800"
                      _ -> "bg-gray-100 text-gray-800"
                    end
                  ]}>
                    {Gettext.gettext(VoileWeb.Gettext, fine.fine_status)}
                  </span>
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {if fine.waived && fine.waived_by do
                    fine.waived_by.fullname || fine.waived_by.email
                  else
                    if fine.processed_by do
                      fine.processed_by.fullname || fine.processed_by.email
                    else
                      gettext("N/A")
                    end
                  end}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  def render_modal(assigns) do
    ~H"""
    <.modal id="transaction-modal" show on_cancel={JS.push("close_modal")}>
      <%= cond do %>
        <% @show_modal == "add_fine" -> %>
          <div>
            <h3 class="text-lg font-semibold mb-4">{gettext("Add New Fine")}</h3>

            <form phx-submit="create_fine" class="space-y-4">
              <div>
                <label class="block text-sm font-medium mb-1">{gettext("Fine Type")}</label>
                <select
                  name="fine_type"
                  class="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600"
                  required
                >
                  <option value="processing">{gettext("Processing Fee")}</option>

                  <option value="damaged_item">{gettext("Damaged Item")}</option>

                  <option value="lost_item">{gettext("Lost Item")}</option>

                  <option value="overdue">{gettext("Overdue")}</option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium mb-1">{gettext("Description")}</label>
                <input
                  type="text"
                  name="description"
                  class="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium mb-1">{gettext("Amount (Rp)")}</label>
                <input
                  type="number"
                  name="amount"
                  class="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600"
                  required
                />
              </div>

              <div class="flex gap-2 justify-end">
                <.button
                  type="button"
                  phx-click="close_modal"
                  class="cancel-btn"
                >
                  Cancel
                </.button>
                <.button type="submit" class="primary-btn">{gettext("Create Fine")}</.button>
              </div>
            </form>
          </div>
        <% @show_modal == "waive_fine" -> %>
          <div>
            <h3 class="text-lg font-semibold mb-4">{gettext("Waive Fine")}</h3>

            <p class="mb-4">
              {gettext("Are you sure you want to waive this fine of %{amount}?",
                amount: format_currency(@modal_data.fine.amount)
              )}
            </p>

            <form phx-submit="confirm_waive_fine" class="space-y-4">
              <input type="hidden" name="fine_id" value={@modal_data.fine.id} />
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  {gettext("Reason for waiving (optional)")}
                </label>
                <textarea
                  name="reason"
                  rows="3"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-indigo-500 dark:bg-gray-700 dark:text-white"
                  placeholder={gettext("Enter reason for waiving this fine...")}
                ></textarea>
              </div>

              <div class="flex gap-2 justify-end">
                <.button
                  type="button"
                  phx-click="close_modal"
                  class="warning-btn"
                >
                  Cancel
                </.button>
                <.button type="submit" class="cancel-btn">{gettext("Confirm Waive")}</.button>
              </div>
            </form>
          </div>
        <% @show_modal == "pay_fine" -> %>
          <div>
            <h3 class="text-lg font-semibold mb-4">Pay Fine</h3>

            <%= if @modal_data.pending_payment do %>
              <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4 mb-4">
                <h4 class="font-semibold text-blue-900 dark:text-blue-100 mb-2">
                  <.icon name="hero-link" class="w-5 h-5 inline" /> Payment Link Generated
                </h4>

                <p class="text-sm text-blue-700 dark:text-blue-200 mb-3">
                  A payment link has been created. Share this link with the member or use it to process online payment.
                </p>

                <div class="bg-white dark:bg-gray-800 rounded p-3 mb-3">
                  <div class="flex items-center gap-2">
                    <input
                      id="payment-link-input"
                      type="text"
                      value={@modal_data.pending_payment.payment_url}
                      readonly
                      class="flex-1 px-2 py-1 text-sm border rounded dark:bg-gray-700 dark:border-gray-600"
                    />
                    <.button
                      type="button"
                      class="bg-blue-600 hover:bg-blue-700 text-white text-sm px-3 py-1"
                    >
                      <.icon name="hero-clipboard-document" class="w-4 h-4" />
                    </.button>
                  </div>
                </div>

                <div class="grid grid-cols-2 gap-2 text-sm">
                  <div>
                    <span class="text-gray-600 dark:text-gray-400">Status:</span>
                    <span class="ml-2 font-medium">
                      {String.upcase(@modal_data.pending_payment.status)}
                    </span>
                  </div>

                  <div>
                    <span class="text-gray-600 dark:text-gray-400">Amount:</span>
                    <span class="ml-2 font-medium">
                      {format_currency(@modal_data.pending_payment.amount)}
                    </span>
                  </div>
                </div>

                <a
                  href={@modal_data.pending_payment.payment_url}
                  target="_blank"
                  class="mt-3 inline-block text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400"
                >
                  Open payment page
                  <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4 inline" />
                </a>
              </div>
            <% end %>

            <%= if !@modal_data.pending_payment do %>
              <div class="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-3 mb-4">
                <p class="text-sm text-yellow-800 dark:text-yellow-200">
                  <.icon name="hero-information-circle" class="w-5 h-5 inline mr-1" />
                  No payment link exists. Generate one for online payment or process cash payment below.
                </p>

                <.button
                  type="button"
                  phx-click="generate_payment_link"
                  phx-value-fine_id={@modal_data.fine.id}
                  class="success-btn"
                >
                  <.icon name="hero-link" class="w-4 h-4 mr-1" /> Generate Payment Link
                </.button>
              </div>
            <% end %>

            <form phx-submit="confirm_pay_fine" class="space-y-4">
              <input type="hidden" name="fine_id" value={@modal_data.fine.id} />

              <div>
                <label class="block text-sm font-medium mb-1">Amount to Pay</label>
                <input
                  type="number"
                  name="amount"
                  value="0"
                  class="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium mb-1">{gettext("Payment Method")}</label>
                <select
                  name="payment_method"
                  class="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600"
                  required
                >
                  <option value="cash">{gettext("Cash")}</option>

                  <option value="credit_card">{gettext("Credit Card")}</option>

                  <option value="debit_card">{gettext("Debit Card")}</option>

                  <option value="bank_transfer">{gettext("Bank Transfer")}</option>

                  <option value="online">{gettext("Online Payment")}</option>
                </select>
              </div>

              <div class="flex gap-2 justify-end">
                <.button
                  type="button"
                  phx-click="close_modal"
                  class="warning-btn"
                >
                  Cancel
                </.button>
                <.button type="submit" class="success-btn">{gettext("Process Payment")}</.button>
              </div>
            </form>
          </div>
        <% @show_modal == "different_unit_warning_temp" -> %>
          <div>
            <div class="flex items-center gap-3 mb-4">
              <div class="flex-shrink-0 w-12 h-12 flex items-center justify-center rounded-full bg-yellow-100 dark:bg-yellow-900/30">
                <.icon
                  name="hero-exclamation-triangle"
                  class="w-6 h-6 text-yellow-600 dark:text-yellow-400"
                />
              </div>

              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                {gettext("Different Unit Location Warning")}
              </h3>
            </div>

            <div class="mb-4 p-4 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg">
              <p class="text-sm text-yellow-800 dark:text-yellow-200 mb-3">
                <strong>{gettext("Warning:")}</strong>
                {gettext("You are trying to add an item from a different unit location.")}
              </p>

              <div class="space-y-2 text-sm">
                <div>
                  <span class="font-medium text-yellow-900 dark:text-yellow-100">
                    {gettext("Current units in loan:")}
                  </span>
                  <span class="ml-2 text-yellow-800 dark:text-yellow-200">
                    {@modal_data.existing_units}
                  </span>
                </div>

                <div>
                  <span class="font-medium text-yellow-900 dark:text-yellow-100">
                    {gettext("New item unit:")}
                  </span>
                  <span class="ml-2 text-yellow-800 dark:text-yellow-200">
                    {@modal_data.item.node.name}
                  </span>
                </div>
              </div>
            </div>

            <div class="mb-4 p-3 bg-gray-50 dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700">
              <p class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                {gettext("Item details:")}
              </p>

              <div class="space-y-1 text-sm text-gray-600 dark:text-gray-400">
                <div>
                  <span class="font-medium">{gettext("Item Code:")}</span>
                  <span class="ml-2">{@modal_data.item.item_code}</span>
                </div>

                <div>
                  <span class="font-medium">{gettext("Title:")}</span>
                  <span class="ml-2">{@modal_data.item.collection.title}</span>
                </div>
              </div>
            </div>

            <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
              {gettext(
                "Loaning items from different unit locations at the same time may complicate the collection process. Do you want to proceed anyway?"
              )}
            </p>

            <div class="flex gap-2 justify-end">
              <.button
                phx-click="cancel_add_different_unit"
                class="default-btn"
              >
                <.icon name="hero-x-mark" class="w-4 h-4 mr-1" /> Cancel
              </.button>
              <.button
                phx-click="confirm_add_different_unit"
                class="warning-btn"
              >
                <.icon name="hero-check" class="w-4 h-4 mr-1" /> {gettext("Proceed Anyway")}
              </.button>
            </div>
          </div>
        <% @show_modal == "finish_transaction" -> %>
          <div>
            <h3 class="text-lg font-semibold mb-4">{gettext("Finish Transaction")}</h3>

            <p class="mb-4">
              {gettext("Are you sure you want to complete this transaction? This will process:")}
            </p>

            <ul class="list-disc list-inside mb-4 space-y-1">
              <li>{gettext("%{count} loan(s)", count: length(@temp_loans))}</li>

              <li>{gettext("%{count} reservation(s)", count: length(@temp_reservations))}</li>
            </ul>

            <div class="flex gap-2 justify-end">
              <.button phx-click="close_modal" class="cancel-btn">Cancel</.button>
              <.button
                phx-click="finish_transaction"
                class="success-btn"
              >
                {gettext("Confirm & Finish")}
              </.button>
            </div>
          </div>
        <% true -> %>
          <div>{gettext("Unknown modal")}</div>
      <% end %>
    </.modal>
    """
  end
end
