### Containerfile - multi-stage build for Voile (Elixir/Phoenix)
#
# Multi-stage Containerfile that builds a production release with Mix and
# builds assets with npm (assumes a standard Phoenix assets folder).

FROM elixir:1.19-slim AS build

ARG MIX_ENV=prod
ENV MIX_ENV=${MIX_ENV}

# Install build deps (including Node & npm for assets)
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    ca-certificates \
    gnupg2 \
    postgresql-client \
    npm \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Hex + Rebar
RUN mix local.hex --force && mix local.rebar --force

# Copy Elixir deps manifests and fetch deps (only prod deps when building prod)
COPY mix.exs mix.lock ./
RUN mix deps.get --only ${MIX_ENV}

# Copy assets package files and install node deps (adjust if you use yarn)
COPY assets/package.json assets/package-lock.json ./assets/ 2>/dev/null || true
RUN if [ -d assets ]; then cd assets && npm ci --no-audit --no-fund || true; fi

# Copy the rest of the project
COPY . .

# Build assets - this expects a deploy script in assets/package.json
RUN if [ -d assets ]; then cd assets && npm run deploy || (echo "WARN: assets deploy failed or not configured" && true); fi

# Compile and build release
RUN mix deps.compile
RUN mix compile

# Create a release (requires releases configured in mix.exs)
RUN if mix help release >/dev/null 2>&1; then mix release --overwrite; else echo "mix release not available"; fi


FROM ubuntu:24.04 AS app
# Use Ubuntu runtime for wider compatibility. Keep the runtime lean but
# include a minimal HTTP client for healthchecks.
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates libssl-dev openssl curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Create non-root user 'voile' and adjust ownership of the app dir. Use UID/GID 1000
# which is commonly safe for mounted volumes and matches standard developer setups.
RUN groupadd -g 1000 voile || true \
  && useradd -m -u 1000 -g 1000 -s /sbin/nologin voile || true

# Copy release from builder (assumes app name `voile` from mix.exs)
COPY --from=build /app/_build/${MIX_ENV}/rel/voile . 2>/dev/null || true

# Ensure the runtime files are owned by the non-root user
RUN chown -R voile:voile /app || true

ENV HOME=/app
ENV PORT=4000
EXPOSE 4000

# Use a lightweight healthcheck that queries the web port. Keep short intervals.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://127.0.0.1:${PORT}/ || exit 1

# Switch to non-root user for improved security
USER voile

# Default to running the release if present, otherwise fall back to mix phx.server (dev-friendly)
CMD ["/bin/sh", "-c", "if [ -x \"./bin/voile\" ]; then exec ./bin/voile start; else echo 'No release found; starting mix server (dev)'; exec mix do deps.get, ecto.setup, phx.server; fi"]
