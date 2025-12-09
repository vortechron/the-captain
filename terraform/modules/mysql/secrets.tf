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

# Local values for secrets to ensure proper string handling
locals {
  mysql_secrets_passwords = {
    root         = var.root_password != "" ? var.root_password : ""
    xtrabackup   = ""
    monitor      = ""
    clustercheck = ""
  }
}

# Generate random passwords for MySQL users (when not provided)
resource "random_password" "mysql_passwords" {
  for_each = toset(["root", "xtrabackup", "monitor", "clustercheck"])

  length  = 32
  special = true
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
    root         = var.root_password != "" ? var.root_password : random_password.mysql_passwords["root"].result
    xtrabackup   = random_password.mysql_passwords["xtrabackup"].result
    monitor      = random_password.mysql_passwords["monitor"].result
    clustercheck = random_password.mysql_passwords["clustercheck"].result
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
    root         = var.root_password != "" ? var.root_password : random_password.mysql_passwords["root"].result
    xtrabackup   = random_password.mysql_passwords["xtrabackup"].result
    monitor      = random_password.mysql_passwords["monitor"].result
    clustercheck = random_password.mysql_passwords["clustercheck"].result
  }
}





