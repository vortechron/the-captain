# MySQL Monitoring Setup Guide

Complete monitoring solution for Percona MySQL cluster with Prometheus + Grafana integration.

## Overview

This setup provides comprehensive monitoring for your MySQL database stack using:

- **MySQL Exporter**: Collects detailed MySQL metrics
- **Prometheus**: Metrics storage and alerting
- **Grafana**: Visualization and dashboards
- **Integration**: Works with your existing Grafana + Loki observability stack

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ MySQL Cluster   │───▶│ MySQL Exporter   │───▶│ Prometheus      │
│ (Percona PXC)   │    │ :9104/metrics    │    │ :9090           │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
                                                ┌─────────────────┐
                                                │ Grafana         │
                                                │ :3000           │
                                                └─────────────────┘
```

## Components Deployed

### 1. MySQL Exporter (`mysql-exporter.yaml`)
- **Purpose**: Exports MySQL metrics to Prometheus format
- **Namespace**: `db`
- **Port**: 9104
- **Metrics**: 200+ MySQL-specific metrics including:
  - Connection statistics
  - Query performance
  - InnoDB buffer pool metrics
  - Galera cluster status
  - Replication metrics

### 2. Prometheus (`prometheus.yaml`)
- **Purpose**: Collects and stores metrics
- **Namespace**: `observability`
- **Port**: 9090
- **Retention**: 7 days
- **Targets**: 
  - MySQL Exporter
  - HAProxy stats (if available)
  - Kubernetes pods with annotations

### 3. Grafana Integration
- **Datasource**: Added Prometheus as datasource
- **Dashboard**: Custom MySQL monitoring dashboard
- **Namespace**: `observability` (existing installation)

## Quick Start

### 1. Verify Installation
```bash
# Run comprehensive status check
./monitoring-setup.sh

# Check all components
kubectl get pods -n db -l app=mysql-exporter
kubectl get pods -n observability -l app=prometheus
```

### 2. Access Grafana
```bash
# Port-forward to Grafana
kubectl port-forward -n observability svc/grafana 3000:80

# Get admin credentials
kubectl get secret grafana -n observability -o jsonpath='{.data.admin-user}' | base64 -d
kubectl get secret grafana -n observability -o jsonpath='{.data.admin-password}' | base64 -d
```

### 3. Add Prometheus Datasource
1. Open Grafana at http://localhost:3000
2. Go to Configuration → Data Sources
3. Add new Prometheus datasource:
   - **URL**: `http://prometheus.observability.svc.cluster.local:9090`
   - **Name**: `Prometheus-MySQL`

### 4. Import MySQL Dashboard
1. Go to Create → Import
2. Upload `mysql-dashboard.json`
3. Select the Prometheus-MySQL datasource

## Key Metrics Monitored

### Database Health
- `mysql_up` - Database availability (1=up, 0=down)
- `mysql_global_status_threads_connected` - Active connections
- `mysql_global_status_threads_running` - Running threads

### Performance Metrics
- `mysql_global_status_questions` - Total queries executed
- `mysql_global_status_slow_queries` - Slow queries count
- `mysql_global_status_innodb_buffer_pool_*` - Buffer pool efficiency

### Galera Cluster Metrics
- `mysql_global_status_wsrep_cluster_size` - Cluster size
- `mysql_global_status_wsrep_local_state` - Node state
- `mysql_global_status_wsrep_flow_control_*` - Flow control events

### InnoDB Metrics
- `mysql_global_status_innodb_buffer_pool_pages_total` - Total buffer pages
- `mysql_global_status_innodb_buffer_pool_pages_free` - Free buffer pages
- `mysql_global_status_innodb_buffer_pool_pages_dirty` - Dirty pages

## Dashboard Panels

The custom MySQL dashboard includes:

1. **MySQL Status** - UP/DOWN indicator
2. **Connections** - Active and running thread counts
3. **Query Rate** - Questions and queries per second
4. **InnoDB Buffer Pool** - Memory usage and efficiency
5. **Slow Queries** - Performance monitoring
6. **Table Locks** - Lock contention metrics
7. **Galera Cluster Status** - Cluster health
8. **Binary Log Position** - Replication monitoring

## Alerting Setup

### Recommended Alerts

Create these alerts in Prometheus (`alerting-rules.yaml`):

```yaml
groups:
- name: mysql-alerts
  rules:
  - alert: MySQLDown
    expr: mysql_up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "MySQL server is down"
      
  - alert: MySQLHighConnections
    expr: mysql_global_status_threads_connected > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High MySQL connection count"
      
  - alert: MySQLSlowQueries
    expr: rate(mysql_global_status_slow_queries[5m]) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High slow query rate"
```

## Troubleshooting

### Common Issues

#### 1. MySQL Exporter Not Starting
```bash
# Check logs
kubectl logs -n db -l app=mysql-exporter

# Common causes:
# - Authentication issues with MySQL user
# - Network connectivity to MySQL
# - Configuration errors
```

#### 2. No Metrics in Prometheus
```bash
# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check if MySQL exporter is reachable
kubectl port-forward -n db svc/mysql-exporter 9104:9104
curl http://localhost:9104/metrics | grep mysql_up
```

#### 3. Grafana Dashboard Issues
```bash
# Check datasource connectivity
# In Grafana: Configuration → Data Sources → Test

# Verify Prometheus service
kubectl get svc -n observability prometheus
```

### Manual Testing

```bash
# Test MySQL exporter metrics
kubectl port-forward -n db svc/mysql-exporter 9104:9104
curl http://localhost:9104/metrics | grep -E "mysql_(up|global_status)"

# Test MySQL user access
kubectl -n db exec cluster1-pxc-db-pxc-0 -c pxc -- mysql -uexporter -pexporterpassword123 -e "SHOW STATUS LIKE 'Threads_connected'"

# Check Prometheus scraping
kubectl port-forward -n observability svc/prometheus 9090:9090
curl "http://localhost:9090/api/v1/query?query=mysql_up"
```

## File Reference

### Core Files
- `mysql-exporter.yaml` - MySQL Exporter deployment
- `prometheus.yaml` - Prometheus server configuration
- `grafana-datasource.yaml` - Grafana datasource config
- `mysql-dashboard.json` - Custom Grafana dashboard

### Scripts
- `monitoring-setup.sh` - Status verification and testing
- `setup-mysql-user.sql` - MySQL monitoring user creation

### Documentation
- `MONITORING_SETUP.md` - This guide
- `README.md` - Main project documentation

## Security Considerations

### MySQL User Permissions
The monitoring user has minimal required privileges:
```sql
GRANT PROCESS ON *.* TO 'exporter'@'%';
GRANT REPLICATION CLIENT ON *.* TO 'exporter'@'%';
-- No data access permissions
```

### Network Security
- All services use ClusterIP (internal only)
- No external exposure by default
- Metrics endpoints not publicly accessible

### Credential Management
- MySQL credentials stored in Kubernetes secrets
- Prometheus config stored in ConfigMaps
- Grafana credentials managed separately

## Scaling and Production

### Resource Requirements
- **MySQL Exporter**: 50m CPU, 64Mi RAM
- **Prometheus**: 100m CPU, 256Mi RAM (can scale up)
- **Storage**: Prometheus uses 7-day retention (configurable)

### High Availability
- Deploy Prometheus with persistent storage for production
- Consider Prometheus federation for multi-cluster setups
- Use external Grafana for centralized monitoring

### Performance Tuning
- Adjust scrape intervals based on requirements
- Enable/disable specific metric collectors
- Configure Prometheus recording rules for heavy queries

## Next Steps

1. **Set up alerting** with AlertManager
2. **Configure persistent storage** for Prometheus
3. **Add more dashboards** for specific use cases
4. **Implement alert routing** to communication channels
5. **Monitor resource usage** and tune as needed

## Support

For issues or questions:
1. Check logs: `kubectl logs -n db -l app=mysql-exporter`
2. Run status check: `./monitoring-setup.sh`
3. Verify MySQL connectivity manually
4. Check Prometheus targets page