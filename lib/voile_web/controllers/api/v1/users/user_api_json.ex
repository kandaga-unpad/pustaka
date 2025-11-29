defmodule VoileWeb.API.V1.Users.UserApiJSON do
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Library.{Transaction, Reservation, Fine, CirculationHistory}
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.System.Node

  @doc """
  Render a list of users (without associations).
  """
  def index(%{users: users, pagination: pagination}) do
    %{
      data: for(user <- users, do: user_data(user)),
      pagination: %{
        page_number: pagination.page_number,
        page_size: pagination.page_size,
        total_pages: pagination.total_pages
      }
    }
  end

  def show(%{user: user}) do
    %{data: user_data_with_associations(user)}
  end

  # Basic user data without associations
  defp user_data(%User{} = user) do
    %{
      id: user.id,
      username: user.username,
      identifier: user.identifier,
      email: user.email,
      fullname: user.fullname,
      user_image: user.user_image,
      groups: user.groups,
      last_login: user.last_login,
      last_login_ip: user.last_login_ip,
      manually_suspended: user.manually_suspended,
      suspension_reason: user.suspension_reason,
      suspended_at: user.suspended_at,
      suspension_ends_at: user.suspension_ends_at,
      address: user.address,
      phone_number: user.phone_number,
      birth_date: user.birth_date,
      birth_place: user.birth_place,
      gender: user.gender,
      registration_date: user.registration_date,
      expiry_date: user.expiry_date,
      organization: user.organization,
      department: user.department,
      position: user.position,
      user_type: render_member_type(user.user_type),
      node: render_node(user.node),
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end

  # User data with associations
  defp user_data_with_associations(%User{} = user) do
    user_data(user)
    |> Map.put(:transactions, render_transactions(user.transactions))
    |> Map.put(:reservations, render_reservations(user.reservations))
    |> Map.put(:fines, render_fines(user.fines))
    |> Map.put(:circulation_history, render_circulation_history(user.circulation_history))
  end

  # Association renderers
  defp render_member_type(nil), do: nil
  defp render_member_type(%Ecto.Association.NotLoaded{}), do: nil

  defp render_member_type(%MemberType{} = member_type) do
    %{
      id: member_type.id,
      name: member_type.name,
      description: member_type.description
    }
  end

  defp render_node(nil), do: nil
  defp render_node(%Ecto.Association.NotLoaded{}), do: nil

  defp render_node(%Node{} = node) do
    %{
      id: node.id,
      name: node.name,
      abbr: node.abbr,
      image: node.image,
      description: node.description
    }
  end

  defp render_transactions(nil), do: []
  defp render_transactions(%Ecto.Association.NotLoaded{}), do: []

  defp render_transactions(transactions) when is_list(transactions) do
    Enum.map(transactions, fn %Transaction{} = transaction ->
      %{
        id: transaction.id,
        transaction_type: transaction.transaction_type,
        transaction_date: transaction.transaction_date,
        due_date: transaction.due_date,
        return_date: transaction.return_date,
        renewal_count: transaction.renewal_count,
        notes: transaction.notes,
        status: transaction.status,
        fine_amount: transaction.fine_amount,
        is_overdue: transaction.is_overdue,
        inserted_at: transaction.inserted_at,
        updated_at: transaction.updated_at
      }
    end)
  end

  defp render_reservations(nil), do: []
  defp render_reservations(%Ecto.Association.NotLoaded{}), do: []

  defp render_reservations(reservations) when is_list(reservations) do
    Enum.map(reservations, fn %Reservation{} = reservation ->
      %{
        id: reservation.id,
        reservation_date: reservation.reservation_date,
        expiry_date: reservation.expiry_date,
        notification_sent: reservation.notification_sent,
        status: reservation.status,
        priority: reservation.priority,
        notes: reservation.notes,
        pickup_date: reservation.pickup_date,
        cancelled_date: reservation.cancelled_date,
        cancellation_reason: reservation.cancellation_reason,
        inserted_at: reservation.inserted_at,
        updated_at: reservation.updated_at
      }
    end)
  end

  defp render_fines(nil), do: []
  defp render_fines(%Ecto.Association.NotLoaded{}), do: []

  defp render_fines(fines) when is_list(fines) do
    Enum.map(fines, fn %Fine{} = fine ->
      %{
        id: fine.id,
        fine_type: fine.fine_type,
        amount: fine.amount,
        paid_amount: fine.paid_amount,
        balance: fine.balance,
        fine_date: fine.fine_date,
        payment_date: fine.payment_date,
        fine_status: fine.fine_status,
        description: fine.description,
        waived: fine.waived,
        waived_date: fine.waived_date,
        waived_reason: fine.waived_reason,
        payment_method: fine.payment_method,
        receipt_number: fine.receipt_number,
        inserted_at: fine.inserted_at,
        updated_at: fine.updated_at
      }
    end)
  end

  defp render_circulation_history(nil), do: []
  defp render_circulation_history(%Ecto.Association.NotLoaded{}), do: []

  defp render_circulation_history(history) when is_list(history) do
    Enum.map(history, fn %CirculationHistory{} = entry ->
      %{
        id: entry.id,
        event_type: entry.event_type,
        event_date: entry.event_date,
        description: entry.description,
        old_value: entry.old_value,
        new_value: entry.new_value,
        ip_address: entry.ip_address,
        user_agent: entry.user_agent,
        inserted_at: entry.inserted_at,
        updated_at: entry.updated_at
      }
    end)
  end
end
