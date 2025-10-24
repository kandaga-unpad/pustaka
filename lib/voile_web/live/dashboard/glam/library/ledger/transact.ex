defmodule VoileWeb.Dashboard.Glam.Library.Ledger.Transact do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Catalog.{Item, Collection}

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => member_id}, _uri, socket) do
    case load_member_data(member_id) do
      {:ok, member} ->
        librarian_id = socket.assigns.current_scope.user.id

        socket =
          socket
          |> assign(:page_title, "Collection Circulation / Books Ledger")
          |> assign(:member, member)
          |> assign(:member_id, member_id)
          |> assign(:librarian_id, librarian_id)
          |> assign(:active_tab, "loan")
          |> assign(:temp_loans, [])
          |> assign(:temp_reservations, [])
          |> assign(:item_search_query, "")
          |> assign(:collection_search_query, "")
          |> assign(:current_loans, load_current_loans(member_id))
          |> assign(:unpaid_fines, load_unpaid_fines(member_id))
          |> assign(:total_unpaid_fines, calculate_total_unpaid_fines(member_id))
          |> assign(:loan_history, load_loan_history(member_id))
          |> assign(:show_modal, nil)
          |> assign(:modal_data, %{})

        {:noreply, socket}

      {:error, _reason} ->
        socket =
          socket
          |> put_flash(:error, "Member not found")
          |> push_navigate(to: ~p"/manage/glam/library/ledger")

        {:noreply, socket}
    end
  end

  # Event handlers
  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # Loan tab events
  def handle_event("search_item", %{"item_code" => item_code}, socket) do
    item_code = String.trim(item_code)

    if item_code == "" do
      {:noreply, put_flash(socket, :error, "Please enter an item code")}
    else
      case find_item_by_code(item_code) do
        nil ->
          {:noreply, put_flash(socket, :error, "Item not found with code: #{item_code}")}

        item ->
          # Check if item is already in temp_loans
          if Enum.any?(socket.assigns.temp_loans, fn loan -> loan.item.id == item.id end) do
            {:noreply, put_flash(socket, :error, "Item already added to loan list")}
          else
            # Add to temporary loans
            temp_loan = %{
              item: item,
              loan_date: Date.utc_today(),
              due_date: calculate_due_date(socket.assigns.member)
            }

            updated_temp_loans = socket.assigns.temp_loans ++ [temp_loan]

            socket =
              socket
              |> assign(:temp_loans, updated_temp_loans)
              |> assign(:item_search_query, "")
              |> put_flash(:info, "Item added to loan list")

            {:noreply, socket}
          end
      end
    end
  end

  def handle_event("remove_temp_loan", %{"item_id" => item_id}, socket) do
    temp_loans =
      Enum.reject(socket.assigns.temp_loans, fn loan -> loan.item.id == item_id end)

    {:noreply, assign(socket, :temp_loans, temp_loans)}
  end

  # Current Loans tab events
  def handle_event("show_return_modal", %{"transaction_id" => transaction_id}, socket) do
    transaction = Enum.find(socket.assigns.current_loans, fn t -> t.id == transaction_id end)

    socket =
      socket
      |> assign(:show_modal, "return")
      |> assign(:modal_data, %{transaction: transaction})

    {:noreply, socket}
  end

  def handle_event("confirm_return", %{"transaction_id" => transaction_id}, socket) do
    case Circulation.return_item(transaction_id, socket.assigns.librarian_id) do
      {:ok, _transaction} ->
        socket =
          socket
          |> assign(:current_loans, load_current_loans(socket.assigns.member_id))
          |> assign(:unpaid_fines, load_unpaid_fines(socket.assigns.member_id))
          |> assign(:total_unpaid_fines, calculate_total_unpaid_fines(socket.assigns.member_id))
          |> assign(:loan_history, load_loan_history(socket.assigns.member_id))
          |> assign(:show_modal, nil)
          |> put_flash(:info, "Item returned successfully")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to return item: #{reason}")}
    end
  end

  def handle_event("show_extend_modal", %{"transaction_id" => transaction_id}, socket) do
    transaction = Enum.find(socket.assigns.current_loans, fn t -> t.id == transaction_id end)

    socket =
      socket
      |> assign(:show_modal, "extend")
      |> assign(:modal_data, %{transaction: transaction})

    {:noreply, socket}
  end

  def handle_event("confirm_extend", %{"transaction_id" => transaction_id}, socket) do
    case Circulation.renew_transaction(transaction_id, socket.assigns.librarian_id) do
      {:ok, _transaction} ->
        socket =
          socket
          |> assign(:current_loans, load_current_loans(socket.assigns.member_id))
          |> assign(:show_modal, nil)
          |> put_flash(:info, "Loan extended successfully")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to extend loan: #{reason}")}
    end
  end

  # Reserve tab events
  def handle_event("search_collection", %{"query" => query}, socket) do
    {:noreply, assign(socket, :collection_search_query, query)}
  end

  def handle_event("add_reservation", %{"collection_id" => collection_id}, socket) do
    collection = Repo.get!(Collection, collection_id)

    # Check if already in temp reservations
    if Enum.any?(socket.assigns.temp_reservations, fn r -> r.collection.id == collection_id end) do
      {:noreply, put_flash(socket, :error, "Collection already in reservation list")}
    else
      temp_reservation = %{
        collection: collection,
        item_code: nil,
        reserve_date: Date.utc_today()
      }

      updated_temp_reservations = socket.assigns.temp_reservations ++ [temp_reservation]

      socket =
        socket
        |> assign(:temp_reservations, updated_temp_reservations)
        |> put_flash(:info, "Collection added to reservation list")

      {:noreply, socket}
    end
  end

  def handle_event("remove_temp_reservation", %{"collection_id" => collection_id}, socket) do
    temp_reservations =
      Enum.reject(socket.assigns.temp_reservations, fn r -> r.collection.id == collection_id end)

    {:noreply, assign(socket, :temp_reservations, temp_reservations)}
  end

  # Fines tab events
  def handle_event("show_add_fine_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_modal, "add_fine")
      |> assign(:modal_data, %{
        fine_form:
          to_form(%{
            "description" => "",
            "amount" => "",
            "fine_type" => "processing"
          })
      })

    {:noreply, socket}
  end

  def handle_event("create_fine", params, socket) do
    fine_attrs = %{
      member_id: socket.assigns.member_id,
      fine_type: params["fine_type"],
      description: params["description"],
      amount: params["amount"],
      fine_date: DateTime.utc_now(),
      fine_status: "pending",
      processed_by_id: socket.assigns.librarian_id
    }

    case Circulation.create_fine(fine_attrs) do
      {:ok, _fine} ->
        socket =
          socket
          |> assign(:unpaid_fines, load_unpaid_fines(socket.assigns.member_id))
          |> assign(:total_unpaid_fines, calculate_total_unpaid_fines(socket.assigns.member_id))
          |> assign(:show_modal, nil)
          |> put_flash(:info, "Fine created successfully")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create fine")}
    end
  end

  def handle_event("show_delete_fine_modal", %{"fine_id" => fine_id}, socket) do
    fine = Enum.find(socket.assigns.unpaid_fines, fn f -> f.id == fine_id end)

    socket =
      socket
      |> assign(:show_modal, "delete_fine")
      |> assign(:modal_data, %{fine: fine})

    {:noreply, socket}
  end

  def handle_event("confirm_delete_fine", %{"fine_id" => fine_id}, socket) do
    fine = Circulation.get_fine!(fine_id)

    case Circulation.delete_fine(fine) do
      {:ok, _} ->
        socket =
          socket
          |> assign(:unpaid_fines, load_unpaid_fines(socket.assigns.member_id))
          |> assign(:total_unpaid_fines, calculate_total_unpaid_fines(socket.assigns.member_id))
          |> assign(:show_modal, nil)
          |> put_flash(:info, "Fine deleted successfully")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete fine")}
    end
  end

  def handle_event("show_pay_fine_modal", %{"fine_id" => fine_id}, socket) do
    fine = Enum.find(socket.assigns.unpaid_fines, fn f -> f.id == fine_id end)

    # Check if there's an existing pending payment link
    pending_payment =
      case Circulation.get_pending_payment_for_fine(fine_id) do
        {:ok, payment} -> payment
        _ -> nil
      end

    socket =
      socket
      |> assign(:show_modal, "pay_fine")
      |> assign(:modal_data, %{
        fine: fine,
        pending_payment: pending_payment,
        payment_form:
          to_form(%{
            "amount" => to_string(fine.balance),
            "payment_method" => "cash"
          })
      })

    {:noreply, socket}
  end

  def handle_event("confirm_pay_fine", %{"fine_id" => fine_id} = params, socket) do
    payment_amount = Decimal.new(params["amount"])
    payment_method = params["payment_method"]

    case Circulation.pay_fine(
           fine_id,
           payment_amount,
           payment_method,
           socket.assigns.librarian_id
         ) do
      {:ok, _fine} ->
        socket =
          socket
          |> assign(:unpaid_fines, load_unpaid_fines(socket.assigns.member_id))
          |> assign(:total_unpaid_fines, calculate_total_unpaid_fines(socket.assigns.member_id))
          |> assign(:show_modal, nil)
          |> put_flash(:info, "Payment processed successfully")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Payment failed: #{reason}")}
    end
  end

  def handle_event("generate_payment_link", %{"fine_id" => fine_id}, socket) do
    # Generate Xendit payment link
    case Circulation.create_payment_link_for_fine(
           fine_id,
           socket.assigns.librarian_id,
           success_redirect_url: ~p"/atrium?payment=success",
           failure_redirect_url: ~p"/atrium?payment=failed"
         ) do
      {:ok, payment} ->
        fine = Enum.find(socket.assigns.unpaid_fines, fn f -> f.id == fine_id end)

        socket =
          socket
          |> assign(:show_modal, "pay_fine")
          |> assign(:modal_data, %{
            fine: fine,
            pending_payment: payment,
            payment_form:
              to_form(%{"amount" => to_string(fine.balance), "payment_method" => "cash"})
          })
          |> put_flash(:info, "Payment link generated successfully")

        {:noreply, socket}

      {:error, :api_key_not_configured} ->
        {:noreply, put_flash(socket, :error, "Xendit API key not configured")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Failed to generate payment link: #{inspect(reason)}")}
    end
  end

  def handle_event("copy_payment_link", %{"url" => _url}, socket) do
    # Client-side will handle the actual copy
    {:noreply, put_flash(socket, :info, "Payment link copied to clipboard")}
  end

  # Finish transaction
  def handle_event("show_finish_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, "finish_transaction")}
  end

  def handle_event("finish_transaction", _params, socket) do
    # Process all temporary loans
    loan_results =
      Enum.map(socket.assigns.temp_loans, fn temp_loan ->
        Circulation.checkout_item(
          socket.assigns.member_id,
          temp_loan.item.id,
          socket.assigns.librarian_id
        )
      end)

    # Process all temporary reservations
    reservation_results =
      Enum.map(socket.assigns.temp_reservations, fn temp_res ->
        Circulation.create_collection_reservation(
          socket.assigns.member_id,
          temp_res.collection.id
        )
      end)

    # Check results
    loan_successes =
      Enum.count(loan_results, fn
        {:ok, _} -> true
        _ -> false
      end)

    reservation_successes =
      Enum.count(reservation_results, fn
        {:ok, _} -> true
        _ -> false
      end)

    socket =
      socket
      |> assign(:temp_loans, [])
      |> assign(:temp_reservations, [])
      |> assign(:current_loans, load_current_loans(socket.assigns.member_id))
      |> assign(:loan_history, load_loan_history(socket.assigns.member_id))
      |> assign(:show_modal, nil)
      |> put_flash(
        :info,
        "Transaction completed: #{loan_successes} loans, #{reservation_successes} reservations"
      )

    {:noreply, socket}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, nil)}
  end

  # Helper functions
  defp load_member_data(member_id) do
    case Repo.get(User, member_id) |> Repo.preload([:user_type]) do
      nil -> {:error, :not_found}
      member -> {:ok, member}
    end
  end

  defp find_item_by_code(item_code) do
    Item
    |> where([i], i.item_code == ^item_code)
    |> where([i], i.status == "active" and i.availability == "available")
    |> preload([:collection])
    |> limit(1)
    |> Repo.one()
  end

  defp load_current_loans(member_id) do
    Circulation.list_member_active_transactions(member_id)
  end

  defp load_unpaid_fines(member_id) do
    Circulation.list_member_unpaid_fines(member_id)
  end

  defp calculate_total_unpaid_fines(member_id) do
    Circulation.get_member_outstanding_fine_amount(member_id)
  end

  defp load_loan_history(member_id) do
    Circulation.get_member_history(member_id)
    |> Enum.filter(fn h -> h.event_type in ["loan", "return"] end)
    |> Enum.take(20)
  end

  defp calculate_due_date(member) do
    days = (member.user_type && member.user_type.max_days) || 14
    Date.add(Date.utc_today(), days)
  end

  defp format_currency(amount) when is_struct(amount, Decimal) do
    # Convert Decimal to integer for formatting
    amount_int =
      amount
      |> Decimal.to_string()
      |> String.split(".")
      |> List.first()
      |> String.to_integer()

    # Format with thousand separators
    amount_str = Integer.to_string(amount_int)
    formatted = format_with_separators(amount_str)
    "Rp #{formatted}"
  end

  defp format_currency(_), do: "Rp 0"

  defp format_with_separators(str) do
    str
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(".")
    |> String.reverse()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.breadcrumb items={[
      %{label: "Manage", path: ~p"/manage"},
      %{label: "GLAM", path: ~p"/manage/glam"},
      %{label: "Library", path: ~p"/manage/glam/library"},
      %{label: "Ledgers", path: ~p"/manage/glam/library/ledger"},
      %{label: "Transaction", path: nil}
    ]} />
    <div class="space-y-6">
      <%!-- Header with Finish Button --%>
      <div class="flex items-center justify-between">
        <div>
          <.back navigate="/manage/glam/library/ledger">Back to Search</.back>

          <h1 class="text-3xl font-bold mt-4">Collection Circulation / Books Ledger</h1>
        </div>

        <.button
          phx-click="show_finish_modal"
          class="bg-green-600 hover:bg-green-700 text-white font-semibold py-3 px-6 rounded-lg"
        >
          <.icon name="hero-check-circle" class="w-5 h-5 mr-2" /> Finish Transaction
        </.button>
      </div>
      <%!-- Member Biodata --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <h2 class="text-xl font-semibold mb-4 text-gray-900 dark:text-white">Member Information</h2>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Full Name</p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">{@member.fullname || "N/A"}</p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Identifier</p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {if @member.identifier, do: Decimal.to_string(@member.identifier), else: "N/A"}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Email</p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">{@member.email || "N/A"}</p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Member Type</p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {if @member.user_type, do: @member.user_type.name, else: "N/A"}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Phone</p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {@member.phone_number || "N/A"}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Organization</p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {@member.organization || "N/A"}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Registration Date</p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {if @member.registration_date,
                do: Calendar.strftime(@member.registration_date, "%B %d, %Y"),
                else: "N/A"}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Expiry Date</p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">
              {if @member.expiry_date,
                do: Calendar.strftime(@member.expiry_date, "%B %d, %Y"),
                else: "N/A"}
            </p>
          </div>

          <div>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Address</p>

            <p class="mt-1 text-base text-gray-900 dark:text-white">{@member.address || "N/A"}</p>
          </div>
        </div>
      </div>
      <%!-- Tabs --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow">
        <%!-- Tab Headers --%>
        <div class="border-b border-gray-200 dark:border-gray-700">
          <nav class="flex -mb-px">
            <button
              phx-click="change_tab"
              phx-value-tab="loan"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "loan",
                  do: "border-indigo-500 text-indigo-600 dark:text-indigo-400",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              Loan
            </button>
            <button
              phx-click="change_tab"
              phx-value-tab="current_loans"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "current_loans",
                  do: "border-indigo-500 text-indigo-600 dark:text-indigo-400",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              Current Loans ({length(@current_loans)})
            </button>
            <button
              phx-click="change_tab"
              phx-value-tab="reserve"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "reserve",
                  do: "border-indigo-500 text-indigo-600 dark:text-indigo-400",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              Reserve
            </button>
            <button
              phx-click="change_tab"
              phx-value-tab="fines"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "fines",
                  do: "border-indigo-500 text-indigo-600 dark:text-indigo-400",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              Fines ({length(@unpaid_fines)})
            </button>
            <button
              phx-click="change_tab"
              phx-value-tab="history"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "history",
                  do: "border-indigo-500 text-indigo-600 dark:text-indigo-400",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              Loan History
            </button>
          </nav>
        </div>
        <%!-- Tab Content --%>
        <div class="p-6">
          <%= if @active_tab == "loan" do %>
            {render_loan_tab(assigns)}
          <% end %>

          <%= if @active_tab == "current_loans" do %>
            {render_current_loans_tab(assigns)}
          <% end %>

          <%= if @active_tab == "reserve" do %>
            {render_reserve_tab(assigns)}
          <% end %>

          <%= if @active_tab == "fines" do %>
            {render_fines_tab(assigns)}
          <% end %>

          <%= if @active_tab == "history" do %>
            {render_history_tab(assigns)}
          <% end %>
        </div>
      </div>
    </div>
    <%!-- Modals --%>
    <%= if @show_modal do %>
      {render_modal(assigns)}
    <% end %>
    """
  end

  defp render_loan_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Search Item by Code
        </label>
        <form phx-submit="search_item" class="flex gap-2">
          <input
            type="text"
            name="item_code"
            value={@item_search_query}
            class="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-indigo-500 dark:bg-gray-700 dark:text-white"
            placeholder="Enter item code..."
          />
          <.button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-2">
            Loan
          </.button>
        </form>
      </div>

      <div>
        <h3 class="text-lg font-semibold mb-4 text-gray-900 dark:text-white">
          Items to Loan ({length(@temp_loans)})
        </h3>

        <%= if @temp_loans == [] do %>
          <div class="text-center py-12 text-gray-500 dark:text-gray-400">
            <.icon name="hero-book-open" class="w-16 h-16 mx-auto mb-4 opacity-50" />
            <p>No items added yet. Search and add items above.</p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Remove
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Item Code
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Title
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Loan Date
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Due Date
                  </th>
                </tr>
              </thead>

              <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                <tr :for={loan <- @temp_loans}>
                  <td class="px-6 py-4">
                    <button
                      phx-click="remove_temp_loan"
                      phx-value-item_id={loan.item.id}
                      class="text-red-600 hover:text-red-900 dark:hover:text-red-400"
                    >
                      <.icon name="hero-trash" class="w-5 h-5" />
                    </button>
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {loan.item.item_code}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {loan.item.collection.title}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {Calendar.strftime(loan.loan_date, "%B %d, %Y")}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {Calendar.strftime(loan.due_date, "%B %d, %Y")}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_current_loans_tab(assigns) do
    ~H"""
    <div>
      <%= if @current_loans == [] do %>
        <div class="text-center py-12 text-gray-500 dark:text-gray-400">
          <.icon name="hero-inbox" class="w-16 h-16 mx-auto mb-4 opacity-50" />
          <p>No active loans for this member.</p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead class="bg-gray-50 dark:bg-gray-700">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  Actions
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  Item Code
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  Title
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  Collection Type
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  Loan Date
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  Due Date
                </th>
              </tr>
            </thead>

            <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              <tr :for={transaction <- @current_loans}>
                <td class="px-6 py-4 flex gap-2">
                  <button
                    phx-click="show_return_modal"
                    phx-value-transaction_id={transaction.id}
                    class="bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded text-sm"
                  >
                    Return
                  </button>
                  <button
                    phx-click="show_extend_modal"
                    phx-value-transaction_id={transaction.id}
                    class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 rounded text-sm"
                  >
                    Extend
                  </button>
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {transaction.item.item_code}
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {transaction.item.collection.title}
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {transaction.item.collection.collection_type || "N/A"}
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {Calendar.strftime(transaction.transaction_date, "%B %d, %Y")}
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {Calendar.strftime(transaction.due_date, "%B %d, %Y")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_reserve_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Search Collection
        </label>
        <form phx-submit="search_collection" class="flex gap-2">
          <input
            type="text"
            name="query"
            value={@collection_search_query}
            class="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-indigo-500 dark:bg-gray-700 dark:text-white"
            placeholder="Search collections..."
          />
          <.button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-2">
            Search
          </.button>
        </form>
      </div>

      <div>
        <h3 class="text-lg font-semibold mb-4 text-gray-900 dark:text-white">
          Temporary Reservations ({length(@temp_reservations)})
        </h3>

        <%= if @temp_reservations == [] do %>
          <div class="text-center py-12 text-gray-500 dark:text-gray-400">
            <.icon name="hero-bookmark" class="w-16 h-16 mx-auto mb-4 opacity-50" />
            <p>No reservations added yet.</p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Remove
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Title
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Item Code
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Reserve Date
                  </th>
                </tr>
              </thead>

              <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                <tr :for={reservation <- @temp_reservations}>
                  <td class="px-6 py-4">
                    <button
                      phx-click="remove_temp_reservation"
                      phx-value-collection_id={reservation.collection.id}
                      class="text-red-600 hover:text-red-900 dark:hover:text-red-400"
                    >
                      <.icon name="hero-trash" class="w-5 h-5" />
                    </button>
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {reservation.collection.title}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {reservation.item_code || "Any available"}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {Calendar.strftime(reservation.reserve_date, "%B %d, %Y")}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_fines_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex gap-2">
        <.button phx-click="show_add_fine_modal" class="bg-indigo-600 hover:bg-indigo-700 text-white">
          Add New Fine
        </.button>
      </div>

      <div class="bg-blue-50 dark:bg-blue-900/20 rounded-lg p-4">
        <p class="text-sm font-medium text-blue-900 dark:text-blue-100">
          Total Unpaid Fines:
          <span class="text-lg font-bold">{format_currency(@total_unpaid_fines)}</span>
        </p>
      </div>

      <div>
        <%= if @unpaid_fines == [] do %>
          <div class="text-center py-12 text-gray-500 dark:text-gray-400">
            <.icon name="hero-currency-dollar" class="w-16 h-16 mx-auto mb-4 opacity-50" />
            <p>No unpaid fines.</p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Actions
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Description
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Fine Date
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Amount
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Paid
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Balance
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                    Status
                  </th>
                </tr>
              </thead>

              <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                <tr :for={fine <- @unpaid_fines}>
                  <td class="px-6 py-4 flex gap-2">
                    <button
                      phx-click="show_delete_fine_modal"
                      phx-value-fine_id={fine.id}
                      class="text-red-600 hover:text-red-900"
                      title="Delete"
                    >
                      <.icon name="hero-trash" class="w-5 h-5" />
                    </button>
                    <button
                      phx-click="show_pay_fine_modal"
                      phx-value-fine_id={fine.id}
                      class="text-green-600 hover:text-green-900"
                      title="Pay"
                    >
                      <.icon name="hero-currency-dollar" class="w-5 h-5" />
                    </button>
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {fine.description || fine.fine_type}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {Calendar.strftime(fine.fine_date, "%B %d, %Y")}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {format_currency(fine.amount)}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {format_currency(fine.paid_amount)}
                  </td>

                  <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                    {format_currency(fine.balance)}
                  </td>

                  <td class="px-6 py-4">
                    <span class={[
                      "px-2 py-1 text-xs rounded-full",
                      case fine.fine_status do
                        "pending" -> "bg-yellow-100 text-yellow-800"
                        "partial_paid" -> "bg-blue-100 text-blue-800"
                        "paid" -> "bg-green-100 text-green-800"
                        _ -> "bg-gray-100 text-gray-800"
                      end
                    ]}>
                      {fine.fine_status}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_history_tab(assigns) do
    ~H"""
    <div>
      <%= if @loan_history == [] do %>
        <div class="text-center py-12 text-gray-500 dark:text-gray-400">
          <.icon name="hero-clock" class="w-16 h-16 mx-auto mb-4 opacity-50" />
          <p>No loan history available.</p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead class="bg-gray-50 dark:bg-gray-700">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  Item Code
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  Title
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  Event
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                  Date
                </th>
              </tr>
            </thead>

            <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              <tr :for={history <- @loan_history}>
                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {(history.item && history.item.item_code) || "N/A"}
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {(history.item && history.item.collection && history.item.collection.title) || "N/A"}
                </td>

                <td class="px-6 py-4">
                  <span class={[
                    "px-2 py-1 text-xs rounded-full",
                    case history.event_type do
                      "loan" -> "bg-blue-100 text-blue-800"
                      "return" -> "bg-green-100 text-green-800"
                      _ -> "bg-gray-100 text-gray-800"
                    end
                  ]}>
                    {history.event_type}
                  </span>
                </td>

                <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                  {Calendar.strftime(history.event_date, "%B %d, %Y %H:%M")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_modal(assigns) do
    ~H"""
    <.modal id="transaction-modal" show on_cancel={JS.push("close_modal")}>
      <%= cond do %>
        <% @show_modal == "return" -> %>
          <div>
            <h3 class="text-lg font-semibold mb-4">Confirm Return</h3>

            <p class="mb-4">
              Are you sure you want to return item <strong>{@modal_data.transaction.item.item_code}</strong>?
            </p>

            <div class="flex gap-2 justify-end">
              <.button phx-click="close_modal" class="bg-gray-500 hover:bg-gray-600 text-white">
                Cancel
              </.button>
              <.button
                phx-click="confirm_return"
                phx-value-transaction_id={@modal_data.transaction.id}
                class="bg-green-600 hover:bg-green-700 text-white"
              >
                Confirm Return
              </.button>
            </div>
          </div>
        <% @show_modal == "extend" -> %>
          <div>
            <h3 class="text-lg font-semibold mb-4">Confirm Extend Loan</h3>

            <p class="mb-4">
              Are you sure you want to extend the loan for item <strong>{@modal_data.transaction.item.item_code}</strong>?
            </p>

            <div class="flex gap-2 justify-end">
              <.button phx-click="close_modal" class="bg-gray-500 hover:bg-gray-600 text-white">
                Cancel
              </.button>
              <.button
                phx-click="confirm_extend"
                phx-value-transaction_id={@modal_data.transaction.id}
                class="bg-blue-600 hover:bg-blue-700 text-white"
              >
                Confirm Extend
              </.button>
            </div>
          </div>
        <% @show_modal == "add_fine" -> %>
          <div>
            <h3 class="text-lg font-semibold mb-4">Add New Fine</h3>

            <form phx-submit="create_fine" class="space-y-4">
              <div>
                <label class="block text-sm font-medium mb-1">Fine Type</label>
                <select
                  name="fine_type"
                  class="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600"
                  required
                >
                  <option value="processing">Processing Fee</option>

                  <option value="damaged_item">Damaged Item</option>

                  <option value="lost_item">Lost Item</option>

                  <option value="overdue">Overdue</option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium mb-1">Description</label>
                <input
                  type="text"
                  name="description"
                  class="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium mb-1">Amount (Rp)</label>
                <input
                  type="number"
                  name="amount"
                  class="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600"
                  required
                />
              </div>

              <div class="flex gap-2 justify-end">
                <.button
                  type="button"
                  phx-click="close_modal"
                  class="bg-gray-500 hover:bg-gray-600 text-white"
                >
                  Cancel
                </.button>
                <.button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white">
                  Create Fine
                </.button>
              </div>
            </form>
          </div>
        <% @show_modal == "delete_fine" -> %>
          <div>
            <h3 class="text-lg font-semibold mb-4">Confirm Delete Fine</h3>

            <p class="mb-4">
              Are you sure you want to delete this fine of <strong>{format_currency(@modal_data.fine.amount)}</strong>?
            </p>

            <div class="flex gap-2 justify-end">
              <.button phx-click="close_modal" class="bg-gray-500 hover:bg-gray-600 text-white">
                Cancel
              </.button>
              <.button
                phx-click="confirm_delete_fine"
                phx-value-fine_id={@modal_data.fine.id}
                class="bg-red-600 hover:bg-red-700 text-white"
              >
                Confirm Delete
              </.button>
            </div>
          </div>
        <% @show_modal == "pay_fine" -> %>
          <div>
            <h3 class="text-lg font-semibold mb-4">Pay Fine</h3>

            <%= if @modal_data.pending_payment do %>
              <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4 mb-4">
                <h4 class="font-semibold text-blue-900 dark:text-blue-100 mb-2">
                  <.icon name="hero-link" class="w-5 h-5 inline" /> Payment Link Generated
                </h4>
                <p class="text-sm text-blue-700 dark:text-blue-200 mb-3">
                  A payment link has been created. Share this link with the member or use it to process online payment.
                </p>

                <div class="bg-white dark:bg-gray-800 rounded p-3 mb-3">
                  <div class="flex items-center gap-2">
                    <input
                      id="payment-link-input"
                      type="text"
                      value={@modal_data.pending_payment.payment_url}
                      readonly
                      class="flex-1 px-2 py-1 text-sm border rounded dark:bg-gray-700 dark:border-gray-600"
                    />
                    <.button
                      type="button"
                      phx-click={
                        JS.dispatch("voile:copy-to-clipboard",
                          to: "#payment-link-input",
                          detail: %{success_message: "Payment link copied!"}
                        )
                      }
                      class="bg-blue-600 hover:bg-blue-700 text-white text-sm px-3 py-1"
                    >
                      <.icon name="hero-clipboard-document" class="w-4 h-4" />
                    </.button>
                  </div>
                </div>

                <div class="grid grid-cols-2 gap-2 text-sm">
                  <div>
                    <span class="text-gray-600 dark:text-gray-400">Status:</span>
                    <span class="ml-2 font-medium">
                      {String.upcase(@modal_data.pending_payment.status)}
                    </span>
                  </div>
                  <div>
                    <span class="text-gray-600 dark:text-gray-400">Amount:</span>
                    <span class="ml-2 font-medium">
                      {format_currency(@modal_data.pending_payment.amount)}
                    </span>
                  </div>
                </div>

                <a
                  href={@modal_data.pending_payment.payment_url}
                  target="_blank"
                  class="mt-3 inline-block text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400"
                >
                  Open payment page
                  <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4 inline" />
                </a>
              </div>
            <% end %>

            <form phx-submit="confirm_pay_fine" class="space-y-4">
              <input type="hidden" name="fine_id" value={@modal_data.fine.id} />

              <%= if !@modal_data.pending_payment do %>
                <div class="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-3 mb-4">
                  <p class="text-sm text-yellow-800 dark:text-yellow-200">
                    <.icon name="hero-information-circle" class="w-5 h-5 inline mr-1" />
                    No payment link exists. Generate one for online payment or process cash payment below.
                  </p>
                  <.button
                    type="button"
                    phx-click="generate_payment_link"
                    phx-value-fine_id={@modal_data.fine.id}
                    class="mt-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm"
                  >
                    <.icon name="hero-link" class="w-4 h-4 mr-1" /> Generate Payment Link
                  </.button>
                </div>
              <% end %>

              <div>
                <label class="block text-sm font-medium mb-1">Amount to Pay</label>
                <input
                  type="number"
                  name="amount"
                  value={Decimal.to_string(@modal_data.fine.balance)}
                  class="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium mb-1">Payment Method</label>
                <select
                  name="payment_method"
                  class="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600"
                  required
                >
                  <option value="cash">Cash</option>
                  <option value="credit_card">Credit Card</option>
                  <option value="debit_card">Debit Card</option>
                  <option value="bank_transfer">Bank Transfer</option>
                  <option value="online">Online Payment</option>
                </select>
              </div>

              <div class="flex gap-2 justify-end">
                <.button
                  type="button"
                  phx-click="close_modal"
                  class="bg-gray-500 hover:bg-gray-600 text-white"
                >
                  Cancel
                </.button>
                <.button type="submit" class="bg-green-600 hover:bg-green-700 text-white">
                  Process Payment
                </.button>
              </div>
            </form>
          </div>
        <% @show_modal == "finish_transaction" -> %>
          <div>
            <h3 class="text-lg font-semibold mb-4">Finish Transaction</h3>

            <p class="mb-4">Are you sure you want to complete this transaction? This will process:</p>

            <ul class="list-disc list-inside mb-4 space-y-1">
              <li>{length(@temp_loans)} loan(s)</li>

              <li>{length(@temp_reservations)} reservation(s)</li>
            </ul>

            <div class="flex gap-2 justify-end">
              <.button phx-click="close_modal" class="bg-gray-500 hover:bg-gray-600 text-white">
                Cancel
              </.button>
              <.button
                phx-click="finish_transaction"
                class="bg-green-600 hover:bg-green-700 text-white"
              >
                Confirm & Finish
              </.button>
            </div>
          </div>
        <% true -> %>
          <div>Unknown modal</div>
      <% end %>
    </.modal>
    """
  end
end
