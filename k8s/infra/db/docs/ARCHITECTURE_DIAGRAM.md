# MySQL PXC Cluster Architecture Diagram

This document provides ASCII diagrams showing how the Percona XtraDB Cluster setup interacts with various components in the Kubernetes environment.

## Overall System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Kubernetes Cluster                                │
│                                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐             │
│  │   default ns    │    │     db ns       │    │   minio ns      │             │
│  │                 │    │                 │    │                 │             │
│  │ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │             │
│  │ │   terapeas  │ │    │ │    MySQL    │ │    │ │    MinIO    │ │             │
│  │ │   Laravel   │─┼────┼─│     PXC     │ │    │ │   Storage   │ │             │
│  │ │     App     │ │    │ │   Cluster   │ │    │ │             │ │             │
│  │ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │             │
│  │                 │    │        │        │    │        ▲        │             │
│  └─────────────────┘    │        │        │    │        │        │             │
│                         │        │        │    │        │        │             │
│  ┌─────────────────┐    │        ▼        │    │        │        │             │
│  │ monitoring ns   │    │ ┌─────────────┐ │    │        │        │             │
│  │                 │    │ │   Backup    │─┼────┼────────┘        │             │
│  │ ┌─────────────┐ │    │ │    Jobs     │ │    │                 │             │
│  │ │  Grafana +  │◄┼────┼─│             │ │    │                 │             │
│  │ │ Prometheus  │ │    │ └─────────────┘ │    │                 │             │
│  │ └─────────────┘ │    │                 │    │                 │             │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘             │
└─────────────────────────────────────────────────────────────────────────────────┘

External Access:
├─ kubectl (port-forward)
├─ Local MySQL clients
└─ MinIO Console UI
```

## Database Namespace (db) - Detailed View

```
┌─────────────────────────────────────────────────────────────────┐
│                        db namespace                            │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                  MySQL PXC Cluster                         │ │
│ │                                                             │ │
│ │  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐      │ │
│ │  │cluster1-pxc-│   │cluster1-pxc-│   │cluster1-pxc-│      │ │
│ │  │    pxc-0    │◄──┤    pxc-1    │◄──┤    pxc-2    │      │ │
│ │  │             │   │  (scaled    │   │  (scaled    │      │ │
│ │  │ MySQL Node  │   │   down)     │   │   down)     │      │ │
│ │  │   Port:3306 │   │             │   │             │      │ │
│ │  └─────────────┘   └─────────────┘   └─────────────┘      │ │
│ │         ▲                                                  │ │
│ │         │                                                  │ │
│ │  ┌─────────────┐                                          │ │
│ │  │cluster1-pxc-│  HAProxy Load Balancer                   │ │
│ │  │   haproxy-0 │  ┌─────────────────────────────────────┐ │ │
│ │  │             │  │ Endpoints:                          │ │ │
│ │  │Port: 3306   │  │ - cluster1-pxc-db-haproxy.db        │ │ │
│ │  │Port: 3307   │  │ - cluster1-pxc-db-pxc.db            │ │ │
│ │  │(admin)      │  │ - cluster1-pxc-db-pxc-unready.db    │ │ │
│ │  └─────────────┘  └─────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                   Monitoring Stack                         │ │
│ │                                                             │ │
│ │  ┌─────────────┐   ┌─────────────┐                        │ │
│ │  │mysql-       │   │mysql-       │                        │ │
│ │  │exporter     │◄──┤exporter     │                        │ │
│ │  │             │   │  service    │                        │ │
│ │  │Port: 9104   │   │Port: 9104   │                        │ │
│ │  └─────────────┘   └─────────────┘                        │ │
│ │         │                                                  │ │
│ │         ▼                                                  │ │
│ │  ┌─────────────┐                                          │ │
│ │  │ Prometheus  │                                          │ │
│ │  │  (external) │                                          │ │
│ │  └─────────────┘                                          │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                    Backup System                           │ │
│ │                                                             │ │
│ │  ┌─────────────┐                                          │ │
│ │  │CronJob:     │  ┌─────────────────────────────────────┐ │ │
│ │  │daily-backup │  │ Schedule: Daily at 2 AM             │ │ │
│ │  │             │  │ Retention: 5 backups               │ │ │
│ │  │             │  │ Storage: MinIO S3                  │ │ │
│ │  └─────────────┘  └─────────────────────────────────────┘ │ │
│ │         │                                                  │ │
│ │         ▼                                                  │ │
│ │  ┌─────────────┐   ┌─────────────┐                        │ │
│ │  │Manual       │   │PerconaXtra  │                        │ │
│ │  │Backup Job   │   │DBBackup CRD │                        │ │
│ │  │             │   │             │                        │ │
│ │  └─────────────┘   └─────────────┘                        │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Service Discovery & Networking

```
┌─────────────────────────────────────────────────────────────────┐
│                    Service Endpoints                           │
│                                                                 │
│ Application Access (from terapeas pods):                       │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ DB_HOST=cluster1-pxc-db-haproxy.db.svc.cluster.local       │ │
│ │ DB_PORT=3306                                                │ │
│ │ DB_CONNECTION=mysql (SSL disabled)                          │ │
│ │                                                             │ │
│ │ Flow:                                                       │ │
│ │ terapeas-pod → kube-dns → HAProxy Service → MySQL Node     │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ Direct Database Access (for maintenance):                      │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ cluster1-pxc-db-pxc.db.svc.cluster.local                   │ │
│ │ └─ Direct access to MySQL nodes (StatefulSet)              │ │
│ │                                                             │ │
│ │ cluster1-pxc-db-pxc-unready.db.svc.cluster.local           │ │
│ │ └─ Access to nodes not ready for traffic                   │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ Local Development Access:                                       │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ kubectl port-forward -n db svc/cluster1-pxc-db-haproxy     │ │
│ │ 3306:3306                                                   │ │
│ │                                                             │ │
│ │ Then: mysql -h localhost -P 3306 -u root -p                │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ Monitoring Access:                                              │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ mysql-exporter.db.svc.cluster.local:9104                   │ │
│ │ └─ Prometheus scrapes metrics from this endpoint           │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### Application Database Operations

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Laravel   │    │   HAProxy   │    │MySQL PXC    │    │   MinIO     │
│  terapeas   │    │Load Balancer│    │   Node      │    │  Storage    │
│             │    │             │    │             │    │             │
│     │       │    │     │       │    │     │       │    │     │       │
│     ▼       │    │     ▼       │    │     ▼       │    │     ▼       │
│             │    │             │    │             │    │             │
│ DB_HOST:    │    │Port 3306    │    │Port 3306    │    │Port 9000    │
│cluster1-pxc-│───►│             │───►│             │    │             │
│db-haproxy   │    │             │    │             │    │             │
│             │    │             │    │             │    │             │
│ SSL=false   │    │Health Check │    │Galera Sync  │    │Backup Store │
│             │◄───│             │◄───│             │◄───│             │
│             │    │             │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Backup Operations Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  CronJob    │    │ Backup Pod  │    │MySQL PXC    │    │   MinIO     │
│daily-backup │    │             │    │   Node      │    │  Storage    │
│             │    │             │    │             │    │             │
│  Daily 2AM  │    │             │    │             │    │             │
│     │       │    │     │       │    │     │       │    │     │       │
│     ▼       │    │     ▼       │    │     ▼       │    │     ▼       │
│             │    │             │    │             │    │             │
│Create Job   │───►│xtrabackup   │───►│Read Data    │    │             │
│             │    │--stream     │    │+ Binlogs    │    │Store Backup │
│             │    │             │    │             │───►│             │
│Schedule:    │    │Compress     │    │Lock Tables  │    │/backups/    │
│0 2 * * *    │    │& Stream     │    │(brief)      │    │cluster1/    │
│             │    │             │    │             │    │YYYY-MM-DD/  │
│             │    │Upload to S3 │    │             │    │             │
│Retention:   │◄───│             │◄───│             │◄───│Auto-cleanup │
│Keep 5       │    │Status Check │    │Unlock       │    │Old backups  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Monitoring Data Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│MySQL PXC    │    │MySQL        │    │ Prometheus  │    │  Grafana    │
│  Nodes      │    │ Exporter    │    │(monitoring) │    │ Dashboard   │
│             │    │             │    │             │    │             │
│Performance  │    │             │    │             │    │             │
│Metrics      │───►│Scrape       │───►│Collect &    │───►│Visualize    │
│             │    │Port 3306    │    │Store Metrics│    │& Alert      │
│             │    │             │    │             │    │             │
│- Queries/sec│    │Transform to │    │Retention:   │    │Dashboards:  │
│- Connections│    │Prometheus   │    │15 days      │    │- Overview   │
│- Replication│    │Format       │    │             │    │- Performance│
│- Disk I/O   │    │             │    │Scrape       │    │- Replication│
│- Memory     │    │Port 9104    │    │Interval:    │    │- Alerts     │
│- CPU        │    │/metrics     │    │30 seconds   │    │             │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## SSL/TLS Configuration Matrix

```
┌─────────────────────────────────────────────────────────────────┐
│                     SSL Configuration                          │
│                                                                 │
│ Component              │ SSL Status  │ Configuration           │
│ ──────────────────────┼─────────────┼────────────────────────│ │
│ MySQL PXC Cluster     │ DISABLED    │ tls.enabled: false     │ │
│ HAProxy Load Balancer │ DISABLED    │ No SSL termination     │ │
│ Laravel Application   │ DISABLED    │ DB_MYSQL_ATTR_SSL_CA:  │ │
│                       │             │ false                  │ │
│ MySQL Exporter        │ DISABLED    │ No SSL for monitoring  │ │
│ MinIO S3 API          │ ENABLED     │ HTTPS with cert-manager│ │
│ Backup Communication  │ ENABLED     │ Uses MinIO HTTPS       │ │
│                                                                 │
│ Why SSL is disabled for MySQL:                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ • Simplified internal cluster communication                │ │
│ │ • Kubernetes network policies provide security            │ │
│ │ • Performance optimization for internal traffic           │ │
│ │ • Development environment setup                           │ │
│ │                                                           │ │
│ │ For Production: Enable SSL with proper certificates      │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Resource Dependencies

```
Dependencies Flow (Creation Order):
┌─────────────┐
│  Namespace  │
│     db      │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│MinIO Secret │
│ (AWS Keys)  │
└──────┬──────┘
       │
       ▼
┌─────────────┐    ┌─────────────┐
│Percona      │    │MySQL        │
│Operator     │───►│PXC Cluster  │
│(Helm Chart) │    │(Custom Res.)│
└─────────────┘    └──────┬──────┘
                          │
                          ▼
                   ┌─────────────┐
                   │Backup       │
                   │Jobs & Cron  │
                   └──────┬──────┘
                          │
                          ▼
                   ┌─────────────┐
                   │MySQL        │
                   │Exporter     │
                   └─────────────┘

Cleanup Order (Reverse):
MySQL Exporter → Backup Jobs → PXC Cluster → Percona Operator → Secrets → Namespace
```

## Common Operations Commands

```
Daily Operations:
├─ Check cluster status:  kubectl get pxc -n db
├─ View pod status:       kubectl get pods -n db
├─ Check backup jobs:     kubectl get pxb -n db
├─ Monitor logs:          kubectl logs -f -n db cluster1-pxc-pxc-0
├─ Access database:       kubectl port-forward -n db svc/cluster1-pxc-db-haproxy 3306:3306
└─ View metrics:          kubectl port-forward -n db svc/mysql-exporter 9104:9104

Troubleshooting:
├─ Describe cluster:      kubectl describe pxc cluster1-pxc -n db
├─ Check events:          kubectl get events -n db --sort-by='.lastTimestamp'
├─ View operator logs:    kubectl logs -n db deployment/percona-xtradb-cluster-operator
├─ Test connectivity:     kubectl exec -n default [pod] -- mysql -h cluster1-pxc-db-haproxy.db -u root -p
└─ Check SSL issues:      kubectl exec -n default [pod] -- openssl s_client -connect cluster1-pxc-db-haproxy.db.svc.cluster.local:3306
```

## Network Policies (If Enabled)

```
┌─────────────────────────────────────────────────────────────────┐
│                     Network Flow Rules                         │
│                                                                 │
│ ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│ │   default   │    │     db      │    │   minio     │         │
│ │ namespace   │    │ namespace   │    │ namespace   │         │
│ │             │    │             │    │             │         │
│ │ terapeas ───┼───►│ MySQL:3306  │    │             │         │
│ │ pods        │    │ HAProxy     │    │             │         │
│ │             │    │             │    │             │         │
│ └─────────────┘    └─────────────┘    └─────────────┘         │
│                           │                   ▲               │
│                           │                   │               │
│                           ▼                   │               │
│                    ┌─────────────┐           │               │
│                    │Backup Pods  │───────────┘               │
│                    │Port: 9000   │                           │
│                    │(MinIO API)  │                           │
│                    └─────────────┘                           │
│                                                               │
│ ┌─────────────┐                                             │
│ │ monitoring  │                                             │ │
│ │ namespace   │                                             │ │
│ │             │                                             │ │
│ │ Prometheus ─┼────────────────►│ Exporter:9104             │ │
│ │             │                                             │ │
│ └─────────────┘                                             │ │
└─────────────────────────────────────────────────────────────────┘
```

This architecture provides:
- **High Availability**: Galera cluster with automatic failover
- **Backup & Recovery**: Daily automated backups with PITR capability
- **Monitoring**: Comprehensive metrics collection and visualization
- **Security**: Network isolation and configurable SSL/TLS
- **Scalability**: Easy horizontal scaling of application and database layers