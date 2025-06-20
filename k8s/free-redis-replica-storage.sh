#!/bin/bash
# This script safely deletes unused Redis replica PVCs after switching to standalone mode

set -e

# Set some colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BOLD}Redis PVC Cleanup Script${NC}"
echo "This script will clean up unused Redis replica PVCs after switching to standalone mode."
echo

# Check if there are any replica PVCs to clean up
REPLICA_PVCS=$(kubectl get pvc -o json | jq -r '.items[] | select(.metadata.name | test("redis-data-redis-replicas-[0-9]+")) | .metadata.name')

if [ -z "$REPLICA_PVCS" ]; then
  echo -e "${YELLOW}No Redis replica PVCs found to clean up.${NC}"
  exit 0
fi

# List the PVCs that will be deleted
echo -e "${BOLD}The following Redis replica PVCs will be deleted:${NC}"
for pvc in $REPLICA_PVCS; do
  size=$(kubectl get pvc $pvc -o jsonpath='{.spec.resources.requests.storage}')
  echo -e "- ${YELLOW}$pvc${NC} (Size: $size)"
done

echo
echo -e "${RED}WARNING: This action will permanently delete these PVCs and their data.${NC}"
echo -e "Make sure your Redis standalone instance is working properly before proceeding."
echo

# Ask for confirmation
read -p "Do you want to proceed with deletion? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Operation cancelled."
  exit 1
fi

echo
echo "Deleting Redis replica PVCs..."

# Delete each PVC
for pvc in $REPLICA_PVCS; do
  echo -n "Deleting $pvc... "
  if kubectl delete pvc $pvc --wait=false; then
    echo -e "${GREEN}Success${NC}"
  else
    echo -e "${RED}Failed${NC}"
  fi
done

echo
echo -e "${BOLD}PVC cleanup completed.${NC}"
echo "You can verify the deletion by running: kubectl get pvc | grep redis" 