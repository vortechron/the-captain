#!/bin/bash
set -euo pipefail

# Manual MySQL Backup Script
# This script performs a backup directly from a PXC pod to MinIO

NAMESPACE="${NAMESPACE:-db}"
CLUSTER="${CLUSTER:-cluster1-pxc-db}"
BACKUP_NAME="manual-backup-$(date +%Y%m%d-%H%M%S)"

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

log_info "Starting manual MySQL backup"
log_info "Backup name: ${BACKUP_NAME}"
log_info "Cluster: ${CLUSTER}"
log_info "Namespace: ${NAMESPACE}"
echo ""

# Get credentials
log_info "Retrieving credentials..."
XTRABACKUP_PASSWORD=$(kubectl get secret ${CLUSTER}-secrets -n ${NAMESPACE} -o jsonpath='{.data.xtrabackup}' | base64 -d)
AWS_ACCESS_KEY=$(kubectl get secret minio-backup-secret -n ${NAMESPACE} -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
AWS_SECRET_KEY=$(kubectl get secret minio-backup-secret -n ${NAMESPACE} -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)

# MinIO configuration
MINIO_ENDPOINT="https://minio.aks.terapeas.com"
MINIO_BUCKET="db-backup"

log_info "Executing backup from PXC pod..."
echo ""

# Run backup from PXC pod
kubectl exec -n ${NAMESPACE} ${CLUSTER}-pxc-0 -c pxc -- bash -c "
set -exo pipefail

export HOME=/tmp
export AWS_ACCESS_KEY_ID='${AWS_ACCESS_KEY}'
export AWS_SECRET_ACCESS_KEY='${AWS_SECRET_KEY}'
export AWS_DEFAULT_REGION='us-east-1'

echo '========================================='
echo 'Starting XtraBackup...'
echo '========================================='

# Use full path to xtrabackup and xbcloud
/usr/bin/pxc_extra/pxb-8.0/bin/xtrabackup --backup \
  --user=xtrabackup \
  --password='${XTRABACKUP_PASSWORD}' \
  --stream=xbstream \
  --parallel=2 \
  --compress \
  --compress-threads=2 \
  --target-dir=/tmp | \
/usr/bin/pxc_extra/pxb-8.0/bin/xbcloud put \
  --storage=s3 \
  --s3-endpoint='${MINIO_ENDPOINT}' \
  --s3-bucket='${MINIO_BUCKET}' \
  --parallel=2 \
  '${BACKUP_NAME}'

EXIT_CODE=\$?

if [ \$EXIT_CODE -eq 0 ]; then
  echo ''
  echo '========================================='
  echo '✅ Backup completed successfully!'
  echo '========================================='
  exit 0
else
  echo ''
  echo '========================================='
  echo '❌ Backup failed!'
  echo '========================================='
  exit 1
fi
"

if [ $? -eq 0 ]; then
  echo ""
  log_success "Backup completed successfully!"
  log_info "Backup location: s3://${MINIO_BUCKET}/${BACKUP_NAME}"
  log_info "Timestamp: $(date)"
  echo ""
  log_info "To verify the backup in MinIO:"
  echo "  kubectl run aws-cli --rm -it --image=amazon/aws-cli --restart=Never -n ${NAMESPACE} -- \\"
  echo "    s3 ls s3://${MINIO_BUCKET}/${BACKUP_NAME}/ --endpoint-url=${MINIO_ENDPOINT}"
  echo ""
  exit 0
else
  echo ""
  log_error "Backup failed!"
  log_info "Check the logs above for details"
  exit 1
fi
