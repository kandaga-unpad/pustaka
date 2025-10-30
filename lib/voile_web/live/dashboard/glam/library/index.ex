defmodule VoileWeb.Dashboard.Glam.Library.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog.{Collection, Item}

  import Ecto.Query
  import VoileWeb.Dashboard.Glam.Library.Circulation.Components
  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # preview collection list (limited)
    preview_collections = get_library_collections()

    # global aggregates
    total_collections = get_library_total_collections()
    total_items = get_library_total_items()
    published_collections = get_library_published_collections()

    socket =
      socket
      |> assign(:page_title, "Library Dashboard")
      |> assign(:library_collections, preview_collections)
      |> assign(:total_collections, total_collections)
      |> assign(:total_items, total_items)
      |> assign(:published_collections, published_collections)
      |> assign(:user, user)
      |> assign(:quick_checkout_visible, false)
      |> assign(:checkout_form, to_form(%{}))
      |> assign(:quick_return_visible, false)
      |> assign(:return_form, to_form(%{}))
      |> assign(:quick_return_transaction, nil)
      |> assign(:quick_return_predicted_fine, Decimal.new("0"))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Breadcrumb --%>
      <.breadcrumb items={[
        %{label: "Manage", path: ~p"/manage"},
        %{label: "GLAM", path: ~p"/manage/glam"},
        %{label: "Library", path: nil}
      ]} /> <%!-- Page Header --%>
      <div class="bg-gradient-to-r from-indigo-600 to-blue-600 rounded-xl p-8 text-white shadow-lg">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold mb-2">Library Management</h1>

            <p class="text-white text-lg">Manage library collections, circulation, and items</p>
          </div>

          <div class="hidden md:block">
            <.icon name="hero-book-open" class="w-24 h-24 opacity-20" />
          </div>
        </div>
      </div>
      <%!-- Quick Actions --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <.link
          navigate="/manage/catalog/collections?glam_type=Library"
          class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow hover:shadow-lg transition-shadow"
        >
          <div class="flex items-center gap-4">
            <div class="p-3 rounded-lg bg-voile-info/10 dark:bg-voile-info/30">
              <.icon
                name="hero-rectangle-stack"
                class="w-6 h-6 text-voile-info dark:text-voile-info/60"
              />
            </div>

            <div>
              <h4 class="font-semibold text-gray-900 dark:text-white">View Collections</h4>

              <p class="text-sm text-gray-600 dark:text-gray-400">Browse all library collections</p>
            </div>
          </div>
        </.link>
        <.link
          navigate="/manage/catalog/collections/new"
          class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow hover:shadow-lg transition-shadow"
        >
          <div class="flex items-center gap-4">
            <div class="p-3 rounded-lg bg-voile-success/10 dark:bg-voile-success/30">
              <.icon
                name="hero-plus-circle"
                class="w-6 h-6 text-voile-success dark:text-voile-success/60"
              />
            </div>

            <div>
              <h4 class="font-semibold text-gray-900 dark:text-white">New Collection</h4>

              <p class="text-sm text-gray-600 dark:text-gray-400">Create a new library collection</p>
            </div>
          </div>
        </.link>
        <.link
          navigate="/manage/catalog/items?glam_type=Library"
          class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow hover:shadow-lg transition-shadow"
        >
          <div class="flex items-center gap-4">
            <div class="p-3 rounded-lg bg-voile-info/10 dark:bg-voile-info/30">
              <.icon name="hero-cube" class="w-6 h-6 text-voile-info dark:text-voile-info/60" />
            </div>

            <div>
              <h4 class="font-semibold text-gray-900 dark:text-white">View Items</h4>

              <p class="text-sm text-gray-600 dark:text-gray-400">Browse all library items</p>
            </div>
          </div>
        </.link>
      </div>
      <%!-- Statistics --%>
      <div class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow">
        <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">Library Statistics</h2>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="text-center">
            <div class="text-2xl font-bold text-voile-info dark:text-voile-info/60">
              {@total_collections}
            </div>

            <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">Total Collections</div>
          </div>

          <div class="text-center">
            <div class="text-2xl font-bold text-voile-info dark:text-voile-info/60">
              {@total_items}
            </div>

            <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">Total Items</div>
          </div>

          <div class="text-center">
            <div class="text-2xl font-bold text-voile-primary dark:text-voile-primary/60">
              {@published_collections}
            </div>

            <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">Published</div>
          </div>
        </div>
      </div>
      <%!-- Library Operationals --%>
      <div class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow">
        <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">Library Operations</h2>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <.link
            navigate="/manage/glam/library/circulation"
            class="bg-gray-200 dark:bg-gray-600 rounded-xl p-6 shadow hover:shadow-lg transition-shadow"
          >
            <div class="flex items-center justify-center gap-4 w-full h-full">
              <div class="p-3 rounded-lg bg-yellow-100 dark:bg-yellow-900/30">
                <.icon name="hero-arrow-path" class="w-6 h-6 text-yellow-600 dark:text-yellow-400" />
              </div>

              <div>
                <h5 class="font-semibold text-gray-900 dark:text-white">Manage Circulations</h5>

                <p class="text-sm text-gray-600 dark:text-gray-400">
                  View and manage book circulations
                </p>
              </div>
            </div>
          </.link>
          <.link
            navigate="/manage/glam/library/ledger"
            class="bg-gray-200 dark:bg-gray-600 rounded-xl p-6 shadow hover:shadow-lg transition-shadow"
          >
            <div class="flex items-center justify-center gap-4 w-full h-full">
              <div class="p-3 rounded-lg bg-green-100 dark:bg-green-900/30">
                <.icon
                  name="hero-document-arrow-down"
                  class="w-6 h-6 text-green-600 dark:text-green-400"
                />
              </div>

              <div>
                <h5 class="font-semibold text-gray-900 dark:text-white">Start Transaction</h5>

                <p class="text-sm text-gray-600 dark:text-gray-400">
                  Start a new transaction or return a book
                </p>
              </div>
            </div>
          </.link>
          <div class="bg-gray-200 dark:bg-gray-600 rounded-xl p-6 shadow">
            <div class="w-full flex flex-col items-center gap-4">
              <button phx-click="show_quick_checkout" class="w-full btn btn-success p-5 rounded-lg">
                <span class="flex items-center gap-2">
                  <.icon
                    name="hero-arrow-right-circle"
                    class="w-6 h-6"
                  /> <span>Quick Checkout</span>
                </span>
              </button>
              <button phx-click="show_quick_return" class="w-full btn btn-warning p-5 rounded-lg">
                <span class="flex items-center gap-2">
                  <.icon
                    name="hero-arrow-left-circle"
                    class="w-6 h-6"
                  /> <span>Quick Return</span>
                </span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    <!-- Quick Modals (re-use circulation components) -->
    <.quick_checkout_modal
      quick_checkout_visible={@quick_checkout_visible}
      checkout_form={@checkout_form}
    />
    <.quick_return_modal
      quick_return_visible={@quick_return_visible}
      return_form={@return_form}
      quick_return_transaction={@quick_return_transaction}
      quick_return_predicted_fine={@quick_return_predicted_fine}
    />
    """
  end

  defp get_library_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Library",
      order_by: [desc: c.inserted_at],
      limit: 50,
      preload: [:resource_class, :items]
    )
    |> Repo.all()
  end

  defp get_library_total_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Library"
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_library_total_items do
    from(i in Item,
      join: c in assoc(i, :collection),
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Library"
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_library_published_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Library" and c.status == "published"
    )
    |> Repo.aggregate(:count, :id)
  end

  ### Quick Checkout / Return Handlers (reuse circulation logic where applicable)

  @impl true
  def handle_event("show_quick_checkout", _params, socket) do
    # permission check: reuse can? helper if available, otherwise allow
    if function_exported?(__MODULE__, :can?, 2) do
      if can?(socket, "circulation.checkout") do
        {:noreply, assign(socket, :quick_checkout_visible, true)}
      else
        {:noreply, put_flash(socket, :error, "You don't have permission to checkout items")}
      end
    else
      {:noreply, assign(socket, :quick_checkout_visible, true)}
    end
  end

  @impl true
  def handle_event("cancel_quick_checkout", _params, socket) do
    socket =
      socket
      |> assign(:quick_checkout_visible, false)
      |> assign(:checkout_form, to_form(%{}))

    {:noreply, socket}
  end

  @impl true
  def handle_event("quick_checkout_submit", params, socket) do
    member_id = Map.get(params, "member_id", "")
    item_id = Map.get(params, "item_id", "")

    cond do
      member_id == "" ->
        {:noreply, put_flash(socket, :error, "Member identifier is required")}

      item_id == "" ->
        {:noreply, put_flash(socket, :error, "Item code is required")}

      true ->
        case Accounts.get_user_by_identifier(member_id) do
          nil ->
            {:noreply, put_flash(socket, :error, "Member not found")}

          member ->
            case Voile.Schema.Catalog.get_item_by_code(item_id) do
              nil ->
                {:noreply, put_flash(socket, :error, "Item not found")}

              item ->
                librarian = socket.assigns.current_scope.user.id

                case Circulation.checkout_item(member.id, item.id, librarian) do
                  {:ok, _transaction} ->
                    socket =
                      socket
                      |> assign(:quick_checkout_visible, false)
                      |> assign(:checkout_form, to_form(%{}))
                      |> put_flash(:info, "Item checked out successfully")

                    {:noreply, socket}

                  {:error, changeset} ->
                    errors =
                      changeset
                      |> Map.get(:errors, [])
                      |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
                      |> Enum.join(", ")

                    {:noreply, put_flash(socket, :error, "Failed to checkout: #{errors}")}
                end
            end
        end
    end
  end

  @impl true
  def handle_event("show_quick_return", _params, socket) do
    if function_exported?(__MODULE__, :can?, 2) do
      if can?(socket, "circulation.return") do
        {:noreply, assign(socket, :quick_return_visible, true)}
      else
        {:noreply, put_flash(socket, :error, "You don't have permission to return items")}
      end
    else
      {:noreply, assign(socket, :quick_return_visible, true)}
    end
  end

  @impl true
  def handle_event("cancel_quick_return", _params, socket) do
    socket =
      socket
      |> assign(:quick_return_visible, false)
      |> assign(:return_form, to_form(%{}))
      |> assign(:quick_return_transaction, nil)
      |> assign(:quick_return_predicted_fine, Decimal.new("0"))

    {:noreply, socket}
  end

  @impl true
  def handle_event("quick_return_search", %{"item_code" => item_code}, socket) do
    case Voile.Schema.Catalog.get_item_by_code(item_code) do
      nil ->
        {:noreply, put_flash(socket, :error, "Item not found")}

      item ->
        case Circulation.get_active_transaction_by_item(item.id) do
          nil ->
            {:noreply, put_flash(socket, :error, "No active transaction found for this item")}

          transaction ->
            member = Accounts.get_user!(transaction.member_id)

            predicted_fine =
              if Voile.Schema.Library.Transaction.overdue?(transaction) do
                days = Voile.Schema.Library.Transaction.days_overdue(transaction)
                daily = member.user_type.fine_per_day || Decimal.new("1.00")
                Decimal.mult(Decimal.new(days), daily)
              else
                Decimal.new("0")
              end

            socket =
              socket
              |> assign(:quick_return_transaction, transaction)
              |> assign(:quick_return_predicted_fine, predicted_fine)

            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("quick_return_confirm", params, socket) do
    transaction_id = Map.get(params, "transaction_id")
    payment_amount = Map.get(params, "payment_amount", "0")
    payment_method = Map.get(params, "payment_method", "cash")
    current_user_id = socket.assigns.current_scope.user.id

    payment_amount_decimal =
      case Decimal.parse(payment_amount) do
        {dec, _rest} when is_struct(dec) -> dec
        :error -> Decimal.new("0")
      end

    case Circulation.return_item(transaction_id, current_user_id) do
      {:ok, _transaction} ->
        socket =
          socket
          |> assign(:quick_return_visible, false)
          |> assign(:return_form, to_form(%{}))
          |> assign(:quick_return_transaction, nil)
          |> assign(:quick_return_predicted_fine, Decimal.new("0"))

        socket =
          if Decimal.compare(payment_amount_decimal, Decimal.new("0")) == :gt do
            case Circulation.get_fine_by_transaction(transaction_id) do
              {:ok, fine} ->
                case Circulation.pay_fine(
                       fine.id,
                       payment_amount_decimal,
                       payment_method,
                       current_user_id
                     ) do
                  {:ok, _} -> put_flash(socket, :info, "Item returned and fine paid successfully")
                  {:error, _} -> put_flash(socket, :info, "Item returned (fine payment failed)")
                end

              _ ->
                put_flash(socket, :info, "Item returned successfully")
            end
          else
            put_flash(socket, :info, "Item returned successfully")
          end

        {:noreply, socket}

      {:error, changeset} ->
        errors =
          changeset
          |> Map.get(:errors, [])
          |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
          |> Enum.join(", ")

        {:noreply, put_flash(socket, :error, "Failed to return: #{errors}")}
    end
  end
end
