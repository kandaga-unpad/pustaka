#!/usr/bin/env bash
set -euo pipefail

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
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
POD_NAME="voile-pod"
DB_CONTAINER="voile-db"
APP_CONTAINER="voile-app"
OLD_APP_CONTAINER="voile-app-old"
DATA_DIR="/data/voile"
ENV_FILE=".env.prod"

# Ports
APP_PORT="4000"

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Voile Full Update${NC}"
echo -e "${GREEN}================================${NC}"

# Check if pod exists
if ! podman pod exists "$POD_NAME" 2>/dev/null; then
    print_error "Pod $POD_NAME does not exist. Run deploy-voile.sh first."
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    print_error "$ENV_FILE file not found. Ensure you are running from the project root."
    exit 1
fi

# Step 1: Pull latest changes
print_step "1/7: Pulling latest changes from git..."
git pull

# Step 2: Backup database
print_step "2/7: Creating database backup..."
BACKUP_DIR="/data/voile/backups"
BACKUP_FILE="$BACKUP_DIR/voile_backup_$(date +%Y%m%d_%H%M%S).sql"
mkdir -p "$BACKUP_DIR"

# Load DB credentials
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

DB_USER="${VOILE_POSTGRES_USER:-voile}"
DB_NAME="${VOILE_POSTGRES_DB:-voile_prod}"

podman exec "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" > "$BACKUP_FILE"
print_status "Backup created: $BACKUP_FILE"

# Step 3: Build new image
print_step "3/7: Building new application image..."
podman build -t voile:latest -f Containerfile .
print_status "New image built successfully"

# Step 4: Run migrations on the new image before switching containers
print_step "4/7: Running migrations on the new image..."
if ! podman run --rm \
    --pod "$POD_NAME" \
    --env-file "$ENV_FILE" \
    -e DATABASE_HOST=localhost \
    -e DATABASE_PORT=5432 \
    voile:latest \
    /app/bin/voile eval 'Voile.Release.migrate()'; then
    print_error "Migrations failed on the new image! Aborting deployment."
    exit 1
fi
print_status "Migrations completed successfully on the new image"

# Step 5: Rename current container to backup
print_step "5/7: Preparing for deployment..."
if podman container exists "$OLD_APP_CONTAINER" 2>/dev/null; then
    print_warning "Removing previous backup container..."
    podman rm -f "$OLD_APP_CONTAINER"
fi

if podman container exists "$APP_CONTAINER" 2>/dev/null; then
    print_status "Renaming current container to backup..."
    podman rename "$APP_CONTAINER" "$OLD_APP_CONTAINER"
fi

# Step 6: Start new container
print_step "6/7: Starting new application container..."
podman run -d \
    --name "$APP_CONTAINER" \
    --pod "$POD_NAME" \
    --restart unless-stopped \
    --env-file "$ENV_FILE" \
    -e PHX_SERVER=true \
    -e DATABASE_HOST=localhost \
    -e DATABASE_PORT=5432 \
    -v "$DATA_DIR/uploads:/app/priv/static/uploads:Z" \
    -v "$DATA_DIR/uploads:/app/lib/voile-0.1.0/priv/static/uploads:Z" \
    -v "$DATA_DIR/images:/app/priv/static/images:Z" \
    -v "$DATA_DIR/sfx:/app/priv/static/sfx:Z" \
    voile:latest

print_status "New container started"

wait_for_app() {
    local elapsed=0
    local timeout=30

    while ! podman exec "$APP_CONTAINER" /app/bin/voile eval 'IO.puts("Health check OK")' > /dev/null 2>&1; do
        if [ "$elapsed" -ge "$timeout" ]; then
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    return 0
}

print_step "7/7: Performing health check..."

if wait_for_app; then
    print_status "Health check passed!"

    # Remove old container
    if podman container exists "$OLD_APP_CONTAINER" 2>/dev/null; then
        print_status "Removing old container..."
        podman stop "$OLD_APP_CONTAINER" 2>/dev/null || true
        podman rm "$OLD_APP_CONTAINER"
    fi

    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}Update completed successfully!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo -e "Application URL: ${YELLOW}http://localhost:$APP_PORT${NC}"
    echo -e "Backup created: ${YELLOW}$BACKUP_FILE${NC}"
    echo ""
    echo -e "${GREEN}Useful commands:${NC}"
    echo -e "  View logs:     ${YELLOW}./manage-voile.sh logs${NC}"
    echo -e "  Check status:  ${YELLOW}./manage-voile.sh status${NC}"
    echo -e "${GREEN}================================${NC}"
else
    print_error "Health check failed!"
    print_warning "Rolling back to old container..."

    # Rollback
    if podman container exists "$APP_CONTAINER" 2>/dev/null; then
        podman stop "$APP_CONTAINER" 2>/dev/null || true
        podman rm "$APP_CONTAINER" 2>/dev/null || true
    else
        print_status "No new container to stop/remove."
    fi

    if podman container exists "$OLD_APP_CONTAINER" 2>/dev/null; then
        podman rename "$OLD_APP_CONTAINER" "$APP_CONTAINER" 2>/dev/null || true
        podman start "$APP_CONTAINER" 2>/dev/null || true
        print_error "Update failed! Rolled back to previous version."
        print_status "Check logs with: podman logs $APP_CONTAINER"
    else
        print_error "Old container $OLD_APP_CONTAINER not found — manual rollback required."
        print_status "Check logs with: podman logs $OLD_APP_CONTAINER"
    fi
    exit 1
fi
