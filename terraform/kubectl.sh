#!/bin/bash
# Helper script to run kubectl commands on AKS cluster
# Note: This script is deprecated. Use 'az aks get-credentials' instead.
# For AKS, configure kubectl with: az aks get-credentials --resource-group <rg-name> --name <cluster-name>

echo "This script is deprecated. For AKS, use:"
echo "az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>"
echo ""
echo "Then use kubectl directly: kubectl $@"

