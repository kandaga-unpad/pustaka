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
NC='\033[0m' # No Color

# Configuration
POD_NAME="voile-pod"
DB_CONTAINER="voile-db"
APP_CONTAINER="voile-app"
DATA_DIR="/data/voile"
ENV_FILE=".env.prod"

# Ports
APP_PORT="4000"
DB_PORT="5432"

# Database configuration (loaded from .env.prod)
DB_USER="${VOILE_POSTGRES_USER:-voile}"
DB_PASSWORD="${VOILE_POSTGRES_PASSWORD:-voile}"
DB_NAME="${VOILE_POSTGRES_DB:-voile_prod}"

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Voile Deployment Script${NC}"
echo -e "${GREEN}================================${NC}"

# Function to print status messages
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if .env.prod exists
if [ ! -f "$ENV_FILE" ]; then
    print_error ".env.prod file not found!"
    exit 1
fi

# Load environment variables
print_status "Loading environment variables from $ENV_FILE"
set -a
source "$ENV_FILE"
set +a

# Create data directories
print_status "Creating data directories at $DATA_DIR"
sudo mkdir -p "$DATA_DIR"/{postgres,uploads,images,sfx}
sudo chown -R $(id -u):$(id -g) "$DATA_DIR"

# Clean up existing containers and pod
print_warning "Checking for existing deployment..."
if podman pod exists "$POD_NAME" 2>/dev/null; then
    print_warning "Removing existing pod and containers..."
    podman pod rm -f "$POD_NAME"
fi

# Create pod
print_status "Creating pod: $POD_NAME"
podman pod create \
    --name "$POD_NAME" \
    -p "${APP_PORT}:${APP_PORT}" \
    -p "${DB_PORT}:${DB_PORT}"

# Start PostgreSQL database
print_status "Starting PostgreSQL database..."
podman run -d \
    --name "$DB_CONTAINER" \
    --pod "$POD_NAME" \
    --restart unless-stopped \
    -e POSTGRES_USER="$DB_USER" \
    -e POSTGRES_PASSWORD="$DB_PASSWORD" \
    -e POSTGRES_DB="$DB_NAME" \
    -v "$DATA_DIR/postgres:/var/lib/postgresql/data:Z" \
    docker.io/library/postgres:15

# Wait for database to be ready
print_status "Waiting for PostgreSQL to be ready..."
TIMEOUT=60
ELAPSED=0
until podman exec "$DB_CONTAINER" pg_isready -U "$DB_USER" > /dev/null 2>&1; do
    if [ $ELAPSED -ge $TIMEOUT ]; then
        print_error "Database failed to become ready after ${TIMEOUT}s"
        podman logs "$DB_CONTAINER"
        exit 1
    fi
    echo -n "."
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done
echo ""
print_status "PostgreSQL is ready!"

# Build the application image if needed
print_status "Building application image..."
podman build -t voile:latest -f Containerfile .

# Start application
print_status "Starting Voile application..."
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
    voile:latest

# Wait a bit for the app to start
print_status "Waiting for application to start..."
sleep 5

# Run database setup and migrations
print_status "Running database setup..."

print_status "Creating database (if not exists)..."
if podman exec "$APP_CONTAINER" /app/bin/voile eval 'Voile.Release.create_database()'; then
    print_status "Database created successfully"
else
    print_warning "Database might already exist, continuing..."
fi

print_status "Running migrations..."
if podman exec "$APP_CONTAINER" /app/bin/voile eval 'Voile.Release.migrate()'; then
    print_status "Migrations completed successfully"
else
    print_error "Migrations failed!"
    podman logs "$APP_CONTAINER" --tail 50
    exit 1
fi

print_status "Running seeds..."
if podman exec "$APP_CONTAINER" /app/bin/voile eval 'Voile.Release.seed()'; then
    print_status "Seeds completed successfully"
else
    print_warning "Seeds might have failed, check logs if needed"
fi

print_status "Importing data..."
if podman exec "$APP_CONTAINER" /app/bin/voile eval 'Voile.Release.import_data()'; then
    print_status "Data import completed successfully"
else
    print_warning "Data import might have failed, check logs if needed"
fi

# Display status
echo ""
print_status "Deployment completed successfully!"
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Deployment Information${NC}"
echo -e "${GREEN}================================${NC}"
echo -e "Pod Name:       ${YELLOW}$POD_NAME${NC}"
echo -e "Database:       ${YELLOW}$DB_CONTAINER${NC}"
echo -e "Application:    ${YELLOW}$APP_CONTAINER${NC}"
echo -e "App URL:        ${YELLOW}http://localhost:$APP_PORT${NC}"
echo -e "Database URL:   ${YELLOW}postgresql://$DB_USER@localhost:$DB_PORT/$DB_NAME${NC}"
echo -e "Data Directory: ${YELLOW}$DATA_DIR${NC}"
echo ""
echo -e "${GREEN}Useful Commands:${NC}"
echo -e "  View app logs:  ${YELLOW}podman logs -f $APP_CONTAINER${NC}"
echo -e "  View db logs:   ${YELLOW}podman logs -f $DB_CONTAINER${NC}"
echo -e "  Stop all:       ${YELLOW}podman pod stop $POD_NAME${NC}"
echo -e "  Start all:      ${YELLOW}podman pod start $POD_NAME${NC}"
echo -e "  Restart app:    ${YELLOW}podman restart $APP_CONTAINER${NC}"
echo -e "  App shell:      ${YELLOW}podman exec -it $APP_CONTAINER /bin/sh${NC}"
echo -e "  DB shell:       ${YELLOW}podman exec -it $DB_CONTAINER psql -U $DB_USER -d $DB_NAME${NC}"
echo -e "  Remove all:     ${YELLOW}./scripts/cleanup.sh${NC}"
echo -e "${GREEN}================================${NC}"