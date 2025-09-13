defmodule VoileWeb.Dashboard.Circulation.Transaction.Index do
  alias Voile.Schema.Accounts
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Circulation.Helpers
  import VoileWeb.Dashboard.Circulation.Components

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
      |> assign(:count_active_collection, count_active_collection)
      |> assign(:count_overdue_collection, count_overdue_collection)
      |> assign(:count_returned_collection, count_returned_collection)

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
            librarian = socket.assigns.current_scope.user.id

            case Circulation.checkout_item(member.id, item_id, librarian) do
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
    current_user_id = socket.assigns.current_user.id

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
  def handle_event("renew", %{"id" => id}, socket) do
    current_user_id = socket.assigns.current_user.id

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
