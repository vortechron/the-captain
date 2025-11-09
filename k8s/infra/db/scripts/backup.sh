#!/bin/bash
set -euo pipefail

# MySQL Backup Trigger Script
# Manually trigger MySQL backups for Percona XtraDB Cluster

NAMESPACE="${NAMESPACE:-db}"
CLUSTER="${CLUSTER:-cluster1}"
PXC_CLUSTER="${PXC_CLUSTER:-${CLUSTER}-pxc-db}"
STORAGE_NAME="minio-storage"

# Colors and emojis for output
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
    
    # Check if cluster is ready
    CLUSTER_STATUS=$(kubectl get pxc "$PXC_CLUSTER" -n "$NAMESPACE" -o jsonpath='{.status.state}' 2>/dev/null || echo "not-found")
    if [ "$CLUSTER_STATUS" != "ready" ]; then
        log_warning "Cluster status is '$CLUSTER_STATUS' (expected 'ready'). Backup may fail."
    fi
    
    log_success "Prerequisites check passed"
}

# Create backup
create_backup() {
    local backup_name=$1
    
    log_info "Creating backup: $backup_name"
    
    # Create PerconaXtraDBClusterBackup resource
    kubectl apply -f - <<EOF
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata:
  name: $backup_name
  namespace: $NAMESPACE
spec:
  pxcCluster: $PXC_CLUSTER
  storageName: $STORAGE_NAME
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Backup resource '$backup_name' created successfully"
        return 0
    else
        log_error "Failed to create backup resource"
        return 1
    fi
}

# Watch backup progress
watch_backup() {
    local backup_name=$1
    
    log_info "Monitoring backup progress (Ctrl+C to stop monitoring)..."
    echo ""
    
    local last_state=""
    local start_time=$(date +%s)
    
    while true; do
        STATE=$(kubectl get pxc-backup "$backup_name" -n "$NAMESPACE" -o jsonpath='{.status.state}' 2>/dev/null || echo "Unknown")
        
        # Get additional status info
        DESTINATION=$(kubectl get pxc-backup "$backup_name" -n "$NAMESPACE" -o jsonpath='{.status.destination}' 2>/dev/null || echo "")
        
        # Only print when state changes
        if [ "$STATE" != "$last_state" ]; then
            case "$STATE" in
                "Succeeded")
                    local elapsed=$(($(date +%s) - start_time))
                    log_success "Backup completed successfully!"
                    echo ""
                    echo "📋 Backup Details:"
                    echo "   Name: $backup_name"
                    echo "   Destination: ${DESTINATION:-N/A}"
                    echo "   Duration: ${elapsed}s"
                    echo ""
                    log_info "Backup is available in MinIO storage"
                    break
                    ;;
                "Failed"|"Error")
                    log_error "Backup failed!"
                    echo ""
                    echo "📋 Backup Details:"
                    kubectl get pxc-backup "$backup_name" -n "$NAMESPACE" -o yaml | grep -A 20 "status:" || true
                    echo ""
                    log_info "Check backup pod logs for details:"
                    echo "   kubectl logs -n $NAMESPACE -l percona.com/backup-name=$backup_name"
                    exit 1
                    ;;
                "New"|"InProgress"|"")
                    if [ -z "$last_state" ]; then
                        echo -e "${BLUE}⏳ Backup status: ${STATE:-Pending}...${NC}"
                    else
                        echo -e "${BLUE}⏳ Backup status: $last_state → ${STATE:-Pending}...${NC}"
                    fi
                    ;;
                *)
                    echo -e "${YELLOW}⏳ Backup status: $STATE...${NC}"
                    ;;
            esac
            last_state="$STATE"
        fi
        
        # Check if backup resource was deleted
        if ! kubectl get pxc-backup "$backup_name" -n "$NAMESPACE" &> /dev/null; then
            log_warning "Backup resource '$backup_name' no longer exists"
            break
        fi
        
        sleep 2
    done
}

# List existing backups
list_backups() {
    log_info "Listing existing backups..."
    echo ""
    
    BACKUPS=$(kubectl get pxc-backups -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.state}{"\t"}{.status.destination}{"\t"}{.metadata.creationTimestamp}{"\n"}{end}' 2>/dev/null | sort -k4 -r || echo "")
    
    if [ -z "$BACKUPS" ]; then
        log_warning "No backup resources found in namespace '$NAMESPACE'"
        echo ""
        echo "To create a backup, run:"
        echo "   $0"
        return 1
    fi
    
    echo "📋 Available Backups (newest first):"
    echo "======================================"
    printf "%-50s %-15s %-10s\n" "BACKUP NAME" "STATE" "CREATED"
    echo "------------------------------------------------------------------------------------------------"
    
    echo "$BACKUPS" | while IFS=$'\t' read -r name state dest created; do
        # Format timestamp to be more readable
        created_short=$(echo "$created" | cut -d'T' -f1,2 | sed 's/T/ /' | cut -d'.' -f1 | cut -d'Z' -f1 || echo "$created")
        
        # Color code state
        case "$state" in
            "Succeeded")
                state_display="${GREEN}✓ $state${NC}"
                ;;
            "Failed"|"Error")
                state_display="${RED}✗ $state${NC}"
                ;;
            "InProgress")
                state_display="${BLUE}⏳ $state${NC}"
                ;;
            *)
                state_display="$state"
                ;;
        esac
        
        printf "%-50s %-15s %-10s\n" "$name" "$(echo -e "$state_display")" "$created_short"
    done
    
    echo ""
    log_info "To view backup details:"
    echo "   kubectl describe pxc-backup <BACKUP_NAME> -n $NAMESPACE"
    echo ""
    log_info "To view backup logs:"
    echo "   kubectl logs -n $NAMESPACE -l percona.com/backup-name=<BACKUP_NAME>"
}

# Show help
show_help() {
    cat <<EOF
💾 MySQL Backup Trigger Script
==============================

Manually trigger MySQL backups for Percona XtraDB Cluster.

Usage:
  $0 [OPTIONS]

Options:
  --name NAME       Create backup with custom name (default: manual-backup-YYYYMMDD-HHMMSS)
  --list, -l        List existing backups
  --help, -h        Show this help message

Environment Variables:
  NAMESPACE         Kubernetes namespace (default: db)
  CLUSTER           MySQL cluster name (default: cluster1)
  PXC_CLUSTER       PXC cluster name (default: {CLUSTER}-pxc-db)

Examples:
  # Create backup with auto-generated name
  $0

  # Create backup with custom name
  $0 --name my-backup-2024

  # List existing backups
  $0 --list

  # Use different namespace
  NAMESPACE=production $0

EOF
}

# Main function
main() {
    echo "💾 MySQL Backup Trigger"
    echo "======================="
    echo ""
    echo "Configuration:"
    echo "  Namespace: $NAMESPACE"
    echo "  Cluster: $PXC_CLUSTER"
    echo "  Storage: $STORAGE_NAME"
    echo ""
    
    # Parse command line arguments
    if [ $# -eq 0 ]; then
        # Default: create backup with timestamp
        check_prerequisites
        BACKUP_NAME="manual-backup-$(date +%Y%m%d-%H%M%S)"
        create_backup "$BACKUP_NAME"
        if [ $? -eq 0 ]; then
            watch_backup "$BACKUP_NAME"
        fi
    elif [ "$1" == "--list" ] || [ "$1" == "-l" ]; then
        check_prerequisites
        list_backups
    elif [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
        show_help
        exit 0
    elif [ "$1" == "--name" ]; then
        if [ -z "${2:-}" ]; then
            log_error "Backup name is required after --name"
            exit 1
        fi
        check_prerequisites
        create_backup "$2"
        if [ $? -eq 0 ]; then
            watch_backup "$2"
        fi
    else
        log_error "Unknown option: $1"
        echo ""
        show_help
        exit 1
    fi
}

# Run main function
main "$@"

