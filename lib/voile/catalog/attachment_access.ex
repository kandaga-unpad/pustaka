defmodule Voile.Catalog.AttachmentAccess do
  @moduledoc """
  Context module for handling attachment access control.
  Provides functions to check permissions, manage access lists, and handle embargos.
  """

  import Ecto.Query
  alias Voile.Repo
  alias Voile.Schema.Catalog.Attachment
  alias Voile.Schema.Catalog.AttachmentRoleAccess
  alias Voile.Schema.Catalog.AttachmentUserAccess
  alias Voile.Schema.Accounts.User

  @doc """
  Check if a user can access an attachment based on:
  - Access level (public, limited, restricted)
  - Embargo dates
  - Role-based access
  - User-specific access
  - Super admin override

  ## Examples

      iex> can_access?(attachment, user)
      true

      iex> can_access?(attachment, nil)
      false  # For restricted content

  """
  def can_access?(%Attachment{} = attachment, user \\ nil) do
    cond do
      # Super admin always has access
      is_super_admin?(user) ->
        true

      # Check embargo first
      not is_embargo_passed?(attachment) ->
        false

      # Public attachments are accessible to everyone
      attachment.access_level == "public" ->
        true

      # Restricted attachments are only for super admins
      attachment.access_level == "restricted" ->
        false

      # Limited access requires authentication and specific permissions
      attachment.access_level == "limited" and is_nil(user) ->
        false

      attachment.access_level == "limited" ->
        has_limited_access?(attachment, user)

      # Default deny
      true ->
        false
    end
  end

  @doc """
  Check if embargo period has passed for an attachment.
  Returns true if the attachment is accessible based on embargo dates.
  """
  def is_embargo_passed?(%Attachment{} = attachment, current_datetime \\ nil) do
    now = current_datetime || DateTime.utc_now() |> DateTime.truncate(:second)

    start_passed =
      is_nil(attachment.embargo_start_date) or
        DateTime.compare(now, attachment.embargo_start_date) in [:gt, :eq]

    end_not_reached =
      is_nil(attachment.embargo_end_date) or
        DateTime.compare(now, attachment.embargo_end_date) in [:lt, :eq]

    start_passed and end_not_reached
  end

  @doc """
  Check if user is a super admin.
  """
  def is_super_admin?(nil), do: false

  def is_super_admin?(%User{} = user) do
    user = Repo.preload(user, :roles)
    Enum.any?(user.roles, fn role -> role.name == "super_admin" end)
  end

  @doc """
  Check if user has limited access to an attachment.
  This checks both role-based and user-specific access.
  """
  def has_limited_access?(%Attachment{id: attachment_id}, %User{id: user_id} = user) do
    # Check user-specific access
    user_has_access =
      from(aua in AttachmentUserAccess,
        where: aua.attachment_id == ^attachment_id and aua.user_id == ^user_id
      )
      |> Repo.exists?()

    if user_has_access do
      true
    else
      # Check role-based access
      user = Repo.preload(user, :roles)
      role_ids = Enum.map(user.roles, & &1.id)

      if role_ids == [] do
        false
      else
        from(ara in AttachmentRoleAccess,
          where: ara.attachment_id == ^attachment_id and ara.role_id in ^role_ids
        )
        |> Repo.exists?()
      end
    end
  end

  def has_limited_access?(_attachment, _user), do: false

  @doc """
  Update access control settings for an attachment.
  """
  def update_access_control(%Attachment{} = attachment, attrs, %User{id: user_id}) do
    attachment
    |> Attachment.access_control_changeset(attrs, user_id)
    |> Repo.update()
  end

  @doc """
  Grant role-based access to an attachment.
  """
  def grant_role_access(attachment_id, role_id) do
    %AttachmentRoleAccess{}
    |> AttachmentRoleAccess.changeset(%{
      attachment_id: attachment_id,
      role_id: role_id
    })
    |> Repo.insert()
  end

  @doc """
  Grant user-specific access to an attachment.
  """
  def grant_user_access(attachment_id, user_id, granted_by_user_id) do
    %AttachmentUserAccess{}
    |> AttachmentUserAccess.create_changeset(%{
      attachment_id: attachment_id,
      user_id: user_id,
      granted_by_id: granted_by_user_id
    })
    |> Repo.insert()
  end

  @doc """
  Revoke role-based access from an attachment.
  """
  def revoke_role_access(attachment_id, role_id) do
    from(ara in AttachmentRoleAccess,
      where: ara.attachment_id == ^attachment_id and ara.role_id == ^role_id
    )
    |> Repo.delete_all()
  end

  @doc """
  Revoke user-specific access from an attachment.
  """
  def revoke_user_access(attachment_id, user_id) do
    from(aua in AttachmentUserAccess,
      where: aua.attachment_id == ^attachment_id and aua.user_id == ^user_id
    )
    |> Repo.delete_all()
  end

  @doc """
  List all roles that have access to an attachment.
  """
  def list_allowed_roles(attachment_id) do
    attachment = Repo.get!(Attachment, attachment_id)
    Repo.preload(attachment, :allowed_roles).allowed_roles
  end

  @doc """
  List all users that have specific access to an attachment.
  """
  def list_allowed_users(attachment_id) do
    attachment = Repo.get!(Attachment, attachment_id)
    Repo.preload(attachment, :allowed_users).allowed_users
  end

  @doc """
  Bulk grant role access to multiple attachments.
  """
  def bulk_grant_role_access(attachment_ids, role_id) when is_list(attachment_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(attachment_ids, fn attachment_id ->
        %{
          id: Ecto.UUID.generate(),
          attachment_id: attachment_id,
          role_id: role_id,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(AttachmentRoleAccess, entries, on_conflict: :nothing)
  end

  @doc """
  Bulk grant user access to multiple attachments.
  """
  def bulk_grant_user_access(attachment_ids, user_id, granted_by_user_id)
      when is_list(attachment_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(attachment_ids, fn attachment_id ->
        %{
          id: Ecto.UUID.generate(),
          attachment_id: attachment_id,
          user_id: user_id,
          granted_by_id: granted_by_user_id,
          granted_at: now,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(AttachmentUserAccess, entries, on_conflict: :nothing)
  end

  @doc """
  Filter a query to only return attachments accessible by the user.
  Useful for listing attachments with proper access control.
  """
  def accessible_by(query, user \\ nil) do
    cond do
      is_super_admin?(user) ->
        # Super admins see everything
        query

      is_nil(user) ->
        # Anonymous users only see public, non-embargoed attachments
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        from a in query,
          where: a.access_level == "public",
          where: is_nil(a.embargo_start_date) or a.embargo_start_date <= ^now,
          where: is_nil(a.embargo_end_date) or a.embargo_end_date >= ^now

      true ->
        # Authenticated users see public + their limited access
        user = Repo.preload(user, :roles)
        role_ids = Enum.map(user.roles, & &1.id)
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        from a in query,
          left_join: ara in AttachmentRoleAccess,
          on: ara.attachment_id == a.id and ara.role_id in ^role_ids,
          left_join: aua in AttachmentUserAccess,
          on: aua.attachment_id == a.id and aua.user_id == ^user.id,
          # Public content
          # Limited content with role access
          # Limited content with user access
          where:
            a.access_level == "public" or
              (a.access_level == "limited" and not is_nil(ara.id)) or
              (a.access_level == "limited" and not is_nil(aua.id)),
          where: is_nil(a.embargo_start_date) or a.embargo_start_date <= ^now,
          where: is_nil(a.embargo_end_date) or a.embargo_end_date >= ^now,
          distinct: true
    end
  end

  @doc """
  Get access summary for an attachment.
  Returns a map with access control details.
  """
  def get_access_summary(%Attachment{} = attachment) do
    attachment =
      attachment
      |> Repo.preload([:allowed_roles, :allowed_users, :access_settings_updated_by])

    %{
      access_level: attachment.access_level,
      embargo_start_date: attachment.embargo_start_date,
      embargo_end_date: attachment.embargo_end_date,
      is_under_embargo: not is_embargo_passed?(attachment),
      allowed_roles: Enum.map(attachment.allowed_roles, &%{id: &1.id, name: &1.name}),
      allowed_users:
        Enum.map(attachment.allowed_users, &%{id: &1.id, email: &1.email, fullname: &1.fullname}),
      last_updated_by:
        if attachment.access_settings_updated_by do
          %{
            id: attachment.access_settings_updated_by.id,
            email: attachment.access_settings_updated_by.email,
            fullname: attachment.access_settings_updated_by.fullname
          }
        else
          nil
        end,
      last_updated_at: attachment.access_settings_updated_at
    }
  end
end
