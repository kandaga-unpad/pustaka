defmodule VoileWeb.AttachmentDownloadControllerTest do
  use VoileWeb.ConnCase, async: true

  import Voile.Factory
  alias Voile.Catalog.AttachmentAccess

  describe "GET /attachments/:id/download" do
    test "public file can be downloaded by anonymous user", %{conn: conn} do
      attachment =
        insert(:attachment,
          access_level: "public",
          file_path: "/uploads/attachments/upload.txt"
        )

      conn = get(conn, ~p"/attachments/#{attachment.id}/download")
      assert response(conn, 200) =~ "You're seeing this text file."

      assert get_resp_header(conn, "content-disposition") |> List.first() =~
               "#{attachment.original_name}"
    end

    test "attachments under embargo are forbidden to anonymous users", %{conn: conn} do
      future = DateTime.utc_now() |> DateTime.add(3600, :second)

      attachment =
        insert(:attachment,
          access_level: "public",
          embargo_start_date: future,
          file_path: "/uploads/attachments/upload.txt"
        )

      conn = get(conn, ~p"/attachments/#{attachment.id}/download")
      assert response(conn, 403) =~ "not authorized"
    end

    test "super admin bypasses embargo", %{conn: conn} do
      future = DateTime.utc_now() |> DateTime.add(3600, :second)

      attachment =
        insert(:attachment,
          access_level: "public",
          embargo_start_date: future,
          file_path: "/uploads/attachments/upload.txt"
        )

      user = insert(:user)
      role = insert(:role, name: "super_admin")
      insert(:user_role_assignment, user: user, role: role)

      conn = conn |> log_in_user(user) |> get(~p"/attachments/#{attachment.id}/download")
      assert response(conn, 200)
    end

    test "limited attachments require authentication", %{conn: conn} do
      attachment =
        insert(:attachment,
          access_level: "limited",
          file_path: "/uploads/attachments/upload.txt"
        )

      conn = get(conn, ~p"/attachments/#{attachment.id}/download")
      assert response(conn, 403)
    end

    test "restricted attachments are blocked for regular users", %{conn: conn} do
      user = insert(:user)

      attachment =
        insert(:attachment,
          access_level: "restricted",
          file_path: "/uploads/attachments/upload.txt"
        )

      conn = conn |> log_in_user(user) |> get(~p"/attachments/#{attachment.id}/download")
      assert response(conn, 403)
    end

    test "restricted attachments are available to super admins", %{conn: conn} do
      user = insert(:user)
      role = insert(:role, name: "super_admin")
      insert(:user_role_assignment, user: user, role: role)

      attachment =
        insert(:attachment,
          access_level: "restricted",
          file_path: "/uploads/attachments/upload.txt"
        )

      conn = conn |> log_in_user(user) |> get(~p"/attachments/#{attachment.id}/download")
      assert response(conn, 200)
    end
  end
end
