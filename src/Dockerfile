FROM hexpm/elixir:1.15.7-erlang-26.1.2-alpine-3.18.4

# Install dependencies
RUN apk add --no-cache build-base curl

WORKDIR /app

# Copy project files from marketplace-api subdirectory
COPY marketplace-api/mix.exs ./
COPY marketplace-api/lib ./lib

# Install hex and rebar, get deps, compile, and create release as root
RUN mix local.hex --force && \
    mix local.rebar --force && \
    MIX_ENV=prod mix deps.get --only prod && \
    MIX_ENV=prod mix deps.compile && \
    MIX_ENV=prod mix compile && \
    MIX_ENV=prod mix release

# Create non-root user and fix permissions
RUN addgroup -g 1000 app && \
    adduser -u 1000 -G app -s /bin/sh -D app && \
    chown -R app:app /app

USER app

EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

# Start with the release (no mix required at runtime)
CMD ["/app/_build/prod/rel/marketplace_api/bin/marketplace_api", "start_iex"]
