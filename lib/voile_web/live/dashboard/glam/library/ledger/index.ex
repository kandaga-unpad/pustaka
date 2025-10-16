defmodule VoileWeb.Dashboard.Glam.Library.Ledger.Index do
  use VoileWeb, :live_view_dashboard

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.breadcrumb items={[
      %{label: "Manage", path: ~p"/manage"},
      %{label: "GLAM", path: ~p"/manage/glam"},
      %{label: "Library", path: ~p"/manage/glam/library"},
      %{label: "Ledgers", path: nil}
    ]} />
    <div class="sm:flex sm:items-center sm:justify-between mb-6">
      <.back navigate="/manage/glam/library">Back</.back>
      
      <div class="text-center">
        <h1 class="text-2xl font-bold">Start Library Transactions</h1>
        
        <p class="mt-2 text-sm text-gray-700">Start and verify the transactions of the collections</p>
      </div>
    </div>

    <div></div>
    """
  end
end
