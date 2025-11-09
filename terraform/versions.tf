terraform {
  required_version = ">= 1.5" # Updated for better performance and features

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" # Allow any 3.x version (currently using 3.117.1)
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0" # Allow any 3.x version (currently using 3.2.4)
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0" # Allow any 2.x version (currently using 2.38.0)
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0" # Allow any 2.x version (currently using 2.17.0)
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9" # Allow any 0.9+ version (currently using 0.13.1)
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0" # Allow any 3.x version (currently using 3.7.2)
    }
  }
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
  }
}

