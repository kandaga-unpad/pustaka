defmodule VoileWeb.DashboardLive do
  use VoileWeb, :live_view_dashboard

  alias Voile.Analytics.SearchAnalytics

  def render(assigns) do
    ~H"""
    <.modal id="manage-btn">
      <h3>Hey There!</h3>

      <p class="text-justify">
        Lorem ipsum dolor sit amet consectetur, adipisicing elit. Sit praesentium voluptatum minus quibusdam enim fugit aperiam tempora. Voluptates facilis commodi pariatur! Tenetur qui similique nobis nulla, atque fugiat ratione id obcaecati autem asperiores illum unde, nostrum eos vel harum mollitia. Inventore consequatur quasi, ut culpa laudantium libero quod assumenda est!
      </p>
    </.modal>

    <section>
      <h6 class="text-center py-5">Manage your Collection with Voile</h6>
      <!-- Search Dashboard Section -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <.dashboard_search_widget /> <.search_stats_widget stats={@search_stats} />
      </div>
    </section>
    <.button class="default-btn" phx-click={show_modal("manage-btn")}>Click Me!</.button>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:search_stats, SearchAnalytics.get_search_stats())

    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end
end
