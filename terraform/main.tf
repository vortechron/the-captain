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

# Helm Repository for Ingress NGINX
resource "helm_release" "ingress_nginx_repo" {
  count = var.ingress_nginx_enabled ? 1 : 0

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.ingress_nginx_version
  namespace  = "ingress-nginx"
  create_namespace = true

  atomic          = false  # Non-critical: disable atomic for faster applies
  wait            = var.helm_wait_enabled
  wait_for_jobs   = var.helm_wait_for_jobs_enabled
  timeout         = 60  # Minimal timeout for Helm API calls
  reuse_values    = false
  force_update    = false
  cleanup_on_fail = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }

  # Removed timestamp annotation to prevent unnecessary pod restarts
  # which cause scheduling issues when CPU is constrained

  depends_on = [azurerm_kubernetes_cluster.main]
}

# Helm Release for cert-manager
resource "helm_release" "cert_manager" {
  count = var.cert_manager_enabled ? 1 : 0

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version
  namespace  = "cert-manager"
  create_namespace = true

  atomic          = false  # Non-critical: disable atomic for faster applies
  wait            = var.helm_wait_enabled
  wait_for_jobs   = var.helm_wait_for_jobs_enabled
  timeout         = 60  # Minimal timeout for Helm API calls
  reuse_values    = false
  force_update    = false
  cleanup_on_fail = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  # Note: cert-manager webhooks restart automatically when configuration changes
  # No need for manual pod restart annotations

  depends_on = [azurerm_kubernetes_cluster.main]
}

# ClusterIssuer for Let's Encrypt (optional - only if create_cluster_issuer is true)
resource "kubernetes_manifest" "cluster_issuer" {
  count = var.cert_manager_enabled && var.minio_create_cluster_issuer ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.minio_cluster_issuer_name
    }
    spec = {
      acme = {
        email = var.minio_cert_manager_email
        privateKeySecretRef = {
          name = "${var.minio_cluster_issuer_name}-account-key"
        }
        server = "https://acme-v02.api.letsencrypt.org/directory"
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

# MinIO Module
module "minio" {
  count = var.minio_enabled ? 1 : 0

  source = "./modules/minio"

  storage_class         = var.minio_storage_class
  storage_size          = var.minio_storage_size
  domain                = var.minio_domain
  minio_root_user       = var.minio_root_user
  minio_root_password    = var.minio_root_password
  cert_manager_email     = var.minio_cert_manager_email
  cluster_issuer_name   = var.minio_cluster_issuer_name
  create_cluster_issuer  = var.minio_create_cluster_issuer

  depends_on = [
    helm_release.ingress_nginx_repo,
    helm_release.cert_manager
  ]
}

# Loki Module
module "loki" {
  count = var.loki_enabled ? 1 : 0

  source = "./modules/loki"

  namespace      = var.loki_namespace
  chart_version  = var.loki_chart_version
  storage_class   = var.loki_storage_class
  storage_size    = var.loki_storage_size
  retention_period = var.loki_retention_period

  helm_wait_enabled        = var.helm_wait_enabled
  helm_wait_for_jobs_enabled = var.helm_wait_for_jobs_enabled
  helm_timeout             = var.helm_timeout

  # Removed depends_on: Loki uses ClusterIP service, doesn't need ingress-nginx
}

# Promtail Module
module "promtail" {
  count = var.promtail_enabled ? 1 : 0

  source = "./modules/promtail"

  namespace   = var.promtail_namespace
  chart_version = var.promtail_chart_version
  loki_url    = var.promtail_loki_url != "" ? var.promtail_loki_url : (var.loki_enabled ? "${module.loki[0].service_url}/loki/api/v1/push" : "http://loki-gateway.observability.svc.cluster.local/loki/api/v1/push")

  helm_wait_enabled        = var.helm_wait_enabled
  helm_wait_for_jobs_enabled = var.helm_wait_for_jobs_enabled
  helm_timeout             = var.helm_timeout

  depends_on = [
    module.loki
  ]
}

# Prometheus Module
module "prometheus" {
  count = var.prometheus_enabled ? 1 : 0

  source = "./modules/prometheus"

  namespace         = var.prometheus_namespace
  chart_version     = var.prometheus_chart_version
  storage_class     = var.prometheus_storage_class
  storage_size      = var.prometheus_storage_size
  retention_time    = var.prometheus_retention_time
  enable_node_exporter = var.prometheus_enable_node_exporter
  enable_kube_state_metrics = var.prometheus_enable_kube_state_metrics

  helm_wait_enabled        = var.helm_wait_enabled
  helm_wait_for_jobs_enabled = var.helm_wait_for_jobs_enabled
  helm_timeout             = var.helm_timeout

  # Removed depends_on: Prometheus uses ClusterIP service, doesn't need ingress-nginx
}

# Grafana Module
module "grafana" {
  count = var.grafana_enabled ? 1 : 0

  source = "./modules/grafana"

  domain                    = var.grafana_domain
  chart_version             = var.grafana_chart_version
  cluster_issuer_name       = var.grafana_cluster_issuer_name
  storage_class             = var.grafana_storage_class
  storage_size              = var.grafana_storage_size
  admin_user                = var.grafana_admin_user
  admin_password            = var.grafana_admin_password
  loki_datasource_url       = var.grafana_loki_datasource_url != "" ? var.grafana_loki_datasource_url : (var.loki_enabled ? module.loki[0].service_url : "http://loki-gateway.observability.svc.cluster.local/")
  prometheus_datasource_url  = var.grafana_prometheus_datasource_url != "" ? var.grafana_prometheus_datasource_url : (var.prometheus_enabled ? "${module.prometheus[0].service_url}:9090" : "http://prometheus.observability.svc.cluster.local:9090")
  enable_loki_datasource    = var.grafana_enable_loki_datasource
  enable_prometheus_datasource = var.grafana_enable_prometheus_datasource

  helm_wait_enabled        = var.helm_wait_enabled
  helm_wait_for_jobs_enabled = var.helm_wait_for_jobs_enabled
  helm_timeout             = var.helm_timeout

  # Dependencies are implicit via data source URLs (module.loki[0].service_url, module.prometheus[0].service_url)
  # Ingress and cert-manager dependencies handled within Grafana module for ingress creation
}

# MySQL Module
module "mysql" {
  count = var.mysql_enabled ? 1 : 0

  source = "./modules/mysql"

  namespace     = var.mysql_namespace
  cluster_name  = var.mysql_cluster_name
  storage_class = var.mysql_storage_class
  storage_size  = var.mysql_storage_size

  pxc_size          = var.mysql_pxc_size
  pxc_resources     = var.mysql_pxc_resources
  haproxy_size      = var.mysql_haproxy_size
  haproxy_resources = var.mysql_haproxy_resources

  backup_enabled         = var.mysql_backup_enabled
  backup_schedule        = var.mysql_backup_schedule
  backup_retention_days  = var.mysql_backup_retention_days
  minio_endpoint_url     = var.mysql_minio_endpoint_url
  minio_bucket           = var.mysql_minio_bucket
  minio_region           = var.mysql_minio_region
  minio_access_key_id    = var.mysql_minio_access_key_id
  minio_secret_access_key = var.mysql_minio_secret_access_key
  root_password          = var.mysql_root_password
  monitoring_enabled     = var.mysql_monitoring_enabled
  monitoring_user        = var.mysql_monitoring_user
  monitoring_password    = var.mysql_monitoring_password

  helm_wait_enabled        = var.helm_wait_enabled
  helm_wait_for_jobs_enabled = var.helm_wait_for_jobs_enabled
  helm_timeout             = var.helm_timeout

  # Removed depends_on: MySQL uses ClusterIP service, doesn't need ingress-nginx
}

# Redis Module
module "redis" {
  count = var.redis_enabled ? 1 : 0

  source = "./modules/redis"

  namespace           = var.redis_namespace
  release_name        = var.redis_release_name
  chart_version       = var.redis_chart_version
  architecture        = var.redis_architecture
  auth_enabled        = var.redis_auth_enabled
  auth_password       = var.redis_auth_password
  persistence_enabled = var.redis_persistence_enabled
  storage_class       = var.redis_storage_class
  storage_size        = var.redis_storage_size
  replica_count       = var.redis_replica_count
  resources           = var.redis_resources

  helm_wait_enabled        = var.helm_wait_enabled
  helm_wait_for_jobs_enabled = var.helm_wait_for_jobs_enabled
  helm_timeout             = var.helm_timeout

  # Removed depends_on: Redis uses ClusterIP service, doesn't need ingress-nginx
}
