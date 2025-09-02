defmodule VoileWeb.PageLive.Home do
  use VoileWeb, :live_view

  alias Voile.Search.Collections, as: SearchCollections
  alias VoileWeb.VoileComponents

  @impl true
  def mount(params, _session, socket) do
    search_query = Map.get(params, "q", "")
    current_glam_type = Map.get(params, "glam_type", "quick")

    socket =
      socket
      |> assign(:search_query, search_query)
      |> assign(:current_glam_type, current_glam_type)
      |> assign(:search_results, [])
      |> assign(:show_suggestions, false)
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    search_query = Map.get(params, "q", "")
    current_glam_type = Map.get(params, "glam_type", "quick")

    socket =
      socket
      |> assign(:search_query, search_query)
      |> assign(:current_glam_type, current_glam_type)

    {:noreply, socket}
  end

  @impl true
  def handle_event("search_change", %{"q" => query, "glam_type" => glam_type}, socket) do
    updated_socket =
      socket
      |> assign(:search_query, query)
      |> assign(:current_glam_type, glam_type)
      |> assign(:loading, true)

    # Debounced search for suggestions
    final_socket =
      if String.length(query) >= 2 do
        send(self(), {:perform_search_suggestions, query, glam_type})
        updated_socket
      else
        assign(updated_socket, :search_results, [])
      end

    final_socket = assign(final_socket, :loading, false)
    {:noreply, final_socket}
  end

  @impl true
  def handle_event("search", %{"q" => query, "glam_type" => glam_type}, socket) do
    # Redirect to search results page
    {:noreply,
     socket
     |> push_navigate(to: "/search?q=#{URI.encode(query)}&glam_type=#{glam_type}")}
  end

  @impl true
  def handle_event("show_suggestions", _params, socket) do
    query = socket.assigns.search_query

    if String.length(query) >= 2 do
      send(self(), {:perform_search_suggestions, query, socket.assigns.current_glam_type})
    end

    {:noreply, assign(socket, :show_suggestions, true)}
  end

  @impl true
  def handle_event("hide_suggestions", _params, socket) do
    # Add a small delay to allow for click events on suggestions
    Process.send_after(self(), :hide_suggestions_delayed, 200)
    {:noreply, socket}
  end

  @impl true
  def handle_event("perform_search", %{"query" => query, "glam_type" => glam_type}, socket) do
    {:noreply,
     socket
     |> push_navigate(to: "/search?q=#{URI.encode(query)}&glam_type=#{glam_type}")}
  end

  @impl true
  def handle_event("select_collection", %{"id" => collection_id}, socket) do
    {:noreply,
     socket
     |> push_navigate(to: "/collections/#{collection_id}")}
  end

  @impl true
  def handle_info({:perform_search_suggestions, query, glam_type}, socket) do
    # Only search if the query is still current (user hasn't typed something else)
    if query == socket.assigns.search_query do
      socket = assign(socket, :loading, true)

      # Simulate search - replace this with actual search logic
      search_results = perform_search_suggestions(query, glam_type)

      socket =
        socket
        |> assign(:search_results, search_results)
        |> assign(:loading, false)
        |> assign(:show_suggestions, true)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:hide_suggestions_delayed, socket) do
    {:noreply, assign(socket, :show_suggestions, false)}
  end

  # Real search function using the Search context
  defp perform_search_suggestions(query, glam_type) do
    try do
      SearchCollections.get_search_suggestions(query, glam_type, 8)
    rescue
      _ ->
        # Fallback to empty results if there's an error
        []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.modal id="advanced-search">
      <h5>Pencarian Lanjutan</h5>
      
      <div><.input type="text" name="keyword" value="" label="Keyword" /></div>
    </.modal>

    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]}>
      <section class="relative">
        <div>
          <img
            src="/images/default_bg.webp"
            class="absolute w-full h-[600px] md:max-h-[600px] object-cover"
            alt="Cover Background"
          />
        </div>
        
        <div class="relative bg-white/50 dark:bg-gray-800/50 h-[600px] w-full">
          <div class="max-w-7xl mx-auto flex flex-col gap-3">
            <div class="flex flex-col items-center justify-center gap-3 pb-16 pt-4 relative z-5 bg-white/80 dark:bg-gray-800/80 rounded-b-xl">
              <img src="/images/v.png" alt="" class="h-full w-32" />
              <h5 class="text-center">Voile, the Magic Library</h5>
              
              <p class="max-w-3xl mx-auto text-center text-sm">
                Voile is your gateway to a world of cultural treasures. Imagine stepping into a digital sanctuary where libraries, museums, and archives converge into one intuitive space. Whether you're seeking your next great read, exploring rare artworks, or diving into historical archives, Voile offers a beautifully curated collection at your fingertips. Simply browse through diverse collections, uncover hidden gems, and let your curiosity lead you on a journey of discovery. With Voile, every click opens a door to inspiration and learning in an inviting, user-friendly environment.
              </p>
            </div>
            
            <div class="max-w-5xl mx-auto flex flex-col w-full gap-4">
              <div class="w-full flex flex-col gap-2">
                <VoileComponents.main_search
                  current_glam_type={@current_glam_type}
                  search_query={@search_query}
                  live_action={@live_action}
                  search_results={@search_results}
                  show_suggestions={@show_suggestions}
                  loading={@loading}
                />
                <div class="flex gap-2">
                  <.link navigate="/collections" class="w-full">
                    <.button class="w-full dashboard-menu-btn">Semua Koleksi</.button>
                  </.link>
                  <.button class="w-full default-btn" phx-click={show_modal("advanced-search")}>
                    Pencarian Lanjutan
                  </.button>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <section class="max-w-5xl mx-auto pt-10">
          <h1 class="text-center">Voile</h1>
          
          <p class="text-justify">
            Lorem ipsum dolor, sit amet consectetur adipisicing elit. Esse iusto qui
            possimus? Explicabo vitae doloremque et atque, reiciendis possimus,
            debitis, optio velit laborum eius facere earum unde nesciunt eligendi amet
            odit? Suscipit, veniam doloremque. Quam quas voluptates reprehenderit
            consectetur dolorum amet rerum in, repellendus consequatur repudiandae
            odio minima sint dicta incidunt quod enim sit temporibus nostrum quaerat
            aut delectus possimus quos! Neque minus optio laboriosam sed ipsa est odio
            facere, accusamus ea eaque aliquid error quia culpa! Quibusdam in, ullam
            labore cupiditate sapiente suscipit nesciunt dolore nam veniam quidem
            quaerat fugit pariatur asperiores autem excepturi voluptas dolorem,
            voluptatibus aut neque, molestias ratione adipisci beatae! Saepe suscipit
            perspiciatis et, a labore ea minima provident atque optio maiores, placeat
            velit, reiciendis eaque corrupti nesciunt molestias amet dicta qui
            excepturi quisquam porro. Itaque dolorum quas commodi unde omnis impedit
            aliquam ipsa praesentium dolores possimus consequatur cumque dolor amet,
            quibusdam ipsam doloremque officia quasi. Dolorum ad voluptatem, animi
            voluptatibus explicabo cumque veniam adipisci, hic ullam ipsa rem
            necessitatibus quisquam aut soluta magnam, eos quidem excepturi minima
            cupiditate. Repellendus neque tenetur ullam perferendis modi, architecto,
            rerum optio consequatur iusto alias quaerat voluptatem provident odio
            numquam odit eum quam ad qui nobis sequi repellat iure exercitationem
            accusantium cum? Ad nostrum veniam aspernatur fuga quasi, exercitationem
            laudantium corporis nesciunt dignissimos nam expedita libero, placeat qui?
            Assumenda, eum delectus. Quasi delectus, eos consectetur qui et quam modi
            iusto tempora dignissimos perferendis temporibus, ab iure? Saepe itaque
            eum tenetur laboriosam voluptatum quis reprehenderit deserunt perspiciatis
            suscipit? Natus, excepturi voluptas perferendis cupiditate velit quae a
            rem sapiente voluptatem illo cum facere similique? Natus corrupti autem
            nemo porro in, laudantium repellat asperiores cum sequi reprehenderit
            voluptas velit eaque laborum accusamus incidunt, non minus nesciunt magnam
            tenetur nam dolore totam, rerum ullam! Alias, culpa nemo? Temporibus unde
            totam laudantium voluptatem commodi, quisquam eveniet, eaque dolore nisi
            nihil inventore quasi doloribus. Nulla perferendis maxime temporibus magni
            pariatur, sequi fugit aliquam commodi provident autem incidunt, accusamus
            enim at eaque consectetur. Quisquam esse consectetur ab doloremque!
            Distinctio reiciendis voluptatibus similique! Quasi ipsa voluptate
            laboriosam optio repellat animi veniam dolorum deleniti ea molestias
            debitis, impedit nemo corporis vitae iure, illo odio et soluta. Officia
            omnis enim culpa tenetur possimus nihil vero reiciendis iusto obcaecati at
            illum, eaque est earum a assumenda labore. Debitis aspernatur doloribus,
            ab quas quae atque vero veniam tempora provident minima expedita
            voluptatibus! Illum impedit aut pariatur. Sequi cum harum error eum
            reiciendis quaerat doloribus soluta perspiciatis vel voluptatum et
            incidunt commodi qui amet quisquam maiores debitis, repellat laborum.
            Quibusdam quia accusamus culpa aut reiciendis atque blanditiis, ut
            nesciunt temporibus modi veritatis dolorum consequuntur quasi laboriosam
            neque? Consequatur eos ea ratione facilis quam pariatur, excepturi autem
            et laudantium dolor possimus dolores harum sequi voluptatibus, ab non?
            Optio molestias qui dolorum aspernatur soluta repellat facilis voluptatem
            corrupti saepe in, debitis numquam veniam. Officiis iusto labore dolore ad
            adipisci? Aut, minima omnis dolores vero tenetur quis blanditiis
            asperiores cumque quasi sequi itaque incidunt veniam nihil ea dolor cum
            odit exercitationem dolorem voluptas. Esse, rem sapiente!
          </p>
        </section>
      </section>
    </Layouts.app>
    """
  end
end
