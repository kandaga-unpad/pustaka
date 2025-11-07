defmodule VoileWeb.Dashboard.Catalog.Attachment.AccessComponent do
  use VoileWeb, :live_component

  alias Voile.Repo
  alias Voile.Catalog.AttachmentAccess
  alias Voile.Schema.Catalog.Attachment
  alias Voile.Schema.Accounts.User
  import Ecto.Query

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(%{attachment: attachment} = assigns, socket) do
    changeset = Attachment.access_control_changeset(attachment, %{}, assigns.current_user.id)

    # Get currently allowed role IDs and user IDs
    allowed_role_ids = Enum.map(attachment.allowed_roles, & &1.id)
    allowed_user_ids = Enum.map(attachment.allowed_users, & &1.id)

    socket =
      socket
      |> assign(assigns)
      |> assign(:changeset, changeset)
      |> assign(:allowed_role_ids, allowed_role_ids)
      |> assign(:allowed_user_ids, allowed_user_ids)
      |> assign(:user_search, "")
      |> assign(:user_search_results, [])
      |> assign(:access_summary, AttachmentAccess.get_access_summary(attachment))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"attachment" => params}, socket) do
    changeset =
      socket.assigns.attachment
      |> Attachment.access_control_changeset(params, socket.assigns.current_user.id)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save_access_level", %{"attachment" => params}, socket) do
    case AttachmentAccess.update_access_control(
           socket.assigns.attachment,
           params,
           socket.assigns.current_user
         ) do
      {:ok, attachment} ->
        # Reload with preloads
        attachment =
          Repo.preload(attachment, [:allowed_roles, :allowed_users, :access_settings_updated_by],
            force: true
          )

        send(self(), {:access_updated, attachment.id})

        {:noreply,
         socket
         |> assign(:attachment, attachment)
         |> assign(:access_summary, AttachmentAccess.get_access_summary(attachment))
         |> put_flash(:info, "Access level updated successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("toggle_role", %{"role-id" => role_id_str}, socket) do
    role_id = String.to_integer(role_id_str)
    attachment = socket.assigns.attachment
    allowed_role_ids = socket.assigns.allowed_role_ids

    updated_role_ids =
      if role_id in allowed_role_ids do
        # Revoke access
        AttachmentAccess.revoke_role_access(attachment.id, role_id)
        List.delete(allowed_role_ids, role_id)
      else
        # Grant access
        AttachmentAccess.grant_role_access(attachment.id, role_id)
        [role_id | allowed_role_ids]
      end

    # Reload attachment with updated associations
    attachment = Repo.preload(attachment, [:allowed_roles, :allowed_users], force: true)

    {:noreply,
     socket
     |> assign(:attachment, attachment)
     |> assign(:allowed_role_ids, updated_role_ids)
     |> assign(:access_summary, AttachmentAccess.get_access_summary(attachment))}
  end

  @impl true
  def handle_event("search_users", %{"search" => search}, socket) do
    results =
      if String.length(search) >= 2 do
        search_term = "%#{search}%"

        User
        |> where([u], ilike(u.email, ^search_term) or ilike(u.fullname, ^search_term))
        |> limit(10)
        |> Repo.all()
      else
        []
      end

    {:noreply, assign(socket, user_search: search, user_search_results: results)}
  end

  @impl true
  def handle_event("add_user", %{"user-id" => user_id}, socket) do
    attachment = socket.assigns.attachment
    allowed_user_ids = socket.assigns.allowed_user_ids

    user_id_binary = user_id

    unless user_id_binary in allowed_user_ids do
      AttachmentAccess.grant_user_access(
        attachment.id,
        user_id_binary,
        socket.assigns.current_user.id
      )

      allowed_user_ids = [user_id_binary | allowed_user_ids]

      # Reload attachment
      attachment = Repo.preload(attachment, [:allowed_users], force: true)

      {:noreply,
       socket
       |> assign(:attachment, attachment)
       |> assign(:allowed_user_ids, allowed_user_ids)
       |> assign(:user_search, "")
       |> assign(:user_search_results, [])
       |> assign(:access_summary, AttachmentAccess.get_access_summary(attachment))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_user", %{"user-id" => user_id}, socket) do
    attachment = socket.assigns.attachment
    allowed_user_ids = socket.assigns.allowed_user_ids

    user_id_binary = user_id

    AttachmentAccess.revoke_user_access(attachment.id, user_id_binary)
    allowed_user_ids = List.delete(allowed_user_ids, user_id_binary)

    # Reload attachment
    attachment = Repo.preload(attachment, [:allowed_users], force: true)

    {:noreply,
     socket
     |> assign(:attachment, attachment)
     |> assign(:allowed_user_ids, allowed_user_ids)
     |> assign(:access_summary, AttachmentAccess.get_access_summary(attachment))}
  end

  @impl true
  def handle_event("close", _, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.return_to)}
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end
end
