defmodule VoileWeb.API.V1.CirculationHistory.CirculationHistoryApiJSON do
  alias Voile.Schema.Library.CirculationHistory
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Library.{Transaction, Reservation, Fine}

  @doc """
  Render a list of circulation history entries.
  """
  def index(%{circulation_history: circulation_history, pagination: pagination}) do
    %{
      data: for(history <- circulation_history, do: data(history)),
      pagination: %{
        page_number: pagination.page_number,
        page_size: pagination.page_size,
        total_pages: pagination.total_pages,
        total_count: pagination.total_count
      }
    }
  end

  def show(%{circulation_history: circulation_history}) do
    %{data: data(circulation_history)}
  end

  defp data(%CirculationHistory{} = history) do
    %{
      id: history.id,
      event_type: history.event_type,
      event_date: history.event_date,
      description: history.description,
      old_value: history.old_value,
      new_value: history.new_value,
      ip_address: history.ip_address,
      user_agent: history.user_agent,
      member: render_user(history.member),
      item: render_item(history.item),
      transaction: render_transaction(history.transaction),
      reservation: render_reservation(history.reservation),
      fine: render_fine(history.fine),
      processed_by: render_user(history.processed_by),
      inserted_at: history.inserted_at,
      updated_at: history.updated_at
    }
  end

  # Association renderers
  defp render_user(nil), do: nil
  defp render_user(%Ecto.Association.NotLoaded{}), do: nil

  defp render_user(%User{} = user) do
    %{
      id: user.id,
      username: user.username,
      identifier: user.identifier,
      email: user.email,
      fullname: user.fullname
    }
  end

  defp render_item(nil), do: nil
  defp render_item(%Ecto.Association.NotLoaded{}), do: nil

  defp render_item(%Item{} = item) do
    %{
      id: item.id,
      item_code: item.item_code,
      inventory_code: item.inventory_code,
      barcode: item.barcode,
      location: item.location,
      status: item.status,
      condition: item.condition,
      availability: item.availability
    }
  end

  defp render_transaction(nil), do: nil
  defp render_transaction(%Ecto.Association.NotLoaded{}), do: nil

  defp render_transaction(%Transaction{} = transaction) do
    %{
      id: transaction.id,
      transaction_type: transaction.transaction_type,
      transaction_date: transaction.transaction_date,
      due_date: transaction.due_date,
      return_date: transaction.return_date,
      status: transaction.status
    }
  end

  defp render_reservation(nil), do: nil
  defp render_reservation(%Ecto.Association.NotLoaded{}), do: nil

  defp render_reservation(%Reservation{} = reservation) do
    %{
      id: reservation.id,
      reservation_date: reservation.reservation_date,
      expiry_date: reservation.expiry_date,
      status: reservation.status,
      priority: reservation.priority
    }
  end

  defp render_fine(nil), do: nil
  defp render_fine(%Ecto.Association.NotLoaded{}), do: nil

  defp render_fine(%Fine{} = fine) do
    %{
      id: fine.id,
      fine_type: fine.fine_type,
      amount: fine.amount,
      balance: fine.balance,
      fine_status: fine.fine_status
    }
  end
end
