defmodule VoileWeb.Frontend.Atrium.Requisition.Index do
  use VoileWeb, :live_view
  use Gettext, backend: VoileWeb.Gettext

  alias Voile.Schema.Library.Circulation

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    page = 1
    per_page = 10

    {requisitions, total_pages, _total} =
      Circulation.list_member_requisitions_paginated(user.id, page, per_page)

    {:ok,
     assign(socket,
       requisitions: requisitions,
       page: page,
       total_pages: total_pages,
       page_title: gettext("My Requests")
     )}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    user = socket.assigns.current_scope.user
    page = max(socket.assigns.page - 1, 1)

    {requisitions, total_pages, _} =
      Circulation.list_member_requisitions_paginated(user.id, page)

    {:noreply, assign(socket, requisitions: requisitions, page: page, total_pages: total_pages)}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    user = socket.assigns.current_scope.user
    page = min(socket.assigns.page + 1, socket.assigns.total_pages)

    {requisitions, total_pages, _} =
      Circulation.list_member_requisitions_paginated(user.id, page)

    {:noreply, assign(socket, requisitions: requisitions, page: page, total_pages: total_pages)}
  end

  @impl true
  def handle_event("go_back", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/atrium")}
  end
end
