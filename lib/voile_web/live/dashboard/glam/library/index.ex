defmodule VoileWeb.Dashboard.Glam.Library.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog.{Collection, Item}

  import Ecto.Query
  import VoileWeb.Dashboard.Glam.Library.Circulation.Components
  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Accounts
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # global aggregates
    total_collections = get_library_total_collections(user)
    total_items = get_library_total_items(user)
    published_collections = get_library_published_collections(user)

    socket =
      socket
      |> assign(:page_title, "Library Dashboard")
      |> assign(:breadcrumb, [
        %{label: gettext("Manage"), path: "/manage"},
        %{label: gettext("GLAM"), path: "/manage/glam"},
        %{label: gettext("Library"), path: nil}
      ])
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
    <.voile_page_header
      eyebrow={gettext("GLAM · Library")}
      title={gettext("Library Management")}
      description={gettext("Manage library collections, circulation, and items")}
      icon="hero-book-open"
      tone={:glam_library}
    >
      <:actions>
        <.voile_button
          href="/manage/catalog/collections/new"
          tone={:glam_library}
          variant={:solid}
          size={:md}
        >
          <.icon name="hero-plus" class="w-4 h-4" /> {gettext("New collection")}
        </.voile_button>
      </:actions>
    </.voile_page_header>

    <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 md:gap-4 mb-6">
      <.voile_stat_card
        label={gettext("Total collections")}
        value={@total_collections}
        icon="hero-rectangle-stack"
        tone={:glam_library}
      />
      <.voile_stat_card
        label={gettext("Total items")}
        value={@total_items}
        icon="hero-cube"
        tone={:glam_library}
      />
      <.voile_stat_card
        label={gettext("Published")}
        value={@published_collections}
        icon="hero-check-badge"
        tone={:success}
      />
    </div>

    <.voile_section_card title={gettext("Quick checkout / return")} icon="hero-bolt" tone={:brand}>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <.voile_button
          tone={:success}
          variant={:solid}
          size={:lg}
          phx-click="show_quick_checkout"
          class="w-full"
        >
          <.icon name="hero-arrow-right-circle" class="w-5 h-5" />
          <span>{gettext("Quick checkout")}</span>
        </.voile_button>
        <.voile_button
          tone={:warning}
          variant={:solid}
          size={:lg}
          phx-click="show_quick_return"
          class="w-full"
        >
          <.icon name="hero-arrow-left-circle" class="w-5 h-5" />
          <span>{gettext("Quick return")}</span>
        </.voile_button>
      </div>
    </.voile_section_card>

    <.voile_section_card
      title={gettext("Quick actions")}
      icon="hero-rectangle-group"
      tone={:glam_library}
    >
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-2">
        <.voile_action_link
          icon="hero-rectangle-stack"
          tone={:glam_library}
          label={gettext("View collections")}
          description={gettext("Browse all library collections")}
          href="/manage/catalog/collections?glam_type=Library"
        />
        <.voile_action_link
          icon="hero-plus-circle"
          tone={:success}
          label={gettext("New collection")}
          description={gettext("Create a new library collection")}
          href="/manage/catalog/collections/new"
        />
        <.voile_action_link
          icon="hero-cube"
          tone={:info}
          label={gettext("View items")}
          description={gettext("Browse all library items")}
          href="/manage/catalog/items?glam_type=Library"
        />
      </div>
    </.voile_section_card>

    <.voile_section_card title={gettext("Library operations")} icon="hero-cog-6-tooth" tone={:brand}>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2">
        <%= if Authorization.is_super_admin?(@user) do %>
          <.voile_action_link
            icon="hero-arrow-path"
            tone={:warning}
            label={gettext("Manage circulations")}
            description={gettext("View and manage book circulations")}
            href="/manage/glam/library/circulation"
          />
        <% end %>
        <.voile_action_link
          icon="hero-chart-bar"
          tone={:brand}
          label={gettext("Circulation report")}
          description={gettext("View circulation statistics and activity")}
          href="/manage/glam/library/circulation/report"
        />
        <.voile_action_link
          icon="hero-document-arrow-down"
          tone={:success}
          label={gettext("Start transaction")}
          description={gettext("Start a new transaction or return a book")}
          href="/manage/glam/library/ledger"
        />
        <.voile_action_link
          icon="hero-eye"
          tone={:info}
          label={gettext("Read on spot")}
          description={gettext("Track items read or used in-library")}
          href="/manage/glam/library/read_on_spot"
        />
        <.voile_action_link
          icon="hero-book-open"
          tone={:success}
          label={gettext("Loan reminders")}
          description={gettext("View and manage loan reminders for library items")}
          href="/manage/glam/library/circulation/loan_reminders"
        />
        <.voile_action_link
          icon="hero-clipboard-document-list"
          tone={:info}
          label={gettext("Requisitions")}
          description={gettext("Manage book and resource acquisition requests")}
          href="/manage/glam/library/requisitions"
        />
      </div>
    </.voile_section_card>

    <%!-- Quick Modals (re-use circulation components) --%>
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

  defp get_library_total_collections(user) do
    base_q =
      from(c in Collection,
        join: rc in assoc(c, :resource_class),
        where: rc.glam_type == "Library"
      )

    q =
      if Authorization.is_super_admin?(user) do
        base_q
      else
        from(c in base_q, where: c.unit_id == ^user.node_id)
      end

    Repo.aggregate(q, :count, :id)
  end

  defp get_library_total_items(user) do
    if Authorization.is_super_admin?(user) do
      from(i in Item,
        join: c in assoc(i, :collection),
        join: rc in assoc(c, :resource_class),
        where: rc.glam_type == "Library"
      )
      |> Repo.aggregate(:count, :id)
    else
      from(i in Item,
        join: c in assoc(i, :collection),
        join: rc in assoc(c, :resource_class),
        where: rc.glam_type == "Library" and c.unit_id == ^user.node_id
      )
      |> Repo.aggregate(:count, :id)
    end
  end

  defp get_library_published_collections(user) do
    base_q =
      from(c in Collection,
        join: rc in assoc(c, :resource_class),
        where: rc.glam_type == "Library" and c.status == "published"
      )

    q =
      if Authorization.is_super_admin?(user) do
        base_q
      else
        from(c in base_q, where: c.unit_id == ^user.node_id)
      end

    Repo.aggregate(q, :count, :id)
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
            case Voile.Schema.Catalog.get_item_by_code_or_barcode(item_id) do
              nil ->
                socket =
                  socket
                  |> assign(:quick_checkout_visible, false)
                  |> assign(:checkout_form, to_form(%{}))
                  |> put_flash(:error, "Item not found")

                {:noreply, socket}

              item ->
                # Preload node for rule resolution
                item = Repo.preload(item, :node)

                # Validate item is available (check availability field, not status)
                if item.availability != "available" do
                  {:noreply,
                   put_flash(
                     socket,
                     :error,
                     "Item is not available for checkout (currently: #{item.availability})"
                   )}
                else
                  librarian = socket.assigns.current_scope.user.id

                  case Circulation.checkout_item(member.id, item.id, librarian, %{node: item.node}) do
                    {:ok, transaction} ->
                      # Preload for display
                      transaction = Repo.preload(transaction, [:member, item: [:collection]])

                      socket =
                        socket
                        |> assign(:quick_checkout_visible, false)
                        |> assign(:checkout_form, to_form(%{}))
                        |> put_flash(
                          :info,
                          "✓ Checked out to #{member.fullname} - Due: #{Calendar.strftime(transaction.due_date, "%b %d, %Y")}"
                        )

                      {:noreply, socket}

                    {:error, reason} when is_binary(reason) ->
                      {:noreply, put_flash(socket, :error, reason)}

                    {:error, changeset} ->
                      error_msg =
                        changeset
                        |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
                        |> Enum.map(fn {field, errors} ->
                          "#{field}: #{Enum.join(errors, ", ")}"
                        end)
                        |> Enum.join("; ")

                      {:noreply, put_flash(socket, :error, "Checkout failed: #{error_msg}")}
                  end
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
    case Voile.Schema.Catalog.get_item_by_code_or_barcode(item_code) do
      nil ->
        socket =
          socket
          |> assign(:quick_return_visible, false)
          |> assign(:return_form, to_form(%{}))
          |> assign(:quick_return_transaction, nil)
          |> assign(:quick_return_predicted_fine, Decimal.new("0"))
          |> put_flash(:error, "Item not found")

        {:noreply, socket}

      item ->
        case Circulation.get_active_transaction_by_item(item.id) do
          nil ->
            {:noreply, put_flash(socket, :error, "No active transaction found for this item")}

          transaction ->
            # Preload associations for fine calculation
            transaction = Repo.preload(transaction, [:member, item: :node])
            member = transaction.member
            member = Repo.preload(member, :user_type)

            # Calculate predicted fine using circulation helper with node rules
            predicted_fine =
              if Voile.Schema.Library.Transaction.overdue?(transaction) do
                Circulation.calculate_fine_amount(
                  transaction,
                  member.user_type,
                  node: transaction.item.node
                )
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

    transaction = Circulation.get_transaction!(transaction_id) |> Repo.preload(item: :node)

    case Circulation.return_item(transaction_id, current_user_id, %{node: transaction.item.node}) do
      {:ok, _returned_transaction} ->
        socket =
          socket
          |> assign(:quick_return_visible, false)
          |> assign(:return_form, to_form(%{}))
          |> assign(:quick_return_transaction, nil)
          |> assign(:quick_return_predicted_fine, Decimal.new("0"))

        # Handle fine payment if amount provided
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
                  {:ok, _} ->
                    put_flash(
                      socket,
                      :info,
                      "✓ Item returned and fine of #{payment_amount_decimal} #{fine.currency || "IDR"} paid"
                    )

                  {:error, _} ->
                    put_flash(
                      socket,
                      :warning,
                      "✓ Item returned but fine payment failed. Please process payment separately."
                    )
                end

              _ ->
                put_flash(socket, :info, "✓ Item returned successfully")
            end
          else
            # Check if there's an unpaid fine to notify about
            case Circulation.get_fine_by_transaction(transaction_id) do
              {:ok, fine} when fine.status == "pending" ->
                put_flash(
                  socket,
                  :info,
                  "✓ Item returned. Fine of #{fine.amount} #{fine.currency || "IDR"} pending payment."
                )

              _ ->
                put_flash(socket, :info, "✓ Item returned successfully")
            end
          end

        {:noreply, socket}

      {:error, error} ->
        error_message =
          cond do
            is_binary(error) ->
              error

            is_struct(error, Ecto.Changeset) and error.errors != %{} ->
              errors =
                error
                |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
                |> Enum.map(fn {field, messages} ->
                  "#{field}: #{Enum.join(messages, ", ")}"
                end)
                |> Enum.join(", ")

              "Failed to return: #{errors}"

            true ->
              "Failed to return: Unknown error"
          end

        {:noreply, put_flash(socket, :error, error_message)}
    end
  end
end
