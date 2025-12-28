# Percona XtraDB Cluster Helm Release
resource "helm_release" "pxc_cluster" {
  name       = var.cluster_name
  repository = "https://percona.github.io/percona-helm-charts/"
  chart      = "pxc-db"
  version    = var.cluster_chart_version != "" ? var.cluster_chart_version : null
  namespace  = kubernetes_namespace.mysql.metadata[0].name

  atomic          = true # Critical: keep atomic for safety
  wait            = var.helm_wait_enabled
  wait_for_jobs   = var.helm_wait_for_jobs_enabled
  timeout         = 60 # Minimal timeout for Helm API calls
  reuse_values    = false
  force_update    = false
  cleanup_on_fail = true

  values = [
    yamlencode({
      crName                    = var.cluster_name
      crVersion                 = "1.18.0"
      enableCRValidationWebhook = false
      allowUnsafeConfigurations = false

      tls = {
        enabled = false
      }

      unsafeFlags = {
        tls       = true
        pxcSize   = true
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
                   # Galera/wsrep configuration
                   wsrep_provider_options="debug=0;gcache.size=300M;gcache.keep_pages_size=300M;gcs.fc_limit=9999999;gcs.fc_factor=1.0;gcs.fc_single_primary=yes;pc.wait_prim_timeout=PT60S;evs.inactive_check_period=PT0.5S;evs.suspect_timeout=PT5S;evs.keepalive_period=PT1S;evs.inactive_timeout=PT15S"
                   wsrep_debug=0
                   wsrep_cluster_name=${var.cluster_name}
                   wsrep_sst_method=xtrabackup-v2

                   # NOTE: wsrep_cluster_address is managed automatically by the operator
                   # Attempting to set it manually with ports will be overridden
                   # Known Issue: Operator 1.18.0 backup script doesn't include port :4567 in garbd gcomm URL
                   # This causes backup failures with "Connection timed out" errors
                   # Workaround: Use operator version 1.19.0+ or manual backup scripts

                   # MySQL configuration
                   binlog_format=ROW
                   default_storage_engine=InnoDB
                   innodb_autoinc_lock_mode=2
                   max_connections=2048
                   innodb_buffer_pool_size=2G

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
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                podAffinityTerm = {
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

        resources = var.backup_enabled ? {
          requests = {
            cpu    = var.backup_resources.requests.cpu
            memory = var.backup_resources.requests.memory
          }
          limits = {
            cpu    = var.backup_resources.limits.cpu
            memory = var.backup_resources.limits.memory
          }
        } : {}

        schedule = var.backup_enabled ? [
          {
            name        = "daily-backup"
            schedule    = var.backup_schedule
            keep        = var.backup_retention_days
            storageName = "minio-storage"
          }
        ] : []

        pitr = var.backup_enabled ? {
          enabled            = true
          storageName        = "minio-storage"
          timeBetweenUploads = 60
          timeoutSeconds     = var.backup_timeout_seconds
          resources = {
            requests = {
              cpu    = var.backup_resources.requests.cpu
              memory = var.backup_resources.requests.memory
            }
            limits = {
              cpu    = var.backup_resources.limits.cpu
              memory = var.backup_resources.limits.memory
            }
          }
        } : null

        storages = var.backup_enabled ? {
          minio-storage = {
            type = "s3"
            containerOptions = {
              args = {
                xbcloud = ["--s3-bucket-lookup=path"]
              }
            }
            s3 = {
              bucket            = var.minio_bucket
              region            = var.minio_region
              endpointUrl       = var.minio_endpoint_url
              credentialsSecret = "minio-backup-secret"
            }
          }
        } : {}
      }

      pmm = {
        enabled = false
      }

      secretsName = "${var.cluster_name}-pxc-db-secrets"
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

  # Set PITR timeout and resources
  set {
    name  = "backup.pitr.timeoutSeconds"
    value = var.backup_enabled ? var.backup_timeout_seconds : 60
  }

  set {
    name  = "backup.pitr.resources.requests.cpu"
    value = var.backup_enabled ? var.backup_resources.requests.cpu : "0"
  }

  set {
    name  = "backup.pitr.resources.requests.memory"
    value = var.backup_enabled ? var.backup_resources.requests.memory : "0"
  }

  set {
    name  = "backup.pitr.resources.limits.cpu"
    value = var.backup_enabled ? var.backup_resources.limits.cpu : "0"
  }

  set {
    name  = "backup.pitr.resources.limits.memory"
    value = var.backup_enabled ? var.backup_resources.limits.memory : "0"
  }

  depends_on = [
    helm_release.pxc_operator,
    kubernetes_secret.minio_backup_secret,
    kubernetes_secret.mysql_cluster_secrets,
    kubernetes_secret.mysql_cluster_secrets_operator
  ]
}

# Patch PerconaXtraDBCluster to set backup job and PITR timeout and resources
# This is needed because the Helm chart values don't always apply these settings correctly
resource "null_resource" "patch_backup_config" {
  count = var.backup_enabled ? 1 : 0

  triggers = {
    cluster_name      = var.cluster_name
    namespace         = var.namespace
    timeout_seconds   = var.backup_timeout_seconds
    resources_cpu_req = var.backup_resources.requests.cpu
    resources_mem_req = var.backup_resources.requests.memory
    resources_cpu_lim = var.backup_resources.limits.cpu
    resources_mem_lim = var.backup_resources.limits.memory
    helm_release_id   = helm_release.pxc_cluster.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl patch perconaxtradbcluster ${var.cluster_name}-pxc-db -n ${var.namespace} --type merge -p '{
        "spec": {
          "backup": {
            "pitr": {
              "timeoutSeconds": ${var.backup_timeout_seconds},
              "resources": {
                "requests": {
                  "cpu": "${var.backup_resources.requests.cpu}",
                  "memory": "${var.backup_resources.requests.memory}"
                },
                "limits": {
                  "cpu": "${var.backup_resources.limits.cpu}",
                  "memory": "${var.backup_resources.limits.memory}"
                }
              }
            }
          }
        }
      }'
    EOT
  }

  depends_on = [helm_release.pxc_cluster]
}
