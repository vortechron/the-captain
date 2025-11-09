#!/bin/bash
# Script to ensure Galera port 4567 is exposed in Percona XtraDB Cluster service
# This is required for backups to work properly

NAMESPACE="${NAMESPACE:-db}"
SERVICE_NAME="${SERVICE_NAME:-cluster1-pxc-db-pxc}"

echo "Ensuring Galera port 4567 is exposed in service $SERVICE_NAME (namespace: $NAMESPACE)..."

# Check if port 4567 already exists
if kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[?(@.port==4567)]}' | grep -q "4567"; then
    echo "Port 4567 already exists in service"
    exit 0
fi

# Add port 4567 to the service
kubectl patch svc "$SERVICE_NAME" -n "$NAMESPACE" --type='json' -p='[{"op": "add", "path": "/spec/ports/-", "value": {"name": "galera", "port": 4567, "protocol": "TCP", "targetPort": 4567}}]'

if [ $? -eq 0 ]; then
    echo "Successfully added port 4567 to service"
else
    echo "Failed to add port 4567 to service"
    exit 1
fi




