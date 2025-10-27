# MySQL PXC Database Infrastructure

This directory contains a complete Percona XtraDB Cluster (PXC) setup with automated backups, monitoring, and management tools.

## 📁 Directory Structure

```
db/
├── 📖 docs/                           # Documentation & Guides
│   ├── README.md                      # Complete setup documentation
│   ├── DEVOPS_CHEATSHEET.md          # Maintenance commands reference
│   ├── ARCHITECTURE_DIAGRAM.md       # System architecture diagrams
│   ├── DEPLOYMENT_LOG.md             # Deployment process log
│   ├── MONITORING_SETUP.md           # Monitoring configuration guide
│   └── mysql-connection-guide.yaml   # Connection examples for apps
│
├── ⚙️  cluster/                        # Core Configuration
│   ├── namespace.yaml                 # Kubernetes namespace
│   ├── minio-secret.yaml             # MinIO credentials for backups
│   ├── pxc-operator-values.yaml      # Operator Helm values
│   ├── cluster1-values-minimal.yaml  # Minimal cluster (current)
│   └── cluster1-values-simple.yaml   # Full 3-node cluster + backups
│
├── 🔧 scripts/                        # Management Scripts
│   ├── install.sh                    # Complete installation
│   ├── uninstall.sh                  # Clean removal
│   ├── status.sh                     # Status check & connection info
│   ├── connect-mysql.sh              # MySQL connection helper
│   └── monitoring-setup.sh           # Monitoring stack setup
│
├── 📊 monitoring/                     # Observability Stack
│   ├── mysql-exporter.yaml           # MySQL metrics exporter
│   ├── prometheus.yaml               # Prometheus configuration
│   ├── grafana-datasource.yaml       # Grafana data source
│   ├── mysql-dashboard.json          # Grafana dashboard config
│   └── setup-mysql-user.sql          # MySQL monitoring user setup
│
└── 💾 backup/                         # Backup Management
    ├── enable-backup.yaml            # Daily backup schedule
    └── manual-backup.yaml            # Manual backup job template
```

## 🚀 Quick Start

```bash
# Navigate to the db infrastructure directory
cd k8s/infra/db

# Make scripts executable
chmod +x scripts/*.sh

# Install everything (operator + cluster + monitoring)
./scripts/install.sh

# Check installation status
./scripts/status.sh

# Connect to MySQL
./scripts/connect-mysql.sh
```

## 📋 What's Included

- **✅ MySQL Cluster**: 1-node Percona XtraDB Cluster (scalable to 3+)
- **✅ Load Balancer**: HAProxy for connection pooling
- **✅ Automated Backups**: Daily backups to MinIO S3 storage
- **✅ Monitoring**: MySQL Exporter + Prometheus + Grafana dashboards
- **✅ Point-in-Time Recovery**: Binary log backups for PITR
- **✅ Management Scripts**: Installation, status, connection helpers
- **✅ Documentation**: Complete setup and maintenance guides

## 🔗 Key Endpoints

| Service | Endpoint | Purpose |
|---------|----------|---------|
| **MySQL** | `cluster1-pxc-db-haproxy.db.svc.cluster.local:3306` | Application connections |
| **MySQL Metrics** | `mysql-exporter.db.svc.cluster.local:9104` | Prometheus scraping |
| **MinIO Backups** | `https://minio.terapeas.com` | Backup storage |

## 📚 Documentation

- **[📖 Complete Guide](docs/README.md)** - Full setup and usage documentation
- **[🔧 DevOps Commands](docs/DEVOPS_CHEATSHEET.md)** - Command reference for daily operations
- **[🏗️ Architecture](docs/ARCHITECTURE_DIAGRAM.md)** - System diagrams and data flow
- **[📊 Monitoring Setup](docs/MONITORING_SETUP.md)** - Observability configuration

## ⚡ Current Status

- **Cluster**: ✅ Running (1 MySQL node + 1 HAProxy)
- **Backups**: ✅ Daily backups to MinIO at 2 AM UTC
- **Monitoring**: ✅ MySQL Exporter + Grafana dashboards
- **SSL**: ⚠️ Disabled (configured for internal cluster communication)

## 🔐 Security Note

This setup is configured for internal Kubernetes networking with SSL disabled for simplicity. For production environments, consider enabling TLS/SSL encryption between components.

## 🆘 Need Help?

1. Check the [DevOps Cheatsheet](docs/DEVOPS_CHEATSHEET.md) for common commands
2. Review [Architecture Diagrams](docs/ARCHITECTURE_DIAGRAM.md) for system understanding
3. Run `./scripts/status.sh` for current cluster health
4. Check pod logs: `kubectl logs -n db cluster1-pxc-pxc-0`