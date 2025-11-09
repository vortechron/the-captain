# Azure Kubernetes Service (AKS) with Terraform

This Terraform configuration sets up a managed Kubernetes cluster on Azure using AKS (Azure Kubernetes Service) with minimal defaults suitable for development and testing.

## Architecture

- **Region**: Southeast Asia (Malaysia) - configurable
- **Cluster Type**: Managed AKS cluster
- **Default Node Pool**: 1 node (configurable) - Standard_D2s_v3 (2 vCPU, 8GB RAM)
- **Additional Node Pool**: 1 node (configurable) - Standard_D4s_v3 (4 vCPU, 16GB RAM)
- **Networking**: Kubenet with Calico network policy
- **Identity**: System-assigned managed identity
- **RBAC**: Enabled

## Prerequisites

1. **Azure Account**: An active Azure subscription
2. **Azure CLI**: Installed and configured
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```
3. **Terraform**: Version >= 1.0
   ```bash
   terraform version
   ```
4. **kubectl**: Kubernetes command-line tool
   ```bash
   kubectl version --client
   ```

## Quick Start

### 1. Configure Variables

Copy the example variables file and update with your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
subscription_id = "your-azure-subscription-id"
resource_group_name = "aks-cluster-rg"
location = "southeastasia"

# AKS Configuration
aks_cluster_name = "my-aks-cluster"
aks_node_count   = 1
aks_vm_size      = "Standard_D2s_v3"
kubernetes_version = ""  # Leave empty for latest
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Plan Deployment

```bash
terraform plan
```

### 4. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted to create the resources.

### 5. Get Connection Information

After deployment, retrieve the outputs:

```bash
terraform output
```

### 6. Connect to the Cluster

Get credentials and configure kubectl:

```bash
az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>
```

Or use the output command:

```bash
$(terraform output -raw aks_cluster_kubeconfig_command)
```

### 7. Verify Cluster

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

## Configuration

### Variables

Key variables you can customize in `terraform.tfvars`:

- `subscription_id`: Your Azure subscription ID (required)
- `resource_group_name`: Name for the Azure resource group (default: "aks-cluster-rg")
- `location`: Azure region (default: "southeastasia")
- `environment`: Environment tag (default: "prod")
- `aks_cluster_name`: Name for the AKS cluster (default: "aks-cluster")
- `aks_node_count`: Number of nodes in the default node pool (default: 1)
- `aks_vm_size`: VM size for nodes (default: "Standard_D2s_v3")
- `kubernetes_version`: Kubernetes version (empty = latest, or specify like "1.28.0")
- `aks_d4_node_pool_enabled`: Enable additional node pool with 4 CPU (default: true)
- `aks_d4_node_pool_name`: Name of the D4 node pool (default: "d4pool")
- `aks_d4_vm_size`: VM size for D4 node pool (default: "Standard_D4s_v3")
- `aks_d4_node_count`: Number of nodes in the D4 node pool (default: 1)

## Post-Deployment

### Access the Cluster

1. **Get kubeconfig**:
   ```bash
   az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>
   ```

2. **Verify cluster**:
   ```bash
   kubectl get nodes
   kubectl cluster-info
   ```

### Deploy a Sample Application

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer
kubectl get service nginx
```

## Outputs

After deployment, Terraform outputs:

- `resource_group_name`: Name of the resource group
- `aks_cluster_name`: Name of the AKS cluster
- `aks_cluster_fqdn`: FQDN of the AKS cluster
- `aks_cluster_kubeconfig_command`: Command to retrieve kubeconfig
- `aks_cluster_portal_url`: Azure Portal URL for the cluster

## Cost Estimation

Approximate monthly costs (Southeast Asia region):

- AKS Control Plane: ~$73/month (free for first cluster in some subscriptions)
- 1x Standard_D2s_v3 node: ~$60-80/month
- Networking: ~$5-10/month
- Storage: ~$10/month

**Total**: ~$75-95/month (or ~$150-170/month if control plane is charged)

**Note**: Azure often provides free control plane for the first AKS cluster. Check current pricing for your region.

## Troubleshooting

### Cannot Connect to Cluster

1. Verify Azure CLI is logged in:
   ```bash
   az account show
   ```

2. Check cluster status:
   ```bash
   az aks show --resource-group <resource-group-name> --name <cluster-name>
   ```

3. Re-authenticate:
   ```bash
   az aks get-credentials --resource-group <resource-group-name> --name <cluster-name> --overwrite-existing
   ```

### Cluster Not Ready

1. Check cluster status in Azure Portal
2. Review cluster logs:
   ```bash
   az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>
   kubectl get events --all-namespaces
   ```

### Node Pool Issues

1. Check node status:
   ```bash
   kubectl get nodes
   kubectl describe node <node-name>
   ```

2. Scale node pool:
   ```bash
   az aks scale --resource-group <resource-group-name> --name <cluster-name> --node-count 2
   ```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will destroy the AKS cluster and all workloads running on it. Make sure you have backups if needed.

## Security Considerations

1. **RBAC**: Enabled by default - configure appropriate roles and bindings
2. **Network Policies**: Calico is enabled - configure policies as needed
3. **Managed Identity**: Uses system-assigned managed identity (more secure than service principal)
4. **Secrets**: Use Azure Key Vault for sensitive data
5. **Monitoring**: Enable Azure Monitor for containers
6. **Updates**: Keep Kubernetes version up to date

## MinIO Deployment

This Terraform configuration includes an optional MinIO module for S3-compatible object storage.

### Prerequisites

Before deploying MinIO, ensure you have:

1. **Ingress Controller**: nginx ingress controller installed
   ```bash
   helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
   ```

2. **cert-manager**: Installed for SSL certificates
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

3. **Storage Class**: Verify available storage classes
   ```bash
   kubectl get storageclass
   ```
   Or use the verification script:
   ```bash
   ./verify-aks-setup.sh
   ```

### Configure MinIO

Add MinIO configuration to `terraform.tfvars`:

```hcl
# MinIO Configuration
minio_enabled            = true
minio_storage_class      = "managed-premium"  # Check available with: kubectl get storageclass
minio_storage_size       = "20Gi"
minio_domain             = "terapeas.com"
minio_root_user          = "minioadmin"  # Change in production!
minio_root_password       = "your-secure-password-here"  # Change in production!
minio_cluster_issuer_name = "letsencrypt-prod"  # Use existing ClusterIssuer (recommended)
minio_create_cluster_issuer = false  # Set to true only if ClusterIssuer doesn't exist
minio_cert_manager_email    = "sayaamiruladli@gmail.com"  # Only used if creating ClusterIssuer
```

**Note**: The module uses **ClusterIssuer** (cluster-scoped) instead of Issuer (namespace-scoped). This allows the same ClusterIssuer to be shared across all applications (MinIO, Laravel API, etc.) - recommended for multi-app setups.

### Deploy MinIO

```bash
terraform plan   # Review changes
terraform apply  # Deploy MinIO
```

### Access MinIO

After deployment, MinIO will be available at:

- **API**: `https://minio.{domain}` (port 9000)
- **Console**: `https://minio-console.{domain}` (port 9001)

Get the endpoints:
```bash
terraform output minio_api_endpoint
terraform output minio_console_endpoint
```

### Configure DNS

Configure DNS records to point to the ingress IP:

```bash
# Get ingress IP
kubectl get ingress -n minio minio-ingress

# Add DNS records:
# minio.{domain}          -> [ingress-ip]
# minio-console.{domain}  -> [ingress-ip]
```

### Verify Deployment

```bash
# Check MinIO resources
kubectl get all -n minio

# Check PVC
kubectl get pvc -n minio

# Check ingress
kubectl get ingress -n minio

# View MinIO logs
kubectl logs -n minio deployment/minio
```

For more details, see [modules/minio/README.md](modules/minio/README.md)

## Performance Optimization

This Terraform configuration includes several optimizations to speed up `terraform apply` operations, especially when Helm charts are already deployed and stable.

### 🕒 Disable Wait on Stable Charts

For faster applies on charts that are already healthy and stable, you can disable Helm wait operations:

```hcl
# In terraform.tfvars
helm_wait_enabled        = false  # Skip waiting for pods to be ready
helm_wait_for_jobs_enabled = false  # Skip waiting for Helm jobs
```

**⚠️ Warning**: Only disable wait if:
- Charts are already deployed and stable
- You're confident the changes won't break the deployment
- You can manually verify deployments after apply

**Recommended**: Keep `wait = true` for initial deployments, then disable for subsequent updates.

### 🚀 Skip Unchanged Resources

Terraform automatically skips unchanged resources, but you can ensure this works optimally:

1. **Run `terraform plan` frequently** to catch unnecessary diffs early
2. **Commit your `.tfstate` properly** to avoid state drift
3. **Use `terraform plan -out=tfplan`** to review changes before applying

### 🧩 Split Big Helm Releases

Large Helm charts (like `kube-prometheus-stack`) can take longer to apply. This configuration already splits monitoring into separate modules:
- Prometheus (standalone)
- Grafana (standalone)
- Loki (standalone)
- Promtail (standalone)

This reduces lock time and allows parallel operations where possible.

### 🪄 Use Helm Diff Plugin

Before running `terraform apply`, you can preview Helm changes using the `helm diff` plugin:

```bash
# Install helm diff plugin (if not already installed)
helm plugin install https://github.com/databus23/helm-diff

# Test changes for a specific release
helm diff upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --values <(terraform output -json | jq -r '.ingress_nginx_values.value')
```

This helps confirm there are no real changes before applying.

### 🧠 Cache Your Helm Repos

Slow Helm chart downloads can add 30-60s per release. Cache repositories before applying:

```bash
# Run the caching script
./cache-helm-repos.sh

# Or manually update repos
helm repo update
```

**Pro Tip**: Add this to your CI/CD pipeline or run it periodically to keep repos cached.

### 📊 Performance Comparison

| Configuration | Apply Time (approx) | Use Case |
|--------------|---------------------|----------|
| `wait = true` (default) | 5-10 min | Initial deployments, critical updates |
| `wait = false` | 2-5 min | Stable charts, non-critical updates |
| `wait = false` + cached repos | 1-3 min | Fast iteration, development |

### Example: Fast Apply Configuration

For development/staging environments with stable charts:

```hcl
# terraform.tfvars
helm_wait_enabled        = false
helm_wait_for_jobs_enabled = false
helm_timeout             = 300  # Reduced timeout for faster failures
```

Then run:
```bash
./cache-helm-repos.sh  # Cache repos first
terraform plan
terraform apply
```

## Next Steps

- Install an ingress controller (e.g., NGINX, Traefik)
- Set up cert-manager for SSL certificates
- Configure Azure Container Registry (ACR) integration
- Set up monitoring with Azure Monitor
- Configure auto-scaling (cluster autoscaler)
- Set up CI/CD pipelines
- Configure persistent storage (Azure Disk CSI driver)

## References

- [AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [Terraform Azure AKS Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster)
- [AKS Best Practices](https://docs.microsoft.com/azure/aks/best-practices)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
