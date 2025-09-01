defmodule VoileWeb.Dashboard.Circulation.Transaction.Index do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Circulation.Helpers

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Library.Transaction

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    per_page = 15
    {transactions, total_pages} = Circulation.list_transactions_paginated(page, per_page)

    socket =
      socket
      |> stream(:transactions, transactions)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:search_query, "")
      |> assign(:filter_status, "all")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Library Transactions")
  end

  defp apply_action(socket, :checkout, _params) do
    socket
    |> assign(:page_title, "New Checkout")
    |> assign(:transaction, %Transaction{})
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
  def handle_event("checkout", %{"member_id" => member_id, "item_id" => item_id}, socket) do
    current_user_id = socket.assigns.current_user.id

    case Circulation.checkout_item(member_id, item_id, current_user_id) do
      {:ok, transaction} ->
        socket =
          socket
          |> stream_insert(:transactions, transaction, at: 0)
          |> put_flash(:info, "Item checked out successfully")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to checkout item: #{extract_error_message(changeset)}")

        {:noreply, socket}
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
    {transactions, total_pages} = Circulation.list_transactions_paginated(page, per_page)

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
end
