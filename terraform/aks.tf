# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.aks_cluster_name
  kubernetes_version  = var.kubernetes_version != "" ? var.kubernetes_version : null

  default_node_pool {
    name       = "default"
    node_count = var.aks_node_count
    vm_size    = var.aks_vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
    network_policy = "calico"
  }

  role_based_access_control_enabled = true

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "aks-cluster"
  }

  lifecycle {
    # Ignore tag changes from external sources (Azure Portal, policies, etc.)
    ignore_changes = [tags]
  }
}

# Additional Node Pool for 4 CPU nodes
resource "azurerm_kubernetes_cluster_node_pool" "d4_pool" {
  count                 = var.aks_d4_node_pool_enabled ? 1 : 0
  name                  = var.aks_d4_node_pool_name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.aks_d4_vm_size
  node_count            = var.aks_d4_node_count
  mode                  = "User"
  os_type               = "Linux"

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "aks-node-pool-d4"
  }

  lifecycle {
    # Ignore tag changes from external sources (Azure Portal, policies, etc.)
    ignore_changes = [tags]
  }
}

