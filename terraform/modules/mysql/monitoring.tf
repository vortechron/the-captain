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





