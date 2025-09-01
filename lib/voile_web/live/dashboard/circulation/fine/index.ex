defmodule VoileWeb.Dashboard.Circulation.Fine.Index do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Circulation.Helpers

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Library.Fine

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    per_page = 15
    {fines, total_pages} = Circulation.list_fines_paginated(page, per_page)

    socket =
      socket
      |> stream(:fines, fines)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:filter_status, "all")
      |> assign(:filter_type, "all")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Library Fines")
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Fine")
    |> assign(:fine, %Fine{})
  end

  defp apply_action(socket, :payment, %{"id" => id}) do
    fine = Circulation.get_fine!(id)

    socket
    |> assign(:page_title, "Process Payment")
    |> assign(:fine, fine)
  end

  defp apply_action(socket, :waive, %{"id" => id}) do
    fine = Circulation.get_fine!(id)

    socket
    |> assign(:page_title, "Waive Fine")
    |> assign(:fine, fine)
  end

  @impl true
  def handle_event("create_fine", params, socket) do
    case Circulation.create_fine(params) do
      {:ok, fine} ->
        socket =
          socket
          |> stream_insert(:fines, fine, at: 0)
          |> put_flash(:info, "Fine created successfully")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to create fine: #{extract_error_message(changeset)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "process_payment",
        %{"id" => id, "amount" => amount, "method" => method},
        socket
      ) do
    fine = Circulation.get_fine!(id)
    current_user_id = socket.assigns.current_user.id

    payment_attrs = %{
      paid_amount: Decimal.new(amount),
      payment_method: method,
      payment_date: DateTime.utc_now(),
      processed_by_id: current_user_id,
      fine_status: determine_status_after_payment(fine, Decimal.new(amount))
    }

    case Circulation.update_fine(fine, payment_attrs) do
      {:ok, updated_fine} ->
        socket =
          socket
          |> stream_insert(:fines, updated_fine)
          |> put_flash(:info, "Payment processed successfully")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to process payment: #{extract_error_message(changeset)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("waive_fine", %{"id" => id, "reason" => reason}, socket) do
    fine = Circulation.get_fine!(id)
    current_user_id = socket.assigns.current_user.id

    waive_attrs = %{
      waived: true,
      waived_date: DateTime.utc_now(),
      waived_reason: reason,
      waived_by_id: current_user_id,
      fine_status: "waived"
    }

    case Circulation.update_fine(fine, waive_attrs) do
      {:ok, updated_fine} ->
        socket =
          socket
          |> stream_insert(:fines, updated_fine)
          |> put_flash(:info, "Fine waived successfully")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to waive fine: #{extract_error_message(changeset)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter", %{"status" => status, "type" => type}, socket) do
    socket =
      socket
      |> assign(:filter_status, status)
      |> assign(:filter_type, type)
      |> reload_fines()

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 15

    {fines, total_pages} = Circulation.list_fines_paginated(page, per_page)

    socket =
      socket
      |> stream(:fines, fines, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end

  defp reload_fines(socket) do
    page = 1
    per_page = 15
    {fines, total_pages} = Circulation.list_fines_paginated(page, per_page)

    socket
    |> stream(:fines, fines, reset: true)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
  end

  defp determine_status_after_payment(fine, payment_amount) do
    total_paid = Decimal.add(fine.paid_amount || Decimal.new(0), payment_amount)

    case Decimal.compare(total_paid, fine.amount) do
      :eq -> "paid"
      :gt -> "paid"
      :lt -> "partial_paid"
    end
  end

  defp extract_error_message(changeset) do
    changeset
    |> Map.get(:errors, [])
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end
end
