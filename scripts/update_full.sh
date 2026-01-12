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
echo -e "${GREEN}Voile Update Script${NC}"
echo -e "${GREEN}================================${NC}"

# Check if pod exists
if ! podman pod exists "$POD_NAME" 2>/dev/null; then
    print_error "Pod $POD_NAME does not exist. Run deploy-voile.sh first."
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

# Step 4: Rename old container (keep it running as backup)
print_step "4/7: Preparing for deployment..."
if podman container exists "$OLD_APP_CONTAINER" 2>/dev/null; then
    print_warning "Removing previous backup container..."
    podman rm -f "$OLD_APP_CONTAINER"
fi

if podman container exists "$APP_CONTAINER" 2>/dev/null; then
    print_status "Renaming current container to backup..."
    podman rename "$APP_CONTAINER" "$OLD_APP_CONTAINER"
fi

# Step 5: Start new container
print_step "5/7: Starting new application container..."
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

# Step 6: Wait for app to be ready and run migrations
print_step "6/7: Waiting for application to start..."
sleep 5

print_status "Running database migrations..."
if podman exec "$APP_CONTAINER" /app/bin/voile eval 'Voile.Release.migrate()'; then
    print_status "Migrations completed successfully"
else
    print_error "Migrations failed!"
    print_warning "Rolling back to old container..."
    
    # Rollback
    podman stop "$APP_CONTAINER"
    podman rm "$APP_CONTAINER"
    podman rename "$OLD_APP_CONTAINER" "$APP_CONTAINER"
    podman start "$APP_CONTAINER"
    
    print_error "Update failed! Rolled back to previous version."
    exit 1
fi

# Step 7: Health check
print_step "7/7: Performing health check..."
sleep 3

if podman exec "$APP_CONTAINER" /app/bin/voile eval 'IO.puts("Health check OK")' > /dev/null 2>&1; then
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
    podman stop "$APP_CONTAINER"
    podman rm "$APP_CONTAINER"
    podman rename "$OLD_APP_CONTAINER" "$APP_CONTAINER"
    podman start "$APP_CONTAINER"
    
    print_error "Update failed! Rolled back to previous version."
    print_status "Check logs with: podman logs voile-app-old"
    exit 1
fi