#!/bin/bash
# Diagnostic script for MinIO access issues
# This script checks LoadBalancer IP, DNS, ingress status, and certificate status

set -e

echo "=========================================="
echo "MinIO Access Diagnostic Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if we can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    echo "Please ensure you have configured kubectl with:"
    echo "  az aks get-credentials --resource-group <resource-group> --name <cluster-name>"
    exit 1
fi

echo "1. Checking Ingress Controller LoadBalancer IP..."
echo "---------------------------------------------------"
LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$LB_IP" ]; then
    echo -e "${RED}✗ LoadBalancer IP not found${NC}"
    echo ""
    echo "Checking service status..."
    kubectl get svc -n ingress-nginx ingress-nginx-controller
    echo ""
    echo "Checking service events..."
    kubectl describe svc -n ingress-nginx ingress-nginx-controller | grep -A 10 "Events:" || echo "No events found"
else
    echo -e "${GREEN}✓ LoadBalancer IP: ${LB_IP}${NC}"
fi

echo ""
echo "2. Checking DNS Configuration..."
echo "---------------------------------------------------"
if [ -z "$LB_IP" ]; then
    echo -e "${YELLOW}⚠ Skipping DNS check - no LoadBalancer IP available${NC}"
else
    DOMAIN="minio.terapeas.com"
    echo "Checking DNS for: $DOMAIN"
    
    # Try dig first
    if command -v dig &> /dev/null; then
        DNS_IP=$(dig +short $DOMAIN | tail -n1)
        if [ -z "$DNS_IP" ]; then
            echo -e "${RED}✗ DNS not configured or not resolving${NC}"
            echo "   Run: dig $DOMAIN"
        elif [ "$DNS_IP" != "$LB_IP" ]; then
            echo -e "${YELLOW}⚠ DNS resolves to: $DNS_IP${NC}"
            echo -e "${YELLOW}⚠ Expected LoadBalancer IP: $LB_IP${NC}"
            echo ""
            echo "DNS is pointing to a different IP. Update your DNS A record:"
            echo "  Type: A"
            echo "  Name: minio"
            echo "  Value: $LB_IP"
            echo "  TTL: 300"
        else
            echo -e "${GREEN}✓ DNS correctly points to LoadBalancer IP: $DNS_IP${NC}"
        fi
    else
        # Fallback to nslookup
        if command -v nslookup &> /dev/null; then
            echo "Using nslookup..."
            nslookup $DOMAIN || echo -e "${RED}✗ DNS lookup failed${NC}"
        else
            echo -e "${YELLOW}⚠ dig and nslookup not available. Please check DNS manually:${NC}"
            echo "   DNS should point to: $LB_IP"
        fi
    fi
fi

echo ""
echo "3. Checking MinIO Ingress Status..."
echo "---------------------------------------------------"
if kubectl get ingress -n minio minio-ingress &> /dev/null; then
    echo "Ingress resource found:"
    kubectl get ingress -n minio minio-ingress
    echo ""
    echo "Ingress details:"
    kubectl describe ingress -n minio minio-ingress | grep -A 20 "Rules:" || echo "No rules found"
    
    # Check if ingress has an address
    INGRESS_ADDR=$(kubectl get ingress -n minio minio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$INGRESS_ADDR" ]; then
        echo -e "${GREEN}✓ Ingress has address: $INGRESS_ADDR${NC}"
    else
        echo -e "${YELLOW}⚠ Ingress does not have an address yet${NC}"
    fi
else
    echo -e "${RED}✗ MinIO ingress not found${NC}"
    echo "Checking if namespace exists..."
    kubectl get namespace minio || echo "Namespace 'minio' does not exist"
fi

echo ""
echo "4. Checking Certificate Status..."
echo "---------------------------------------------------"
if kubectl get certificate -n minio &> /dev/null; then
    echo "Certificates in minio namespace:"
    kubectl get certificate -n minio
    echo ""
    
    CERT_STATUS=$(kubectl get certificate -n minio minio-tls -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "")
    if [ "$CERT_STATUS" == "True" ]; then
        echo -e "${GREEN}✓ Certificate is ready${NC}"
    else
        echo -e "${YELLOW}⚠ Certificate status: $CERT_STATUS${NC}"
        echo "Certificate details:"
        kubectl describe certificate -n minio minio-tls | grep -A 10 "Status:" || echo "Certificate 'minio-tls' not found"
    fi
else
    echo -e "${YELLOW}⚠ No certificates found in minio namespace${NC}"
    echo "This might be normal if cert-manager hasn't created them yet"
fi

echo ""
echo "5. Testing Direct Access (if LoadBalancer IP available)..."
echo "---------------------------------------------------"
if [ -z "$LB_IP" ]; then
    echo -e "${YELLOW}⚠ Skipping direct access test - no LoadBalancer IP${NC}"
else
    echo "Testing with Host header (bypasses DNS):"
    echo "Command: curl -k -H 'Host: minio.terapeas.com' https://$LB_IP/"
    echo ""
    
    if command -v curl &> /dev/null; then
        RESPONSE=$(curl -k -s -o /dev/null -w "%{http_code}" -H "Host: minio.terapeas.com" "https://$LB_IP/" 2>&1 || echo "000")
        if [ "$RESPONSE" == "200" ] || [ "$RESPONSE" == "403" ] || [ "$RESPONSE" == "401" ]; then
            echo -e "${GREEN}✓ Direct access works (HTTP $RESPONSE)${NC}"
            echo "   The LoadBalancer is reachable. DNS configuration is likely the issue."
        elif [ "$RESPONSE" == "000" ]; then
            echo -e "${RED}✗ Cannot connect to LoadBalancer${NC}"
            echo "   This might indicate:"
            echo "   - Azure NSG blocking traffic"
            echo "   - LoadBalancer not fully provisioned"
            echo "   - Network connectivity issues"
        else
            echo -e "${YELLOW}⚠ Unexpected response: HTTP $RESPONSE${NC}"
            echo "   Full response:"
            curl -k -v -H "Host: minio.terapeas.com" "https://$LB_IP/" 2>&1 | head -20
        fi
    else
        echo -e "${YELLOW}⚠ curl not available. Test manually:${NC}"
        echo "   curl -k -H 'Host: minio.terapeas.com' https://$LB_IP/"
    fi
fi

echo ""
echo "=========================================="
echo "Summary and Recommendations"
echo "=========================================="
echo ""

if [ -z "$LB_IP" ]; then
    echo -e "${RED}Action Required:${NC}"
    echo "1. Wait for LoadBalancer to get an external IP"
    echo "2. Check ingress-nginx controller logs:"
    echo "   kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller"
else
    echo -e "${GREEN}LoadBalancer IP: $LB_IP${NC}"
    echo ""
    echo "Next Steps:"
    echo "1. Configure DNS A record:"
    echo "   - Type: A"
    echo "   - Name: minio"
    echo "   - Value: $LB_IP"
    echo "   - TTL: 300"
    echo ""
    echo "2. Wait for DNS propagation (can take a few minutes)"
    echo ""
    echo "3. Wait for SSL certificate provisioning (cert-manager)"
    echo ""
    echo "4. Test access:"
    echo "   curl https://minio.terapeas.com/"
fi

echo ""
echo "For more details, check:"
echo "  - Ingress: kubectl describe ingress -n minio minio-ingress"
echo "  - Certificate: kubectl describe certificate -n minio minio-tls"
echo "  - Service: kubectl describe svc -n ingress-nginx ingress-nginx-controller"


