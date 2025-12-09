# Terraform Infrastructure Architecture

This document provides an ASCII diagram representation of the Terraform-managed infrastructure setup.

## Infrastructure Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Azure Cloud Platform                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    azurerm_resource_group.main                              │
│                    (Resource Group Container)                                │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    azurerm_kubernetes_cluster.main                          │
│                    (AKS Cluster)                                            │
│                                                                              │
│  ┌──────────────────────────┐  ┌──────────────────────────┐              │
│  │   Default Node Pool      │  │   D4 Node Pool (opt)     │              │
│  │   (var.aks_node_count)   │  │   (var.aks_d4_node_count)│              │
│  └──────────────────────────┘  └──────────────────────────┘              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
                    ▼               ▼               ▼
        ┌──────────────────┐  ┌──────────┐  ┌──────────────┐
        │  Ingress NGINX    │  │ cert-    │  │  Let's Encrypt│
        │  (LoadBalancer)   │  │ manager  │  │  ClusterIssuer│
        │                   │  │          │  │  (optional)   │
        │  helm_release.    │  │ helm_    │  │ kubernetes_   │
        │  ingress_nginx_   │  │ release. │  │ manifest.     │
        │  repo             │  │ cert_    │  │ cluster_issuer│
        └──────────────────┘  └──────────┘  └──────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
┌───────────────┐      ┌───────────────┐
│   MinIO       │      │   Grafana     │
│   Module      │      │   Module      │
│               │      │               │
│  ┌─────────┐ │      │  ┌─────────┐ │
│  │Ingress  │ │      │  │Ingress  │ │
│  │(HTTPS)  │ │      │  │(HTTPS)  │ │
│  └─────────┘ │      │  └─────────┘ │
│  ┌─────────┐ │      │  ┌─────────┐ │
│  │Service  │ │      │  │Service  │ │
│  │(ClusterIP)│      │  │(ClusterIP)│
│  └─────────┘ │      │  └─────────┘ │
│  ┌─────────┐ │      │  ┌─────────┐ │
│  │PVC      │ │      │  │PVC      │ │
│  │Storage  │ │      │  │Storage  │ │
│  └─────────┘ │      │  └─────────┘ │
└───────────────┘      └───────┬───────┘
                               │
                    ┌──────────┴──────────┐
                    │                     │
                    ▼                     ▼
            ┌───────────────┐    ┌───────────────┐
            │    Loki       │    │  Prometheus   │
            │    Module     │    │    Module     │
            │               │    │               │
            │  ┌─────────┐ │    │  ┌─────────┐ │
            │  │Service  │ │    │  │Service  │ │
            │  │(ClusterIP)│    │  │(ClusterIP)│
            │  └─────────┘ │    │  └─────────┘ │
            │  ┌─────────┐ │    │  ┌─────────┐ │
            │  │PVC      │ │    │  │PVC      │ │
            │  │Storage  │ │    │  │Storage  │ │
            │  └─────────┘ │    │  └─────────┘ │
            └───────┬───────┘    └───────────────┘
                    │
                    │ (logs)
                    │
                    ▼
            ┌───────────────┐
            │   Promtail    │
            │    Module     │
            │               │
            │  ┌─────────┐ │
            │  │DaemonSet│ │
            │  │(collects│ │
            │  │ logs)   │ │
            │  └─────────┘ │
            └───────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         Data & Cache Layer                                   │
└─────────────────────────────────────────────────────────────────────────────┘

┌───────────────┐                    ┌───────────────┐
│   MySQL       │                    │    Redis      │
│   Module      │                    │    Module     │
│               │                    │               │
│  ┌─────────┐ │                    │  ┌─────────┐ │
│  │Percona  │ │                    │  │Standalone│ │
│  │XtraDB   │ │                    │  │or Cluster│ │
│  │Cluster  │ │                    │  └─────────┘ │
│  │(PXC)    │ │                    │  ┌─────────┐ │
│  └────┬────┘ │                    │  │Service  │ │
│       │      │                    │  │(ClusterIP)│
│       │      │                    │  └─────────┘ │
│  ┌────▼────┐ │                    │  ┌─────────┐ │
│  │HAProxy  │ │                    │  │PVC      │ │
│  │(Load    │ │                    │  │(optional)│
│  │Balancer)│ │                    │  └─────────┘ │
│  └────┬────┘ │                    └───────────────┘
│       │      │
│  ┌────▼────┐ │
│  │Service  │ │
│  │(ClusterIP)│
│  └─────────┘ │
│  ┌─────────┐ │
│  │PVC      │ │
│  │Storage  │ │
│  └─────────┘ │
│  ┌─────────┐ │
│  │Backup   │ │
│  │(to MinIO)│
│  │CronJob  │ │
│  └─────────┘ │
└───────────────┘
```

## Component Relationships

### Base Infrastructure
- **Resource Group**: Container for all Azure resources
- **AKS Cluster**: Kubernetes cluster with configurable node pools
  - Default node pool (required)
  - D4 node pool (optional, for 4 CPU nodes)

### Ingress & SSL
- **Ingress NGINX**: LoadBalancer service for external traffic routing
- **cert-manager**: Automated SSL certificate management
- **ClusterIssuer**: Let's Encrypt integration (optional)

### Storage & Object Storage
- **MinIO**: S3-compatible object storage
  - Exposed via Ingress (HTTPS)
  - Used for MySQL backups
  - Persistent storage via PVC

### Observability Stack
- **Loki**: Log aggregation system
  - Receives logs from Promtail
  - Provides data source for Grafana
  - Persistent storage via PVC

- **Promtail**: Log collection agent
  - DaemonSet that collects logs from all pods
  - Sends logs to Loki

- **Prometheus**: Metrics collection and storage
  - Collects metrics from cluster and applications
  - Provides data source for Grafana
  - Persistent storage via PVC

- **Grafana**: Visualization and dashboards
  - Exposed via Ingress (HTTPS)
  - Connects to Loki and Prometheus as data sources
  - Persistent storage for dashboards/configs

### Data Layer
- **MySQL (Percona XtraDB Cluster)**:
  - High-availability MySQL cluster
  - HAProxy for load balancing
  - Automated backups to MinIO
  - Monitoring support
  - Persistent storage via PVC

- **Redis**:
  - Standalone or cluster mode
  - Optional persistence
  - Optional authentication
  - Persistent storage via PVC (if enabled)

## Data Flow

### External Traffic Flow
```
Internet → Azure LoadBalancer → Ingress NGINX → [MinIO | Grafana]
```

### Log Flow
```
All Pods → Promtail (DaemonSet) → Loki → Grafana
```

### Metrics Flow
```
Cluster/Apps → Prometheus → Grafana
```

### Backup Flow
```
MySQL Cluster → Backup CronJob → MinIO (S3)
```

## Module Dependencies

```
AKS Cluster
    │
    ├──> Ingress NGINX
    │       │
    │       └──> cert-manager
    │               │
    │               └──> ClusterIssuer (optional)
    │
    ├──> MinIO Module ──> depends_on: [Ingress NGINX, cert-manager]
    │
    ├──> Grafana Module ──> depends_on: [Loki, Prometheus] (via datasource URLs)
    │
    ├──> Loki Module (no ingress dependency)
    │       │
    │       └──> Promtail Module ──> depends_on: [Loki]
    │
    ├──> Prometheus Module (no ingress dependency)
    │
    ├──> MySQL Module (no ingress dependency)
    │       │
    │       └──> Backups ──> MinIO
    │
    └──> Redis Module (no ingress dependency)
```

## Network Architecture

- **Network Plugin**: kubenet
- **Network Policy**: Calico
- **Service Types**:
  - LoadBalancer: Ingress NGINX (external access)
  - ClusterIP: All other services (internal only)

## Storage Architecture

All modules with persistent storage use:
- **Storage Classes**: Configurable per module
- **PVC**: Persistent Volume Claims for data persistence
- **Storage Sizes**: Configurable per module

## Security

- **RBAC**: Enabled on AKS cluster
- **Network Policies**: Calico for pod-to-pod communication control
- **SSL/TLS**: Automated via cert-manager and Let's Encrypt
- **Secrets**: Managed via Kubernetes secrets (MinIO, MySQL, Redis, Grafana)





