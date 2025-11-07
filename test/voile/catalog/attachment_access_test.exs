defmodule Voile.Catalog.AttachmentAccessTest do
  use Voile.DataCase, async: true

  alias Voile.Catalog.AttachmentAccess
  alias Voile.Schema.Catalog.Attachment
  alias Voile.Schema.Accounts.{User, Role}

  describe "can_access?/2" do
    test "public attachments are accessible to everyone" do
      attachment = insert(:attachment, access_level: "public")

      assert AttachmentAccess.can_access?(attachment, nil)
      assert AttachmentAccess.can_access?(attachment, insert(:user))
    end

    test "restricted attachments are only accessible to super_admin" do
      attachment = insert(:attachment, access_level: "restricted")
      regular_user = insert(:user)
      super_admin = insert(:user)
      super_admin_role = insert(:role, name: "super_admin")
      insert(:user_role_assignment, user: super_admin, role: super_admin_role)

      refute AttachmentAccess.can_access?(attachment, nil)
      refute AttachmentAccess.can_access?(attachment, regular_user)
      assert AttachmentAccess.can_access?(attachment, super_admin)
    end

    test "limited attachments require authentication" do
      attachment = insert(:attachment, access_level: "limited")

      refute AttachmentAccess.can_access?(attachment, nil)
    end

    test "limited attachments with role access" do
      attachment = insert(:attachment, access_level: "limited")
      role = insert(:role, name: "staff")
      user_with_role = insert(:user)
      insert(:user_role_assignment, user: user_with_role, role: role)
      user_without_role = insert(:user)

      AttachmentAccess.grant_role_access(attachment.id, role.id)

      assert AttachmentAccess.can_access?(attachment, user_with_role)
      refute AttachmentAccess.can_access?(attachment, user_without_role)
    end

    test "limited attachments with user-specific access" do
      attachment = insert(:attachment, access_level: "limited")
      granted_user = insert(:user)
      other_user = insert(:user)
      granter = insert(:user)

      AttachmentAccess.grant_user_access(attachment.id, granted_user.id, granter.id)

      assert AttachmentAccess.can_access?(attachment, granted_user)
      refute AttachmentAccess.can_access?(attachment, other_user)
    end
  end

  describe "embargo functionality" do
    test "attachment under embargo (start date in future)" do
      future_date = DateTime.utc_now() |> DateTime.add(7, :day)

      attachment =
        insert(:attachment,
          access_level: "public",
          embargo_start_date: future_date
        )

      refute AttachmentAccess.can_access?(attachment)
      refute AttachmentAccess.is_embargo_passed?(attachment)
    end

    test "attachment under embargo (end date in past)" do
      past_date = DateTime.utc_now() |> DateTime.add(-7, :day)

      attachment =
        insert(:attachment,
          access_level: "public",
          embargo_end_date: past_date
        )

      refute AttachmentAccess.can_access?(attachment)
      refute AttachmentAccess.is_embargo_passed?(attachment)
    end

    test "attachment within embargo window" do
      start_date = DateTime.utc_now() |> DateTime.add(-7, :day)
      end_date = DateTime.utc_now() |> DateTime.add(7, :day)

      attachment =
        insert(:attachment,
          access_level: "public",
          embargo_start_date: start_date,
          embargo_end_date: end_date
        )

      assert AttachmentAccess.can_access?(attachment)
      assert AttachmentAccess.is_embargo_passed?(attachment)
    end

    test "super admin bypasses embargo" do
      future_date = DateTime.utc_now() |> DateTime.add(7, :day)

      attachment =
        insert(:attachment,
          access_level: "public",
          embargo_start_date: future_date
        )

      super_admin = insert(:user)
      super_admin_role = insert(:role, name: "super_admin")
      insert(:user_role_assignment, user: super_admin, role: super_admin_role)

      assert AttachmentAccess.can_access?(attachment, super_admin)
    end
  end

  describe "update_access_control/3" do
    test "updates access level and tracks who made the change" do
      attachment = insert(:attachment, access_level: "public")
      admin_user = insert(:user)

      {:ok, updated} =
        AttachmentAccess.update_access_control(
          attachment,
          %{access_level: "limited"},
          admin_user
        )

      assert updated.access_level == "limited"
      assert updated.access_settings_updated_by_id == admin_user.id
      assert updated.access_settings_updated_at != nil
    end

    test "updates embargo dates" do
      attachment = insert(:attachment, access_level: "public")
      admin_user = insert(:user)
      start_date = DateTime.utc_now() |> DateTime.add(1, :day)
      end_date = DateTime.utc_now() |> DateTime.add(30, :day)

      {:ok, updated} =
        AttachmentAccess.update_access_control(
          attachment,
          %{
            embargo_start_date: start_date,
            embargo_end_date: end_date
          },
          admin_user
        )

      assert updated.embargo_start_date == start_date
      assert updated.embargo_end_date == end_date
    end

    test "validates embargo dates" do
      attachment = insert(:attachment, access_level: "public")
      admin_user = insert(:user)
      start_date = DateTime.utc_now() |> DateTime.add(30, :day)
      end_date = DateTime.utc_now() |> DateTime.add(1, :day)

      {:error, changeset} =
        AttachmentAccess.update_access_control(
          attachment,
          %{
            embargo_start_date: start_date,
            embargo_end_date: end_date
          },
          admin_user
        )

      assert "must be after embargo start date" in errors_on(changeset).embargo_end_date
    end
  end

  describe "grant and revoke access" do
    test "grant and revoke role access" do
      attachment = insert(:attachment, access_level: "limited")
      role = insert(:role)

      {:ok, _} = AttachmentAccess.grant_role_access(attachment.id, role.id)

      allowed_roles = AttachmentAccess.list_allowed_roles(attachment.id)
      assert Enum.any?(allowed_roles, &(&1.id == role.id))

      {count, _} = AttachmentAccess.revoke_role_access(attachment.id, role.id)
      assert count == 1

      allowed_roles = AttachmentAccess.list_allowed_roles(attachment.id)
      refute Enum.any?(allowed_roles, &(&1.id == role.id))
    end

    test "grant and revoke user access" do
      attachment = insert(:attachment, access_level: "limited")
      user = insert(:user)
      granter = insert(:user)

      {:ok, _} = AttachmentAccess.grant_user_access(attachment.id, user.id, granter.id)

      allowed_users = AttachmentAccess.list_allowed_users(attachment.id)
      assert Enum.any?(allowed_users, &(&1.id == user.id))

      {count, _} = AttachmentAccess.revoke_user_access(attachment.id, user.id)
      assert count == 1

      allowed_users = AttachmentAccess.list_allowed_users(attachment.id)
      refute Enum.any?(allowed_users, &(&1.id == user.id))
    end

    test "bulk grant role access" do
      attachments = insert_list(3, :attachment, access_level: "limited")
      role = insert(:role)
      attachment_ids = Enum.map(attachments, & &1.id)

      {count, _} = AttachmentAccess.bulk_grant_role_access(attachment_ids, role.id)
      assert count == 3
    end

    test "bulk grant user access" do
      attachments = insert_list(3, :attachment, access_level: "limited")
      user = insert(:user)
      granter = insert(:user)
      attachment_ids = Enum.map(attachments, & &1.id)

      {count, _} = AttachmentAccess.bulk_grant_user_access(attachment_ids, user.id, granter.id)
      assert count == 3
    end
  end

  describe "accessible_by/2" do
    test "super admin sees all attachments" do
      insert(:attachment, access_level: "public")
      insert(:attachment, access_level: "limited")
      insert(:attachment, access_level: "restricted")

      super_admin = insert(:user)
      super_admin_role = insert(:role, name: "super_admin")
      insert(:user_role_assignment, user: super_admin, role: super_admin_role)

      attachments =
        Attachment
        |> AttachmentAccess.accessible_by(super_admin)
        |> Repo.all()

      assert length(attachments) == 3
    end

    test "anonymous users only see public attachments" do
      insert(:attachment, access_level: "public")
      insert(:attachment, access_level: "limited")
      insert(:attachment, access_level: "restricted")

      attachments =
        Attachment
        |> AttachmentAccess.accessible_by(nil)
        |> Repo.all()

      assert length(attachments) == 1
    end

    test "authenticated users see public + their limited access" do
      public_attachment = insert(:attachment, access_level: "public")
      limited_attachment = insert(:attachment, access_level: "limited")
      insert(:attachment, access_level: "restricted")

      user = insert(:user)
      role = insert(:role)
      insert(:user_role_assignment, user: user, role: role)
      AttachmentAccess.grant_role_access(limited_attachment.id, role.id)

      attachments =
        Attachment
        |> AttachmentAccess.accessible_by(user)
        |> Repo.all()

      assert length(attachments) == 2
      attachment_ids = Enum.map(attachments, & &1.id)
      assert public_attachment.id in attachment_ids
      assert limited_attachment.id in attachment_ids
    end

    test "filters out embargoed attachments" do
      future_date = DateTime.utc_now() |> DateTime.add(7, :day)
      insert(:attachment, access_level: "public")
      insert(:attachment, access_level: "public", embargo_start_date: future_date)

      attachments =
        Attachment
        |> AttachmentAccess.accessible_by(nil)
        |> Repo.all()

      assert length(attachments) == 1
    end
  end

  describe "get_access_summary/1" do
    test "returns comprehensive access information" do
      admin = insert(:user)

      attachment =
        insert(:attachment,
          access_level: "limited",
          access_settings_updated_by_id: admin.id,
          access_settings_updated_at: DateTime.utc_now()
        )

      role = insert(:role, name: "staff")
      user = insert(:user)
      granter = insert(:user)

      AttachmentAccess.grant_role_access(attachment.id, role.id)
      AttachmentAccess.grant_user_access(attachment.id, user.id, granter.id)

      summary = AttachmentAccess.get_access_summary(attachment)

      assert summary.access_level == "limited"
      assert length(summary.allowed_roles) == 1
      assert length(summary.allowed_users) == 1
      assert summary.last_updated_by.id == admin.id
    end
  end
end
