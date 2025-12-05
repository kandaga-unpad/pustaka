# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?name=ubuntu
# https://hub.docker.com/_/ubuntu/tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian/tags?name=bookworm-20251103-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: docker.io/hexpm/elixir:1.19.1-erlang-27.3.4.3-debian-bookworm-20251103-slim
#
ARG ELIXIR_VERSION=1.19.1
ARG OTP_VERSION=27.3.4.3
ARG DEBIAN_VERSION=bookworm-20251103-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force \
  && mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# copy only mix.exs and mix.lock first for better layer caching
COPY mix.exs mix.lock ./

# copy config needed for deps (including runtime.exs for releases)
COPY config/config.exs config/${MIX_ENV}.exs config/runtime.exs config/

# install mix dependencies and compile them
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

# copy the app source
COPY lib lib
COPY priv priv
COPY assets assets
COPY rel rel
COPY scripts scripts

COPY _build/tailwind-linux-x64 /app/_build/tailwind-linux-x64
RUN chmod +x /app/_build/tailwind-linux-x64

# compile and build assets and release
RUN mix do compile
RUN mix assets.deploy
RUN mix release

# Final minimal runtime image
FROM ${RUNNER_IMAGE} AS final

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses5 locales ca-certificates postgresql-client \
  && rm -rf /var/lib/apt/lists/*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"

# set runner ENV
ENV MIX_ENV="prod"

# Copy the release and scripts from the builder
COPY --from=builder /app/_build/${MIX_ENV}/rel/voile ./
COPY --from=builder /app/scripts ./scripts

# Create a dedicated non-root user with a fixed UID/GID for runtime file ownership.
# Using UID/GID 1000 is common for deploy users; adjust if your host uses a different uid.
RUN groupadd -g 1000 voile || true \
  && useradd -m -u 1000 -g 1000 -s /bin/sh voile || true \
  && chown -R voile:voile /app

USER voile

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENTRYPOINT ["/tini", "--"]

CMD ["/app/bin/server"]
