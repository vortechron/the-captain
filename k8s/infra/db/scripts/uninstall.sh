#!/bin/bash
set -euo pipefail

# Percona Operator for MySQL (PXC) Uninstall Script

NAMESPACE="db"
OPERATOR_RELEASE="pxc-operator"
CLUSTER_RELEASE="cluster1"

echo "🗑️  Uninstalling Percona Operator for MySQL (PXC)..."

# Uninstall cluster first
echo "🗄️  Removing PXC Cluster ($CLUSTER_RELEASE)..."
helm uninstall $CLUSTER_RELEASE -n $NAMESPACE || true

# Wait for cluster resources to be cleaned up
echo "⏳ Waiting for cluster cleanup..."
kubectl wait --for=delete pxc/$CLUSTER_RELEASE -n $NAMESPACE --timeout=300s || true

# Uninstall operator
echo "⚙️  Removing Percona Operator ($OPERATOR_RELEASE)..."
helm uninstall $OPERATOR_RELEASE -n $NAMESPACE || true

# Clean up PVCs (CAREFUL: This deletes data!)
echo "⚠️  WARNING: About to delete all PVCs and data in namespace $NAMESPACE"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Deleting PVCs..."
    kubectl delete pvc --all -n $NAMESPACE || true
fi

# Clean up secrets
echo "🔐 Removing secrets..."
kubectl delete secret minio-backup-secret -n $NAMESPACE || true

echo "✅ Uninstall complete!"
echo ""
echo "ℹ️  Note: Namespace '$NAMESPACE' is preserved."
echo "   To remove it completely: kubectl delete namespace $NAMESPACE"