# Default Node ID Configuration

This setting allows you to configure a fallback node/location for users who don't have a `node_id` assigned (like super_admin).

## Setting Up

### Option 1: Run the Migration

The migration file will automatically insert the setting with a default value of `20`:

```bash
mix ecto.migrate
```

### Option 2: Update via Database

If you want to change the default node ID to a different value, you can update it directly:

```sql
UPDATE settings 
SET setting_value = 'YOUR_NODE_ID_HERE'
WHERE setting_name = 'default_node_id_for_items';
```

Replace `YOUR_NODE_ID_HERE` with your desired node ID.

### Option 3: Update via Elixir Console

```elixir
# In iex -S mix or mix run
Voile.Repo.insert!(
  %Voile.Schema.System.Setting{
    setting_name: "default_node_id_for_items",
    setting_value: "20"  # Change this to your node ID
  },
  on_conflict: {:replace, [:setting_value, :updated_at]},
  conflict_target: :setting_name
)
```

## How It Works

When a user without a `node_id` (like super_admin) tries to add an item to a collection:

1. The system checks if the user has a `node_id`
2. If not, it reads the `default_node_id_for_items` setting
3. If the setting exists, it uses that node ID as a fallback
4. If the setting doesn't exist, it shows an error message

This allows each instance to configure their own fallback node according to their needs.

## Finding Your Node IDs

To see available node IDs in your system:

```elixir
# In iex -S mix
Voile.Schema.System.list_nodes() |> Enum.map(&{&1.id, &1.name})
```

Or via SQL:

```sql
SELECT id, name FROM nodes;
```
