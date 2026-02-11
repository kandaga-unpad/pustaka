# Deployment

This section covers deploying VOILE to various environments, including CI/CD pipelines and container-based deployments.

## Deployment Options

VOILE supports multiple deployment strategies:

1. **Container-based** (Recommended) - Using Podman or Docker
2. **CI/CD Pipeline** - Automated deployment with GitHub Actions to Kubernetes
3. **Traditional** - Direct deployment to a server

## Guides

### CI/CD Deployment

Set up automated builds and deployments using GitHub Actions with Kubernetes (k3s).

[Read the CI Deployment Guide →](ci-deploy.md)

**Key Features:**

- Automated builds on push to `main`
- Container image building and pushing to registry
- Kubernetes deployment updates
- Service account configuration for secure deployments

### Podman Deployment

Deploy VOILE using Podman and podman-compose for local development and production.

[Read the Podman Deployment Guide →](podman-deployment.md)

**Key Features:**

- Development environment with hot-reloading
- Production-ready container configuration
- Database management with volumes
- Environment variable configuration

## Quick Start

### Development with Containers

```bash
# Start development environment
podman-compose up -d

# View logs
podman-compose logs -f web

# Stop environment
podman-compose down
```

### Production Deployment

```bash
# Copy and configure production environment
cp .env.prod.example .env.prod
# Edit .env.prod with your production values

# Generate secret key
mix phx.gen.secret

# Build and start production containers
podman-compose -f podman-compose.prod.yml up -d --build
```

## Environment Configuration

VOILE uses different environment files for different contexts:

| Environment | File | Database Host | Use Case |
|-------------|------|---------------|----------|
| Local Development | `.env.local` | `localhost` | Running with `mix phx.server` |
| Container Development | `.env.dev` | `db` | Running with podman-compose |
| Production | `.env.prod` | `db` | Production containers |

## Production Checklist

Before deploying to production, ensure:

- [ ] `SECRET_KEY_BASE` is generated and set
- [ ] Database credentials are secure and unique
- [ ] `PHX_HOST` is set to your domain
- [ ] SSL/TLS is configured (via reverse proxy)
- [ ] Database backups are configured
- [ ] Monitoring and logging are set up
- [ ] Migrations have been tested on staging
- [ ] Health checks are configured

## Container Images

VOILE provides two Containerfiles:

- **`Containerfile`** - Production build with release compilation
- **`Containerfile.dev`** - Development build with hot-reloading

## Related Documentation

- [Environment Setup](../getting-started/environment-setup.md) - Development environment configuration
- [Seeds Setup](../getting-started/seeds-setup.md) - Database seeding for new deployments