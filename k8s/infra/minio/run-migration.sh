#!/bin/bash
# MinIO Cross-Cluster Migration Runner
# Usage: ./run-migration.sh <source-endpoint>
# Example: ./run-migration.sh https://minio.terapeas.com

set -e

SOURCE_ENDPOINT="${1:-${MINIO_SOURCE_ENDPOINT:-https://minio.terapeas.com}}"
TARGET_CLUSTER="${TARGET_CLUSTER:-aks-cluster}"
NAMESPACE="${NAMESPACE:-minio}"

if [ -z "$SOURCE_ENDPOINT" ]; then
    echo "ERROR: Source endpoint required"
    echo "Usage: $0 <source-endpoint>"
    echo "Example: $0 https://minio.terapeas.com"
    exit 1
fi

echo "=========================================="
echo "MinIO Cross-Cluster Migration"
echo "=========================================="
echo "Source: $SOURCE_ENDPOINT"
echo "Target: $TARGET_CLUSTER"
echo "Buckets: db-backup, terapeas, terapeas-local"
echo ""

# Switch to target cluster
kubectl config use-context "$TARGET_CLUSTER" || exit 1

# Verify MinIO is running
kubectl wait --for=condition=Ready pod -l app=minio -n "$NAMESPACE" --timeout=60s || {
    echo "ERROR: MinIO not ready"
    exit 1
}
echo "✓ MinIO is ready"
echo ""

# Apply config
kubectl apply -f "$(dirname "$0")/cross-cluster-rclone-config.yaml"

# Delete existing job if present
kubectl delete job minio-cross-cluster-migration -n "$NAMESPACE" --ignore-not-found=true --wait=true

# Apply job directly (endpoint configured in the YAML)
kubectl apply -f "$(dirname "$0")/cross-cluster-migration-job-mc.yaml"

echo ""
echo "✓ Migration job started"
echo ""
echo "Monitor progress:"
echo "  kubectl logs -f job/minio-cross-cluster-migration -n $NAMESPACE"
echo ""

# Follow logs
read -p "Follow logs now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl logs -f job/minio-cross-cluster-migration -n "$NAMESPACE"
fi

