# MinIO Module
module "minio" {
  count = var.minio_enabled ? 1 : 0

  source = "./modules/minio"

  storage_class         = var.minio_storage_class
  storage_size          = var.minio_storage_size
  domain                = var.minio_domain
  minio_root_user       = var.minio_root_user
  minio_root_password   = var.minio_root_password
  cert_manager_email    = var.minio_cert_manager_email
  cluster_issuer_name   = var.minio_cluster_issuer_name
  create_cluster_issuer = var.minio_create_cluster_issuer

  depends_on = [
    helm_release.ingress_nginx_repo,
    helm_release.cert_manager
  ]
}

# Loki Module
module "loki" {
  count = var.loki_enabled ? 1 : 0

  source = "./modules/loki"

  namespace        = var.loki_namespace
  chart_version    = var.loki_chart_version
  storage_class    = var.loki_storage_class
  storage_size     = var.loki_storage_size
  retention_period = var.loki_retention_period

  helm_wait_enabled          = var.helm_wait_enabled
  helm_wait_for_jobs_enabled = var.helm_wait_for_jobs_enabled
  helm_timeout               = var.helm_timeout

  # Removed depends_on: Loki uses ClusterIP service, doesn't need ingress-nginx
}

# Promtail Module
module "promtail" {
  count = var.promtail_enabled ? 1 : 0

  source = "./modules/promtail"

  namespace     = var.promtail_namespace
  chart_version = var.promtail_chart_version
  loki_url      = var.promtail_loki_url != "" ? var.promtail_loki_url : (var.loki_enabled ? "${module.loki[0].service_url}/loki/api/v1/push" : "http://loki-gateway.observability.svc.cluster.local/loki/api/v1/push")

  helm_wait_enabled          = var.helm_wait_enabled
  helm_wait_for_jobs_enabled = var.helm_wait_for_jobs_enabled
  helm_timeout               = var.helm_timeout

  depends_on = [
    module.loki
  ]
}

# Prometheus Module
module "prometheus" {
  count = var.prometheus_enabled ? 1 : 0

  source = "./modules/prometheus"

  namespace                 = var.prometheus_namespace
  chart_version             = var.prometheus_chart_version
  storage_class             = var.prometheus_storage_class
  storage_size              = var.prometheus_storage_size
  retention_time            = var.prometheus_retention_time
  enable_node_exporter      = var.prometheus_enable_node_exporter
  enable_kube_state_metrics = var.prometheus_enable_kube_state_metrics

  helm_wait_enabled          = var.helm_wait_enabled
  helm_wait_for_jobs_enabled = var.helm_wait_for_jobs_enabled
  helm_timeout               = var.helm_timeout

  # Removed depends_on: Prometheus uses ClusterIP service, doesn't need ingress-nginx
}

# Grafana Module
module "grafana" {
  count = var.grafana_enabled ? 1 : 0

  source = "./modules/grafana"

  domain                       = var.grafana_domain
  chart_version                = var.grafana_chart_version
  cluster_issuer_name          = var.grafana_cluster_issuer_name
  storage_class                = var.grafana_storage_class
  storage_size                 = var.grafana_storage_size
  admin_user                   = var.grafana_admin_user
  admin_password               = var.grafana_admin_password
  loki_datasource_url          = var.grafana_loki_datasource_url != "" ? var.grafana_loki_datasource_url : (var.loki_enabled ? module.loki[0].service_url : "http://loki-gateway.observability.svc.cluster.local/")
  prometheus_datasource_url    = var.grafana_prometheus_datasource_url != "" ? var.grafana_prometheus_datasource_url : (var.prometheus_enabled ? "${module.prometheus[0].service_url}:9090" : "http://prometheus.observability.svc.cluster.local:9090")
  enable_loki_datasource       = var.grafana_enable_loki_datasource
  enable_prometheus_datasource = var.grafana_enable_prometheus_datasource

  helm_wait_enabled          = var.helm_wait_enabled
  helm_wait_for_jobs_enabled = var.helm_wait_for_jobs_enabled
  helm_timeout               = var.helm_timeout

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

  backup_enabled          = var.mysql_backup_enabled
  backup_schedule         = var.mysql_backup_schedule
  backup_retention_days   = var.mysql_backup_retention_days
  backup_resources        = var.mysql_backup_resources
  backup_timeout_seconds  = var.mysql_backup_timeout_seconds
  minio_endpoint_url      = var.mysql_minio_endpoint_url
  minio_bucket            = var.mysql_minio_bucket
  minio_region            = var.mysql_minio_region
  minio_access_key_id     = var.mysql_minio_access_key_id
  minio_secret_access_key = var.mysql_minio_secret_access_key
  root_password           = var.mysql_root_password
  monitoring_enabled      = var.mysql_monitoring_enabled
  monitoring_user         = var.mysql_monitoring_user
  monitoring_password     = var.mysql_monitoring_password

  helm_wait_enabled          = var.helm_wait_enabled
  helm_wait_for_jobs_enabled = var.helm_wait_for_jobs_enabled
  helm_timeout               = var.helm_timeout

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

  helm_wait_enabled          = var.helm_wait_enabled
  helm_wait_for_jobs_enabled = var.helm_wait_for_jobs_enabled
  helm_timeout               = var.helm_timeout

  # Removed depends_on: Redis uses ClusterIP service, doesn't need ingress-nginx
}





