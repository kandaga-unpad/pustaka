#!/bin/bash
set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine project root (parent of scripts directory if script is in scripts/)
if [[ "$SCRIPT_DIR" == */scripts ]]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi

# Change to project root
cd "$PROJECT_ROOT"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
APP_CONTAINER="voile-app"
ENV_FILE=".env.prod"

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Simple Voile Update${NC}"
echo -e "${GREEN}================================${NC}"

# Pull latest code
print_status "Pulling latest changes..."
git pull

# Build new image
print_status "Building new image..."
podman build -t voile:latest -f Containerfile .

# Stop and remove old container
print_status "Stopping old container..."
OLD_ID=$(podman ps -a -q -f name="$APP_CONTAINER")
if [[ -n "$OLD_ID" ]]; then
    podman stop "$APP_CONTAINER"
    podman rm "$APP_CONTAINER"
else
    print_status "No existing container named '$APP_CONTAINER' found, skipping stop/remove."
fi

# Run migrations BEFORE starting the server
print_status "Running migrations..."
if ! podman run --rm \
    --pod voile-pod \
    --env-file "$ENV_FILE" \
    -e DATABASE_HOST=localhost \
    -e DATABASE_PORT=5432 \
    voile:latest \
    /app/bin/voile eval 'Voile.Release.migrate()'; then
    print_error "Migrations failed! Aborting deployment."
    exit 1
fi

print_status "Migrations completed successfully."

# Start new container (only after migrations succeed)
print_status "Starting new container..."
podman run -d \
    --name "$APP_CONTAINER" \
    --pod voile-pod \
    --restart unless-stopped \
    --env-file "$ENV_FILE" \
    -e PHX_SERVER=true \
    -e DATABASE_HOST=localhost \
    -e DATABASE_PORT=5432 \
    -v /data/voile/uploads:/app/priv/static/uploads:Z \
    -v /data/voile/uploads:/app/lib/voile-0.1.0/priv/static/uploads:Z \
    -v /data/voile/images:/app/priv/static/images:Z \
    -v /data/voile/sfx:/app/priv/static/sfx:Z \
    voile:latest

# Wait and verify the container is still running (didn't crash on startup)
print_status "Verifying container started successfully..."
sleep 5

if podman ps -q -f name="$APP_CONTAINER" -f status=running | grep -q .; then
    print_status "Container is running."
else
    print_error "Container crashed after startup! Check logs:"
    echo -e "  ${YELLOW}podman logs $APP_CONTAINER${NC}"
    exit 1
fi

echo ""
print_status "Update completed!"
echo -e "View logs: ${YELLOW}./manage-voile.sh logs${NC}"