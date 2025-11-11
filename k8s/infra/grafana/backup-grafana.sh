#!/bin/bash
set -euo pipefail

# Grafana Backup Script
# This script backs up Grafana data from a Kubernetes cluster to local storage

SOURCE_CLUSTER="${SOURCE_CLUSTER:-}"
NAMESPACE="${NAMESPACE:-observability}"
BACKUP_DIR="grafana-backup-$(date +%Y%m%d-%H%M%S)"

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

# Switch to source cluster if specified
if [ -n "$SOURCE_CLUSTER" ]; then
    log_info "Switching to source cluster: $SOURCE_CLUSTER"
    kubectl config use-context "$SOURCE_CLUSTER" || {
        log_error "Failed to switch to cluster: $SOURCE_CLUSTER"
        exit 1
    }
fi

log_info "Starting Grafana backup"
log_info "Namespace: ${NAMESPACE}"
log_info "Backup directory: ${BACKUP_DIR}"
echo ""

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

# Create local backup directory
log_info "Creating local backup directory..."
mkdir -p "${BACKUP_DIR}"

# Copy Grafana data from pod to local directory
log_info "Copying /var/lib/grafana from pod to local directory..."
log_info "This may take a few minutes depending on data size..."
echo ""

if kubectl cp "${NAMESPACE}/${GRAFANA_POD}:/var/lib/grafana" \
    "${BACKUP_DIR}/grafana"; then
    echo ""
    log_success "Backup completed successfully!"
    log_info "Backup location: $(pwd)/${BACKUP_DIR}"
    log_info "Backup size: $(du -sh "${BACKUP_DIR}" | cut -f1)"
    echo ""
    log_info "To restore this backup, run:"
    echo "  TARGET_CLUSTER=<azure-cluster> ./restore-grafana.sh ${BACKUP_DIR}"
    echo ""
    exit 0
else
    echo ""
    log_error "Failed to copy Grafana data"
    rm -rf "${BACKUP_DIR}"
    exit 1
fi

