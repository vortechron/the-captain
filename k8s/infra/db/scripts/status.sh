#!/bin/bash
set -euo pipefail

# Percona Operator for MySQL (PXC) Status Check Script

NAMESPACE="db"
CLUSTER_RELEASE="cluster1"

echo "📊 Percona MySQL Cluster Status"
echo "================================"
echo ""

# Check namespace
echo "🏠 Namespace: $NAMESPACE"
kubectl get namespace $NAMESPACE >/dev/null 2>&1 && echo "   ✅ Exists" || echo "   ❌ Missing"
echo ""

# Check operator status
echo "⚙️  Operator Status:"
kubectl get deployment pxc-operator -n $NAMESPACE -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null && echo " pods ready" || echo "❌ Operator not found"
echo ""

# Check cluster status
echo "🗄️  Cluster Status:"
kubectl get pxc -n $NAMESPACE 2>/dev/null || echo "❌ No clusters found"
echo ""

# Check pods
echo "🔍 Pods:"
kubectl get pods -n $NAMESPACE
echo ""

# Check services
echo "🌐 Services:"
kubectl get svc -n $NAMESPACE
echo ""

# Check PVCs
echo "💾 Storage:"
kubectl get pvc -n $NAMESPACE
echo ""

# Test connection if cluster is ready
CLUSTER_STATUS=$(kubectl get pxc $CLUSTER_RELEASE-pxc-db -n $NAMESPACE -o jsonpath='{.status.state}' 2>/dev/null || echo "not-found")

if [ "$CLUSTER_STATUS" = "ready" ]; then
    echo "🧪 Connection Test:"
    ROOT_PASSWORD=$(kubectl -n $NAMESPACE get secrets $CLUSTER_RELEASE-pxc-db-secrets -o jsonpath="{.data.root}" | base64 --decode)
    
    if kubectl -n $NAMESPACE exec $CLUSTER_RELEASE-pxc-db-pxc-0 -c pxc -- mysql -uroot -p"$ROOT_PASSWORD" -e "SELECT 'Connection OK' as status;" >/dev/null 2>&1; then
        echo "   ✅ MySQL connection successful"
    else
        echo "   ❌ MySQL connection failed"
    fi
    
    echo ""
    echo "🔐 Connection Commands:"
    echo "   # Get root password:"
    echo "   kubectl get secret $CLUSTER_RELEASE-pxc-db-secrets -n $NAMESPACE -o jsonpath='{.data.root}' | base64 -d"
    echo ""
    echo "   # Connect via port-forward:"
    echo "   kubectl port-forward svc/$CLUSTER_RELEASE-pxc-db-haproxy 3306:3306 -n $NAMESPACE"
    echo ""
    echo "   # Internal service endpoint:"
    echo "   $CLUSTER_RELEASE-pxc-db-haproxy.$NAMESPACE.svc.cluster.local:3306"
else
    echo "⚠️  Cluster not ready. Current status: $CLUSTER_STATUS"
fi