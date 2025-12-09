# MinIO Access Troubleshooting Guide

This guide helps diagnose and fix issues accessing MinIO from your local machine.

## Quick Diagnostic

Run the diagnostic script:

```bash
cd terraform
./diagnose-minio-access.sh
```

## Common Issues and Solutions

### Issue 1: DNS Not Configured (Most Common)

**Symptoms:**
- Cannot resolve `minio.terapeas.com`
- Connection timeout
- "Name or service not known" error

**Solution:**

1. Get the LoadBalancer IP:
   ```bash
   kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```

2. Configure DNS A record in your DNS provider:
   - **Type**: A
   - **Name**: `minio` (or `minio.terapeas.com` depending on provider)
   - **Value**: [LoadBalancer IP from step 1]
   - **TTL**: 300

3. Wait for DNS propagation (usually 1-5 minutes)

4. Verify DNS:
   ```bash
   dig minio.terapeas.com
   # Should show the LoadBalancer IP
   ```

### Issue 2: LoadBalancer Has No External IP

**Symptoms:**
- LoadBalancer IP shows as `<pending>`
- Cannot get external IP

**Solution:**

1. Check service status:
   ```bash
   kubectl get svc -n ingress-nginx ingress-nginx-controller
   kubectl describe svc -n ingress-nginx ingress-nginx-controller
   ```

2. Check for errors in service events:
   ```bash
   kubectl describe svc -n ingress-nginx ingress-nginx-controller | grep -A 10 "Events:"
   ```

3. Check ingress controller logs:
   ```bash
   kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
   ```

4. Verify Azure Load Balancer was created:
   ```bash
   az network lb list --resource-group <your-resource-group>
   ```

**Common Causes:**
- Azure quota limits
- Insufficient permissions
- Network configuration issues

### Issue 3: Certificate Not Ready

**Symptoms:**
- SSL/TLS errors
- Certificate not found errors
- HTTPS connection fails

**Solution:**

1. Check certificate status:
   ```bash
   kubectl get certificate -n minio
   kubectl describe certificate -n minio minio-tls
   ```

2. Check cert-manager logs:
   ```bash
   kubectl logs -n cert-manager -l app=cert-manager --tail=50
   ```

3. Check certificate challenges:
   ```bash
   kubectl get challenges -n minio
   kubectl describe challenge -n minio
   ```

**Common Causes:**
- DNS not configured (cert-manager needs DNS to validate)
- ClusterIssuer not configured correctly
- Let's Encrypt rate limits

### Issue 4: Azure NSG Blocking Traffic

**Symptoms:**
- Cannot connect even with correct DNS
- Connection timeout
- Direct IP access fails

**Solution:**

Azure Load Balancers created by AKS should automatically allow traffic, but verify:

1. Check Load Balancer rules:
   ```bash
   # Get Load Balancer name
   LB_NAME=$(az network lb list --resource-group <rg> --query "[?contains(name, 'kubernetes')].name" -o tsv | head -1)
   
   # List rules
   az network lb rule list --resource-group <rg> --lb-name $LB_NAME
   ```

2. Check NSG rules (if using custom NSG):
   ```bash
   az network nsg rule list --resource-group <rg> --nsg-name <nsg-name>
   ```

3. Verify ports 80 and 443 are allowed:
   - Port 80 (HTTP) - for Let's Encrypt validation
   - Port 443 (HTTPS) - for MinIO API access

### Issue 5: Ingress Not Configured Correctly

**Symptoms:**
- 404 errors
- Wrong service routing
- Ingress shows errors

**Solution:**

1. Check ingress status:
   ```bash
   kubectl get ingress -n minio minio-ingress
   kubectl describe ingress -n minio minio-ingress
   ```

2. Verify ingress rules match your domain:
   ```bash
   kubectl get ingress -n minio minio-ingress -o yaml | grep -A 5 "rules:"
   ```

3. Check ingress controller logs:
   ```bash
   kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100 | grep minio
   ```

## Step-by-Step Diagnostic Process

### Step 1: Verify LoadBalancer IP

```bash
LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "LoadBalancer IP: $LB_IP"
```

If empty, see Issue 2 above.

### Step 2: Verify DNS Configuration

```bash
dig minio.terapeas.com
# or
nslookup minio.terapeas.com
```

DNS should resolve to the LoadBalancer IP from Step 1. If not, see Issue 1 above.

### Step 3: Test Direct Access (Bypass DNS)

```bash
LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -k -v -H "Host: minio.terapeas.com" "https://$LB_IP/"
```

- If this works: DNS is the issue (see Issue 1)
- If this fails: Network/NSG issue (see Issue 4)

### Step 4: Check Certificate Status

```bash
kubectl get certificate -n minio
kubectl describe certificate -n minio minio-tls
```

If certificate is not ready, see Issue 3 above.

### Step 5: Check Ingress Status

```bash
kubectl get ingress -n minio minio-ingress
kubectl describe ingress -n minio minio-ingress
```

If ingress has errors, see Issue 5 above.

## Testing MinIO Access

Once everything is configured, test MinIO access:

### Using curl

```bash
# Test API endpoint
curl https://minio.terapeas.com/

# Test with credentials
curl -u minioadmin:yourpassword https://minio.terapeas.com/
```

### Using MinIO Client (mc)

```bash
# Configure alias
mc alias set minio https://minio.terapeas.com minioadmin yourpassword

# List buckets
mc ls minio

# Test connection
mc admin info minio
```

### Using Environment Variables

```bash
export MINIO_ENDPOINT=https://minio.terapeas.com
export MINIO_ACCESS_KEY_ID=minioadmin
export MINIO_SECRET_ACCESS_KEY=yourpassword
export MINIO_BUCKET=your-bucket-name
export MINIO_USE_PATH_STYLE_ENDPOINT=true

# Test with your application
```

## Environment Variables Configuration

When configuring your application to use MinIO, ensure:

```bash
MINIO_ENDPOINT=https://minio.terapeas.com
MINIO_URL=https://minio.terapeas.com/your-bucket-name
MINIO_USE_PATH_STYLE_ENDPOINT=true
MINIO_ACCESS_KEY_ID=minioadmin
MINIO_SECRET_ACCESS_KEY=your-secure-password
MINIO_DEFAULT_REGION=us-east-1
MINIO_BUCKET=your-bucket-name
```

**Important Notes:**
- Use `https://` (not `http://`)
- Use the full domain name (not IP address)
- Set `MINIO_USE_PATH_STYLE_ENDPOINT=true` for path-style access
- Ensure DNS is configured correctly

## Getting Help

If issues persist:

1. Run the diagnostic script: `./terraform/diagnose-minio-access.sh`
2. Check all component logs:
   - Ingress: `kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller`
   - Cert-manager: `kubectl logs -n cert-manager -l app=cert-manager`
   - MinIO: `kubectl logs -n minio -l app=minio`
3. Check Azure Load Balancer status in Azure Portal
4. Verify DNS configuration in your DNS provider


