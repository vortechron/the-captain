#!/bin/bash
set -euo pipefail

# Manual MySQL Restore Script
# This script restores a MySQL backup from MinIO

NAMESPACE="${NAMESPACE:-db}"
CLUSTER="${CLUSTER:-cluster1-pxc-db}"

# Check if backup name is provided
if [ -z "${1:-}" ]; then
  echo "Usage: $0 <backup-name>"
  echo ""
  echo "Example:"
  echo "  $0 manual-backup-20251109-152635"
  exit 1
fi

BACKUP_NAME="$1"

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

echo ""
log_warning "╔════════════════════════════════════════════════════════════╗"
log_warning "║  WARNING: This will STOP and RESTORE the MySQL cluster    ║"
log_warning "║  All current data will be REPLACED with backup data       ║"
log_warning "║  This is a DISRUPTIVE operation!                          ║"
log_warning "╚════════════════════════════════════════════════════════════╝"
echo ""

# Get MinIO credentials
log_info "Retrieving MinIO credentials..."
AWS_ACCESS_KEY=$(kubectl get secret minio-backup-secret -n ${NAMESPACE} -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
AWS_SECRET_KEY=$(kubectl get secret minio-backup-secret -n ${NAMESPACE} -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)

# MinIO configuration
MINIO_ENDPOINT="https://minio.aks.terapeas.com"
MINIO_BUCKET="db-backup"
MINIO_STORAGE_NAME="minio-storage"
MINIO_SECRET="minio-backup-secret"
MINIO_REGION="us-east-1"

log_info "Backup to restore: ${BACKUP_NAME}"
log_info "Cluster: ${CLUSTER}"
log_info "Namespace: ${NAMESPACE}"
echo ""

# Verify backup exists (skip if SKIP_VERIFY is set)
if [ "${SKIP_VERIFY:-false}" != "true" ]; then
  log_info "Verifying backup exists in MinIO..."
  POD_NAME="aws-cli-verify-$(date +%s)"
  BACKUP_CHECK=$(kubectl run ${POD_NAME} --rm -i --image=amazon/aws-cli --restart=Never -n ${NAMESPACE} \
    --env="AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY}" \
    --env="AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}" \
    --env="AWS_DEFAULT_REGION=us-east-1" \
    -- \
    s3 ls "s3://${MINIO_BUCKET}/${BACKUP_NAME}/" --endpoint-url="${MINIO_ENDPOINT}" 2>&1 || true)

  if echo "$BACKUP_CHECK" | grep -q -E "(xtrabackup_info|backup-my\.cnf|\.zst)"; then
    log_success "Backup verified in MinIO"
    echo ""
  else
    log_error "Backup not found or invalid: ${BACKUP_NAME}"
    echo "Debug output:"
    echo "$BACKUP_CHECK"
    exit 1
  fi
else
  log_info "Skipping backup verification (SKIP_VERIFY=true)"
fi

# Final confirmation (skip if SKIP_CONFIRM is set)
if [ "${SKIP_CONFIRM:-false}" != "true" ]; then
  log_warning "You are about to restore backup: ${BACKUP_NAME}"
  log_warning "This will:"
  log_warning "  1. Stop the MySQL cluster"
  log_warning "  2. Delete all current data"
  log_warning "  3. Restore data from backup"
  log_warning "  4. Restart the cluster"
  echo ""
  read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM

  if [ "$CONFIRM" != "yes" ]; then
    log_info "Restore cancelled"
    exit 0
  fi
else
  log_warning "Skipping confirmation (SKIP_CONFIRM=true)"
  log_warning "Proceeding with restore of: ${BACKUP_NAME}"
fi

echo ""
log_info "Starting restore process..."

# Create restore resource name
RESTORE_NAME="restore-$(date +%Y%m%d-%H%M%S)"

log_info "Creating restore resource: ${RESTORE_NAME}"

# Create the restore
kubectl apply -f - <<EOF
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterRestore
metadata:
  name: ${RESTORE_NAME}
  namespace: ${NAMESPACE}
spec:
  pxcCluster: ${CLUSTER}
  backupSource:
    destination: s3://${MINIO_BUCKET}/${BACKUP_NAME}
    storageName: ${MINIO_STORAGE_NAME}
    s3:
      bucket: ${MINIO_BUCKET}
      credentialsSecret: ${MINIO_SECRET}
      endpointUrl: ${MINIO_ENDPOINT}
      region: ${MINIO_REGION}
EOF

if [ $? -eq 0 ]; then
  log_success "Restore resource created"
  echo ""
  log_info "Monitoring restore progress..."
  echo ""

  # Monitor restore status
  TIMEOUT=1800  # 30 minutes timeout
  ELAPSED=0
  INTERVAL=5

  while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(kubectl get pxc-restore ${RESTORE_NAME} -n ${NAMESPACE} -o jsonpath='{.status.state}' 2>/dev/null || echo "unknown")

    case "$STATUS" in
      "ready"|"succeeded")
        echo ""
        log_success "Restore completed successfully!"
        log_info "Backup restored: ${BACKUP_NAME}"
        log_info "Restore name: ${RESTORE_NAME}"
        echo ""
        log_info "Checking cluster status..."
        kubectl get pxc ${CLUSTER} -n ${NAMESPACE}
        echo ""
        log_info "To verify the restore:"
        echo "  kubectl exec -n ${NAMESPACE} ${CLUSTER}-pxc-0 -c pxc -- mysql -uroot -p\$(kubectl get secret ${CLUSTER}-secrets -n ${NAMESPACE} -o jsonpath='{.data.root}' | base64 -d) -e 'SHOW DATABASES;'"
        echo ""
        exit 0
        ;;
      "error"|"failed")
        echo ""
        log_error "Restore failed!"
        echo ""
        log_info "Checking restore details:"
        kubectl describe pxc-restore ${RESTORE_NAME} -n ${NAMESPACE}
        exit 1
        ;;
      "running")
        printf "\r${BLUE}ℹ${NC} Restore in progress... (${ELAPSED}s elapsed)"
        ;;
      *)
        printf "\r${BLUE}ℹ${NC} Waiting for restore to start... (${ELAPSED}s elapsed)"
        ;;
    esac

    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
  done

  echo ""
  log_error "Restore timed out after ${TIMEOUT} seconds"
  log_info "Check status manually:"
  echo "  kubectl get pxc-restore ${RESTORE_NAME} -n ${NAMESPACE}"
  echo "  kubectl describe pxc-restore ${RESTORE_NAME} -n ${NAMESPACE}"
  exit 1
else
  log_error "Failed to create restore resource"
  exit 1
fi
