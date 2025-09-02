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
        <.dashboard_search_widget />
        <.search_stats_widget stats={@search_stats} />
      </div>

      <div class="grid grid-cols-2 gap-8">
        <div class="voile-card">
          <.icon name="hero-photo" class="w-32 h-32 voile-gradient" />
          <h5 class="text-violet-600">Gallery</h5>

          <p class="text-sm pt-4">
            Galleries can host a variety of exhibitions, ranging from contemporary art to historical pieces, and often include paintings, sculptures, photographs, and other visual media. They play a vital role in promoting cultural expression and fostering a deeper understanding of artistic practices and movements.
          </p>
        </div>

        <div class="voile-card">
          <.icon name="hero-book-open" class="w-32 h-32 voile-gradient" />
          <h5 class="text-violet-600">Library</h5>

          <p class="text-sm pt-4">
            A library is a collection of materials, such as books, periodicals, and other resources, that are organized for use by the public. Libraries serve as repositories of knowledge and information, providing access to a wide range of materials for research, study, and leisure.
          </p>
        </div>

        <div class="voile-card">
          <.icon name="hero-archive-box" class="w-32 h-32 voile-gradient" />
          <h5 class="text-violet-600">Archive</h5>

          <p class="text-sm pt-4">
            An archive is a collection of historical records, documents, and other materials that are preserved for research and reference purposes. Archives can include a wide range of materials, such as manuscripts, photographs, maps, and audiovisual recordings, and are often organized by subject, creator, or format.
          </p>
        </div>

        <div class="voile-card">
          <.icon name="hero-globe-asia-australia" class="w-32 h-32 voile-gradient" />
          <h5 class="text-violet-600">Museum</h5>

          <p class="text-sm pt-4">
            A museum is an institution that collects, preserves, and exhibits objects and artifacts of cultural, historical, or scientific significance. Museums can include a wide range of collections, such as art, natural history, science, and technology, and often feature exhibitions, programs, and events for the public.
          </p>
        </div>
      </div>
    </section>

    <.button class="default-btn" phx-click={show_modal("manage-btn")}>
      Click Me!
    </.button>
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
