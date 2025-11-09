#!/bin/bash
set -euo pipefail

# MySQL Backup Restore Script for AKS Cluster
# Wrapper script that calls the module script with proper context

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_SCRIPT="$SCRIPT_DIR/modules/mysql/restore-backup.sh"

if [ ! -f "$MODULE_SCRIPT" ]; then
    echo "Error: Restore script not found at $MODULE_SCRIPT"
    exit 1
fi

# Execute the module script with all arguments
exec "$MODULE_SCRIPT" "$@"

