defmodule VoileWeb.Dashboard.Master.MemberTypeLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Master

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>{gettext("Manage membership types and entitlements.")}</:subtitle>
      </.header>

      <.form
        for={@form}
        id="member-type-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label={gettext("Name")} />
        <.input field={@form[:slug]} type="text" label={gettext("Slug")} />
        <.input field={@form[:description]} type="textarea" label={gettext("Description")} />
        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:max_items]} type="number" label={gettext("Max Items")} />
          <.input field={@form[:max_days]} type="number" label={gettext("Max Days")} />
          <.input field={@form[:max_renewals]} type="number" label={gettext("Max Renewals")} />
          <.input field={@form[:max_reserves]} type="number" label={gettext("Max Reserves")} />
          <.input
            field={@form[:max_concurrent_loans]}
            type="number"
            label={gettext("Max Concurrent Loans")}
          />
          <.input
            field={@form[:max_event_bookings_per_year]}
            type="number"
            label={gettext("Max Event Bookings / Year")}
          />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:fine_per_day]} type="text" label={gettext("Fine / Day")} />
          <.input field={@form[:max_fine]} type="text" label={gettext("Max Fine")} />
          <.input field={@form[:membership_fee]} type="text" label={gettext("Membership Fee")} />
          <.input field={@form[:currency]} type="text" label={gettext("Currency")} />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input
            field={@form[:ticket_discount_percent]}
            type="number"
            label={gettext("Ticket Discount %")}
          />
          <.input
            field={@form[:shop_discount_percent]}
            type="number"
            label={gettext("Shop Discount %")}
          />
          <.input
            field={@form[:membership_period_days]}
            type="number"
            label={gettext("Membership Period (days)")}
          />
          <.input field={@form[:priority_level]} type="number" label={gettext("Priority Level")} />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:auto_renew]} type="checkbox" label={gettext("Auto Renew")} />
          <.input field={@form[:can_reserve]} type="checkbox" label={gettext("Can Reserve")} />
          <.input field={@form[:can_renew]} type="checkbox" label={gettext("Can Renew")} />
          <.input field={@form[:digital_access]} type="checkbox" label={gettext("Digital Access")} />
        </div>

        <div class="mt-4 flex gap-3">
          <.button phx-disable-with={gettext("Saving...")}>{gettext("Save Member Type")}</.button>
          <.link patch={@patch} class="btn">{gettext("Cancel")}</.link>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{member_type: member_type} = assigns, socket) do
    changeset = Master.change_member_type(member_type)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn -> to_form(changeset) end)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"member_type" => params}, socket) do
    changeset = Master.change_member_type(socket.assigns.member_type, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"member_type" => params}, socket) do
    save_item(socket, socket.assigns.action, params)
  end

  defp save_item(socket, :edit, params) do
    case Master.update_member_type(socket.assigns.member_type, params) do
      {:ok, member_type} ->
        notify_parent({:saved, member_type})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Member type updated successfully."))
         |> push_navigate(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_item(socket, :new, params) do
    case Master.create_member_type(params) do
      {:ok, member_type} ->
        notify_parent({:saved, member_type})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Member type created successfully."))
         |> push_navigate(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
