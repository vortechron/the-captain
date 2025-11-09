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

Add AKS-specific variables to your `terraform.tfvars`:

```hcl
# AKS Configuration
aks_cluster_name = "my-aks-cluster"
aks_node_count   = 1
aks_vm_size      = "Standard_D2s_v3"
kubernetes_version = ""  # Leave empty for latest, or specify like "1.28.0"
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

Key AKS variables you can customize in `terraform.tfvars`:

- `aks_cluster_name`: Name for the AKS cluster (default: "aks-cluster")
- `aks_node_count`: Number of nodes in the default node pool (default: 1)
- `aks_vm_size`: VM size for nodes (default: "Standard_D2s_v3")
- `kubernetes_version`: Kubernetes version (empty = latest, or specify like "1.28.0")
- `aks_d4_node_pool_enabled`: Enable additional node pool with 4 CPU (default: true)
- `aks_d4_node_pool_name`: Name of the D4 node pool (default: "d4pool")
- `aks_d4_vm_size`: VM size for D4 node pool (default: "Standard_D4s_v3")
- `aks_d4_node_count`: Number of nodes in the D4 node pool (default: 1)

### Existing Variables Used

The AKS configuration also uses these existing variables:

- `subscription_id`: Your Azure subscription ID
- `resource_group_name`: Name for the Azure resource group
- `location`: Azure region (default: "southeastasia")
- `environment`: Environment tag (default: "prod")

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

## Node Pools

This configuration includes two node pools:

1. **Default Node Pool**: Standard_D2s_v3 (2 vCPU, 8GB RAM) - for general workloads
2. **D4 Node Pool**: Standard_D4s_v3 (4 vCPU, 16GB RAM) - for workloads requiring more CPU/memory

You can schedule pods to specific node pools using node selectors or taints/tolerations.

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

To destroy all AKS resources:

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

