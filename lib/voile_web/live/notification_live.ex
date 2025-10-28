defmodule VoileWeb.NotificationComponent do
  @moduledoc """
  LiveComponent for displaying reservation notifications to staff/admin.
  Receives notifications from parent LiveView via assigns.
  """
  use VoileWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("dismiss_notification", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    notifications = List.delete_at(socket.assigns.notifications, index)

    # Send update back to parent LiveView
    send(self(), {:update_notifications, notifications})

    {:noreply, assign(socket, :notifications, notifications)}
  end

  @impl true
  def handle_event("dismiss_all", _params, socket) do
    # Send update back to parent LiveView
    send(self(), {:update_notifications, []})

    {:noreply, assign(socket, :notifications, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="reservation-notifications"
      class={[
        "fixed bottom-4 right-4 z-50 w-96 max-h-[80vh] overflow-y-auto",
        length(@notifications) == 0 && "hidden"
      ]}
      phx-hook="NotificationSound"
    >
      <div class="space-y-2">
        <%= for {notification, index} <- Enum.with_index(@notifications) do %>
          <div
            id={"notification-#{index}"}
            class="bg-white dark:bg-gray-800 rounded-lg shadow-lg border-l-4 border-blue-500 p-4 animate-slide-in"
          >
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <div class="flex items-center gap-2 mb-2">
                  <.icon name="hero-bell" class="w-5 h-5 text-blue-500" />
                  <h4 class="font-semibold text-gray-900 dark:text-white text-sm">
                    New Reservation Request
                  </h4>
                </div>

                <div class="space-y-1 text-sm text-gray-600 dark:text-gray-300">
                  <p class="flex items-center gap-2">
                    <.icon name="hero-user" class="w-4 h-4" />
                    <span class="font-medium">{notification.member_name}</span>
                  </p>

                  <p class="flex items-center gap-2">
                    <.icon name="hero-bookmark" class="w-4 h-4" />
                    <span>{notification.item_code}</span>
                  </p>

                  <%= if notification.collection_title do %>
                    <p class="text-xs text-gray-500 dark:text-gray-400 ml-6">
                      {notification.collection_title}
                    </p>
                  <% end %>

                  <%= if notification.notes && String.trim(notification.notes) != "" do %>
                    <p class="text-xs text-gray-500 dark:text-gray-400 italic ml-6">
                      "{notification.notes}"
                    </p>
                  <% end %>
                </div>

                <div class="mt-3 flex items-center gap-2">
                  <.link
                    navigate={~p"/manage/glam/library/circulation/reservations/#{notification.id}"}
                    class="text-xs font-medium text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
                  >
                    View Details →
                  </.link>
                </div>
              </div>

              <button
                phx-click="dismiss_notification"
                phx-value-index={index}
                phx-target={@myself}
                class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 ml-2"
              >
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>
          </div>
        <% end %>

        <%= if length(@notifications) > 1 do %>
          <button
            phx-click="dismiss_all"
            phx-target={@myself}
            class="w-full bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 text-sm font-medium py-2 px-4 rounded-lg transition-colors"
          >
            Dismiss All ({length(@notifications)})
          </button>
        <% end %>
      </div>
    </div>
    """
  end
end
