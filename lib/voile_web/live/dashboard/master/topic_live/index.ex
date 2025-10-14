defmodule VoileWeb.Dashboard.Master.TopicLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias Voile.Schema.Master.Topic

  @impl true
  def mount(_params, _session, socket) do
    # Check permission for managing metadata/master data
    authorize!(socket, "metadata.manage")

    page = 1
    per_page = 10
    {topics, total_pages} = Master.list_mst_topics_paginated(page, per_page)

    socket =
      socket
      |> assign(:page_title, "Listing Topics")
      |> assign(:live_action, :index)
      |> assign(:topics, topics)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Topic")
    |> assign(:topic, Master.get_topic!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Topic")
    |> assign(:topic, %Topic{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Topics")
    |> assign(:topic, nil)
  end

  @impl true
  def handle_info({VoileWeb.Dashboard.Master.TopicLive.FormComponent, {:saved, topic}}, socket) do
    {:noreply, stream_insert(socket, :topics, topic)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    topic = Master.get_topic!(id)
    {:ok, _} = Master.delete_topic(topic)

    {:noreply, stream_delete(socket, :topics, topic)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 10
    {topics, total_pages} = Master.list_mst_topics_paginated(page, per_page)

    socket =
      socket
      |> assign(:topics, topics)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end
end
