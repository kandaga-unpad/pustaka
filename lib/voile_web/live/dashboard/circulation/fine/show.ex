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

    {:noreply,
     socket
     |> assign(:fine, fine)
     |> assign(:page_title, "Fine Details")}
  end

  @impl true
  def handle_event("pay", %{"id" => id}, socket) do
    fine = Circulation.get_fine!(id)
    current_user_id = socket.assigns.current_user.id

    case Circulation.pay_fine(fine, fine.amount, "cash", current_user_id) do
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
    current_user_id = socket.assigns.current_user.id

    case Circulation.waive_fine(fine, "Waived by librarian", current_user_id) do
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
    current_user_id = socket.assigns.current_user.id

    case Circulation.pay_fine(fine, Decimal.new(amount), "cash", current_user_id, true) do
      {:ok, _fine} ->
        {:noreply,
         socket
         |> put_flash(:info, "Partial payment recorded successfully.")
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
