#!/bin/bash
set -euo pipefail

# MySQL Monitoring Setup and Test Script

NAMESPACE="db"
OBS_NAMESPACE="observability"

echo "🔍 MySQL Monitoring Status Check"
echo "================================="
echo ""

# Check MySQL Exporter
echo "📊 MySQL Exporter Status:"
kubectl get pods -n $NAMESPACE -l app=mysql-exporter
echo ""

# Check Prometheus
echo "📈 Prometheus Status:"
kubectl get pods -n $OBS_NAMESPACE -l app=prometheus
echo ""

# Test MySQL Exporter Metrics
echo "🧪 Testing MySQL Exporter Metrics:"
echo "Port-forwarding to MySQL Exporter..."
kubectl port-forward -n $NAMESPACE svc/mysql-exporter 9104:9104 &
PF_PID=$!
sleep 5

echo "Testing metrics endpoint..."
if curl -s http://localhost:9104/metrics | grep -q "mysql_up 1"; then
    echo "✅ MySQL Exporter is working - MySQL is UP"
    echo "📊 Available metric samples:"
    curl -s http://localhost:9104/metrics | grep -E "^mysql_" | head -10
else
    echo "❌ MySQL Exporter is not working properly"
fi

# Kill port-forward
kill $PF_PID 2>/dev/null || true
wait $PF_PID 2>/dev/null || true
echo ""

# Test Prometheus
echo "🔍 Testing Prometheus Targets:"
echo "Port-forwarding to Prometheus..."
kubectl port-forward -n $OBS_NAMESPACE svc/prometheus 9090:9090 &
PF_PID=$!
sleep 5

echo "Checking Prometheus targets..."
if curl -s http://localhost:9090/api/v1/targets | grep -q "mysql-exporter"; then
    echo "✅ Prometheus is scraping MySQL Exporter"
else
    echo "⚠️  Prometheus may not be scraping MySQL Exporter yet"
fi

# Kill port-forward
kill $PF_PID 2>/dev/null || true
wait $PF_PID 2>/dev/null || true
echo ""

# Grafana Access Instructions
echo "🎯 Grafana Access Instructions:"
echo "==============================="
echo ""
echo "1. Port-forward to Grafana:"
echo "   kubectl port-forward -n $OBS_NAMESPACE svc/grafana 3000:80"
echo ""
echo "2. Access Grafana at: http://localhost:3000"
echo ""
echo "3. Login credentials (check secrets):"
echo "   kubectl get secret grafana -n $OBS_NAMESPACE -o jsonpath='{.data.admin-user}' | base64 -d && echo"
echo "   kubectl get secret grafana -n $OBS_NAMESPACE -o jsonpath='{.data.admin-password}' | base64 -d && echo"
echo ""
echo "4. Add Prometheus datasource:"
echo "   - Go to Configuration > Data Sources"
echo "   - Add Prometheus"
echo "   - URL: http://prometheus.observability.svc.cluster.local:9090"
echo ""
echo "5. Import MySQL Dashboard:"
echo "   - Go to Create > Import"
echo "   - Upload mysql-dashboard.json"
echo ""

echo "📋 Key Metrics to Monitor:"
echo "=========================="
echo "• mysql_up - Database availability"
echo "• mysql_global_status_threads_connected - Active connections"
echo "• mysql_global_status_questions - Query rate"
echo "• mysql_global_status_innodb_buffer_pool_* - Buffer pool metrics"
echo "• mysql_global_status_slow_queries - Performance issues"
echo "• mysql_global_status_wsrep_* - Galera cluster health"
echo ""

echo "🔧 Troubleshooting Commands:"
echo "============================"
echo "# Check MySQL Exporter logs:"
echo "kubectl logs -n $NAMESPACE -l app=mysql-exporter"
echo ""
echo "# Check Prometheus logs:"
echo "kubectl logs -n $OBS_NAMESPACE -l app=prometheus"
echo ""
echo "# Test MySQL connection:"
echo "kubectl -n $NAMESPACE exec cluster1-pxc-db-pxc-0 -c pxc -- mysql -uexporter -pexporterpassword123 -e 'SELECT 1'"
echo ""
echo "# Manual metrics check:"
echo "kubectl port-forward -n $NAMESPACE svc/mysql-exporter 9104:9104"
echo "curl http://localhost:9104/metrics | grep mysql_up"
echo ""