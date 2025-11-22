defmodule VoileWeb.API.V1.Fines.FineApiJson do
  alias Voile.Schema.Library.Fine

  @doc """
    Render a list of fines.
  """
  def index(%{fines: fines, pagination: pagination}) do
    %{
      data: for(fine <- fines, do: data(fine)),
      pagination: %{
        page_number: pagination.page_number,
        page_size: pagination.page_size,
        total_pages: pagination.total_pages
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
      member: fine.member,
      item: fine.item,
      transaction: fine.transaction,
      librarian: fine.processed_by,
      waived_by: fine.waived_by,
      payments: fine.payments,
      inserted_at: fine.inserted_at,
      updated_at: fine.updated_at
    }
  end
end
