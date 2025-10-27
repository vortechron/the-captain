#!/bin/bash
set -euo pipefail

# Percona Operator for MySQL (PXC) Installation Script
# Installs operator + cluster with MinIO backups + PITR

NAMESPACE="db"
OPERATOR_RELEASE="pxc-operator"
CLUSTER_RELEASE="cluster1"

echo "🚀 Installing Percona Operator for MySQL (PXC) with MinIO backups..."

# Create namespace
echo "📁 Creating namespace: $NAMESPACE"
kubectl apply -f cluster/namespace.yaml

# Create MinIO secret for backups
echo "🔐 Creating MinIO backup secret..."
kubectl apply -f cluster/minio-secret.yaml

# Add Percona Helm repository
echo "📦 Adding Percona Helm repository..."
helm repo add percona https://percona.github.io/percona-helm-charts/
helm repo update

# Install Percona Operator
echo "⚙️  Installing Percona Operator ($OPERATOR_RELEASE)..."
helm upgrade --install $OPERATOR_RELEASE percona/pxc-operator \
  --namespace $NAMESPACE \
  --values cluster/pxc-operator-values.yaml \
  --wait \
  --timeout 300s

echo "✅ Operator installed successfully!"

# Wait for operator to be ready
echo "⏳ Waiting for operator to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=pxc-operator -n $NAMESPACE --timeout=300s

# Install PXC Cluster
echo "🗄️  Installing PXC Cluster ($CLUSTER_RELEASE)..."
helm upgrade --install $CLUSTER_RELEASE percona/pxc-db \
  --namespace $NAMESPACE \
  --values cluster/cluster1-values-minimal.yaml \
  --wait \
  --timeout 600s

echo "✅ PXC Cluster installation initiated!"

# Display connection info
echo ""
echo "🎉 Installation complete!"
echo ""
echo "📋 Connection Information:"
echo "  Namespace: $NAMESPACE"
echo "  Cluster: $CLUSTER_RELEASE"
echo "  HAProxy Service: $CLUSTER_RELEASE-haproxy.$NAMESPACE.svc.cluster.local:3306"
echo ""
echo "🔍 Check cluster status:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl get pxc -n $NAMESPACE"
echo ""
echo "🔑 Get root password:"
echo "  kubectl get secret $CLUSTER_RELEASE-secrets -n $NAMESPACE -o jsonpath='{.data.root}' | base64 -d"
echo ""
echo "💾 Backup configuration:"
echo "  - Daily backups: 02:00 UTC (keep 7 days)"
echo "  - PITR: Binlog uploads every 60s to MinIO"
echo "  - Storage: s3://db-backup/ via https://minio.terapeas.com"