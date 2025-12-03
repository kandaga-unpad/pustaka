defmodule VoileWeb.API.V1.Fines.FineApiJSON do
  alias Voile.Schema.Library.Fine
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Library.Transaction
  alias Voile.Schema.Library.Payment

  @doc """
    Render a list of fines.
  """
  def index(%{fines: fines, pagination: pagination}) do
    %{
      data: for(fine <- fines, do: data(fine)),
      pagination: %{
        page_number: pagination.page_number,
        page_size: pagination.page_size,
        total_pages: pagination.total_pages,
        total_count: pagination.total_count
      }
    }
  end

  def show(%{fine: fine}) do
    %{data: data(fine)}
  end

  defp data(%Fine{} = fine) do
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
      member: render_user(fine.member),
      item: render_item(fine.item),
      transaction: render_transaction(fine.transaction),
      librarian: render_user(fine.processed_by),
      waived_by: render_user(fine.waived_by),
      payments: render_payments(fine.payments),
      inserted_at: fine.inserted_at,
      updated_at: fine.updated_at
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
      status: transaction.status,
      fine_amount: transaction.fine_amount,
      is_overdue: transaction.is_overdue
    }
  end

  defp render_payments(nil), do: []
  defp render_payments(%Ecto.Association.NotLoaded{}), do: []

  defp render_payments(payments) when is_list(payments) do
    Enum.map(payments, fn %Payment{} = payment ->
      %{
        id: payment.id,
        payment_gateway: payment.payment_gateway,
        external_id: payment.external_id,
        amount: payment.amount,
        paid_amount: payment.paid_amount,
        currency: payment.currency,
        payment_method: payment.payment_method,
        payment_channel: payment.payment_channel,
        status: payment.status,
        payment_date: payment.payment_date,
        description: payment.description
      }
    end)
  end
end
