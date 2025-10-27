# Percona Operator for MySQL (PXC) with MinIO Backups

Production-ready MySQL cluster using Percona XtraDB Cluster Operator with MinIO S3-compatible backups and Point-In-Time Recovery (PITR).

## Quick Start

```bash
# Navigate to db directory
cd k8s/infra/db

# Make scripts executable
chmod +x scripts/*.sh

# Install everything (operator + cluster)
./scripts/install.sh

# Check status
kubectl get pods -n db
kubectl get pxc -n db
```

## Architecture

- **Namespace**: `db`
- **Operator**: `pxc-operator` (manages PXC clusters)
- **Cluster**: `cluster1` (1-node MySQL cluster + 1 HAProxy instance - minimal setup)
- **Storage**: DigitalOcean Block Storage (8Gi per pod)
- **Backups**: Ready for MinIO configuration (disabled initially)

## Configuration

### Cluster Details
- 1x MySQL pod (1Gi RAM, 0.5 CPU max, minimal resources)
- 1x HAProxy pod for load balancing
- Single-node configuration for development/testing
- Unsafe flags enabled for minimal deployment

### Backup Strategy (Ready for Configuration)
- **MinIO integration**: Available in `cluster/cluster1-values-simple.yaml`
- **Daily full backups**: 02:00 UTC, keep 7 days
- **PITR**: Binary logs uploaded every 60s
- **Storage**: `s3://db-backup/` via `https://minio.terapeas.com`

### Networking
- **Internal**: `cluster1-haproxy.db.svc.cluster.local:3306`
- **External**: Disabled by default (change `serviceType: LoadBalancer` in values)

## Common Operations

### Connect to MySQL
```bash
# Get root password
kubectl get secret cluster1-secrets -n db -o jsonpath='{.data.root}' | base64 -d

# Port-forward to connect locally
kubectl port-forward svc/cluster1-haproxy 3306:3306 -n db

# Connect via mysql client
mysql -h 127.0.0.1 -P 3306 -u root -p
```

### Monitor Cluster
```bash
# Check cluster status
kubectl get pxc cluster1 -n db

# View pod status
kubectl get pods -n db -l app.kubernetes.io/name=percona-xtradb-cluster

# Check logs
kubectl logs -f deployment/pxc-operator -n db
```

### Backup Operations
```bash
# List backup schedules
kubectl get pxc-backup-schedules -n db

# Manual backup
kubectl apply -f - <<EOF
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata:
  name: manual-backup-$(date +%Y%m%d-%H%M%S)
  namespace: db
spec:
  pxcCluster: cluster1
  storageName: minio-storage
EOF

# Check backup status
kubectl get pxc-backups -n db
```

### Restore from Backup
```bash
# Point-in-time restore example
kubectl apply -f - <<EOF
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterRestore
metadata:
  name: restore-$(date +%Y%m%d-%H%M%S)
  namespace: db
spec:
  pxcCluster: cluster1
  backupName: daily-backup-2024-01-01-020000
  # Optional: point-in-time
  pitr:
    type: date
    date: "2024-01-01T10:30:00Z"
EOF
```

## Scaling

### Scale MySQL Nodes
```bash
# Edit cluster/cluster1-values.yaml, change pxc.size: 5
helm upgrade cluster1 percona/pxc-db -n db --values cluster/cluster1-values.yaml
```

### Scale HAProxy
```bash
# Edit cluster/cluster1-values.yaml, change haproxy.size: 3
helm upgrade cluster1 percona/pxc-db -n db --values cluster/cluster1-values.yaml
```

## Troubleshooting

### Common Issues
```bash
# Operator not ready
kubectl describe pod -l app.kubernetes.io/name=pxc-operator -n db

# Cluster stuck in initializing
kubectl describe pxc cluster1 -n db
kubectl logs -l app.kubernetes.io/name=percona-xtradb-cluster -n db

# Backup failures
kubectl describe pxc-backup -n db
kubectl logs -l job-name -n db
```

### Resource Constraints
- Minimum: 2 CPUs, 4Gi RAM per node
- Current allocation: ~3 CPUs, 6Gi RAM total
- Storage: 60Gi total (3x 20Gi)

## Security

- All pods run as non-root (UID 1001)
- Random passwords generated for all MySQL users
- TLS disabled by default (can be enabled)
- Network policies recommended (not included)

## Files Structure

```
db/
├── docs/                           # Documentation
│   ├── README.md                   # This file
│   ├── DEVOPS_CHEATSHEET.md       # Maintenance commands
│   ├── ARCHITECTURE_DIAGRAM.md    # System architecture diagrams
│   ├── DEPLOYMENT_LOG.md          # Deployment process log
│   ├── MONITORING_SETUP.md        # Monitoring configuration
│   └── mysql-connection-guide.yaml # Connection examples
├── cluster/                        # Cluster configuration
│   ├── namespace.yaml              # Kubernetes namespace
│   ├── minio-secret.yaml          # MinIO credentials for backups
│   ├── pxc-operator-values.yaml   # Operator Helm values
│   ├── cluster1-values-minimal.yaml # Working minimal cluster config
│   └── cluster1-values-simple.yaml # Full cluster with backups
├── scripts/                        # Management scripts
│   ├── install.sh                 # Complete installation script
│   ├── uninstall.sh               # Clean removal script
│   ├── status.sh                  # Status check and connection info
│   ├── connect-mysql.sh           # MySQL connection helper
│   └── monitoring-setup.sh        # Monitoring stack setup
├── monitoring/                     # Monitoring resources
│   ├── mysql-exporter.yaml        # MySQL metrics exporter
│   ├── prometheus.yaml            # Prometheus configuration
│   ├── grafana-datasource.yaml    # Grafana data source
│   ├── mysql-dashboard.json       # Grafana dashboard
│   └── setup-mysql-user.sql       # MySQL monitoring user
└── backup/                         # Backup configurations
    ├── enable-backup.yaml         # Backup schedule configuration
    └── manual-backup.yaml         # Manual backup job template
```

## Customization

### Enable External Access
Uncomment in `cluster/cluster1-values.yaml`:
```yaml
haproxy:
  serviceType: LoadBalancer
```

### Node Affinity
Uncomment and modify node selector examples in values files.

### Resource Limits
Adjust `resources` sections in `cluster/cluster1-values.yaml` based on workload.

## Dependencies

- Kubernetes 1.19+
- Helm 3.0+
- MinIO instance at `https://minio.terapeas.com`
- DigitalOcean Block Storage CSI (or compatible storage class)

Here are all the ways to connect to your MySQL database:

  🏠 From Your Local Machine

  Method 1: Port Forward (Recommended)

  # Terminal 1: Start port forward
  kubectl port-forward -n db svc/cluster1-pxc-db-haproxy 3306:3306

  # Terminal 2: Connect with MySQL client
  mysql -h 127.0.0.1 -P 3306 -u root -p'jgab3IiennmI]OqS'

  # Or use GUI clients (MySQL Workbench, DBeaver, etc.):
  # Host: 127.0.0.1
  # Port: 3306
  # Username: root
  # Password: jgab3IiennmI]OqS

  Method 2: Quick Helper Script

  ./scripts/connect-mysql.sh
  # This script shows all connection options and can start port-forward for you

  🔗 From Other Pods/Namespaces in Kubernetes

  Service Endpoint (Works from ANY namespace)

  # Internal service endpoint:
  cluster1-pxc-db-haproxy.db.svc.cluster.local:3306

  Test Connection from Any Namespace

  # Quick test (automatically deletes pod after):
  kubectl run mysql-test --image=mysql:8.0 --rm -it --restart=Never -- \
    mysql -hcluster1-pxc-db-haproxy.db.svc.cluster.local -uroot -p'jgab3IiennmI]OqS'

  For Your Applications

  Use this connection string in your app pods:
  # Connection string format:
  mysql://root:jgab3IiennmI]OqS@cluster1-pxc-db-haproxy.db.svc.cluster.local:3306/

  # Environment variables for apps:
  MYSQL_HOST=cluster1-pxc-db-haproxy.db.svc.cluster.local
  MYSQL_PORT=3306
  MYSQL_USER=root
  MYSQL_PASSWORD=jgab3IiennmI]OqS

  📦 Deploy Example App with MySQL Connection

  I've created mysql-connection-guide.yaml with examples showing:
  - ConfigMap for connection details
  - Secret for credentials
  - Sample app deployment with environment variables
  - Test job to verify connectivity

  # Deploy example connection resources to your app namespace:
  kubectl apply -f docs/mysql-connection-guide.yaml -n YOUR_APP_NAMESPACE

  🔧 Direct Pod Access

  # Connect directly to MySQL pod (bypasses HAProxy):
  kubectl -n db exec -it cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'jgab3IiennmI]OqS'

  ✅ Verified Working

  - ✅ Local connection via port-forward
  - ✅ Cross-namespace connectivity tested
  - ✅ Service discovery working properly
  - ✅ Authentication successful

  The database is accessible from anywhere in your Kubernetes cluster using the internal service endpoint, and from your local machine via port-forwarding!