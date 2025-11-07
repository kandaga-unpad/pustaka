# Podman Deployment Guide for Voile

This guide covers deploying the Voile Phoenix application using Podman and podman-compose.

## Prerequisites

- Podman installed
- podman-compose installed
- Environment files configured

## Environment Files

You need to create environment files for your deployments:

### Development: `.env.dev`

```bash
# Database
VOILE_POSTGRES_USER=voile
VOILE_POSTGRES_PASSWORD=change_me
VOILE_POSTGRES_DB=voile_dev
VOILE_DATABASE_URL=ecto://voile:change_me@db/voile_dev

# Phoenix
VOILE_SECRET_KEY=generate_with_mix_phx_gen_secret
MIX_ENV=dev
PORT=4000
PHX_HOST=localhost
```

### Production: `.env.prod.docker`

```bash
# Database
VOILE_POSTGRES_USER=voile
VOILE_POSTGRES_PASSWORD=secure_password_here
VOILE_POSTGRES_DB=voile_prod
DATABASE_URL=ecto://voile:secure_password_here@db/voile_prod

# Phoenix
SECRET_KEY_BASE=generate_with_mix_phx_gen_secret
MIX_ENV=prod
PORT=4000
PHX_HOST=your-domain.com
```

## Generate Secret Key

Generate a secret key for your Phoenix app:

```bash
mix phx.gen.secret
```

Copy the output and use it for `VOILE_SECRET_KEY` (dev) or `SECRET_KEY_BASE` (prod).

## Development Deployment

### 1. Start services

```bash
podman-compose up -d
```

This will:

- Build the development image using `Dockerfile.dev`
- Start PostgreSQL database
- Mount your source code as a volume
- Start Phoenix server with hot reloading

### 2. View logs

```bash
# All services
podman-compose logs -f

# Just the web service
podman-compose logs -f web

# Just the database
podman-compose logs -f db
```

### 3. Run commands inside the container

```bash
# Open a shell
podman-compose exec web bash

# Run migrations
podman-compose exec web mix ecto.migrate

# Run seeds
podman-compose exec web mix run priv/repo/seeds.exs

# Create database
podman-compose exec web mix ecto.create

# Reset database
podman-compose exec web mix ecto.reset
```

### 4. Stop services

```bash
# Stop services (keeps data)
podman-compose down

# Stop and remove volumes (deletes data!)
podman-compose down -v
```

## Production Deployment

### 1. Build and start services

```bash
podman-compose -f podman-compose.prod.yml up -d --build
```

This will:

- Build the production release using `Dockerfile`
- Start PostgreSQL database
- Start the Phoenix release (no source code mounted)

### 2. Run migrations

Production deployments need manual migration:

```bash
podman-compose -f podman-compose.prod.yml exec web /app/bin/voile eval "Voile.Release.migrate"
```

Or create a migration helper in `lib/voile/release.ex`:

```elixir
defmodule Voile.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :voile

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
```

### 3. View logs

```bash
podman-compose -f podman-compose.prod.yml logs -f web
```

### 4. Rebuild after code changes

```bash
# Rebuild and restart
podman-compose -f podman-compose.prod.yml up -d --build

# Or rebuild specific service
podman-compose -f podman-compose.prod.yml build web
podman-compose -f podman-compose.prod.yml up -d web
```

## Using Podman Directly (without compose)

### Build the image

```bash
# Development
podman build -f Dockerfile.dev -t voile:dev .

# Production
podman build -f Dockerfile -t voile:prod .
```

### Run with podman

```bash
# Create a pod
podman pod create --name voile -p 4000:4000

# Run PostgreSQL
podman run -d \
  --name voile-db \
  --pod voile \
  -e POSTGRES_USER=voile \
  -e POSTGRES_PASSWORD=change_me \
  -e POSTGRES_DB=voile_prod \
  -v voile_db_data:/var/lib/postgresql/data:Z \
  docker.io/library/postgres:15

# Run Voile (production)
podman run -d \
  --name voile-web \
  --pod voile \
  --env-file .env.prod.docker \
  voile:prod
```

## Troubleshooting

### Container won't start

Check logs:

```bash
podman-compose logs web
```

### Database connection issues

Verify database is healthy:

```bash
podman-compose exec db pg_isready -U voile
```

Check DATABASE_URL format:

```
ecto://username:password@hostname/database
```

### Permission issues with volumes

Podman uses SELinux labels. The `:Z` flag in volume mounts handles this:

```yaml
volumes:
  - .:/app:Z # :Z for private volume
```

### Port already in use

Change the port mapping in podman-compose.yml:

```yaml
ports:
  - "4001:4000" # Map host port 4001 to container port 4000
```

### Rebuild from scratch

```bash
# Stop everything
podman-compose down -v

# Remove images
podman rmi voile:dev voile:prod

# Remove all containers and cache
podman system prune -a

# Rebuild
podman-compose up -d --build
```

## Production Checklist

- [ ] Set secure `SECRET_KEY_BASE`
- [ ] Set secure database password
- [ ] Configure `PHX_HOST` to your domain
- [ ] Set up SSL/TLS (use a reverse proxy like Caddy or nginx)
- [ ] Configure backups for database volume
- [ ] Set up monitoring and logging
- [ ] Test migrations on staging first
- [ ] Configure resource limits in compose file
- [ ] Set up health checks
- [ ] Configure restart policies

## Additional Resources

- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [Podman Documentation](https://docs.podman.io/)
- [podman-compose](https://github.com/containers/podman-compose)
