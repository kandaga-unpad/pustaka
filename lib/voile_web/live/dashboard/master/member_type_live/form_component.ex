defmodule VoileWeb.Dashboard.Master.MemberTypeLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Master

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Manage membership types and entitlements.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="member-type-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:slug]} type="text" label="Slug" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:max_items]} type="number" label="Max Items" />
          <.input field={@form[:max_days]} type="number" label="Max Days" />
          <.input field={@form[:max_renewals]} type="number" label="Max Renewals" />
          <.input field={@form[:max_reserves]} type="number" label="Max Reserves" />
          <.input field={@form[:max_concurrent_loans]} type="number" label="Max Concurrent Loans" />
          <.input
            field={@form[:max_event_bookings_per_year]}
            type="number"
            label="Max Event Bookings / Year"
          />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:fine_per_day]} type="text" label="Fine / Day" />
          <.input field={@form[:max_fine]} type="text" label="Max Fine" />
          <.input field={@form[:membership_fee]} type="text" label="Membership Fee" />
          <.input field={@form[:currency]} type="text" label="Currency" />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:ticket_discount_percent]} type="number" label="Ticket Discount %" />
          <.input field={@form[:shop_discount_percent]} type="number" label="Shop Discount %" />
          <.input
            field={@form[:membership_period_days]}
            type="number"
            label="Membership Period (days)"
          /> <.input field={@form[:priority_level]} type="number" label="Priority Level" />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:auto_renew]} type="checkbox" label="Auto Renew" />
          <.input field={@form[:can_reserve]} type="checkbox" label="Can Reserve" />
          <.input field={@form[:can_renew]} type="checkbox" label="Can Renew" />
          <.input field={@form[:digital_access]} type="checkbox" label="Digital Access" />
        </div>

        <div class="mt-4 flex gap-3">
          <.button phx-disable-with="Saving...">Save Member Type</.button>
          <.link patch={@patch} class="btn">Cancel</.link>
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
         |> put_flash(:info, "Member type updated successfully.")
         |> push_patch(to: socket.assigns.patch)}

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
         |> put_flash(:info, "Member type created successfully.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
