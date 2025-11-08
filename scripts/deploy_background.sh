#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
POD_NAME="voile-pod"
DB_CONTAINER="voile-db"
APP_CONTAINER="voile-app"
DATA_DIR="/data/voile"
ENV_FILE=".env.prod"
LOG_FILE="/tmp/voile-deploy-$(date +%Y%m%d_%H%M%S).log"

# Ports
APP_PORT="4000"
DB_PORT="5432"

# Function to log to both file and console
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_status() {
    log "${GREEN}[INFO]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

# Main deployment function
deploy() {
    log "${GREEN}================================${NC}"
    log "${GREEN}Voile Background Deployment${NC}"
    log "${GREEN}================================${NC}"
    log_status "Started at: $(date)"
    log_status "Log file: $LOG_FILE"
    log ""

    # Check if .env.prod exists
    if [ ! -f "$ENV_FILE" ]; then
        log_error ".env.prod file not found!"
        exit 1
    fi

    # Load environment variables
    log_status "Loading environment variables from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a

    DB_USER="${VOILE_POSTGRES_USER:-voile}"
    DB_PASSWORD="${VOILE_POSTGRES_PASSWORD:-voile}"
    DB_NAME="${VOILE_POSTGRES_DB:-voile_prod}"

    # Create data directories
    log_status "Creating data directories at $DATA_DIR"
    sudo mkdir -p "$DATA_DIR"/{postgres,uploads,images,sfx} 2>&1 | tee -a "$LOG_FILE"
    sudo chown -R $(id -u):$(id -g) "$DATA_DIR" 2>&1 | tee -a "$LOG_FILE"

    # Clean up existing containers and pod
    log_warning "Checking for existing deployment..."
    if podman pod exists "$POD_NAME" 2>/dev/null; then
        log_warning "Removing existing pod and containers..."
        podman pod rm -f "$POD_NAME" 2>&1 | tee -a "$LOG_FILE"
    fi

    # Create pod
    log_status "Creating pod: $POD_NAME"
    podman pod create \
        --name "$POD_NAME" \
        -p "${APP_PORT}:${APP_PORT}" \
        -p "${DB_PORT}:${DB_PORT}" 2>&1 | tee -a "$LOG_FILE"

    # Start PostgreSQL database
    log_status "Starting PostgreSQL database..."
    podman run -d \
        --name "$DB_CONTAINER" \
        --pod "$POD_NAME" \
        --restart unless-stopped \
        -e POSTGRES_USER="$DB_USER" \
        -e POSTGRES_PASSWORD="$DB_PASSWORD" \
        -e POSTGRES_DB="$DB_NAME" \
        -v "$DATA_DIR/postgres:/var/lib/postgresql/data:Z" \
        docker.io/library/postgres:15 2>&1 | tee -a "$LOG_FILE"

    # Wait for database to be ready
    log_status "Waiting for PostgreSQL to be ready (max 60 seconds)..."
    TIMEOUT=60
    ELAPSED=0
    until podman exec "$DB_CONTAINER" pg_isready -U "$DB_USER" > /dev/null 2>&1; do
        if [ $ELAPSED -ge $TIMEOUT ]; then
            log_error "Database failed to become ready after ${TIMEOUT}s"
            podman logs "$DB_CONTAINER" 2>&1 | tee -a "$LOG_FILE"
            exit 1
        fi
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        if [ $((ELAPSED % 10)) -eq 0 ]; then
            log_status "Still waiting... ($ELAPSED/${TIMEOUT}s)"
        fi
    done
    log_status "PostgreSQL is ready!"

    # Build the application image
    log_status "Building application image (this may take several minutes)..."
    podman build -t voile:latest -f Containerfile . 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        log_status "Image built successfully"
    else
        log_error "Image build failed!"
        exit 1
    fi

    # Start application
    log_status "Starting Voile application..."
    podman run -d \
        --name "$APP_CONTAINER" \
        --pod "$POD_NAME" \
        --restart unless-stopped \
        --env-file "$ENV_FILE" \
        -e PHX_SERVER=true \
        -e DATABASE_HOST=localhost \
        -e DATABASE_PORT="$DB_PORT" \
        -v "$DATA_DIR/uploads:/app/priv/static/uploads:Z" \
        -v "$DATA_DIR/uploads:/app/lib/voile-0.1.0/priv/static/uploads:Z" \
        -v "$DATA_DIR/images:/app/priv/static/images:Z" \
        -v "$DATA_DIR/sfx:/app/priv/static/sfx:Z" \
        voile:latest 2>&1 | tee -a "$LOG_FILE"

    # Wait for the app to start
    log_status "Waiting for application to start..."
    sleep 10

    # Run database setup and migrations
    log_status "Running database setup..."

    log_status "Creating database (if not exists)..."
    if podman exec "$APP_CONTAINER" /app/bin/voile eval 'Voile.Release.create_database()' 2>&1 | tee -a "$LOG_FILE"; then
        log_status "Database created successfully"
    else
        log_warning "Database might already exist, continuing..."
    fi

    log_status "Running migrations..."
    if podman exec "$APP_CONTAINER" /app/bin/voile eval 'Voile.Release.migrate()' 2>&1 | tee -a "$LOG_FILE"; then
        log_status "Migrations completed successfully"
    else
        log_error "Migrations failed!"
        podman logs "$APP_CONTAINER" --tail 50 2>&1 | tee -a "$LOG_FILE"
        exit 1
    fi

    log_status "Running seeds..."
    if podman exec "$APP_CONTAINER" /app/bin/voile eval 'Voile.Release.seed()' 2>&1 | tee -a "$LOG_FILE"; then
        log_status "Seeds completed successfully"
    else
        log_warning "Seeds might have failed, check logs if needed"
    fi

    log_status "Importing data..."
    if podman exec "$APP_CONTAINER" /app/bin/voile eval 'Voile.Release.import_data()' 2>&1 | tee -a "$LOG_FILE"; then
        log_status "Data import completed successfully"
    else
        log_warning "Data import might have failed, check logs if needed"
    fi

    # Display status
    log ""
    log_status "Deployment completed successfully!"
    log_status "Finished at: $(date)"
    log ""
    log "${GREEN}================================${NC}"
    log "${GREEN}Deployment Information${NC}"
    log "${GREEN}================================${NC}"
    log "Pod Name:       ${YELLOW}$POD_NAME${NC}"
    log "Database:       ${YELLOW}$DB_CONTAINER${NC}"
    log "Application:    ${YELLOW}$APP_CONTAINER${NC}"
    log "App URL:        ${YELLOW}http://localhost:$APP_PORT${NC}"
    log "Database URL:   ${YELLOW}postgresql://$DB_USER@localhost:$DB_PORT/$DB_NAME${NC}"
    log "Data Directory: ${YELLOW}$DATA_DIR${NC}"
    log "Log File:       ${YELLOW}$LOG_FILE${NC}"
    log ""
    log "${GREEN}Useful Commands:${NC}"
    log "  View app logs:  ${YELLOW}podman logs -f $APP_CONTAINER${NC}"
    log "  View db logs:   ${YELLOW}podman logs -f $DB_CONTAINER${NC}"
    log "  Check status:   ${YELLOW}./manage-voile.sh status${NC}"
    log "  View this log:  ${YELLOW}cat $LOG_FILE${NC}"
    log "${GREEN}================================${NC}"
}

# Check if running in background mode
if [ "$1" = "bg" ] || [ "$1" = "background" ]; then
    # Run in background with nohup
    echo "Starting deployment in background..."
    echo "Log file: $LOG_FILE"
    echo "Monitor progress: tail -f $LOG_FILE"
    echo ""
    nohup bash -c "$(declare -f deploy); $(declare -f log); $(declare -f log_status); $(declare -f log_error); $(declare -f log_warning); deploy" >> "$LOG_FILE" 2>&1 &
    PID=$!
    echo "Deployment started with PID: $PID"
    echo "You can safely log out now."
    echo ""
    echo "To monitor progress:"
    echo "  tail -f $LOG_FILE"
    echo ""
    echo "To check if still running:"
    echo "  ps -p $PID"
    echo ""
    echo "PID saved to: /tmp/voile-deploy.pid"
    echo $PID > /tmp/voile-deploy.pid
else
    # Run in foreground
    deploy
fi