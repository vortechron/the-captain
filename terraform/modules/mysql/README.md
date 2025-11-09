# MySQL Module

This Terraform module deploys a Percona XtraDB Cluster (MySQL) on Kubernetes using Helm charts.

## Features

- ✅ Percona XtraDB Cluster Operator
- ✅ MySQL cluster with configurable node count
- ✅ HAProxy for load balancing
- ✅ Automated backups to MinIO (optional)
- ✅ Point-in-Time Recovery (PITR) support
- ✅ Persistent storage with configurable storage class
- ✅ MySQL Exporter for Prometheus monitoring (optional)
- ✅ Automatic monitoring user creation

## Usage

```hcl
module "mysql" {
  source = "./modules/mysql"

  namespace     = "db"
  cluster_name  = "cluster1"
  storage_class = "managed-premium"
  storage_size  = "20Gi"
  
  pxc_size = 1
  haproxy_size = 1
  
  backup_enabled = true
  minio_endpoint_url = "https://minio.aks.terapeas.com"
  minio_bucket = "db-backup"
  minio_access_key_id = "minioadmin"
  minio_secret_access_key = "your-secret-key"
  root_password = "jgab3IiennmI]OqS"
  monitoring_enabled = true
  monitoring_user = "exporter"
  monitoring_password = "exporterpassword123"
}
```

## Requirements

- Kubernetes cluster (AKS, EKS, GKE, etc.)
- Helm 3.x
- Storage class available in cluster
- MinIO instance (if backups enabled)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| namespace | Kubernetes namespace | `string` | `"db"` | no |
| cluster_name | Percona cluster name | `string` | `"cluster1"` | no |
| storage_class | Storage class for PVCs | `string` | `"managed-premium"` | no |
| storage_size | Storage size per node | `string` | `"20Gi"` | no |
| pxc_size | Number of MySQL nodes | `number` | `1` | no |
| haproxy_size | Number of HAProxy replicas | `number` | `1` | no |
| backup_enabled | Enable MinIO backups | `bool` | `true` | no |
| minio_endpoint_url | MinIO S3 endpoint | `string` | `"https://minio.aks.terapeas.com"` | no |
| minio_bucket | MinIO bucket name | `string` | `"db-backup"` | no |
| minio_access_key_id | MinIO access key | `string` | `"minioadmin"` | yes (if backups enabled) |
| minio_secret_access_key | MinIO secret key | `string` | `""` | yes (if backups enabled) |
| root_password | MySQL root password | `string` | `""` (auto-generate) | no |
| monitoring_enabled | Enable MySQL monitoring | `bool` | `true` | no |
| monitoring_user | MySQL monitoring user | `string` | `"exporter"` | no |
| monitoring_password | MySQL monitoring password | `string` | `"exporterpassword123"` | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace | MySQL namespace name |
| cluster_name | Percona cluster name |
| service_endpoint | Internal MySQL service endpoint |
| service_name | HAProxy service name |
| secret_name | MySQL secrets name |
| monitoring_enabled | Whether monitoring is enabled |
| monitoring_service_endpoint | MySQL Exporter service endpoint |
| monitoring_service_name | MySQL Exporter service name |

## Getting Database Credentials

```bash
# Get root password
kubectl get secret cluster1-pxc-db-secrets -n db -o jsonpath='{.data.root}' | base64 -d

# Get all passwords
kubectl get secret cluster1-pxc-db-secrets -n db -o yaml
```

## Connecting to Database

### From Kubernetes Pods

Use the internal service endpoint:
```
cluster1-pxc-db-haproxy.db.svc.cluster.local:3306
```

### From Local Machine

```bash
# Port forward
kubectl port-forward svc/cluster1-pxc-db-haproxy 3306:3306 -n db

# Connect
mysql -h 127.0.0.1 -P 3306 -u root -p
```

## Scaling

To scale the cluster, update the `pxc_size` variable and run `terraform apply`:

```hcl
pxc_size = 3  # Scale to 3 nodes
```

## Backups

Backups are configured to run daily at 2 AM UTC by default. To customize:

```hcl
backup_schedule = "0 2 * * *"  # Cron expression
backup_retention_days = 7       # Keep 7 days of backups
```

### Restoring from Backup

Use the provided restore script to restore backups from MinIO:

```bash
# Interactive restore (recommended)
./restore-mysql-backup.sh

# List available backups
./restore-mysql-backup.sh --list

# Restore from specific backup
./restore-mysql-backup.sh --backup manual-backup-20240101-120000

# Point-in-time restore
./restore-mysql-backup.sh --backup manual-backup-20240101-120000 --pitr "2024-01-01T10:30:00Z"
```

The restore script:
- Automatically retrieves MinIO credentials from Kubernetes secrets
- Lists available backups from MinIO or Kubernetes resources
- Creates a `PerconaXtraDBClusterRestore` resource
- Monitors restore progress and reports status

**Important Notes:**
- Restoring will replace the current database state with backup data
- Ensure you have a recent backup before performing a restore
- The restore process may take several minutes depending on backup size
- Monitor the restore progress using the script or `kubectl get pxc-restore -n db`

## Monitoring

When `monitoring_enabled = true`, the module will:

1. **Deploy MySQL Exporter**: Prometheus MySQL Exporter pod that scrapes MySQL metrics
2. **Create Monitoring User**: Automatically creates an `exporter` user in MySQL with necessary privileges
3. **Service Discovery**: Exporter service is annotated for Prometheus auto-discovery
4. **Metrics Endpoint**: Available at `mysql-exporter.db.svc.cluster.local:9104/metrics`

The Prometheus Helm chart will automatically discover and scrape the MySQL Exporter if it's deployed in the same cluster.

### Monitoring User Privileges

The monitoring user (`exporter` by default) is granted:
- `PROCESS` - View running processes
- `REPLICATION CLIENT` - Monitor replication status
- `SELECT` on `performance_schema.*` - Performance metrics
- `SELECT` on `information_schema.*` - Database metadata
- `SELECT` on `mysql.slave_*` - Replication info

## Notes

- The module uses Helm to install Percona Operator and Cluster
- Storage class should match your cluster's available storage classes
- For Azure AKS, use `managed-premium` storage class
- Backups require MinIO instance to be accessible from the cluster
- Monitoring requires Prometheus to be deployed in the cluster for metrics collection
- The monitoring user setup job runs automatically after cluster creation

