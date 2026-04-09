defmodule VoileWeb.Dashboard.Glam.Library.Requisition.Show do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Glam.Library.Circulation.Helpers

  alias Voile.Schema.Library.Circulation
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(_params, _session, socket) do
    unless Authorization.can?(socket, "circulation.view_transactions") do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to view requisition details")
        |> push_navigate(to: ~p"/manage/glam/library")

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    requisition = Circulation.get_requisition!(id)

    {:noreply,
     socket
     |> assign(:requisition, requisition)
     |> assign(:page_title, "Requisition: #{requisition.title}")}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    case Circulation.approve_requisition(id) do
      {:ok, requisition} ->
        {:noreply,
         socket
         |> assign(:requisition, Circulation.get_requisition!(requisition.id))
         |> put_flash(:info, "Requisition approved.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to approve requisition.")}
    end
  end

  @impl true
  def handle_event("reject", %{"id" => id}, socket) do
    case Circulation.reject_requisition(id) do
      {:ok, requisition} ->
        {:noreply,
         socket
         |> assign(:requisition, Circulation.get_requisition!(requisition.id))
         |> put_flash(:info, "Requisition rejected.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reject requisition.")}
    end
  end

  @impl true
  def handle_event("fulfill", %{"id" => id}, socket) do
    requisition = Circulation.get_requisition!(id)

    case Circulation.update_requisition(requisition, %{
           status: "fulfilled",
           fulfilled_date: DateTime.utc_now()
         }) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:requisition, Circulation.get_requisition!(updated.id))
         |> put_flash(:info, "Requisition fulfilled.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to fulfill requisition.")}
    end
  end

  @impl true
  def handle_event("cancel", %{"id" => id}, socket) do
    requisition = Circulation.get_requisition!(id)

    case Circulation.update_requisition(requisition, %{status: "cancelled"}) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:requisition, Circulation.get_requisition!(updated.id))
         |> put_flash(:info, "Requisition cancelled.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel requisition.")}
    end
  end

  @impl true
  def handle_event("set_reviewing", %{"id" => id}, socket) do
    requisition = Circulation.get_requisition!(id)

    case Circulation.update_requisition(requisition, %{status: "reviewing"}) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:requisition, Circulation.get_requisition!(updated.id))
         |> put_flash(:info, "Requisition is now under review.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update status.")}
    end
  end
end
