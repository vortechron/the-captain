#!/bin/bash
# Script to verify AKS cluster prerequisites for MinIO deployment

set -e

echo "🔍 Verifying AKS Cluster Setup for MinIO"
echo "========================================"
echo ""

# Check kubectl connectivity
echo "1. Checking kubectl connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo "   ❌ Cannot connect to cluster. Please configure kubeconfig:"
    echo "      az aks get-credentials --resource-group <rg-name> --name <cluster-name>"
    exit 1
fi
echo "   ✅ kubectl connected successfully"
echo ""

# Check ingress controller
echo "2. Checking ingress controller..."
if kubectl get namespace ingress-nginx &>/dev/null; then
    if kubectl get deployment -n ingress-nginx ingress-nginx-controller &>/dev/null; then
        echo "   ✅ nginx ingress controller is installed"
        INGRESS_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$INGRESS_IP" ]; then
            echo "      Ingress IP: $INGRESS_IP"
        else
            echo "      ⚠️  Ingress IP not yet assigned (may take a few minutes)"
        fi
    else
        echo "   ⚠️  ingress-nginx namespace exists but controller not found"
    fi
else
    echo "   ❌ nginx ingress controller not found"
    echo "      Install with: helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace"
fi
echo ""

# Check cert-manager
echo "3. Checking cert-manager..."
if kubectl get namespace cert-manager &>/dev/null; then
    if kubectl get deployment -n cert-manager cert-manager &>/dev/null; then
        echo "   ✅ cert-manager is installed"
    else
        echo "   ⚠️  cert-manager namespace exists but deployment not found"
    fi
else
    echo "   ❌ cert-manager not found"
    echo "      Install with: kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml"
fi
echo ""

# Check storage classes
echo "4. Checking available storage classes..."
STORAGE_CLASSES=$(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
if [ -n "$STORAGE_CLASSES" ]; then
    echo "   ✅ Available storage classes:"
    kubectl get storageclass
    echo ""
    echo "   💡 Recommended for MinIO:"
    if echo "$STORAGE_CLASSES" | grep -q "managed-premium"; then
        echo "      ✅ managed-premium (Premium SSD - best performance)"
    elif echo "$STORAGE_CLASSES" | grep -q "managed-csi"; then
        echo "      ✅ managed-csi (Standard HDD - default)"
    else
        echo "      ⚠️  Using first available: $(echo $STORAGE_CLASSES | cut -d' ' -f1)"
    fi
else
    echo "   ❌ No storage classes found"
fi
echo ""

# Summary
echo "========================================"
echo "Verification complete!"
echo ""
echo "Next steps:"
echo "1. If ingress controller is missing, install it"
echo "2. If cert-manager is missing, install it"
echo "3. Note the storage class to use in terraform.tfvars"
echo "4. Configure DNS to point to ingress IP when ready"

