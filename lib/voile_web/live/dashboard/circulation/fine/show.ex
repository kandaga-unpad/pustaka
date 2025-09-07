defmodule VoileWeb.Dashboard.Circulation.Fine.Show do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Circulation.Helpers

  alias Voile.Schema.Library.Circulation

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    fine = Circulation.get_fine!(id)

    socket =
      socket
      |> assign(:fine, fine)
      |> assign(:page_title, "Fine Details")

    case socket.assigns.live_action do
      action when action in [:payment, :waive] ->
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("pay", %{"id" => id}, socket) do
    fine = Circulation.get_fine!(id)
    current_user_id = socket.assigns.current_scope.user.id

    case Circulation.pay_fine(fine.id, fine.amount, "cash", current_user_id) do
      {:ok, _fine} ->
        {:noreply,
         socket
         |> put_flash(:info, "Fine payment recorded successfully.")
         |> push_navigate(to: ~p"/manage/circulation/fines/#{fine.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("waive", %{"id" => id}, socket) do
    fine = Circulation.get_fine!(id)
    current_user_id = socket.assigns.current_scope.user.id

    case Circulation.waive_fine(fine.id, "Waived by librarian", current_user_id) do
      {:ok, _fine} ->
        {:noreply,
         socket
         |> put_flash(:info, "Fine waived successfully.")
         |> push_navigate(to: ~p"/manage/circulation/fines/#{fine.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("partial_pay", %{"_id" => id, "amount" => amount}, socket) do
    fine = Circulation.get_fine!(id)
    current_user_id = socket.assigns.current_scope.user.id

    case Circulation.pay_fine(fine.id, Decimal.new(amount), "cash", current_user_id) do
      {:ok, _fine} ->
        {:noreply,
         socket
         |> put_flash(:info, "Partial payment recorded successfully.")
         |> push_navigate(to: ~p"/manage/circulation/fines/#{fine.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        dbg(changeset.errors)
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event(
        "process_payment",
        %{"id" => id, "amount" => amount, "method" => method},
        socket
      ) do
    fine = Circulation.get_fine!(id)
    current_user_id = socket.assigns.current_scope.user.id

    case Circulation.pay_fine(fine.id, Decimal.new(amount), method, current_user_id) do
      {:ok, _fine} ->
        {:noreply,
         socket
         |> put_flash(:info, "Payment processed successfully.")
         |> push_navigate(to: ~p"/manage/circulation/fines/#{fine.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("waive_fine", %{"id" => id, "reason" => reason}, socket) do
    fine = Circulation.get_fine!(id)
    current_user_id = socket.assigns.current_scope.user.id

    case Circulation.waive_fine(fine.id, reason, current_user_id) do
      {:ok, _fine} ->
        {:noreply,
         socket
         |> put_flash(:info, "Fine waived successfully.")
         |> push_navigate(to: ~p"/manage/circulation/fines/#{fine.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  # Import helper functions
  # defdelegate status_badge_class(status), to: VoileWeb.Dashboard.Circulation.Helpers
  # defdelegate format_datetime(datetime), to: VoileWeb.Dashboard.Circulation.Helpers

  # Helper functions for fine calculations

  def calculate_balance(fine) do
    total_amount = fine.amount || Decimal.new(0)
    paid_amount = fine.paid_amount || Decimal.new(0)
    Decimal.sub(total_amount, paid_amount)
  end

  def format_currency(amount) do
    format_idr(amount)
  end
end
