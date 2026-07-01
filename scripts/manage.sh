#!/bin/bash

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

POD_NAME="voile-pod"
DB_CONTAINER="voile-db"
APP_CONTAINER="voile-app"
ENV_FILE=".env.prod"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

DB_USER="${VOILE_POSTGRES_USER:-voile}"
DB_NAME="${VOILE_POSTGRES_DB:-voile_prod}"

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_help() {
    echo -e "${GREEN}Voile Management Script${NC}"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status        - Show pod and container status"
    echo "  logs          - Show application logs"
    echo "  logs-db       - Show database logs"
    echo "  restart       - Restart the application"
    echo "  restart-all   - Restart everything (pod)"
    echo "  stop          - Stop all services"
    echo "  start         - Start all services"
    echo "  shell         - Open shell in application container"
    echo "  db-shell      - Open PostgreSQL shell"
    echo "  migrate       - Run database migrations"
    echo "  seed          - Run database seeds"
    echo "  import        - Run data import"
    echo "  remote        - Open Elixir remote console"
    echo "  backup-db     - Backup database to /data/voile/backups"
    echo "  restore-db    - Restore database from backup"
    echo "  rollback      - List available rollback images"
    echo "  rollback-to   - Rollback to specific backup image"
    echo ""
}

case "$1" in
    status)
        print_status "Pod status:"
        podman pod ps --filter name="$POD_NAME"
        echo ""
        print_status "Containers:"
        podman ps --filter pod="$POD_NAME"
        ;;
    
    logs)
        print_status "Showing application logs (Ctrl+C to exit)..."
        podman logs -f "$APP_CONTAINER"
        ;;
    
    logs-db)
        print_status "Showing database logs (Ctrl+C to exit)..."
        podman logs -f "$DB_CONTAINER"
        ;;
    
    restart)
        print_status "Restarting application..."
        podman restart "$APP_CONTAINER"
        print_status "Application restarted"
        ;;
    
    restart-all)
        print_status "Restarting pod..."
        podman pod restart "$POD_NAME"
        print_status "Pod restarted"
        ;;
    
    stop)
        print_status "Stopping pod..."
        podman pod stop "$POD_NAME"
        print_status "Pod stopped"
        ;;
    
    start)
        print_status "Starting pod..."
        podman pod start "$POD_NAME"
        print_status "Pod started"
        ;;
    
    shell)
        print_status "Opening shell in application container..."
        podman exec -it "$APP_CONTAINER" /bin/sh
        ;;
    
    db-shell)
        print_status "Opening PostgreSQL shell..."
        podman exec -it "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME"
        ;;
    
    migrate)
        print_status "Running migrations..."
        podman exec "$APP_CONTAINER" /app/bin/voile eval 'Voile.Release.migrate()'
        print_status "Migrations completed"
        ;;
    
    seed)
        print_status "Running seeds..."
        podman exec "$APP_CONTAINER" /app/bin/voile eval 'Voile.Release.seed()'
        print_status "Seeds completed"
        ;;
    
    import)
        print_status "Running data import..."
        podman exec "$APP_CONTAINER" /app/bin/voile eval 'Voile.Release.import_data()'
        print_status "Import completed"
        ;;
    
    remote)
        print_status "Opening remote console..."
        podman exec -it "$APP_CONTAINER" /app/bin/voile remote
        ;;
    
    backup-db)
        BACKUP_DIR="/data/voile/backups"
        BACKUP_FILE="$BACKUP_DIR/voile_backup_$(date +%Y%m%d_%H%M%S).sql"
        
        print_status "Creating backup directory..."
        mkdir -p "$BACKUP_DIR"
        
        print_status "Backing up database to $BACKUP_FILE..."
        podman exec "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" > "$BACKUP_FILE"
        
        print_status "Backup completed: $BACKUP_FILE"
        print_status "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
        ;;
    
    restore-db)
        BACKUP_DIR="/data/voile/backups"

        if [ -z "$2" ]; then
            echo "Available backups:"
            ls -lh "$BACKUP_DIR"/*.sql 2>/dev/null || echo "No backups found"
            echo ""
            echo "Usage: $0 restore-db <backup_file>"
            exit 1
        fi

        BACKUP_FILE="$2"

        if [ ! -f "$BACKUP_FILE" ]; then
            print_error "Backup file not found: $BACKUP_FILE"
            exit 1
        fi

        echo -e "${YELLOW}WARNING: This will replace the current database!${NC}"
        echo -n "Are you sure? (yes/no): "
        read -r CONFIRM

        if [ "$CONFIRM" != "yes" ]; then
            echo "Restore cancelled."
            exit 0
        fi

        print_status "Restoring database from $BACKUP_FILE..."
        cat "$BACKUP_FILE" | podman exec -i "$DB_CONTAINER" psql -U "$DB_USER" "$DB_NAME"
        print_status "Restore completed"
        ;;

    rollback)
        echo -e "${GREEN}Available rollback images:${NC}"
        echo ""

        # Find backup images
        BACKUPS=$(podman images | grep -E 'voile.*backup-[0-9]{8}-[0-9]{6}' || true)

        if [ -z "$BACKUPS" ]; then
            echo "No backup images found."
        else
            echo "$BACKUPS" | awk '{print $1 " " $3 " " $4 " " $5}' | column -t
            echo ""
            echo "Usage: $0 rollback-to <image-name>"
            echo "Example: $0 rollback-to voile:backup-20241229-143025"
        fi

        # Show voile:backup if it exists
        if podman image exists "voile:backup" 2>/dev/null; then
            echo ""
            echo "Current backup available: voile:backup"
            echo "Usage: $0 rollback-to voile:backup"
        fi
        ;;

    rollback-to)
        TARGET_IMAGE="$2"

        if [ -z "$TARGET_IMAGE" ]; then
            print_error "Please specify a backup image."
            echo "Run '$0 rollback' to list available images."
            exit 1
        fi

        if ! podman image exists "$TARGET_IMAGE" 2>/dev/null; then
            print_error "Image $TARGET_IMAGE not found."
            exit 1
        fi

        echo -e "${YELLOW}WARNING: This will rollback to $TARGET_IMAGE!${NC}"
        echo -n "Are you sure? (yes/no): "
        read -r CONFIRM

        if [ "$CONFIRM" != "yes" ]; then
            echo "Rollback cancelled."
            exit 0
        fi

        print_status "Stopping current container..."
        podman stop "$APP_CONTAINER" 2>/dev/null || true
        podman rm "$APP_CONTAINER" 2>/dev/null || true

        print_status "Tagging $TARGET_IMAGE as voile:latest..."
        podman tag "$TARGET_IMAGE" voile:latest

        print_status "Starting container with rollback image..."
        podman run -d \
            --name "$APP_CONTAINER" \
            --pod "$POD_NAME" \
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

        print_status "Waiting for container to start..."
        sleep 5

        if podman ps -q -f name="$APP_CONTAINER" -f status=running | grep -q .; then
            print_status "Rollback successful! Container is running."
            echo ""
            echo "View logs: ./manage.sh logs"
        else
            print_error "Rollback failed! Check logs: podman logs $APP_CONTAINER"
        fi
        ;;

    *)
        print_help
        ;;
esac