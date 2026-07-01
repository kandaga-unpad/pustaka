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
DATA_DIR="/data/voile"
ENV_FILE=".env.prod"

# Ports
APP_PORT="4000"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

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

# Rollback function - called on any failure
rollback() {
    local reason="$1"
    print_error "$reason"
    print_warning "Rolling back to previous version..."

    # Stop and remove new container if it exists
    if podman container exists "$APP_CONTAINER" 2>/dev/null; then
        podman stop "$APP_CONTAINER" 2>/dev/null || true
        podman rm "$APP_CONTAINER" 2>/dev/null || true
    fi

    # Restore backup image if it exists
    if podman image exists "voile:backup" 2>/dev/null; then
        print_status "Restoring backup image..."
        podman tag voile:backup voile:latest

        # Start old container with backup image
        print_status "Starting previous version..."
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

        # Wait for container to start
        sleep 5

        if podman ps -q -f name="$APP_CONTAINER" -f status=running | grep -q .; then
            print_status "Rollback successful! Previous version is running."
        else
            print_error "Rollback failed! Manual intervention required."
        fi
    else
        print_error "No backup image found. Manual recovery required."
        print_status "Available images:"
        podman images | grep voile || true
    fi

    exit 1
}

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Safe Voile Full Update${NC}"
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

# Step 1: Backup current image
print_step "1/8: Backing up current image..."
if podman image exists "voile:latest" 2>/dev/null; then
    # Remove old backup if it exists
    podman image exists "voile:backup" 2>/dev/null && podman rmi voile:backup 2>/dev/null || true
    podman tag voile:latest voile:backup
    print_status "Current image backed up as voile:backup"
else
    print_warning "No voile:latest image found. This might be the first deployment."
fi

# Step 2: Pull latest changes
print_step "2/8: Pulling latest changes from git..."
git pull

# Step 3: Backup database
print_step "3/8: Creating database backup..."
BACKUP_DIR="/data/voile/backups"
BACKUP_FILE="$BACKUP_DIR/voile_backup_${TIMESTAMP}.sql"
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

# Step 4: Build new image with timestamp tag (not overwriting latest yet)
print_step "4/8: Building new application image..."
NEW_IMAGE="voile:new-${TIMESTAMP}"
if ! podman build -t "$NEW_IMAGE" -f Containerfile .; then
    rollback "Build failed!"
fi
print_status "New image built: $NEW_IMAGE"

# Step 5: Run migrations on new image (old app still running)
print_step "5/8: Running migrations on new image..."
if ! podman run --rm \
    --pod "$POD_NAME" \
    --env-file "$ENV_FILE" \
    -e DATABASE_HOST=localhost \
    -e DATABASE_PORT=5432 \
    "$NEW_IMAGE" \
    /app/bin/voile eval 'Voile.Release.migrate()'; then
    rollback "Migrations failed on the new image!"
fi
print_status "Migrations completed successfully on the new image"

# Step 6: Stop old container (now that migrations passed)
print_step "6/8: Stopping old container..."
if podman container exists "$APP_CONTAINER" 2>/dev/null; then
    podman stop "$APP_CONTAINER"
    podman rm "$APP_CONTAINER"
    print_status "Old container stopped and removed"
else
    print_status "No existing container found, skipping stop/remove."
fi

# Step 7: Start new container
print_step "7/8: Starting new application container..."
if ! podman run -d \
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
    "$NEW_IMAGE"; then
    rollback "Failed to start new container!"
fi

print_status "New container started"

# Step 8: Health check
wait_for_app() {
    local elapsed=0
    local timeout=60

    while ! podman exec "$APP_CONTAINER" /app/bin/voile eval 'IO.puts("health_ok")' > /dev/null 2>&1; do
        if [ "$elapsed" -ge "$timeout" ]; then
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    return 0
}

print_step "8/8: Performing health check..."
print_status "Waiting for container to be ready..."

if wait_for_app; then
    print_status "Health check passed!"

    # Promote new image to latest
    print_status "Promoting new image to voile:latest..."
    podman tag "$NEW_IMAGE" voile:latest

    # Clean up old build artifacts
    print_status "Cleaning up old build artifacts..."
    podman images | grep 'voile.*new-' | awk '{print $3}' | xargs -r podman rmi 2>/dev/null || true

    # Archive backup with timestamp for rollback history
    if podman image exists "voile:backup" 2>/dev/null; then
        podman tag voile:backup "voile:backup-${TIMESTAMP}"
        print_status "Backup archived as voile:backup-${TIMESTAMP}"
    fi

    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}Update completed successfully!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo -e "Application URL: ${YELLOW}http://localhost:$APP_PORT${NC}"
    echo -e "Backup created: ${YELLOW}$BACKUP_FILE${NC}"
    echo -e "Backup image: ${YELLOW}voile:backup-${TIMESTAMP}${NC}"
    echo ""
    echo -e "${GREEN}Useful commands:${NC}"
    echo -e "  View logs:     ${YELLOW}./manage.sh logs${NC}"
    echo -e "  Check status:  ${YELLOW}./manage.sh status${NC}"
    echo -e "  Rollback to previous: ${YELLOW}podman tag voile:backup-${TIMESTAMP} voile:latest && ./manage.sh restart${NC}"
    echo -e "${GREEN}================================${NC}"
else
    rollback "Health check failed! Container crashed or is unresponsive."
fi