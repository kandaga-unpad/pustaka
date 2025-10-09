alias Voile.Repo
alias Voile.Schema.Accounts
alias Voile.Schema.System

import Ecto.Query, warn: false

# Create one librarian account per node

# Fetch nodes from DB
nodes = System.list_nodes()

if nodes == [] do
  IO.puts("⚠️  No nodes found. Run master seeds to create nodes first.")
else
  IO.puts("Creating librarian accounts for #{length(nodes)} nodes...")

  # >= 12 chars
  pw = "defaultPustakawan2025"

  nodes
  |> Enum.with_index(1)
  |> Enum.each(fn {node, _idx} ->
    node_abbr = (node.abbr || "node") |> String.downcase()

    # Email format: librarian_<node_abbr>@unpad.ac.id
    email = "librarian_#{node_abbr}@unpad.ac.id"
    username = String.slice(email |> String.split("@") |> hd, 0, 30)
    fullname = "Librarian - #{node.name}"

    confirmed_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

    attrs = %{
      email: email,
      fullname: fullname,
      username: username,
      password: pw,
      node_id: node.id,
      confirmed_at: confirmed_at
    }

    case Repo.get_by(Accounts.User, email: email) do
      nil ->
        %Accounts.User{}
        |> Accounts.User.registration_changeset(attrs)
        |> Repo.insert!()

        IO.puts("✅ Created #{email} (node=#{node.name})")

      existing ->
        # Ensure node is set for existing account
        existing
        |> Accounts.User.changeset(%{node_id: node.id})
        |> Repo.update!()

        IO.puts("🔁 Updated existing user #{email} with node #{node.name}")
    end
  end)

  IO.puts("Librarian accounts creation completed!")
end
