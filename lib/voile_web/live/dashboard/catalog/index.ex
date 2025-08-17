defmodule VoileWeb.Dashboard.Catalog.Index do
  use VoileWeb, :live_view_dashboard

  import VoileWeb.VoileDashboardComponents, only: [dashboard_menu_bar: 1]

  def render(assigns) do
    ~H"""
    <section class="flex flex-col gap-4">
      <div><.dashboard_menu_bar /></div>
      
      <div class="flex flex-col gap-4 p-4 rounded-lg shadow-md bg-white dark:bg-gray-700">
        <h1 class="text-2xl font-bold">Catalog</h1>
        
        <p>Manage your catalog items here.</p>
      </div>
    </section>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
