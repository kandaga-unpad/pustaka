defmodule VoileWeb.API.V1.Circulation.CirculationApiJSON do
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Library.{Transaction, CirculationHistory, Fine}

  @doc """
  Render complete circulation data for a user.
  """
  def show(%{
        user: user,
        active_transactions: active_transactions,
        circulation_history: circulation_history,
        unpaid_fines: unpaid_fines
      }) do
    %{
      data: %{
        user: render_user(user),
        active_transactions: render_transactions(active_transactions),
        circulation_history: render_circulation_history(circulation_history),
        unpaid_fines: render_fines(unpaid_fines),
        summary: %{
          active_loans_count: length(active_transactions),
          history_count: length(circulation_history),
          unpaid_fines_count: length(unpaid_fines)
        }
      }
    }
  end

  @doc """
  Render paginated transactions for a user.
  """
  def transactions(%{user: user, transactions: transactions, pagination: pagination}) do
    %{
      data: render_transactions(transactions),
      pagination: pagination,
      user: render_user(user)
    }
  end

  @doc """
  Render paginated circulation history for a user.
  """
  def history(%{user: user, history: history, pagination: pagination}) do
    %{
      data: render_circulation_history(history),
      pagination: pagination,
      user: render_user(user)
    }
  end

  @doc """
  Render paginated fines for a user.
  """
  def fines(%{user: user, fines: fines, pagination: pagination}) do
    %{
      data: render_fines(fines),
      pagination: pagination,
      user: render_user(user)
    }
  end

  # Private renderers

  defp render_user(%User{} = user) do
    %{
      id: user.id,
      identifier: user.identifier,
      username: user.username,
      email: user.email,
      fullname: user.fullname,
      user_type: render_user_type(user.user_type),
      node: render_node(user.node)
    }
  end

  defp render_user_type(nil), do: nil
  defp render_user_type(%Ecto.Association.NotLoaded{}), do: nil

  defp render_user_type(user_type) do
    %{
      id: user_type.id,
      name: user_type.name,
      slug: user_type.slug
    }
  end

  defp render_node(nil), do: nil
  defp render_node(%Ecto.Association.NotLoaded{}), do: nil

  defp render_node(node) do
    %{
      id: node.id,
      name: node.name,
      abbr: node.abbr
    }
  end

  defp render_transactions(transactions) when is_list(transactions) do
    Enum.map(transactions, &render_transaction/1)
  end

  defp render_transaction(%Transaction{} = transaction) do
    %{
      id: transaction.id,
      transaction_type: transaction.transaction_type,
      transaction_date: transaction.transaction_date,
      due_date: transaction.due_date,
      return_date: transaction.return_date,
      renewal_count: transaction.renewal_count,
      status: transaction.status,
      fine_amount: transaction.fine_amount,
      is_overdue: transaction.is_overdue,
      notes: transaction.notes,
      item: render_item(transaction.item),
      librarian: render_librarian(transaction.librarian),
      collection: render_collection(transaction.collection)
    }
  end

  defp render_item(nil), do: nil
  defp render_item(%Ecto.Association.NotLoaded{}), do: nil

  defp render_item(item) do
    %{
      id: item.id,
      item_code: item.item_code,
      inventory_code: item.inventory_code,
      title: item.collection && item.collection.title,
      collection_code: item.collection && item.collection.collection_code
    }
  end

  defp render_librarian(nil), do: nil
  defp render_librarian(%Ecto.Association.NotLoaded{}), do: nil

  defp render_librarian(librarian) do
    %{
      id: librarian.id,
      username: librarian.username,
      fullname: librarian.fullname
    }
  end

  defp render_collection(nil), do: nil
  defp render_collection(%Ecto.Association.NotLoaded{}), do: nil

  defp render_collection(collection) do
    %{
      id: collection.id,
      title: collection.title,
      collection_code: collection.collection_code
    }
  end

  defp render_circulation_history(history) when is_list(history) do
    Enum.map(history, &render_history_entry/1)
  end

  defp render_history_entry(%CirculationHistory{} = entry) do
    %{
      id: entry.id,
      event_type: entry.event_type,
      event_date: entry.event_date,
      description: entry.description,
      old_value: entry.old_value,
      new_value: entry.new_value,
      item: render_history_item(entry.item),
      transaction: render_history_transaction(entry.transaction),
      reservation: render_history_reservation(entry.reservation),
      fine: render_history_fine(entry.fine),
      processed_by: render_processed_by(entry.processed_by)
    }
  end

  defp render_history_item(nil), do: nil
  defp render_history_item(%Ecto.Association.NotLoaded{}), do: nil

  defp render_history_item(item) do
    %{
      id: item.id,
      item_code: item.item_code,
      inventory_code: item.inventory_code
    }
  end

  defp render_history_transaction(nil), do: nil
  defp render_history_transaction(%Ecto.Association.NotLoaded{}), do: nil

  defp render_history_transaction(transaction) do
    %{
      id: transaction.id,
      transaction_type: transaction.transaction_type,
      status: transaction.status
    }
  end

  defp render_history_reservation(nil), do: nil
  defp render_history_reservation(%Ecto.Association.NotLoaded{}), do: nil

  defp render_history_reservation(reservation) do
    %{
      id: reservation.id,
      status: reservation.status
    }
  end

  defp render_history_fine(nil), do: nil
  defp render_history_fine(%Ecto.Association.NotLoaded{}), do: nil

  defp render_history_fine(fine) do
    %{
      id: fine.id,
      amount: fine.amount,
      fine_status: fine.fine_status
    }
  end

  defp render_processed_by(nil), do: nil
  defp render_processed_by(%Ecto.Association.NotLoaded{}), do: nil

  defp render_processed_by(user) do
    %{
      id: user.id,
      username: user.username,
      fullname: user.fullname
    }
  end

  defp render_fines(fines) when is_list(fines) do
    Enum.map(fines, &render_fine/1)
  end

  defp render_fine(%Fine{} = fine) do
    %{
      id: fine.id,
      fine_type: fine.fine_type,
      amount: fine.amount,
      balance: fine.balance,
      fine_date: fine.fine_date,
      fine_status: fine.fine_status,
      description: fine.description,
      item: render_fine_item(fine.item),
      transaction: render_fine_transaction(fine.transaction),
      processed_by: render_processed_by(fine.processed_by),
      waived_by: render_waived_by(fine.waived_by)
    }
  end

  defp render_fine_item(nil), do: nil
  defp render_fine_item(%Ecto.Association.NotLoaded{}), do: nil

  defp render_fine_item(item) do
    %{
      id: item.id,
      item_code: item.item_code,
      inventory_code: item.inventory_code
    }
  end

  defp render_fine_transaction(nil), do: nil
  defp render_fine_transaction(%Ecto.Association.NotLoaded{}), do: nil

  defp render_fine_transaction(transaction) do
    %{
      id: transaction.id,
      transaction_type: transaction.transaction_type,
      status: transaction.status
    }
  end

  defp render_waived_by(nil), do: nil
  defp render_waived_by(%Ecto.Association.NotLoaded{}), do: nil

  defp render_waived_by(user) do
    %{
      id: user.id,
      username: user.username,
      fullname: user.fullname
    }
  end
end
