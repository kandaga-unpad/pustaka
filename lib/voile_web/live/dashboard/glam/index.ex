defmodule VoileWeb.Dashboard.Glam.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Dashboard.Stats
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    is_super_admin = Authorization.is_super_admin?(user)

    socket =
      socket
      |> assign(:page_title, gettext("GLAM Dashboard"))
      |> assign(:breadcrumb, [
        %{label: gettext("Manage"), path: "/manage"},
        %{label: gettext("GLAM"), path: nil}
      ])
      |> assign(:user, user)
      |> assign(:is_super_admin, is_super_admin)

    socket =
      if is_super_admin do
        nodes = Voile.Schema.System.list_nodes()

        socket |> assign(:nodes, nodes) |> assign(:selected_node_id, nil)
      else
        socket |> assign(:nodes, []) |> assign(:selected_node_id, user.node_id)
      end

    # compute initial stats scoped by user/node and recent collections
    socket =
      socket
      |> assign(:glam_stats, Stats.get_glam_statistics(user))
      |> assign(:recent_feed_items, build_recent_feed(Stats.list_recent_collections(5, user)))
      |> assign(:visitor_stats, load_visitor_stats(user))

    {:ok, socket}
  end

  @impl true
  def handle_event("select_node", %{"node_id" => node_id_str}, socket) do
    node_id =
      case node_id_str do
        nil -> nil
        "all" -> nil
        "" -> nil
        id -> String.to_integer(id)
      end

    socket = assign(socket, :selected_node_id, node_id)

    # Determine user context for stats (override node for super_admin when a node is selected)
    user = socket.assigns.user

    user_for_stats =
      if Authorization.is_super_admin?(user) and not is_nil(node_id) do
        Map.put(user, :node_id, node_id)
      else
        user
      end

    socket =
      socket
      |> assign(:glam_stats, Stats.get_glam_statistics(user_for_stats))
      |> assign(
        :recent_feed_items,
        build_recent_feed(Stats.list_recent_collections(5, user_for_stats))
      )
      |> assign(:visitor_stats, load_visitor_stats(user_for_stats))

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.voile_page_header
      eyebrow={gettext("GLAM · Overview")}
      title={gettext("GLAM Management Dashboard")}
      description={gettext("Gallery, Library, Archive & Museum — unified collections management")}
      icon="hero-building-library"
      tone={:brand}
    >
      <:actions>
        <%= if @is_super_admin do %>
          <form phx-change="select_node" class="voile-chip">
            <.icon name="hero-map-pin" class="w-4 h-4 text-tertiary" />
            <select
              name="node_id"
              class="bg-transparent text-sm text-primary outline-none cursor-pointer"
            >
              <option value="all">
                {gettext("All Nodes")}
              </option>
              <%= for node <- @nodes || [] do %>
                <option value={node.id} selected={@selected_node_id == node.id}>
                  {node.name}
                </option>
              <% end %>
            </select>
          </form>
        <% end %>
      </:actions>
    </.voile_page_header>

    <.voile_glam_strip stats={@glam_stats} />

    <.voile_section_card
      title={gettext("Visitor statistics")}
      icon="hero-chart-bar"
      tone={:info}
      action_label={gettext("Details")}
      action_path="/manage/visitor/statistics"
      class="mb-6"
    >
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div>
          <p class="t-label text-tertiary">{gettext("Visitors today")}</p>
          <p class="t-stat text-primary text-3xl">{@visitor_stats.today}</p>
        </div>
        <div>
          <p class="t-label text-tertiary">{gettext("Visitors (30 days)")}</p>
          <p class="t-stat text-primary text-3xl">{@visitor_stats.total_30d}</p>
        </div>
        <div>
          <p class="t-label text-tertiary">{gettext("Unique (30 days)")}</p>
          <p class="t-stat text-primary text-3xl">{@visitor_stats.unique_30d}</p>
        </div>
        <div>
          <p class="t-label text-tertiary">{gettext("Avg / day (30 days)")}</p>
          <p class="t-stat text-primary text-3xl">{@visitor_stats.avg_per_day}</p>
        </div>
      </div>
    </.voile_section_card>

    <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3 md:gap-4 mb-6">
      <.voile_stat_card
        label={gettext("Total collections")}
        value={@glam_stats.total_collections}
        icon="hero-rectangle-stack"
        tone={:info}
      />
      <.voile_stat_card
        label={gettext("Total items")}
        value={@glam_stats.total_items}
        icon="hero-cube"
        tone={:success}
      />
      <.voile_stat_card
        label={gettext("Nodes")}
        value={@glam_stats.total_nodes}
        icon="hero-map-pin"
        tone={:brand}
      />
      <.voile_stat_card
        label={gettext("Resource classes")}
        value={@glam_stats.resource_classes}
        icon="hero-tag"
        tone={:warning}
      />
    </div>

    <.voile_section_card
      title={gettext("Recent collections")}
      icon="hero-clock"
      tone={:brand}
      action_label={gettext("View all")}
      action_path="/manage/catalog/collections"
    >
      <.voile_activity_feed
        items={@recent_feed_items}
        empty_text={gettext("No collections yet.")}
      />
    </.voile_section_card>
    """
  end

  defp build_recent_feed(collections) do
    Enum.map(collections, &collection_to_feed_item/1)
  end

  defp load_visitor_stats(user) do
    node_id = user.node_id
    now = DateTime.utc_now()

    start_of_today =
      Date.utc_today() |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    start_30d = DateTime.add(now, -30, :day)

    today =
      Voile.Schema.System.get_visitor_statistics(
        from_date: start_of_today,
        to_date: now,
        node_id: node_id
      )

    last_30d =
      Voile.Schema.System.get_visitor_statistics(
        from_date: start_30d,
        to_date: now,
        node_id: node_id
      )

    %{
      today: today.total_visitors,
      total_30d: last_30d.total_visitors,
      unique_30d: last_30d.unique_visitors,
      avg_per_day: if(last_30d.total_visitors > 0, do: div(last_30d.total_visitors, 30), else: 0)
    }
  end

  defp collection_to_feed_item(collection) do
    glam_type =
      collection.resource_class && collection.resource_class.glam_type

    %{
      icon: glam_icon(glam_type),
      tone: glam_tone(glam_type),
      title: collection.title || gettext("Untitled collection"),
      subtitle:
        (collection.mst_creator && collection.mst_creator.creator_name) ||
          glam_label(glam_type),
      meta: format_date(collection.inserted_at),
      href: "/manage/catalog/collections/#{collection.id}"
    }
  end

  defp glam_icon("Gallery"), do: "hero-photo"
  defp glam_icon("Library"), do: "hero-book-open"
  defp glam_icon("Archive"), do: "hero-archive-box"
  defp glam_icon("Museum"), do: "hero-cube"
  defp glam_icon(_), do: "hero-rectangle-stack"

  defp glam_tone("Gallery"), do: :glam_gallery
  defp glam_tone("Library"), do: :glam_library
  defp glam_tone("Archive"), do: :glam_archive
  defp glam_tone("Museum"), do: :glam_museum
  defp glam_tone(_), do: :brand

  defp glam_label("Gallery"), do: gettext("Gallery")
  defp glam_label("Library"), do: gettext("Library")
  defp glam_label("Archive"), do: gettext("Archive")
  defp glam_label("Museum"), do: gettext("Museum")
  defp glam_label(_), do: gettext("Collection")

  defp format_date(nil), do: nil

  defp format_date(%DateTime{} = dt) do
    dt
    |> DateTime.to_date()
    |> Date.to_string()
  end

  defp format_date(%Date{} = d), do: Date.to_string(d)
  defp format_date(_), do: nil
end
