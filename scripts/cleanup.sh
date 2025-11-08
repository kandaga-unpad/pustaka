#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

POD_NAME="voile-pod"

echo -e "${YELLOW}================================${NC}"
echo -e "${YELLOW}Voile Cleanup Script${NC}"
echo -e "${YELLOW}================================${NC}"

# Ask for confirmation
echo -e "${RED}WARNING: This will remove all Voile containers and the pod.${NC}"
echo -e "${RED}Database data in /data/voile will be preserved.${NC}"
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

echo -e "${GREEN}[INFO]${NC} Cleanup completed!"
echo -e "${YELLOW}Note: Data in /data/voile has been preserved.${NC}"
echo -e "To remove data as well, run: ${RED}sudo rm -rf /data/voile${NC}"