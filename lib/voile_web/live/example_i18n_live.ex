defmodule VoileWeb.ExampleI18nLive do
  @moduledoc """
  Example LiveView demonstrating i18n usage.

  This is a reference implementation showing how to use translations
  throughout your LiveViews and components.
  """
  use VoileWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Dashboard"))
     |> assign(:products, list_example_products())
     |> assign(:selected_count, 0)}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <!-- Page Header with Locale Switcher -->
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-3xl font-bold">{gettext("Dashboard")}</h1>
        <.locale_switcher current_path={~p"/"} />
      </div>
      <!-- Welcome Message with Variable -->
      <div class="alert alert-info mb-6">
        <.icon name="hero-information-circle" class="w-6 h-6" />
        <span>{gettext("Welcome, %{name}!", name: "User")}</span>
      </div>
      <!-- Action Buttons -->
      <div class="flex gap-2 mb-6">
        <button class="btn btn-primary" phx-click="create">
          <.icon name="hero-plus" class="w-5 h-5" /> {gettext("Create")}
        </button>
        <button class="btn btn-secondary" phx-click="export">
          <.icon name="hero-arrow-down-tray" class="w-5 h-5" /> {gettext("Export")}
        </button>
        <button class="btn btn-ghost" phx-click="refresh">
          <.icon name="hero-arrow-path" class="w-5 h-5" /> {gettext("Refresh")}
        </button>
      </div>
      <!-- Data Table -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">{gettext("Products")}</h2>

          <%= if @products == [] do %>
            <!-- Empty State -->
            <div class="text-center py-8">
              <.icon name="hero-inbox" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
              <p class="text-gray-500">{gettext("No data available")}</p>
            </div>
          <% else %>
            <!-- Products Table -->
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>{gettext("Name")}</th>

                    <th>{gettext("Status")}</th>

                    <th>{gettext("Date")}</th>

                    <th>{gettext("Actions")}</th>
                  </tr>
                </thead>

                <tbody>
                  <tr :for={product <- @products}>
                    <td>{product.name}</td>

                    <td><span class="badge badge-success">{gettext("Active")}</span></td>

                    <td>{product.date}</td>

                    <td>
                      <div class="flex gap-2">
                        <button
                          class="btn btn-sm btn-ghost"
                          phx-click="view"
                          phx-value-id={product.id}
                          title={gettext("View")}
                        >
                          <.icon name="hero-eye" class="w-4 h-4" />
                        </button>
                        <button
                          class="btn btn-sm btn-ghost"
                          phx-click="edit"
                          phx-value-id={product.id}
                          title={gettext("Edit")}
                        >
                          <.icon name="hero-pencil" class="w-4 h-4" />
                        </button>
                        <button
                          class="btn btn-sm btn-error btn-ghost"
                          phx-click="delete"
                          phx-value-id={product.id}
                          title={gettext("Delete")}
                          data-confirm={gettext("Are you sure?")}
                        >
                          <.icon name="hero-trash" class="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <!-- Pagination Info -->
            <div class="text-sm text-gray-500 mt-4">
              {gettext("Showing %{start} to %{end} of %{total} entries",
                start: 1,
                end: length(@products),
                total: length(@products)
              )}
            </div>
          <% end %>
        </div>
      </div>
      <!-- Info Cards with Statistics -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-6">
        <div class="stat bg-base-100 shadow">
          <div class="stat-title">{gettext("Total")}</div>

          <div class="stat-value">{length(@products)}</div>

          <div class="stat-desc">{gettext("Total items")}</div>
        </div>

        <div class="stat bg-base-100 shadow">
          <div class="stat-title">{gettext("Status")}</div>

          <div class="stat-value text-success">{gettext("Active")}</div>

          <div class="stat-desc">{gettext("All systems operational")}</div>
        </div>

        <div class="stat bg-base-100 shadow">
          <div class="stat-title">{gettext("Date")}</div>

          <div class="stat-value text-sm">{gettext("Today")}</div>

          <div class="stat-desc">{Date.utc_today()}</div>
        </div>
      </div>
    </div>
    """
  end

  # Event handlers with translated flash messages
  def handle_event("create", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, gettext("Successfully created"))}
  end

  def handle_event("export", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, gettext("Export started"))}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply,
     socket
     |> assign(:products, list_example_products())
     |> put_flash(:info, gettext("Data refreshed"))}
  end

  def handle_event("view", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, gettext("Viewing item %{id}", id: id))}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, gettext("Editing item %{id}", id: id))}
  end

  def handle_event("delete", %{"id" => _id}, socket) do
    # In a real app, you would delete from the database
    {:noreply,
     socket
     |> put_flash(:info, gettext("Successfully deleted"))}
  end

  # Helper function for example data
  defp list_example_products do
    [
      %{id: 1, name: "Product A", date: "2024-01-15"},
      %{id: 2, name: "Product B", date: "2024-01-16"},
      %{id: 3, name: "Product C", date: "2024-01-17"}
    ]
  end
end
