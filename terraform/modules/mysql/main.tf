# MySQL Namespace
resource "kubernetes_namespace" "mysql" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

# MinIO Secret for Backups
resource "kubernetes_secret" "minio_backup_secret" {
  metadata {
    name      = "minio-backup-secret"
    namespace = kubernetes_namespace.mysql.metadata[0].name
  }

  type = "Opaque"

  data = {
    AWS_ACCESS_KEY_ID     = var.minio_access_key_id
    AWS_SECRET_ACCESS_KEY = var.minio_secret_access_key
  }
}

# Percona Operator Helm Release
resource "helm_release" "pxc_operator" {
  name       = "pxc-operator"
  repository = "https://percona.github.io/percona-helm-charts/"
  chart      = "pxc-operator"
  version    = var.operator_chart_version != "" ? var.operator_chart_version : null
  namespace  = kubernetes_namespace.mysql.metadata[0].name

  atomic          = true  # Critical: keep atomic for safety
  wait            = var.helm_wait_enabled
  wait_for_jobs   = var.helm_wait_for_jobs_enabled
  timeout         = 60  # Minimal timeout for Helm API calls
  reuse_values    = false
  force_update    = false
  cleanup_on_fail = true

  values = [
    yamlencode({
      resources = {
        limits = {
          cpu    = "200m"
          memory = "500Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "200Mi"
        }
      }
      rbac = {
        useClusterWideAccess = false
      }
      operator = {
        watchNamespace = var.namespace
      }
      leaderElection = true
      logLevel       = "INFO"
    })
  ]
}

# Local values for secrets to ensure proper string handling
locals {
  mysql_secrets_passwords = {
    root         = var.root_password != "" ? var.root_password : ""
    xtrabackup  = ""
    monitor      = ""
    clustercheck = ""
  }
}

# Create MySQL secrets manually as Kubernetes resource
# This avoids Terraform/Helm yamlencode issues with empty strings
# Note: Percona operator creates secret with pattern: {cluster-name}-pxc-db-secrets
# We create both to ensure compatibility
resource "kubernetes_secret" "mysql_cluster_secrets" {
  metadata {
    name      = "${var.cluster_name}-secrets"
    namespace = kubernetes_namespace.mysql.metadata[0].name
  }

  type = "Opaque"

  data = {
    root         = base64encode(var.root_password != "" ? var.root_password : random_password.mysql_passwords["root"].result)
    xtrabackup  = base64encode(random_password.mysql_passwords["xtrabackup"].result)
    monitor      = base64encode(random_password.mysql_passwords["monitor"].result)
    clustercheck = base64encode(random_password.mysql_passwords["clustercheck"].result)
  }
}

# Also create/update the secret that Percona operator actually uses
resource "kubernetes_secret" "mysql_cluster_secrets_operator" {
  metadata {
    name      = "${var.cluster_name}-pxc-db-secrets"
    namespace = kubernetes_namespace.mysql.metadata[0].name
  }

  type = "Opaque"

  data = {
    root         = base64encode(var.root_password != "" ? var.root_password : random_password.mysql_passwords["root"].result)
    xtrabackup  = base64encode(random_password.mysql_passwords["xtrabackup"].result)
    monitor      = base64encode(random_password.mysql_passwords["monitor"].result)
    clustercheck = base64encode(random_password.mysql_passwords["clustercheck"].result)
  }
}

# Generate random passwords for MySQL users (when not provided)
resource "random_password" "mysql_passwords" {
  for_each = toset(["root", "xtrabackup", "monitor", "clustercheck"])
  
  length  = 32
  special = true
}

# Percona XtraDB Cluster Helm Release
resource "helm_release" "pxc_cluster" {
  name       = var.cluster_name
  repository = "https://percona.github.io/percona-helm-charts/"
  chart      = "pxc-db"
  version    = var.cluster_chart_version != "" ? var.cluster_chart_version : null
  namespace  = kubernetes_namespace.mysql.metadata[0].name

  atomic          = true  # Critical: keep atomic for safety
  wait            = var.helm_wait_enabled
  wait_for_jobs   = var.helm_wait_for_jobs_enabled
  timeout         = 60  # Minimal timeout for Helm API calls
  reuse_values    = false
  force_update    = false
  cleanup_on_fail = true

  values = [
    yamlencode({
      crName                     = var.cluster_name
      crVersion                  = "1.18.0"
      enableCRValidationWebhook  = false
      allowUnsafeConfigurations  = false
      
      tls = {
        enabled = false
      }
      
      unsafeFlags = {
        tls     = true
        pxcSize = true
        proxySize = true
      }
      
      pxc = {
        size         = var.pxc_size
        autoRecovery = true
        image = {
          repository = "percona/percona-xtradb-cluster"
          tag        = var.pxc_image_tag
        }
        
        resources = {
          requests = {
            memory = var.pxc_resources.requests.memory
            cpu    = var.pxc_resources.requests.cpu
          }
          limits = {
            memory = var.pxc_resources.limits.memory
            cpu    = var.pxc_resources.limits.cpu
          }
        }
        
        volumeSpec = {
          persistentVolumeClaim = {
            storageClassName = var.storage_class
            accessModes      = ["ReadWriteOnce"]
            resources = {
              requests = {
                storage = var.storage_size
              }
            }
          }
        }
        
                 configuration = <<-EOT
                   [mysqld]
                   wsrep_provider_options="debug=0;gcache.size=300M;gcache.keep_pages_size=300M"
                   wsrep_debug=0
                   wsrep_cluster_name=${var.cluster_name}
                   binlog_format=ROW
                   default_storage_engine=InnoDB
                   innodb_autoinc_lock_mode=2
                   max_connections=1024
                   innodb_buffer_pool_size=512M
                   
                   # Binary logging for PITR
                   log-bin=mysql-bin
                   binlog_expire_logs_seconds=604800
                   max_binlog_size=100M
                   sync_binlog=1
                   
                   # GTID for consistent backups
                   gtid_mode=ON
                   enforce_gtid_consistency=ON
                   log_replica_updates=ON
                 EOT
        
        podSecurityContext = {
          runAsUser  = 1001
          runAsGroup = 1001
          fsGroup    = 1001
        }
        
        affinity = {
          nodeAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                preference = {
                  matchExpressions = [
                    {
                      key      = "kubernetes.azure.com/agentpool"
                      operator = "In"
                      values   = ["d4pool"]
                    }
                  ]
                }
              }
            ]
          }
          podAntiAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = [
              {
                labelSelector = {
                  matchExpressions = [
                    {
                      key      = "app.kubernetes.io/name"
                      operator = "In"
                      values   = ["percona-xtradb-cluster"]
                    }
                  ]
                }
                topologyKey = "kubernetes.io/hostname"
              }
            ]
          }
        }
      }
      
      haproxy = {
        enabled     = true
        size        = var.haproxy_size
        serviceType = "ClusterIP"
        affinity = {
          nodeAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                preference = {
                  matchExpressions = [
                    {
                      key      = "kubernetes.azure.com/agentpool"
                      operator = "In"
                      values   = ["d4pool"]
                    }
                  ]
                }
              }
            ]
          }
        }
      }
      
      podDisruptionBudget = {
        enabled        = true
        maxUnavailable = 1
      }
      
      backup = {
        enabled = var.backup_enabled
        image = {
          repository = "percona/percona-xtrabackup"
          tag        = var.backup_image_tag
        }
        
        schedule = var.backup_enabled ? [
          {
            name       = "daily-backup"
            schedule   = var.backup_schedule
            keep       = var.backup_retention_days
            storageName = "minio-storage"
          }
        ] : []
        
        pitr = var.backup_enabled ? {
          enabled          = true
          storageName      = "minio-storage"
          timeBetweenUploads = 60
        } : {
          enabled = false
        }
        
        storages = var.backup_enabled ? {
          minio-storage = {
            type = "s3"
            s3 = {
              bucket          = var.minio_bucket
              region          = var.minio_region
              endpointUrl     = var.minio_endpoint_url
              credentialsSecret = "minio-backup-secret"
              forcePathStyle  = true
            }
          }
        } : {}
      }
      
      pmm = {
        enabled = false
      }
      
      secretsName = "${var.cluster_name}-secrets"
    })
  ]
  
  # Set HAProxy image as a single string (not repository/tag object)
  # The Helm chart expects: haproxy.image = "percona/haproxy:2.8.15"
  set {
    name  = "haproxy.image"
    value = "percona/haproxy:2.8.15"
  }
  
  # Set HAProxy resources
  set {
    name  = "haproxy.resources.requests.cpu"
    value = var.haproxy_resources.requests.cpu
  }
  
  set {
    name  = "haproxy.resources.requests.memory"
    value = var.haproxy_resources.requests.memory
  }
  
  set {
    name  = "haproxy.resources.limits.cpu"
    value = var.haproxy_resources.limits.cpu
  }
  
  set {
    name  = "haproxy.resources.limits.memory"
    value = var.haproxy_resources.limits.memory
  }

  depends_on = [
    helm_release.pxc_operator,
    kubernetes_secret.minio_backup_secret,
    kubernetes_secret.mysql_cluster_secrets,
    kubernetes_secret.mysql_cluster_secrets_operator
  ]
}

# MySQL Exporter Secret
resource "kubernetes_secret" "mysql_exporter_secret" {
  count = var.monitoring_enabled ? 1 : 0

  metadata {
    name      = "mysql-exporter-secret"
    namespace = kubernetes_namespace.mysql.metadata[0].name
  }

  type = "Opaque"

  data = {
    MYSQL_USER       = base64encode(var.monitoring_user)
    MYSQL_PASSWORD   = base64encode(var.monitoring_password)
    DATA_SOURCE_NAME = base64encode("${var.monitoring_user}:${var.monitoring_password}@(${var.cluster_name}-pxc-db-haproxy.${var.namespace}.svc.cluster.local:3306)/")
  }

  depends_on = [helm_release.pxc_cluster]
}

# MySQL Exporter ConfigMap
resource "kubernetes_config_map" "mysql_exporter_config" {
  count = var.monitoring_enabled ? 1 : 0

  metadata {
    name      = "mysql-exporter-config"
    namespace = kubernetes_namespace.mysql.metadata[0].name
  }

  data = {
    ".my.cnf" = <<-EOT
      [client]
      user=${var.monitoring_user}
      password=${var.monitoring_password}
      host=${var.cluster_name}-pxc-db-haproxy.${var.namespace}.svc.cluster.local
      port=3306
    EOT
  }
}

# MySQL Exporter Deployment
resource "kubernetes_deployment" "mysql_exporter" {
  count = var.monitoring_enabled ? 1 : 0

  metadata {
    name      = "mysql-exporter"
    namespace = kubernetes_namespace.mysql.metadata[0].name
    labels = {
      app = "mysql-exporter"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mysql-exporter"
      }
    }

    template {
      metadata {
        labels = {
          app = "mysql-exporter"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "9104"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        container {
          name  = "mysql-exporter"
          image = var.monitoring_exporter_image

          port {
            container_port = 9104
            name           = "metrics"
          }

          env {
            name = "DATA_SOURCE_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_exporter_secret[0].metadata[0].name
                key  = "DATA_SOURCE_NAME"
              }
            }
          }

          env {
            name  = "MYSQLD_EXPORTER_WEB_LISTEN_ADDRESS"
            value = ":9104"
          }

          env {
            name = "MYSQL_PWD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_exporter_secret[0].metadata[0].name
                key  = "MYSQL_PASSWORD"
              }
            }
          }

          # Enable additional collectors for detailed metrics
          env {
            name  = "MYSQLD_EXPORTER_COLLECT_GLOBAL_STATUS"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_GLOBAL_VARIABLES"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_SLAVE_STATUS"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_INFO_SCHEMA_INNODB_METRICS"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_INFO_SCHEMA_INNODB_TABLESPACES"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_INFO_SCHEMA_INNODB_CMP"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_INFO_SCHEMA_INNODB_CMPMEM"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_PERF_SCHEMA_TABLELOCKS"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_PERF_SCHEMA_EVENTSWAITS"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_PERF_SCHEMA_INDEXIOWAITS"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_PERF_SCHEMA_TABLEIOWAITS"
            value = "true"
          }

          volume_mount {
            name       = "mysql-config"
            mount_path = "/.my.cnf"
            sub_path   = ".my.cnf"
            read_only  = true
          }

          resources {
            requests = {
              cpu    = var.monitoring_resources.requests.cpu
              memory = var.monitoring_resources.requests.memory
            }
            limits = {
              cpu    = var.monitoring_resources.limits.cpu
              memory = var.monitoring_resources.limits.memory
            }
          }

          liveness_probe {
            http_get {
              path = "/metrics"
              port = 9104
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }

          readiness_probe {
            http_get {
              path = "/metrics"
              port = 9104
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }

        volume {
          name = "mysql-config"
          config_map {
            name = kubernetes_config_map.mysql_exporter_config[0].metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.pxc_cluster,
    kubernetes_secret.mysql_exporter_secret
  ]
}

# MySQL Exporter Service
resource "kubernetes_service" "mysql_exporter" {
  count = var.monitoring_enabled ? 1 : 0

  metadata {
    name      = "mysql-exporter"
    namespace = kubernetes_namespace.mysql.metadata[0].name
    labels = {
      app = "mysql-exporter"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9104"
      "prometheus.io/path"   = "/metrics"
    }
  }

  spec {
    selector = {
      app = "mysql-exporter"
    }

    port {
      name        = "metrics"
      port        = 9104
      target_port = 9104
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.mysql_exporter]
}

# MySQL Monitoring User Setup Job
resource "kubernetes_job" "mysql_monitoring_user" {
  count = var.monitoring_enabled ? 1 : 0

  metadata {
    name      = "mysql-monitoring-user-setup"
    namespace = kubernetes_namespace.mysql.metadata[0].name
  }

  spec {
    template {
      metadata {
        labels = {
          app = "mysql-monitoring-user-setup"
        }
      }

      spec {
        container {
          name  = "mysql-client"
          image = "mysql:8.0"

          command = [
            "sh",
            "-c",
            <<-EOT
              mysql -h${var.cluster_name}-pxc-db-haproxy.${var.namespace}.svc.cluster.local -uroot -p'${var.root_password}' <<EOF
              CREATE USER IF NOT EXISTS '${var.monitoring_user}'@'%' IDENTIFIED BY '${var.monitoring_password}';
              GRANT PROCESS ON *.* TO '${var.monitoring_user}'@'%';
              GRANT REPLICATION CLIENT ON *.* TO '${var.monitoring_user}'@'%';
              GRANT SELECT ON performance_schema.* TO '${var.monitoring_user}'@'%';
              FLUSH PRIVILEGES;
              EOF
            EOT
          ]

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }

        restart_policy = "OnFailure"
      }
    }

    backoff_limit = 3
  }

  depends_on = [helm_release.pxc_cluster]
}

