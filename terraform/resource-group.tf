# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

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

