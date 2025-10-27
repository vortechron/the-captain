#!/bin/bash
set -euo pipefail

# MySQL Connection Helper Script

NAMESPACE="db"
CLUSTER="cluster1"

echo "🔐 MySQL Connection Helper"
echo "=========================="
echo ""

# Get root password
ROOT_PASSWORD=$(kubectl -n $NAMESPACE get secrets $CLUSTER-pxc-db-secrets -o jsonpath="{.data.root}" | base64 --decode)

echo "📋 Connection Information:"
echo "  Host: cluster1-pxc-db-haproxy.db.svc.cluster.local"
echo "  Port: 3306"
echo "  Username: root"
echo "  Password: $ROOT_PASSWORD"
echo ""

echo "🔗 Connection Methods:"
echo ""
echo "1️⃣  Port Forward (Recommended for local development):"
echo "   kubectl port-forward -n $NAMESPACE svc/$CLUSTER-pxc-db-haproxy 3306:3306"
echo "   mysql -h 127.0.0.1 -P 3306 -u root -p'$ROOT_PASSWORD'"
echo ""

echo "2️⃣  Temporary MySQL Client Pod:"
echo "   kubectl run -i --tty --rm mysql-client --image=mysql:8.0 --restart=Never -- mysql -h$CLUSTER-pxc-db-haproxy.$NAMESPACE.svc.cluster.local -uroot -p'$ROOT_PASSWORD'"
echo ""

echo "3️⃣  Direct Pod Access:"
echo "   kubectl -n $NAMESPACE exec -it $CLUSTER-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'$ROOT_PASSWORD'"
echo ""

echo "🎯 Quick Actions:"
echo ""
read -p "Start port-forward now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Starting port-forward to MySQL..."
    echo "   Connect with: mysql -h 127.0.0.1 -P 3306 -u root -p'$ROOT_PASSWORD'"
    echo "   Press Ctrl+C to stop port-forward"
    echo ""
    kubectl port-forward -n $NAMESPACE svc/$CLUSTER-pxc-db-haproxy 3306:3306
fi

echo ""
echo "📱 GUI Client Configuration:"
echo "  Host: 127.0.0.1 (when port-forward is active)"
echo "  Port: 3306"
echo "  Username: root"
echo "  Password: $ROOT_PASSWORD"
echo "  SSL: Disabled"
echo ""

echo "🔗 From Other Kubernetes Pods/Namespaces:"
echo "=========================================="
echo ""
echo "Internal Service Endpoint:"
echo "  Host: $CLUSTER-pxc-db-haproxy.db.svc.cluster.local"
echo "  Port: 3306"
echo ""
echo "Example connection from any pod in any namespace:"
echo "  mysql -h $CLUSTER-pxc-db-haproxy.db.svc.cluster.local -u root -p'$ROOT_PASSWORD'"
echo ""
echo "Test connectivity from another namespace:"
echo "  kubectl run mysql-test --image=mysql:8.0 --rm -it --restart=Never -- mysql -h$CLUSTER-pxc-db-haproxy.db.svc.cluster.local -uroot -p'$ROOT_PASSWORD'"