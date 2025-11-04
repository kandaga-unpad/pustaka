defmodule VoileWeb.Frontend.Atrium.FineDetail.Show do
  use VoileWeb, :live_view

  alias Voile.Schema.Library.Circulation

  @impl true
  def mount(%{"id" => fine_id}, _session, socket) do
    member = socket.assigns.current_scope.user

    case Circulation.get_fine_with_details(fine_id) do
      {:ok, fine} ->
        # Ensure the fine belongs to the current member
        if fine.member_id == member.id do
          {:ok, assign(socket, fine: fine, page_title: "Fine Details")}
        else
          {:ok,
           socket
           |> put_flash(:error, "You don't have permission to view this fine.")
           |> push_navigate(to: ~p"/atrium")}
        end

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Fine not found.")
         |> push_navigate(to: ~p"/atrium")}
    end
  end

  @impl true
  def handle_event("go_back", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/atrium")}
  end
end
