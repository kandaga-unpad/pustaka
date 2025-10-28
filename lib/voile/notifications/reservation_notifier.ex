defmodule Voile.Notifications.ReservationNotifier do
  @moduledoc """
  Handles broadcasting and subscribing to reservation notifications.
  Staff and admin users can subscribe to get notified when members request reservations.
  """

  alias Phoenix.PubSub
  alias Voile.Schema.Library.Reservation

  @topic "reservations:new"

  @doc """
  Broadcasts a new reservation notification to all subscribed staff/admin.
  """
  def broadcast_new_reservation(%Reservation{} = reservation) do
    reservation = Voile.Repo.preload(reservation, [:member, {:item, :collection}])

    notification_data = %{
      id: reservation.id,
      member_id: reservation.member_id,
      member_name: get_member_name(reservation),
      item_id: reservation.item_id,
      item_code: get_item_code(reservation),
      collection_title: get_collection_title(reservation),
      status: reservation.status,
      notes: reservation.notes,
      inserted_at: reservation.inserted_at
    }

    PubSub.broadcast(
      Voile.PubSub,
      @topic,
      {:new_reservation, notification_data}
    )
  end

  @doc """
  Subscribe to new reservation notifications.
  Should only be called by staff/admin users.
  """
  def subscribe_to_reservations do
    PubSub.subscribe(Voile.PubSub, @topic)
  end

  @doc """
  Unsubscribe from reservation notifications.
  """
  def unsubscribe_from_reservations do
    PubSub.unsubscribe(Voile.PubSub, @topic)
  end

  # Helper functions
  defp get_member_name(%{member: %{fullname: fullname}}) when not is_nil(fullname),
    do: fullname

  defp get_member_name(%{member: %{email: email}}) when not is_nil(email), do: email
  defp get_member_name(_), do: "Unknown Member"

  defp get_item_code(%{item: %{item_code: code}}) when not is_nil(code), do: code
  defp get_item_code(_), do: "Unknown Item"

  defp get_collection_title(%{item: %{collection: %{title: title}}}) when not is_nil(title),
    do: title

  defp get_collection_title(%{collection: %{title: title}}) when not is_nil(title), do: title
  defp get_collection_title(_), do: nil
end
