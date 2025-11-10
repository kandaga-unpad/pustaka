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
  Notify the reservation member (via email) that their reservation is ready or a staff action occurred.

  Returns {:ok, _} on success or {:error, reason} on failure. If the member has no email,
  returns {:error, :no_recipient} but still broadcasts an internal message for staff.
  """
  def notify_member(%Reservation{} = reservation) do
    reservation = Voile.Repo.preload(reservation, [:member, {:item, :collection}])

    # Build notification payload
    notification_data = %{
      id: reservation.id,
      member_id: reservation.member_id,
      member_name: get_member_name(reservation),
      item_code: get_item_code(reservation),
      collection_title: get_collection_title(reservation),
      status: reservation.status,
      notes: reservation.notes,
      inserted_at: reservation.inserted_at
    }

    # Broadcast to staff topic so dashboard listeners can react if needed
    PubSub.broadcast(Voile.PubSub, @topic, {:reservation_member_notify, notification_data})

    # If we have a member_id, prefer realtime in-app notification.
    # If there's no member_id (user not logged in / not connected), fall back to email when available.
    case reservation.member_id do
      nil ->
        # No connected member topic possible; fall back to email if present
        case reservation.member do
          %{email: email} when is_binary(email) and email != "" ->
            import Swoosh.Email

            html_body =
              """
              <p>Hello #{get_member_name(reservation)},</p>
              <p>Your reservation <strong>#{get_item_code(reservation) || "item"}</strong> status is: <strong>#{reservation.status}</strong>.</p>
              <p>Notes: #{reservation.notes || "-"}</p>
              <p>If you have questions, please contact the library.</p>
              """

            text_body =
              "Hello #{get_member_name(reservation)},\n\nYour reservation (#{get_item_code(reservation) || "item"}) status is: #{reservation.status}.\n\nNotes: #{reservation.notes || "-"}\n\nThank you."

            email_msg =
              new()
              |> to(email)
              |> from({"Voile", "hi@curatorian.id"})
              |> subject("Your reservation update")
              |> html_body(html_body)
              |> text_body(text_body)

            case Voile.Mailer.deliver(email_msg) do
              {:ok, _meta} -> {:ok, :email_only}
              {:error, reason} -> {:error, reason}
            end

          _ ->
            {:error, :no_recipient}
        end

      member_id ->
        member_topic = "reservations:member:#{member_id}"

        :ok =
          PubSub.broadcast(
            Voile.PubSub,
            member_topic,
            {:reservation_notification, notification_data}
          )

        {:ok, :realtime_only}
    end
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

  @doc """
  Subscribe the current process to a member-specific reservation topic.
  Use this in member-facing LiveViews to receive realtime reservation notifications.
  """
  def subscribe_member(member_id) when is_binary(member_id) or is_integer(member_id) do
    member_topic = "reservations:member:#{member_id}"
    PubSub.subscribe(Voile.PubSub, member_topic)
  end

  @doc """
  Unsubscribe the current process from a member-specific reservation topic.
  """
  def unsubscribe_member(member_id) when is_binary(member_id) or is_integer(member_id) do
    member_topic = "reservations:member:#{member_id}"
    PubSub.unsubscribe(Voile.PubSub, member_topic)
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
