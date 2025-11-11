#!/bin/bash
set -euo pipefail

# Grafana Restore Script
# This script restores Grafana data from local backup to a Kubernetes cluster

TARGET_CLUSTER="${TARGET_CLUSTER:-}"
NAMESPACE="${NAMESPACE:-observability}"

# Check if backup directory is provided
if [ -z "${1:-}" ]; then
    echo "Usage: $0 <backup-directory>"
    echo ""
    echo "Example:"
    echo "  TARGET_CLUSTER=aks-cluster $0 grafana-backup-20250110-120000"
    exit 1
fi

BACKUP_DIR="$1"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Verify backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    log_error "Backup directory not found: $BACKUP_DIR"
    exit 1
fi

# Convert to absolute path if relative (now that we know it exists)
if [[ ! "$BACKUP_DIR" = /* ]]; then
    BACKUP_DIR="$(cd "$(dirname "$BACKUP_DIR")" && pwd)/$(basename "$BACKUP_DIR")"
fi

# Verify grafana subdirectory exists
if [ ! -d "$BACKUP_DIR/grafana" ]; then
    log_error "Grafana data not found in backup directory: $BACKUP_DIR/grafana"
    exit 1
fi

echo ""
log_warning "╔════════════════════════════════════════════════════════════╗"
log_warning "║  WARNING: This will OVERWRITE Grafana data in the pod    ║"
log_warning "║  This includes users, orgs, API keys, and dashboards    ║"
log_warning "║  This is a DISRUPTIVE operation!                          ║"
log_warning "╚════════════════════════════════════════════════════════════╝"
echo ""

log_info "Backup directory: $BACKUP_DIR"
log_info "Target namespace: $NAMESPACE"
if [ -n "$TARGET_CLUSTER" ]; then
    log_info "Target cluster: $TARGET_CLUSTER"
fi
echo ""

# Confirmation prompt
read -p "Are you sure you want to proceed? (yes/no): " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "Restore cancelled"
    exit 0
fi

# Switch to target cluster if specified
if [ -n "$TARGET_CLUSTER" ]; then
    log_info "Switching to target cluster: $TARGET_CLUSTER"
    kubectl config use-context "$TARGET_CLUSTER" || {
        log_error "Failed to switch to cluster: $TARGET_CLUSTER"
        exit 1
    }
fi

# Get Grafana pod name
log_info "Detecting Grafana pod..."
GRAFANA_POD=$(kubectl get pods --namespace "${NAMESPACE}" \
    -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" \
    -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")

if [ -z "$GRAFANA_POD" ]; then
    log_error "Grafana pod not found in namespace ${NAMESPACE}"
    log_info "Available pods:"
    kubectl get pods --namespace "${NAMESPACE}" || true
    exit 1
fi

log_success "Found Grafana pod: ${GRAFANA_POD}"

# Verify pod is running
log_info "Verifying pod is ready..."
kubectl wait --for=condition=Ready pod/"${GRAFANA_POD}" \
    --namespace "${NAMESPACE}" \
    --timeout=60s || {
    log_error "Grafana pod is not ready"
    exit 1
}

# Copy local backup to pod
log_info "Copying backup data to Grafana pod..."
log_info "This will overwrite existing data in /var/lib/grafana"
log_info "This may take a few minutes depending on data size..."
echo ""

# Note: kubectl cp creates a subdirectory when copying a directory to an existing directory
# So we copy to a temp location first, then move contents to the correct location
log_info "Copying to temporary location..."
if kubectl cp "${BACKUP_DIR}/grafana" \
    "${NAMESPACE}/${GRAFANA_POD}:/tmp/grafana-restore"; then
    log_info "Moving files to correct location..."
    if kubectl exec "${GRAFANA_POD}" --namespace "${NAMESPACE}" -- sh -c "
        cd /var/lib/grafana
        # Backup existing data (optional safety measure)
        if [ -f grafana.db ]; then
            mv grafana.db grafana.db.backup-\$(date +%s) 2>/dev/null || true
        fi
        # Copy all files from temp location
        cp -r /tmp/grafana-restore/* .
        # Clean up temp location
        rm -rf /tmp/grafana-restore
        # Ensure correct permissions
        chown -R grafana:grafana /var/lib/grafana
        echo 'Files moved successfully'
    "; then
    
    echo ""
    log_success "Restore completed successfully!"
    log_info "Grafana pod: ${GRAFANA_POD}"
    log_info "Restarting Grafana pod to apply changes..."
    
    # Restart the pod to ensure Grafana picks up the restored data
    kubectl delete pod "${GRAFANA_POD}" --namespace "${NAMESPACE}" --wait=false || {
        log_warning "Failed to restart pod automatically. Please restart manually:"
        echo "  kubectl delete pod ${GRAFANA_POD} -n ${NAMESPACE}"
    }
    
    echo ""
    log_info "Waiting for new pod to be ready..."
    sleep 5
    NEW_POD=$(kubectl get pods --namespace "${NAMESPACE}" \
        -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" \
        -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")
    
    if [ -n "$NEW_POD" ]; then
        kubectl wait --for=condition=Ready pod/"${NEW_POD}" \
            --namespace "${NAMESPACE}" \
            --timeout=120s && {
            log_success "Grafana pod restarted and ready!"
        } || {
            log_warning "Pod restart in progress. Check status with:"
            echo "  kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/name=grafana"
        }
    fi
        echo ""
        exit 0
    else
        log_error "Failed to move files to correct location"
        kubectl exec "${GRAFANA_POD}" --namespace "${NAMESPACE}" -- rm -rf /tmp/grafana-restore || true
        exit 1
    fi
else
    echo ""
    log_error "Failed to copy Grafana data to pod"
    exit 1
fi

