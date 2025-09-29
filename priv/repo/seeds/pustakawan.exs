alias Voile.Repo
alias Voile.Schema.Accounts
alias Voile.Schema.System

import Ecto.Query, warn: false

# Create one librarian account per node. Each librarian gets a different role
# (cycled if there are more nodes than roles). This seed assumes user roles
# defined in `master.exs` are present.

roles_to_use = [
  "Pustakawan (Koordinator)",
  "Pustakawan Sirkulasi",
  "Pustakawan Pengolahan (Buku)",
  "Pustakawan Referensi",
  "Pustakawan Sistem (TI)",
  "Pustakawan Pengolahan (ETD)",
  "Pustakawan (General)",
  "Pustakawan Koleksi Populer"
]

# Fetch nodes and roles from DB
nodes = System.list_nodes()
all_roles = Accounts.list_user_roles()

roles_map = Enum.into(all_roles, %{}, fn r -> {r.name, r} end)

selected_roles =
  roles_to_use
  |> Enum.map(fn name -> Map.get(roles_map, name) end)
  |> Enum.filter(& &1)

if nodes == [] do
  IO.puts("⚠️  No nodes found. Run master seeds to create nodes first.")
end

if selected_roles == [] do
  IO.puts("⚠️  No librarian roles found. Ensure roles from master.exs were seeded.")
end

# >= 12 chars
pw = "defaultPustakawan2025"

# Build a slug for the role that preserves parenthetical parts, e.g.
# "Pustakawan (Koordinator)" -> "pustakawan_koordinator"
role_slug_fun = fn role_name ->
  # extract parenthetical content
  inner =
    case Regex.run(~r/\(([^)]+)\)/, role_name) do
      [_, m] -> String.trim(m)
      _ -> nil
    end

  base = String.replace(role_name, ~r/\([^)]*\)/, "") |> String.trim()

  combined =
    if inner && inner != "" do
      "#{base} #{inner}"
    else
      base
    end

  combined
  |> String.downcase()
  |> String.replace(~r/[^a-z0-9]+/, "_")
  |> String.replace(~r/_+/, "_")
  |> String.trim("_")
end

nodes
|> Enum.with_index(1)
|> Enum.each(fn {node, idx} ->
  role = Enum.at(selected_roles, rem(idx - 1, length(selected_roles)))

  if role do
    role_slug = role_slug_fun.(role.name)
    node_abbr = (node.abbr || "node") |> String.downcase()

    # Email format requested: <role_slug>_<node_abbr>@unpad.ac.id
    email = "#{role_slug}_#{node_abbr}@unpad.ac.id"
    username = String.slice(email |> String.split("@") |> hd, 0, 30)
    fullname = "#{role.name} - #{node.name}"

    confirmed_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

    attrs = %{
      email: email,
      fullname: fullname,
      username: username,
      password: pw,
      user_role_id: role.id,
      node_id: node.id,
      confirmed_at: confirmed_at
    }

    case Repo.get_by(Accounts.User, email: email) do
      nil ->
        %Accounts.User{}
        |> Accounts.User.registration_changeset(attrs)
        |> Repo.insert!()

        IO.puts("✅ Created #{email} (role=#{role.name}, node=#{node.name})")

      existing ->
        # Ensure role and node are set for existing account
        existing
        |> Accounts.User.changeset(%{user_role_id: role.id, node_id: node.id})
        |> Repo.update!()

        IO.puts("🔁 Updated existing user #{email} with role #{role.name} and node #{node.name}")
    end
  else
    IO.puts("⚠️  No role available for node #{node.name}")
  end
end)
