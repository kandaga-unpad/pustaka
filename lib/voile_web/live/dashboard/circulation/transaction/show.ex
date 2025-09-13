defmodule VoileWeb.Dashboard.Circulation.Transaction.Show do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Circulation.Helpers
  import VoileWeb.Dashboard.Circulation.Components

  alias Voile.Schema.Library.Circulation

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    transaction = Circulation.get_transaction!(id)

    socket =
      socket
      |> assign(:transaction, transaction)
      |> assign(:page_title, "Transaction Details")

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("return", %{"id" => id}, socket) do
    current_user_id = socket.assigns.current_user.id

    case Circulation.return_item(id, current_user_id) do
      {:ok, transaction} ->
        socket =
          socket
          |> assign(:transaction, transaction)
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

  defp extract_error_message(changeset) do
    changeset
    |> Map.get(:errors, [])
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end
end
