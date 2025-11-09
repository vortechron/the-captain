#!/bin/bash
set -euo pipefail

# MySQL Backup Restore Script for AKS Cluster
# This script restores a backup from MinIO db-backup bucket to MySQL cluster

# Configuration (can be overridden via environment variables)
NAMESPACE="${MYSQL_NAMESPACE:-db}"
CLUSTER_NAME="${MYSQL_CLUSTER_NAME:-cluster1}"
PXC_CLUSTER="${PXC_CLUSTER:-${CLUSTER_NAME}-pxc-db}"
MINIO_NAMESPACE="${MINIO_NAMESPACE:-minio}"
MINIO_BUCKET="${MINIO_BUCKET:-db-backup}"
MINIO_REGION="${MINIO_REGION:-us-east-1}"

# Detect MinIO endpoint - prefer internal service if available
# Internal endpoint for pods running in cluster
MINIO_INTERNAL_ENDPOINT="http://minio-service.${MINIO_NAMESPACE}.svc.cluster.local:9000"
# External endpoint (fallback)
MINIO_EXTERNAL_ENDPOINT="${MINIO_ENDPOINT:-https://minio.aks.terapeas.com}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    
    # Check if PXC cluster exists
    if ! kubectl get pxc "$PXC_CLUSTER" -n "$NAMESPACE" &> /dev/null; then
        log_error "PXC cluster '$PXC_CLUSTER' not found in namespace '$NAMESPACE'"
        exit 1
    fi
    
    # Check if MinIO secret exists
    if ! kubectl get secret minio-backup-secret -n "$NAMESPACE" &> /dev/null; then
        log_error "MinIO backup secret 'minio-backup-secret' not found in namespace '$NAMESPACE'"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Get MinIO credentials from secret
get_minio_credentials() {
    log_info "Retrieving MinIO credentials from secret..."
    
    ACCESS_KEY=$(kubectl get secret minio-backup-secret -n "$NAMESPACE" -o jsonpath='{.data.ACCESS_KEY_ID}' | base64 -d)
    SECRET_KEY=$(kubectl get secret minio-backup-secret -n "$NAMESPACE" -o jsonpath='{.data.SECRET_ACCESS_KEY}' | base64 -d)
    
    if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
        log_error "Failed to retrieve MinIO credentials from secret"
        exit 1
    fi
    
    log_success "MinIO credentials retrieved"
}

# List available backups from MinIO using mc (MinIO Client) in a pod
# Uses the same approach as the migration job
list_backups() {
    log_info "Listing available backups from MinIO..."
    
    # Try internal endpoint first (faster, more reliable)
    log_info "Attempting to connect via internal service endpoint..."
    
    MC_POD_NAME="mc-list-backups-$(date +%s)"
    
    # Use a Job instead of kubectl run for better reliability
    # Pass credentials as environment variables (similar to migration job)
    cat <<EOF | kubectl apply -f - > /dev/null 2>&1
apiVersion: batch/v1
kind: Job
metadata:
  name: ${MC_POD_NAME}
  namespace: ${NAMESPACE}
spec:
  ttlSecondsAfterFinished: 300
  backoffLimit: 1
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: mc-client
        image: minio/mc:latest
        env:
        - name: ACCESS_KEY
          value: "${ACCESS_KEY}"
        - name: SECRET_KEY
          value: "${SECRET_KEY}"
        - name: MINIO_INTERNAL_ENDPOINT
          value: "${MINIO_INTERNAL_ENDPOINT}"
        - name: MINIO_EXTERNAL_ENDPOINT
          value: "${MINIO_EXTERNAL_ENDPOINT}"
        - name: MINIO_BUCKET
          value: "${MINIO_BUCKET}"
        command:
        - /bin/sh
        - -c
        - |
          set -e
          echo "Configuring MinIO aliases..."
          
          # Try internal endpoint first (no --insecure needed for HTTP)
          if mc alias set minio-internal "\${MINIO_INTERNAL_ENDPOINT}" "\${ACCESS_KEY}" "\${SECRET_KEY}" 2>/dev/null; then
            echo "✓ Connected via internal endpoint"
            ENDPOINT="minio-internal"
          elif mc alias set minio-external "\${MINIO_EXTERNAL_ENDPOINT}" "\${ACCESS_KEY}" "\${SECRET_KEY}" --insecure 2>/dev/null; then
            echo "✓ Connected via external endpoint"
            ENDPOINT="minio-external"
            USE_INSECURE="--insecure"
          else
            echo "ERROR: Cannot connect to MinIO"
            echo "Tried internal: \${MINIO_INTERNAL_ENDPOINT}"
            echo "Tried external: \${MINIO_EXTERNAL_ENDPOINT}"
            exit 1
          fi
          
          echo "Listing backups in bucket: \${MINIO_BUCKET}"
          echo ""
          
          # List all backup folders (Percona backups are typically in folders named like cluster-name-timestamp-full)
          mc ls \${ENDPOINT}/\${MINIO_BUCKET}/ \${USE_INSECURE:-} | \
            grep -E '(full|backup|cluster|pxc)' | \
            awk '{print \$NF}' | \
            sed 's|/$||' | \
            sort -r | \
            head -30
EOF

    # Wait for job to complete
    log_info "Waiting for backup listing job to complete..."
    kubectl wait --for=condition=complete --timeout=60s job/${MC_POD_NAME} -n "${NAMESPACE}" > /dev/null 2>&1 || true
    
    # Wait a bit for logs to be available
    sleep 2
    
    # Get job output - filter out status messages
    BACKUP_LIST=$(kubectl logs job/${MC_POD_NAME} -n "${NAMESPACE}" 2>/dev/null | \
        grep -v -E "(Configuring|Connected|Listing|ERROR|Tried)" | \
        grep -v "^$" | \
        grep -E "(full|backup|cluster|pxc)" || echo "")
    
    # Check if job failed
    JOB_STATUS=$(kubectl get job ${MC_POD_NAME} -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || echo "")
    if [ "$JOB_STATUS" == "True" ]; then
        log_warning "Job failed. Checking logs for details..."
        kubectl logs job/${MC_POD_NAME} -n "${NAMESPACE}" 2>&1 | tail -10
        kubectl delete job ${MC_POD_NAME} -n "${NAMESPACE}" > /dev/null 2>&1 || true
        list_backups_alternative
        return 1
    fi
    
    # Cleanup job
    kubectl delete job ${MC_POD_NAME} -n "${NAMESPACE}" > /dev/null 2>&1 || true
    
    if [ -n "$BACKUP_LIST" ]; then
        echo ""
        echo "Available backups in MinIO (newest first):"
        echo "==========================================="
        echo "$BACKUP_LIST" | while read -r backup_name; do
            if [ -n "$backup_name" ]; then
                echo "  - $backup_name"
            fi
        done
        echo ""
        log_info "Note: Use the backup folder name as shown above for restore"
        return 0
    else
        log_warning "No backups found or could not list backups from MinIO"
        list_backups_alternative
        return 1
    fi
}

# Alternative method: List backups using kubectl get pxc-backups
list_backups_alternative() {
    log_info "Listing backups from Kubernetes resources..."
    
    BACKUPS=$(kubectl get pxc-backups -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.destination}{"\t"}{.status.state}{"\t"}{.metadata.creationTimestamp}{"\n"}{end}' 2>/dev/null | sort -k4 -r || echo "")
    
    if [ -z "$BACKUPS" ]; then
        log_warning "No backup resources found in Kubernetes. You may need to specify backup name manually."
        echo ""
        echo "To find backups in MinIO manually, you can:"
        echo ""
        echo "Option 1: Use MinIO client in a pod:"
        echo "  kubectl run mc-client --image=minio/mc:latest --rm -it --restart=Never -n ${NAMESPACE} -- \\"
        echo "    sh -c 'mc alias set minio ${MINIO_INTERNAL_ENDPOINT} ${ACCESS_KEY} ${SECRET_KEY} && mc ls minio/${MINIO_BUCKET}/ --recursive'"
        echo ""
        echo "Option 2: Access MinIO console externally:"
        echo "  External endpoint: ${MINIO_EXTERNAL_ENDPOINT}"
        echo "  Browse bucket: ${MINIO_BUCKET}"
        echo "  Look for folders like: ${PXC_CLUSTER}-YYYY-MM-DD-HH:MM:SS-full"
        echo ""
        echo "Option 3: Check Kubernetes backup resources:"
        echo "  kubectl get pxc-backups -n ${NAMESPACE}"
        return
    fi
    
    echo ""
    echo "Available backups (sorted by creation time, newest first):"
    echo "============================================================"
    printf "%-50s %-20s %-15s\n" "BACKUP NAME" "CREATED" "STATE"
    echo "------------------------------------------------------------------------------------------------"
    echo "$BACKUPS" | while IFS=$'\t' read -r name dest state created; do
        # Format timestamp to be more readable
        created_short=$(echo "$created" | cut -d'T' -f1,2 | sed 's/T/ /' | cut -d'.' -f1 | cut -d'Z' -f1)
        printf "%-50s %-20s %-15s\n" "$name" "$created_short" "$state"
    done
    echo ""
    log_info "To restore, use: $0 --backup <BACKUP_NAME>"
    echo ""
}

# Check if backup resource exists, if not, try to find it or create reference
check_backup_exists() {
    local backup_name=$1
    
    # Check if backup resource exists in Kubernetes
    if kubectl get pxc-backup "$backup_name" -n "$NAMESPACE" &> /dev/null; then
        log_success "Found backup resource: $backup_name"
        return 0
    fi
    
    # Check if it looks like an S3 path (contains / or s3://)
    if [[ "$backup_name" == *"/"* ]] || [[ "$backup_name" == s3://* ]]; then
        log_warning "Backup name looks like an S3 path. Percona restore requires a backup resource name."
        log_info "You may need to create a PerconaXtraDBClusterBackup resource that references this S3 path first."
        return 1
    fi
    
    # Check if it's a folder name from MinIO (might need to be registered)
    log_warning "Backup resource '$backup_name' not found in Kubernetes."
    log_info "This might be a backup from another cluster or a folder name from MinIO."
    log_info "The backup name should match a PerconaXtraDBClusterBackup resource name."
    echo ""
    echo "To find the correct backup name, run:"
    echo "  kubectl get pxc-backups -n $NAMESPACE"
    echo ""
    echo "Or if this is a backup from MinIO, you may need to:"
    echo "1. Create a PerconaXtraDBClusterBackup resource pointing to the S3 path, or"
    echo "2. Use the backup name that matches the Kubernetes resource"
    echo ""
    
    read -p "Do you want to proceed anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 1
    fi
    return 0
}

# Restore from backup
restore_from_backup() {
    local backup_name=$1
    local pitr_date=${2:-}
    
    log_info "Preparing restore for backup: $backup_name"
    
    # Check if backup exists (warn but allow to proceed)
    if ! check_backup_exists "$backup_name"; then
        log_error "Cannot proceed with restore. Please verify the backup name."
        exit 1
    fi
    
    RESTORE_NAME="restore-$(date +%Y%m%d-%H%M%S)"
    
    # Create restore manifest
    if [ -z "$pitr_date" ]; then
        # Full restore
        log_info "Performing full restore..."
        kubectl apply -f - <<EOF
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterRestore
metadata:
  name: $RESTORE_NAME
  namespace: $NAMESPACE
spec:
  pxcCluster: $PXC_CLUSTER
  backupName: $backup_name
EOF
    else
        # Point-in-time restore
        log_info "Performing point-in-time restore to: $pitr_date"
        kubectl apply -f - <<EOF
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterRestore
metadata:
  name: $RESTORE_NAME
  namespace: $NAMESPACE
spec:
  pxcCluster: $PXC_CLUSTER
  backupName: $backup_name
  pitr:
    type: date
    date: "$pitr_date"
EOF
    fi
    
    log_success "Restore job '$RESTORE_NAME' created"
    echo ""
    log_info "Monitoring restore progress (Ctrl+C to stop monitoring)..."
    echo ""
    
    # Monitor restore progress
    watch_restore "$RESTORE_NAME"
}

# Watch restore progress
watch_restore() {
    local restore_name=$1
    
    while true; do
        STATE=$(kubectl get pxc-restore "$restore_name" -n "$NAMESPACE" -o jsonpath='{.status.state}' 2>/dev/null || echo "Unknown")
        
        case "$STATE" in
            "Succeeded")
                log_success "Restore completed successfully!"
                echo ""
                log_info "Restore details:"
                kubectl get pxc-restore "$restore_name" -n "$NAMESPACE" -o yaml | grep -A 10 "status:"
                break
                ;;
            "Failed"|"Error")
                log_error "Restore failed!"
                echo ""
                log_info "Restore details:"
                kubectl get pxc-restore "$restore_name" -n "$NAMESPACE" -o yaml | grep -A 20 "status:"
                log_info "Check restore pod logs for more details:"
                echo "  kubectl logs -n $NAMESPACE -l percona.com/restore-name=$restore_name"
                exit 1
                ;;
            "New"|"InProgress"|"")
                echo -ne "\r${BLUE}Restore status: ${STATE:-Pending}...${NC}"
                sleep 2
                ;;
            *)
                echo -ne "\r${YELLOW}Restore status: $STATE...${NC}"
                sleep 2
                ;;
        esac
    done
    echo ""
}

# Interactive backup selection
interactive_restore() {
    echo ""
    log_info "Interactive restore mode"
    echo "=========================="
    echo ""
    
    # Try to list backups from Kubernetes first
    list_backups_alternative
    
    echo "Enter backup name (or press Enter to list from MinIO):"
    read -r backup_name
    
    if [ -z "$backup_name" ]; then
        log_info "Attempting to list backups from MinIO..."
        get_minio_credentials
        
        # Try listing from MinIO
        if ! list_backups; then
            log_warning "Could not list backups from MinIO. Please enter backup name manually."
        fi
        
        echo ""
        echo "Enter backup name (use folder name from MinIO, e.g., cluster1-pxc-db-2024-01-01-12:00:00-full):"
        read -r backup_name
    fi
    
    if [ -z "$backup_name" ]; then
        log_error "Backup name is required"
        exit 1
    fi
    
    echo ""
    echo "Do you want to perform a point-in-time restore? (y/N)"
    read -r pitr_choice
    
    pitr_date=""
    if [[ "$pitr_choice" =~ ^[Yy]$ ]]; then
        echo "Enter restore date/time (ISO 8601 format, e.g., 2024-01-01T10:30:00Z):"
        read -r pitr_date
    fi
    
    echo ""
    log_warning "WARNING: This will restore the database from backup!"
    log_warning "The current database state will be replaced with the backup data."
    echo ""
    echo "Are you sure you want to proceed? (yes/no)"
    read -r confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi
    
    restore_from_backup "$backup_name" "$pitr_date"
}

# Main script
main() {
    echo "=========================================="
    echo "  MySQL Backup Restore Script"
    echo "  AKS Cluster: $(kubectl config current-context 2>/dev/null || echo 'unknown')"
    echo "=========================================="
    echo ""
    echo "Configuration:"
    echo "  Namespace: $NAMESPACE"
    echo "  Cluster: $PXC_CLUSTER"
    echo "  MinIO Namespace: $MINIO_NAMESPACE"
    echo "  MinIO Internal: $MINIO_INTERNAL_ENDPOINT"
    echo "  MinIO External: $MINIO_EXTERNAL_ENDPOINT"
    echo "  Bucket: $MINIO_BUCKET"
    echo ""
    
    check_prerequisites
    
    # Parse command line arguments
    if [ $# -eq 0 ]; then
        interactive_restore
    elif [ "$1" == "--list" ] || [ "$1" == "-l" ]; then
        get_minio_credentials
        list_backups
    elif [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
        cat <<EOF
Usage: $0 [OPTIONS] [BACKUP_NAME] [PITR_DATE]

Restore MySQL backup from MinIO to Percona XtraDB Cluster.

Options:
  --list, -l              List available backups
  --backup BACKUP_NAME    Restore from specific backup name
  --pitr DATE             Point-in-time restore to specific date (ISO 8601 format)
  --help, -h              Show this help message

Environment Variables:
  MYSQL_NAMESPACE         Kubernetes namespace (default: db)
  MYSQL_CLUSTER_NAME      MySQL cluster name (default: cluster1)
  PXC_CLUSTER             PXC cluster name (default: {CLUSTER_NAME}-pxc-db)
  MINIO_ENDPOINT          MinIO endpoint URL (default: https://minio.aks.terapeas.com)
  MINIO_BUCKET            MinIO bucket name (default: db-backup)
  MINIO_REGION            MinIO region (default: us-east-1)

Examples:
  # Interactive restore
  $0

  # List backups
  $0 --list

  # Full restore from specific backup
  $0 --backup manual-backup-20240101-120000

  # Point-in-time restore
  $0 --backup manual-backup-20240101-120000 --pitr "2024-01-01T10:30:00Z"

EOF
        exit 0
    elif [ "$1" == "--backup" ]; then
        if [ -z "${2:-}" ]; then
            log_error "Backup name is required after --backup"
            exit 1
        fi
        backup_name=$2
        pitr_date=${4:-}
        if [ "$3" == "--pitr" ] && [ -n "${4:-}" ]; then
            pitr_date=$4
        fi
        restore_from_backup "$backup_name" "$pitr_date"
    else
        # Positional arguments: backup_name [pitr_date]
        backup_name=$1
        pitr_date=${2:-}
        restore_from_backup "$backup_name" "$pitr_date"
    fi
}

# Run main function
main "$@"

