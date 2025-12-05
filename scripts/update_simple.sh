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
NC='\033[0m' # No Color

# Configuration
APP_CONTAINER="voile-app"
ENV_FILE=".env.prod"

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Simple Voile Update${NC}"
echo -e "${GREEN}================================${NC}"

# Pull latest code
print_status "Pulling latest changes..."
git pull

# Download Tailwind binary if not present
print_status "Preparing Tailwind binary..."
mkdir -p _build
if [ ! -f "_build/tailwind-linux-x64" ]; then
    print_status "Downloading Tailwind..."
    curl -L https://github.com/tailwindlabs/tailwindcss/releases/download/v4.1.7/tailwindcss-linux-x64 \
        -o _build/tailwind-linux-x64
    chmod +x _build/tailwind-linux-x64
else
    print_status "Tailwind binary already exists"
fi

# Build new image
print_status "Building new image..."
podman build -t voile:latest -f Containerfile .

# Stop and remove old container
print_status "Stopping old container..."
podman stop "$APP_CONTAINER"
podman rm "$APP_CONTAINER"

# Start new container
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

# Wait a bit
print_status "Waiting for app to start..."
sleep 5

# Run migrations
print_status "Running migrations..."
podman exec "$APP_CONTAINER" /app/bin/voile eval 'Voile.Release.migrate()'

echo ""
print_status "Update completed!"
echo -e "View logs: ${YELLOW}./manage-voile.sh logs${NC}"