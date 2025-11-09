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
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

POD_NAME="voile-pod"
DATA_DIR="/data/voile"

# Parse command line arguments
DESTROY_ALL=false

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Voile Cleanup Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  (no options)    Remove containers and pod, preserve database data"
    echo "  --destroy-all   Remove everything including all database data"
    echo "  --full          Same as --destroy-all"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Preserve data"
    echo "  $0 --destroy-all # Destroy everything"
    exit 0
fi

if [ "$1" = "--destroy-all" ] || [ "$1" = "--full" ]; then
    DESTROY_ALL=true
fi

echo -e "${YELLOW}================================${NC}"
echo -e "${YELLOW}Voile Cleanup Script${NC}"
echo -e "${YELLOW}================================${NC}"

# Show appropriate warning based on mode
if [ "$DESTROY_ALL" = true ]; then
    echo -e "${RED}WARNING: This will COMPLETELY DESTROY everything!${NC}"
    echo -e "${RED}This includes:${NC}"
    echo -e "${RED}  - All Voile containers and the pod${NC}"
    echo -e "${RED}  - ALL database data in $DATA_DIR${NC}"
    echo -e "${RED}  - ALL uploaded files and images${NC}"
    echo -e "${RED}  - ALL application data${NC}"
    echo -e "${RED}${NC}"
    echo -e "${RED}This action CANNOT be undone!${NC}"
    echo -e "${RED}You will need to run deploy.sh to start fresh.${NC}"
else
    echo -e "${RED}WARNING: This will remove all Voile containers and the pod.${NC}"
    echo -e "${RED}Database data in $DATA_DIR will be preserved.${NC}"
fi

echo ""
echo -n "Are you sure you want to continue? (yes/no): "
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo -e "${GREEN}[INFO]${NC} Stopping and removing pod..."
if podman pod exists "$POD_NAME" 2>/dev/null; then
    podman pod stop "$POD_NAME"
    podman pod rm -f "$POD_NAME"
    echo -e "${GREEN}[INFO]${NC} Pod removed successfully"
else
    echo -e "${YELLOW}[WARNING]${NC} Pod not found"
fi

# Destroy all data if requested
if [ "$DESTROY_ALL" = true ]; then
    echo -e "${GREEN}[INFO]${NC} Destroying all data..."
    if [ -d "$DATA_DIR" ]; then
        sudo rm -rf "$DATA_DIR"
        echo -e "${GREEN}[INFO]${NC} All data destroyed successfully"
    else
        echo -e "${YELLOW}[WARNING]${NC} Data directory not found"
    fi
fi

echo -e "${GREEN}[INFO]${NC} Cleanup completed!"

if [ "$DESTROY_ALL" = true ]; then
    echo -e "${GREEN}Everything has been destroyed. You can now run deploy.sh to start fresh.${NC}"
else
    echo -e "${YELLOW}Note: Data in $DATA_DIR has been preserved.${NC}"
    echo -e "To remove data as well, run: ${RED}./scripts/cleanup.sh --destroy-all${NC}"
fi