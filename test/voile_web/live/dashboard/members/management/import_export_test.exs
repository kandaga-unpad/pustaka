defmodule VoileWeb.Dashboard.Members.Management.ImportExportTest do
  use VoileWeb.ConnCase, async: true

  alias Decimal
  alias Voile.Schema.Accounts
  alias Voile.AccountsFixtures
  alias Voile.SystemFixtures
  alias Voile.Repo
  alias Voile.Schema.Master.MemberType
  alias VoileWeb.Dashboard.Members.Management.ImportExport

  setup do
    node = SystemFixtures.node_fixture(name: "Main Library")

    member_type =
      %MemberType{}
      |> MemberType.changeset(%{name: "Staff", slug: "staff"})
      |> Repo.insert!()

    current_user =
      AccountsFixtures.user_fixture(%{
        user_type_id: member_type.id,
        node_id: node.id
      })

    %{current_user: current_user, node: node, member_type: member_type}
  end

  test "import CSV row maps to register_user fields and creates the same user", %{
    current_user: current_user,
    node: node,
    member_type: member_type
  } do
    row = %{
      "fullname" => "Jane Doe",
      "email" => "jane.doe@example.com",
      "username" => "jane.doe",
      "identifier" => "123456",
      "member_type" => member_type.name,
      "node" => node.name,
      "user_image" => "https://example.com/avatar.jpg",
      "groups" => "group-a,group-b",
      "registration_date" => "2026-01-01",
      "expiry_date" => "2027-01-01",
      "manually_suspended" => "false",
      "suspension_reason" => "",
      "address" => "123 Main St",
      "phone_number" => "+62-812-3456-7890",
      "birth_date" => "1990-02-15",
      "birth_place" => "Jakarta",
      "gender" => "Female",
      "organization" => "Example University",
      "department" => "Science",
      "position" => "Research Assistant",
      "password" => "changeme1234"
    }

    socket = %{
      assigns: %{
        is_super_admin: false,
        import_node_id: node.id,
        current_scope: %{user: current_user}
      }
    }

    attrs = ImportExport.build_import_attrs(row, socket)

    assert attrs["fullname"] == "Jane Doe"
    assert attrs["email"] == "jane.doe@example.com"
    assert attrs["username"] == "jane.doe"
    assert attrs["identifier"] == Decimal.new("123456")
    assert attrs["user_type_id"] == member_type.id
    assert attrs["node_id"] == node.id
    assert attrs["groups"] == ["group-a", "group-b"]
    assert attrs["registration_date"] == ~D[2026-01-01]
    assert attrs["expiry_date"] == ~D[2027-01-01]
    assert attrs["birth_date"] == ~D[1990-02-15]

    assert {:ok, user} = Accounts.register_user(attrs)

    assert user.fullname == "Jane Doe"
    assert user.email == "jane.doe@example.com"
    assert user.username == "jane.doe"
    assert user.identifier == Decimal.new("123456")
    assert user.user_type_id == member_type.id
    assert user.node_id == node.id
    assert user.groups == ["group-a", "group-b"]
    assert user.registration_date == ~D[2026-01-01]
    assert user.expiry_date == ~D[2027-01-01]
    assert user.birth_date == ~D[1990-02-15]
  end
end
