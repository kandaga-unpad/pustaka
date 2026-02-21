# Voile Plugins

This directory contains Voile plugin OTP applications.

## Directory Structure

Each plugin is a separate Elixir application:

```
plugins/
├── voile_locker_luggage/
│   ├── lib/
│   │   ├── voile_locker_luggage.ex      # Main module (implements Voile.Plugin)
│   │   ├── voile_locker_luggage/        # Context modules
│   │   │   ├── lockers.ex
│   │   │   └── sessions.ex
│   │   └── voile_locker_luggage_web/    # LiveView modules
│   │       ├── index_live.ex
│   │       └── settings_live.ex
│   ├── priv/
│   │   └── migrations/                  # Plugin database migrations
│   │       └── 20260201000001_create_lockers.exs
│   ├── mix.exs                          # Plugin dependencies
│   └── README.md
└── voile_isbn_lookup/
    └── ...
```

## Adding a Plugin to Voile

1. Place the plugin directory in `plugins/`
2. Add to `mix.exs` as a path dependency:

```elixir
def deps do
  [
    # ... other deps
    {:voile_locker_luggage, path: "plugins/voile_locker_luggage"}
  ]
end
```

3. Run `mix deps.get`
4. Rebuild and redeploy Voile
5. Install and activate via admin UI at `/manage/plugins`

## Plugin Naming Convention

- Directory: `voile_<plugin_name>` (snake_case)
- OTP app: `:voile_<plugin_name>`
- Main module: `Voile<PluginName>` (CamelCase)

## Documentation

See `docs/features/plugins/developer-guide.md` for the complete plugin development guide.
