defmodule VoileWeb.API.V1.Circulation.CirculationApiController do
  use VoileWeb, :controller
  use PhoenixSwagger

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Accounts

  action_fallback VoileWeb.API.FallbackController

  swagger_path :show do
    get("/v1/circulation/{identifier}")
    summary("Get circulation information for a user")

    description(
      "Returns circulation information including active transactions, history, and fines for a user"
    )

    produces("application/json")
    tag("Circulation")
    security([%{Bearer: []}])

    parameters do
      identifier(:path, :string, "User identifier", required: true)
    end

    response(200, "OK", Schema.ref(:CirculationResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(500, "Internal Server Error")
  end

  def show(conn, %{"identifier" => identifier}) do
    with {:ok, user} <- get_user_by_identifier(identifier) do
      # Get active transactions for the user
      active_transactions = Circulation.list_member_active_transactions(user.id)

      # Get circulation history for the user
      circulation_history = Circulation.get_member_history(user.id)

      # Get unpaid fines for the user
      unpaid_fines = Circulation.list_member_unpaid_fines(user.id)

      conn
      |> put_status(:ok)
      |> render(:show, %{
        user: user,
        active_transactions: active_transactions,
        circulation_history: circulation_history,
        unpaid_fines: unpaid_fines
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(VoileWeb.API.ErrorJSON)
        |> render(:"404")
    end
  end

  swagger_path :transactions do
    get("/v1/circulation/{identifier}/transactions")
    summary("Get active transactions for a user")
    description("Returns a paginated list of active transactions for a user")
    produces("application/json")
    tag("Circulation")
    security([%{Bearer: []}])

    parameters do
      identifier(:path, :string, "User identifier", required: true)
      page(:query, :integer, "Page number", required: false, default: 1)
      per_page(:query, :integer, "Items per page", required: false, default: 10)
    end

    response(200, "OK", Schema.ref(:TransactionsResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(500, "Internal Server Error")
  end

  def transactions(conn, %{"identifier" => identifier}) do
    page = Map.get(conn.params, "page", "1") |> String.to_integer()
    per_page = Map.get(conn.params, "per_page", "10") |> String.to_integer()

    with {:ok, user} <- get_user_by_identifier(identifier) do
      {transactions, total_pages} =
        Circulation.list_member_active_transactions_paginated(user.id, page, per_page)

      pagination = %{
        page_number: page,
        page_size: per_page,
        total_pages: total_pages
      }

      conn
      |> put_status(:ok)
      |> render(:transactions, %{
        user: user,
        transactions: transactions,
        pagination: pagination
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(VoileWeb.API.ErrorJSON)
        |> render(:"404")
    end
  end

  swagger_path :history do
    get("/v1/circulation/{identifier}/history")
    summary("Get circulation history for a user")
    description("Returns a paginated list of circulation history for a user")
    produces("application/json")
    tag("Circulation")
    security([%{Bearer: []}])

    parameters do
      identifier(:path, :string, "User identifier", required: true)
      page(:query, :integer, "Page number", required: false, default: 1)
      per_page(:query, :integer, "Items per page", required: false, default: 10)
    end

    response(200, "OK", Schema.ref(:HistoryResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(500, "Internal Server Error")
  end

  def history(conn, %{"identifier" => identifier}) do
    page = Map.get(conn.params, "page", "1") |> String.to_integer()
    per_page = Map.get(conn.params, "per_page", "10") |> String.to_integer()

    with {:ok, user} <- get_user_by_identifier(identifier) do
      {history, total_pages} =
        Circulation.list_circulation_history_paginated_with_filters_by_member(
          user.id,
          page,
          per_page
        )

      pagination = %{
        page_number: page,
        page_size: per_page,
        total_pages: total_pages
      }

      conn
      |> put_status(:ok)
      |> render(:history, %{
        user: user,
        history: history,
        pagination: pagination
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(VoileWeb.API.ErrorJSON)
        |> render(:"404")
    end
  end

  swagger_path :fines do
    get("/v1/circulation/{identifier}/fines")
    summary("Get unpaid fines for a user")
    description("Returns a paginated list of unpaid fines for a user")
    produces("application/json")
    tag("Circulation")
    security([%{Bearer: []}])

    parameters do
      identifier(:path, :string, "User identifier", required: true)
      page(:query, :integer, "Page number", required: false, default: 1)
      per_page(:query, :integer, "Items per page", required: false, default: 10)
    end

    response(200, "OK", Schema.ref(:FinesResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(500, "Internal Server Error")
  end

  def fines(conn, %{"identifier" => identifier}) do
    page = Map.get(conn.params, "page", "1") |> String.to_integer()
    per_page = Map.get(conn.params, "per_page", "10") |> String.to_integer()

    with {:ok, user} <- get_user_by_identifier(identifier) do
      {fines, total_pages} =
        Circulation.list_member_unpaid_fines_paginated(user.id, page, per_page)

      pagination = %{
        page_number: page,
        page_size: per_page,
        total_pages: total_pages
      }

      conn
      |> put_status(:ok)
      |> render(:fines, %{
        user: user,
        fines: fines,
        pagination: pagination
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(VoileWeb.API.ErrorJSON)
        |> render(:"404")
    end
  end

  defp get_user_by_identifier(identifier) do
    case Accounts.get_user_by_identifier(identifier) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  def swagger_definitions do
    %{
      Transaction:
        swagger_schema do
          title("Transaction")
          description("A circulation transaction entity")

          properties do
            id(:string, "Unique identifier (UUID)", required: true, format: "uuid")
            transaction_type(:string, "Transaction type")
            transaction_date(:string, "Transaction date", format: "date-time")
            due_date(:string, "Due date", format: "date-time")
            return_date(:string, "Return date", format: "date-time")
            renewal_count(:integer, "Renewal count", default: 0)
            notes(:string, "Notes")
            status(:string, "Status")
            fine_amount(:number, "Fine amount", format: "decimal", default: 0.0)
            is_overdue(:boolean, "Is overdue", default: false)
            item_id(:string, "Item ID", format: "uuid")
            member_id(:string, "Member ID", format: "uuid")
            librarian_id(:string, "Librarian ID", format: "uuid")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end
        end,
      CirculationHistory:
        swagger_schema do
          title("CirculationHistory")
          description("A circulation history entry with enhanced item and collection details")

          properties do
            id(:string, "Unique identifier (UUID)", required: true, format: "uuid")
            event_type(:string, "Event type")
            event_date(:string, "Event date", format: "date-time")
            description(:string, "Description")
            old_value(:object, "Old value")
            new_value(:object, "New value")
            ip_address(:string, "IP address")
            user_agent(:string, "User agent")
            member_id(:string, "Member ID", format: "uuid")
            item(Schema.ref(:HistoryItem), "Item details with collection information")
            transaction(Schema.ref(:HistoryTransaction), "Transaction details")
            reservation(Schema.ref(:HistoryReservation), "Reservation details")
            fine(Schema.ref(:HistoryFine), "Fine details")
            processed_by(Schema.ref(:ProcessedBy), "User who processed this event")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end
        end,
      Fine:
        swagger_schema do
          title("Fine")
          description("A fine entity")

          properties do
            id(:string, "Unique identifier (UUID)", required: true, format: "uuid")
            fine_type(:string, "Fine type")
            amount(:number, "Amount", format: "decimal")
            paid_amount(:number, "Paid amount", format: "decimal", default: 0)
            balance(:number, "Balance", format: "decimal")
            fine_date(:string, "Fine date", format: "date-time")
            payment_date(:string, "Payment date", format: "date-time")
            fine_status(:string, "Fine status")
            description(:string, "Description")
            waived(:boolean, "Waived", default: false)
            waived_date(:string, "Waived date", format: "date-time")
            waived_reason(:string, "Waived reason")
            payment_method(:string, "Payment method")
            receipt_number(:string, "Receipt number")
            member_id(:string, "Member ID", format: "uuid")
            item_id(:string, "Item ID", format: "uuid")
            transaction_id(:string, "Transaction ID", format: "uuid")
            processed_by_id(:string, "Processed by user ID", format: "uuid")
            waived_by_id(:string, "Waived by user ID", format: "uuid")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end
        end,
      CirculationResponse:
        swagger_schema do
          title("CirculationResponse")
          description("Response containing circulation information for a user")

          properties do
            data(:object, "Circulation data",
              required: true,
              properties: %{
                user: Schema.ref(:User),
                active_transactions: %{
                  type: :array,
                  items: Schema.ref(:Transaction)
                },
                circulation_history: %{
                  type: :array,
                  items: Schema.ref(:CirculationHistory)
                },
                unpaid_fines: %{
                  type: :array,
                  items: Schema.ref(:Fine)
                }
              }
            )
          end
        end,
      TransactionsResponse:
        swagger_schema do
          title("TransactionsResponse")
          description("Response containing paginated transactions")

          properties do
            data(:object, "Transaction data",
              required: true,
              properties: %{
                user: Schema.ref(:User),
                transactions: %{
                  type: :array,
                  items: Schema.ref(:Transaction)
                },
                pagination: Schema.ref(:Pagination)
              }
            )
          end
        end,
      HistoryResponse:
        swagger_schema do
          title("HistoryResponse")
          description("Response containing paginated circulation history")

          properties do
            data(:object, "History data",
              required: true,
              properties: %{
                user: Schema.ref(:User),
                history: %{
                  type: :array,
                  items: Schema.ref(:CirculationHistory)
                },
                pagination: Schema.ref(:Pagination)
              }
            )
          end
        end,
      FinesResponse:
        swagger_schema do
          title("FinesResponse")
          description("Response containing paginated fines")

          properties do
            data(:object, "Fines data",
              required: true,
              properties: %{
                user: Schema.ref(:User),
                fines: %{
                  type: :array,
                  items: Schema.ref(:Fine)
                },
                pagination: Schema.ref(:Pagination)
              }
            )
          end
        end,
      User:
        swagger_schema do
          title("User")
          description("A user entity")

          properties do
            id(:string, "Unique identifier (UUID)", required: true, format: "uuid")
            username(:string, "Username")
            identifier(:number, "User identifier number")
            email(:string, "Email address", format: "email")
            fullname(:string, "Full name")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end
        end,
      Pagination:
        swagger_schema do
          title("Pagination")
          description("Pagination metadata")

          properties do
            page_number(:integer, "Current page number", required: true)
            page_size(:integer, "Number of items per page", required: true)
            total_pages(:integer, "Total number of pages", required: true)
          end

          example(%{
            page_number: 1,
            page_size: 10,
            total_pages: 5
          })
        end,
      HistoryItem:
        swagger_schema do
          title("HistoryItem")
          description("Item details in circulation history")

          properties do
            id(:string, "Item ID", format: "uuid")
            item_code(:string, "Item code")
            inventory_code(:string, "Inventory code")
            title(:string, "Item title")
            collection_code(:string, "Collection code")
            collection(Schema.ref(:HistoryCollection), "Collection details")
          end
        end,
      HistoryCollection:
        swagger_schema do
          title("HistoryCollection")
          description("Collection details in circulation history")

          properties do
            id(:string, "Collection ID", format: "uuid")
            title(:string, "Collection title")
            collection_code(:string, "Collection code")
          end
        end,
      HistoryTransaction:
        swagger_schema do
          title("HistoryTransaction")
          description("Transaction details in circulation history")

          properties do
            id(:string, "Transaction ID", format: "uuid")
            status(:string, "Transaction status")
            transaction_type(:string, "Transaction type")
          end
        end,
      HistoryReservation:
        swagger_schema do
          title("HistoryReservation")
          description("Reservation details in circulation history")

          properties do
            id(:string, "Reservation ID", format: "uuid")
            status(:string, "Reservation status")
            priority(:integer, "Reservation priority")
          end
        end,
      HistoryFine:
        swagger_schema do
          title("HistoryFine")
          description("Fine details in circulation history")

          properties do
            id(:string, "Fine ID", format: "uuid")
            amount(:number, "Fine amount", format: "decimal")
            fine_type(:string, "Fine type")
          end
        end,
      ProcessedBy:
        swagger_schema do
          title("ProcessedBy")
          description("User who processed the circulation event")

          properties do
            id(:string, "User ID", format: "uuid")
            username(:string, "Username")
            fullname(:string, "Full name")
          end
        end
    }
  end
end
