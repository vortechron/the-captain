# MinIO Terraform Module

This Terraform module deploys MinIO object storage on Kubernetes using the MinIO Operator and Tenant CRD, replacing the previous Kubernetes manifest-based deployment.

## Features

- MinIO server deployment via MinIO Operator (official MinIO method)
- Persistent storage with configurable storage class
- API (port 9000) and Console (port 9001) services
- SSL/TLS termination via cert-manager and Let's Encrypt
- Resource limits for production stability
- Uses Kubernetes CRDs for better integration

## Usage

```hcl
module "minio" {
  source = "./modules/minio"

  storage_class         = "managed-premium"
  storage_size          = "20Gi"
  domain                = "terapeas.com"
  minio_root_user       = "minioadmin"
  minio_root_password    = "your-secure-password"
  cluster_issuer_name   = "letsencrypt-prod"  # Use existing ClusterIssuer
  create_cluster_issuer = false                # Set to true to create ClusterIssuer
  cert_manager_email    = "your-email@example.com"  # Only needed if creating ClusterIssuer
}
```

## Requirements

- Kubernetes cluster (AKS in this case)
- Helm provider configured in Terraform
- nginx ingress controller installed
- cert-manager installed
- Storage class available in cluster
- **ClusterIssuer** (recommended) or the module can create one

## ClusterIssuer vs Issuer

This module uses **ClusterIssuer** (cluster-scoped) instead of Issuer (namespace-scoped) because:

✅ **ClusterIssuer Benefits:**
- **Shared across all namespaces** - One ClusterIssuer can serve MinIO, Laravel API, and all other apps
- **Easier management** - Single place to configure certificate settings
- **Better for multi-app setups** - No need to create Issuer per namespace
- **Follows best practices** - Recommended approach for production

❌ **Issuer Limitations:**
- Namespace-scoped - Need separate Issuer for each namespace
- More complex to manage with multiple applications
- Duplicate configuration across namespaces

### Using Existing ClusterIssuer (Recommended)

If you already have a ClusterIssuer (like `letsencrypt-prod`), set:

```hcl
cluster_issuer_name   = "letsencrypt-prod"
create_cluster_issuer = false  # Use existing ClusterIssuer
```

### Creating New ClusterIssuer

If ClusterIssuer doesn't exist, the module can create it:

```hcl
cluster_issuer_name   = "letsencrypt-prod"
create_cluster_issuer = true   # Create ClusterIssuer
cert_manager_email    = "your-email@example.com"
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| storage_class | Storage class for MinIO persistent volume | `string` | `"managed-premium"` | no |
| storage_size | Size of the persistent volume | `string` | `"20Gi"` | no |
| domain | Base domain for MinIO endpoints | `string` | `"terapeas.com"` | no |
| minio_root_user | MinIO root username | `string` | `"minioadmin"` | yes |
| minio_root_password | MinIO root password | `string` | n/a | yes |
| cert_manager_email | Email for Let's Encrypt certificate (only if creating ClusterIssuer) | `string` | `"sayaamiruladli@gmail.com"` | no |
| cluster_issuer_name | Name of ClusterIssuer to use | `string` | `"letsencrypt-prod"` | no |
| create_cluster_issuer | Whether to create ClusterIssuer | `bool` | `true` | no |
| namespace | Kubernetes namespace | `string` | `"minio"` | no |
| chart_version | MinIO Helm chart version (leave empty for latest) | `string` | `""` | no |
| resources | Resource requests and limits | `object` | See variables.tf | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace | MinIO namespace name |
| minio_api_endpoint | MinIO API endpoint URL |
| minio_console_endpoint | MinIO Console endpoint URL |
| service_name | MinIO API service name |
| console_service_name | MinIO Console service name |
| ingress_name | MinIO ingress name |
| cluster_issuer_name | Name of ClusterIssuer being used |

## Resources Created

- `kubernetes_namespace` - MinIO namespace
- `helm_release` - MinIO Helm release (Bitnami chart)
- `kubernetes_manifest` - cert-manager ClusterIssuer (optional, if create_cluster_issuer = true)
- `kubernetes_ingress_v1` - Ingress with TLS

The Helm chart automatically creates:
- Secret for MinIO credentials
- PersistentVolumeClaim for storage
- Deployment with MinIO server
- Service exposing API and Console ports

## Endpoints

After deployment, MinIO will be available at:

- **API**: `https://minio.{domain}` (port 9000)
- **Console**: `https://minio-console.{domain}` (port 9001)

## DNS Configuration

After deployment, configure DNS records to point to the LoadBalancer IP:

### Step 1: Get the LoadBalancer IP

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Or use the diagnostic script:

```bash
./terraform/diagnose-minio-access.sh
```

### Step 2: Configure DNS A Records

Add the following DNS A records in your DNS provider (e.g., Cloudflare, Route53, Azure DNS):

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `minio` | `[LoadBalancer IP from Step 1]` | 300 |
| A | `minio-console` | `[LoadBalancer IP from Step 1]` | 300 |

**Example for terapeas.com domain:**
- `minio.terapeas.com` → `[LoadBalancer IP]`
- `minio-console.terapeas.com` → `[LoadBalancer IP]`

### Step 3: Verify DNS Propagation

```bash
dig minio.terapeas.com
# or
nslookup minio.terapeas.com
```

DNS should resolve to the LoadBalancer IP. Propagation can take a few minutes.

### Step 4: Wait for SSL Certificate

After DNS is configured, cert-manager will automatically provision SSL certificates. Check status:

```bash
kubectl get certificate -n minio
kubectl describe certificate -n minio minio-tls
```

Certificates typically take 1-5 minutes to provision.

## Troubleshooting Access Issues

If you cannot access MinIO from your local machine:

### Common Issues

1. **DNS not configured** - Most common issue
   - Verify DNS points to LoadBalancer IP: `dig minio.terapeas.com`
   - Update DNS A record if incorrect

2. **LoadBalancer has no external IP**
   - Check service status: `kubectl get svc -n ingress-nginx ingress-nginx-controller`
   - Wait a few minutes for Azure to provision the LoadBalancer

3. **Certificate not ready**
   - Check certificate status: `kubectl get certificate -n minio`
   - Check cert-manager logs: `kubectl logs -n cert-manager -l app=cert-manager`

4. **Azure NSG blocking traffic**
   - Azure Load Balancers created by AKS should automatically allow traffic
   - Verify LoadBalancer rules: `az network lb rule list --resource-group <rg> --lb-name <lb-name>`

### Diagnostic Script

Run the comprehensive diagnostic script:

```bash
cd terraform
./diagnose-minio-access.sh
```

This script will:
- Check LoadBalancer IP
- Verify DNS configuration
- Check ingress status
- Check certificate status
- Test direct access (bypassing DNS)

### Test Direct Access (Bypass DNS)

If DNS isn't configured yet, test directly with the LoadBalancer IP:

```bash
LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -k -H "Host: minio.terapeas.com" "https://$LB_IP/"
```

If this works, DNS configuration is the issue.

## Notes

- Uses Bitnami MinIO Helm chart for better maintainability
- Default credentials match existing k8s manifests for consistency
- Change default credentials in production!
- Storage class should match your cluster's available storage classes
- Certificates are automatically provisioned by cert-manager
- **Use existing ClusterIssuer** if you have one (recommended for multi-app setups)
- ClusterIssuer is shared across all namespaces - perfect for MinIO, Laravel API, and other apps
- Chart version can be left empty to use the latest, or specify a version for stability

