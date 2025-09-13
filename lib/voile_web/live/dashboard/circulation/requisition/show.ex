defmodule VoileWeb.Dashboard.Circulation.Requisition.Show do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Circulation.Helpers
  import VoileWeb.Dashboard.Circulation.Components

  alias Voile.Schema.Library.Circulation

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    requisition = Circulation.get_requisition!(id)

    {:noreply,
     socket
     |> assign(:requisition, requisition)
     |> assign(:page_title, "Requisition Details")}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    requisition = Circulation.get_requisition!(id)

    case Circulation.approve_requisition(requisition) do
      {:ok, _requisition} ->
        {:noreply,
         socket
         |> put_flash(:info, "Requisition approved successfully.")
         |> push_navigate(to: ~p"/manage/circulation/requisitions/#{requisition.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("reject", %{"id" => id}, socket) do
    requisition = Circulation.get_requisition!(id)

    case Circulation.reject_requisition(requisition) do
      {:ok, _requisition} ->
        {:noreply,
         socket
         |> put_flash(:info, "Requisition rejected.")
         |> push_navigate(to: ~p"/manage/circulation/requisitions/#{requisition.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("fulfill", %{"id" => id}, socket) do
    requisition = Circulation.get_requisition!(id)

    case Circulation.fulfill_requisition(requisition) do
      {:ok, _requisition} ->
        {:noreply,
         socket
         |> put_flash(:info, "Requisition fulfilled successfully.")
         |> push_navigate(to: ~p"/manage/circulation/requisitions/#{requisition.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("cancel", %{"id" => id}, socket) do
    requisition = Circulation.get_requisition!(id)

    case Circulation.update_requisition(requisition, %{
           status: "cancelled",
           rejection_date: DateTime.utc_now()
         }) do
      {:ok, _requisition} ->
        {:noreply,
         socket
         |> put_flash(:info, "Requisition cancelled.")
         |> push_navigate(to: ~p"/manage/circulation/requisitions/#{requisition.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  # Import helper functions
  # defdelegate status_badge_class(status), to: VoileWeb.Dashboard.Circulation.Helpers
  # defdelegate priority_badge_class(priority), to: VoileWeb.Dashboard.Circulation.Helpers
  # defdelegate format_datetime(datetime), to: VoileWeb.Dashboard.Circulation.Helpers

  # Local helper functions that aren't in the shared helpers
  def priority_badge_class("high"), do: "bg-red-100 text-red-800"
  def priority_badge_class("urgent"), do: "bg-red-200 text-red-900"
  def priority_badge_class("normal"), do: "bg-blue-100 text-blue-800"
  def priority_badge_class("low"), do: "bg-gray-100 text-gray-800"
  def priority_badge_class("book_request"), do: "bg-purple-100 text-purple-800"
  def priority_badge_class("interlibrary_loan"), do: "bg-indigo-100 text-indigo-800"
  def priority_badge_class("equipment_request"), do: "bg-green-100 text-green-800"
  def priority_badge_class(_), do: "bg-gray-100 text-gray-800"
end
