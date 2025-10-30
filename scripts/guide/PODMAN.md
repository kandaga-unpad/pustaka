# Podman / podman-compose usage for Voile

This file explains how to build and run the Voile Phoenix app using Podman.

Quick notes
- The repository contains a `Containerfile` (multi-stage) that builds a release.
- `podman-compose.yml` provides a `db` (Postgres) and `web` service and expects a `.env` file.

Setup
1. Copy `.env.sample` to `.env` and edit the values (at minimum set `POSTGRES_PASSWORD` and `SECRET_KEY_BASE`).
   - Generate `SECRET_KEY_BASE` with `mix phx.gen.secret` (run locally if you have Elixir installed).

Development (bind-mounted, live code)
1. Ensure you have Podman and podman-compose installed on your machine.
2. From the project root (where `podman-compose.yml` lives) run:

   podman-compose up -d

3. The compose file bind-mounts the project into the container and runs `mix ecto.setup && mix phx.server`.
   - Phoenix will be available on http://localhost:4000

Production (release)
1. Build the image with podman (this builds the release stage in the Containerfile):

   podman build -t voile:latest -f Containerfile .

2. Run the DB, then run the release container. Example (unguarded):

   podman volume create voile_db_data
   podman run -d --name voile-db -e POSTGRES_USER=voile -e POSTGRES_PASSWORD=change_me -e POSTGRES_DB=voile_prod -v voile_db_data:/var/lib/postgresql/data:Z docker.io/library/postgres:15

   # then run the web service linking to the DB network
   podman run -d --name voile-web -p 4000:4000 --env-file .env --link voile-db:db voile:latest

Notes & troubleshooting
- If assets are built by a different tool (esbuild, tailwind), adjust the `npm run deploy` step in the `Containerfile` accordingly.
- The Containerfile assumes the release is named `voile` (matching the `mix.exs` app name). If your app name differs, update the COPY/CMD accordingly.
- On SELinux-enabled systems the `:Z` mount option is used in the compose file to set the correct context. If you hit permission problems, try without `:Z` or adjust contexts.

Next steps / optional improvements
- Add a healthcheck for the web service.
- Add a `Makefile` or scripts to generate `SECRET_KEY_BASE` and create `.env` from `.env.sample`.
- Add CI steps to build and push the image to a registry.
