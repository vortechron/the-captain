# MySQL Percona PXC DevOps Cheatsheet

Complete command reference for managing Percona XtraDB Cluster (PXC) on Kubernetes.

## 📋 Quick Reference

```bash
# Cluster Info
NAMESPACE="db"
CLUSTER="cluster1"
OPERATOR="pxc-operator"
```

## 🔍 Status & Monitoring

### Cluster Health
```bash
# Check cluster status
kubectl get pxc -n db
kubectl get pxc cluster1-pxc -n db -o wide

# Detailed cluster info
kubectl describe pxc cluster1-pxc -n db

# Check all pods
kubectl get pods -n db
kubectl get pods -n db -l app.kubernetes.io/name=percona-xtradb-cluster

# Pod details
kubectl describe pod cluster1-pxc-pxc-0 -n db
```

### Service & Network Status
```bash
# Check services
kubectl get svc -n db

# Check endpoints
kubectl get endpoints -n db

# Test connectivity
kubectl run mysql-test --image=mysql:8.0 --rm -it --restart=Never -- \
  mysql -hcluster1-pxc-db-haproxy.db.svc.cluster.local -uroot -p'PASSWORD'
```

### Resource Usage
```bash
# Check resource usage
kubectl top pods -n db
kubectl top nodes

# Check storage
kubectl get pvc -n db
kubectl describe pvc datadir-cluster1-pxc-db-pxc-0 -n db

# Storage usage
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- df -h /var/lib/mysql
```

## 🔄 Restart & Recovery

### Restart Pods
```bash
# Restart MySQL pod (rolling restart)
kubectl delete pod cluster1-pxc-db-pxc-0 -n db

# Restart HAProxy pod
kubectl delete pod cluster1-pxc-db-haproxy-0 -n db

# Restart operator
kubectl rollout restart deployment pxc-operator -n db

# Force restart all cluster pods
kubectl delete pods -l app.kubernetes.io/name=percona-xtradb-cluster -n db
```

### Cluster Recovery
```bash
# Check cluster state
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'PASSWORD' \
  -e "SHOW STATUS LIKE 'wsrep_%';"

# Force cluster bootstrap (if all nodes are down)
kubectl patch pxc cluster1-pxc-db -n db --type='merge' -p='{"spec":{"pxc":{"autoRecovery":false}}}'

# Manual bootstrap (dangerous - use only when cluster is completely down)
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- \
  /var/lib/mysql/unsafe-bootstrap.sh
```

## 🔐 Password & User Management

### Get Current Passwords
```bash
# Root password
kubectl get secret cluster1-pxc-db-secrets -n db -o jsonpath='{.data.root}' | base64 -d

# All passwords
kubectl get secret cluster1-pxc-db-secrets -n db -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'
```

### Change Root Password
```bash
# Method 1: Update secret and restart
NEW_PASSWORD="newrootpass123"
kubectl patch secret cluster1-pxc-db-secrets -n db -p="{\"data\":{\"root\":\"$(echo -n $NEW_PASSWORD | base64)\"}}"
kubectl delete pod cluster1-pxc-db-pxc-0 -n db

# Method 2: Direct MySQL command
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'OLD_PASSWORD' \
  -e "ALTER USER 'root'@'%' IDENTIFIED BY 'newrootpass123'; FLUSH PRIVILEGES;"
```

### Create New Users
```bash
# Create application user
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'PASSWORD' << 'EOF'
CREATE USER 'appuser'@'%' IDENTIFIED BY 'apppassword';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.* TO 'appuser'@'%';
FLUSH PRIVILEGES;
EOF

# Create read-only user
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'PASSWORD' << 'EOF'
CREATE USER 'readonly'@'%' IDENTIFIED BY 'readpass';
GRANT SELECT ON *.* TO 'readonly'@'%';
FLUSH PRIVILEGES;
EOF
```

## 💾 Backup & Restore

### Prerequisites - Enable Backup Configuration
```bash
# First, ensure backup is enabled on the cluster
kubectl patch pxc cluster1-pxc-db -n db --type='merge' -p='{"spec":{"backup":{"image":"percona/percona-xtrabackup:8.0.35-33.1","storages":{"minio-storage":{"type":"s3","s3":{"bucket":"db-backup","region":"us-east-1","endpointUrl":"https://minio.terapeas.com","credentialsSecret":"minio-backup-secret"}}}}}}'

# Ensure MinIO secret has correct AWS-style keys
kubectl patch secret minio-backup-secret -n db -p='{"data":{"AWS_ACCESS_KEY_ID":"bWluaW9hZG1pbg==","AWS_SECRET_ACCESS_KEY":"TXBmdDBxQkFFWDJ5SUZYQ3FlL0V6NWtBWFo4OWNhYkxFekk5MGpNdENSZz0="}}'
```

### Manual Backup
```bash
# Method 1: Using YAML file (recommended)
cat > manual-backup.yaml << EOF
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata:
  name: manual-backup-$(date +%Y%m%d-%H%M%S)
  namespace: db
spec:
  pxcCluster: cluster1-pxc-db
  storageName: minio-storage
EOF

kubectl apply -f manual-backup.yaml

# Method 2: Direct kubectl apply
kubectl apply -f - << EOF
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata:
  name: manual-backup-test
  namespace: db
spec:
  pxcCluster: cluster1-pxc-db
  storageName: minio-storage
EOF

# Check backup status
kubectl get pxc-backups -n db

# Watch backup progress
kubectl get pxc-backups -n db -w

# Check backup details
kubectl describe pxc-backup manual-backup-test -n db

# Check backup pod logs (while running)
kubectl logs -f $(kubectl get pods -n db -l percona.com/backup-name=manual-backup-test -o name) -n db

# Verify backup in MinIO
# Destination: s3://db-backup/cluster1-pxc-db-YYYY-MM-DD-HH:MM:SS-full/
```

### Backup Troubleshooting
```bash
# Check backup pod status
kubectl get pods -n db | grep backup

# Check backup pod logs for errors
kubectl logs $(kubectl get pods -n db -l job-name -o name | grep backup) -n db

# Common issues and fixes:
# 1. Secret key error - ensure AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY exist
kubectl get secret minio-backup-secret -n db -o yaml

# 2. Backup pod stuck - delete and let it recreate
kubectl delete pod $(kubectl get pods -n db -l job-name -o name | grep backup) -n db

# 3. Check backup storage configuration
kubectl get pxc cluster1-pxc-db -n db -o jsonpath='{.spec.backup}' | jq .
```

### Restore from Backup
```bash
# List available backups
kubectl get pxc-backups -n db

# Restore from backup
kubectl apply -f - << 'EOF'
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterRestore
metadata:
  name: restore-$(date +%Y%m%d-%H%M%S)
  namespace: db
spec:
  pxcCluster: cluster1-pxc-db
  backupName: BACKUP_NAME_HERE
EOF

# Point-in-time restore
kubectl apply -f - << 'EOF'
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterRestore
metadata:
  name: pitr-restore-$(date +%Y%m%d-%H%M%S)
  namespace: db
spec:
  pxcCluster: cluster1-pxc-db
  backupName: BACKUP_NAME_HERE
  pitr:
    type: date
    date: "2024-01-01T10:30:00Z"
EOF
```

### Backup Management
```bash
# List all backups with status
kubectl get pxc-backups -n db -o wide

# Check backup schedules (if configured)
kubectl get pxc-backup-schedules -n db

# Clean up old backups
kubectl delete pxc-backup BACKUP_NAME -n db

# Delete backup data from MinIO (manual)
# Use MinIO console or aws cli to remove s3://db-backup/BACKUP_FOLDER/

# Quick backup verification
BACKUP_NAME="manual-backup-test"
kubectl get pxc-backup $BACKUP_NAME -n db -o jsonpath='{.status.state}'

# Get backup destination path
kubectl get pxc-backup $BACKUP_NAME -n db -o jsonpath='{.status.destination}'

# Example successful backup verification
# Status should be: "Succeeded"
# Destination should be: "s3://db-backup/cluster1-pxc-db-YYYY-MM-DD-HH:MM:SS-full"

# Monitor ongoing backup
kubectl describe pxc-backup $BACKUP_NAME -n db
kubectl logs -f $(kubectl get pods -n db -l percona.com/backup-name=$BACKUP_NAME -o name) -n db
```

## ⚙️ Configuration Management

### Update Cluster Configuration
```bash
# Scale cluster (add/remove nodes)
kubectl patch pxc cluster1-pxc-db -n db --type='merge' -p='{"spec":{"pxc":{"size":3}}}'

# Update resource limits
kubectl patch pxc cluster1-pxc-db -n db --type='merge' -p='{"spec":{"pxc":{"resources":{"limits":{"memory":"2Gi","cpu":"1000m"}}}}}'

# Enable/disable HAProxy
kubectl patch pxc cluster1-pxc-db -n db --type='merge' -p='{"spec":{"haproxy":{"enabled":true,"size":2}}}'

# Update MySQL configuration
kubectl edit pxc cluster1-pxc-db -n db
# Edit the spec.pxc.configuration section
```

### Storage Management
```bash
# Check storage usage
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- df -h /var/lib/mysql

# Expand PVC (if storage class supports it)
kubectl patch pvc datadir-cluster1-pxc-db-pxc-0 -n db -p='{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Check PVC expansion status
kubectl describe pvc datadir-cluster1-pxc-db-pxc-0 -n db
```

## 🔧 Helm Operations

### Upgrade Cluster
```bash
# Upgrade with new values
helm upgrade cluster1 percona/pxc-db -n db --values cluster1-values-minimal.yaml

# Upgrade to new chart version
helm repo update
helm upgrade cluster1 percona/pxc-db -n db --values cluster1-values-minimal.yaml

# Check upgrade status
helm status cluster1 -n db
helm history cluster1 -n db
```

### Rollback Changes
```bash
# See release history
helm history cluster1 -n db

# Rollback to previous version
helm rollback cluster1 -n db

# Rollback to specific revision
helm rollback cluster1 2 -n db
```

## 📊 Monitoring Commands

### MySQL Metrics
```bash
# Check MySQL status
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'PASSWORD' \
  -e "SHOW STATUS;"

# Check connections
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'PASSWORD' \
  -e "SHOW PROCESSLIST;"

# Check slow queries
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'PASSWORD' \
  -e "SHOW STATUS LIKE 'Slow_queries';"

# Check Galera status
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'PASSWORD' \
  -e "SHOW STATUS LIKE 'wsrep_%';"
```

### Log Analysis
```bash
# Check MySQL logs
kubectl logs -n db cluster1-pxc-db-pxc-0 -c pxc --tail=100

# Check operator logs
kubectl logs -n db deployment/pxc-operator --tail=100

# Check HAProxy logs
kubectl logs -n db cluster1-pxc-db-haproxy-0 -c haproxy --tail=100

# Follow logs in real-time
kubectl logs -n db cluster1-pxc-db-pxc-0 -c pxc -f
```

### Performance Monitoring
```bash
# Check MySQL exporter metrics
kubectl port-forward -n db svc/mysql-exporter 9104:9104 &
curl http://localhost:9104/metrics | grep mysql_up

# Check HAProxy stats
kubectl port-forward -n db svc/cluster1-pxc-db-haproxy 8404:8404 &
curl http://localhost:8404/stats
```

## 🚨 Troubleshooting

### Common Issues

#### Cluster Not Starting
```bash
# Check operator logs
kubectl logs -n db deployment/pxc-operator

# Check pod events
kubectl describe pod cluster1-pxc-db-pxc-0 -n db

# Check PVC issues
kubectl describe pvc datadir-cluster1-pxc-db-pxc-0 -n db

# Check node resources
kubectl describe node NODE_NAME
```

#### Connection Issues
```bash
# Test internal connectivity
kubectl run debug --image=busybox --rm -it --restart=Never -- \
  nslookup cluster1-pxc-db-haproxy.db.svc.cluster.local

# Check service endpoints
kubectl get endpoints cluster1-pxc-db-haproxy -n db

# Test MySQL connection
kubectl run mysql-debug --image=mysql:8.0 --rm -it --restart=Never -- \
  mysql -hcluster1-pxc-db-haproxy.db.svc.cluster.local -uroot -p'PASSWORD' -e "SELECT 1"
```

#### Performance Issues
```bash
# Check slow queries
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'PASSWORD' \
  -e "SELECT * FROM performance_schema.events_statements_summary_by_digest ORDER BY avg_timer_wait DESC LIMIT 10;"

# Check InnoDB status
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'PASSWORD' \
  -e "SHOW ENGINE INNODB STATUS\G"

# Check table locks
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'PASSWORD' \
  -e "SHOW STATUS LIKE 'Table_locks%';"
```

## 🔒 Security Operations

### SSL/TLS Management
```bash
# Check TLS status
kubectl get secret cluster1-pxc-db-ssl -n db

# View certificate details
kubectl get secret cluster1-pxc-db-ssl -n db -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Update certificates (if using custom certs)
kubectl patch secret cluster1-pxc-db-ssl -n db --patch='{"data":{"tls.crt":"BASE64_CERT","tls.key":"BASE64_KEY"}}'
```

### Network Policies
```bash
# Create network policy to restrict access
kubectl apply -f - << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: mysql-network-policy
  namespace: db
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: percona-xtradb-cluster
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: allowed-namespace
    ports:
    - protocol: TCP
      port: 3306
EOF
```

## 🧹 Cleanup Operations

### Remove Cluster (Keep Data)
```bash
# Uninstall Helm release
helm uninstall cluster1 -n db

# Keep PVCs for data preservation
# Data remains in PVCs for potential recovery
```

### Complete Cleanup (DELETE ALL DATA)
```bash
# WARNING: This deletes all data permanently!

# Uninstall cluster
helm uninstall cluster1 -n db

# Delete PVCs (THIS DELETES ALL DATA!)
kubectl delete pvc --all -n db

# Delete secrets
kubectl delete secret --all -n db

# Remove operator
helm uninstall pxc-operator -n db
```

### Selective Cleanup
```bash
# Remove only monitoring
kubectl delete deployment mysql-exporter -n db
kubectl delete service mysql-exporter -n db
kubectl delete configmap mysql-exporter-config -n db
kubectl delete secret mysql-exporter-secret -n db

# Remove only Prometheus
kubectl delete deployment prometheus -n observability
kubectl delete service prometheus -n observability
kubectl delete configmap prometheus-config -n observability
```

## 📚 Useful Queries

### Database Administration
```sql
-- Show all databases
SHOW DATABASES;

-- Show database size
SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables 
GROUP BY table_schema;

-- Show table sizes
SELECT 
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
FROM information_schema.TABLES 
WHERE table_schema = 'DATABASE_NAME'
ORDER BY (data_length + index_length) DESC;

-- Show current connections
SELECT USER, HOST, DB, COMMAND, TIME, STATE, INFO 
FROM information_schema.PROCESSLIST 
WHERE COMMAND != 'Sleep';

-- Show Galera cluster status
SHOW STATUS LIKE 'wsrep_%';
```

## 🚀 Quick Actions

### Emergency Procedures
```bash
# 1. Cluster completely down - force bootstrap
kubectl patch pxc cluster1-pxc-db -n db --type='merge' -p='{"spec":{"pxc":{"autoRecovery":false}}}'
kubectl delete pod cluster1-pxc-db-pxc-0 -n db
# Wait for pod to start, then re-enable autoRecovery

# 2. Out of disk space
kubectl patch pvc datadir-cluster1-pxc-db-pxc-0 -n db -p='{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# 3. Memory issues
kubectl patch pxc cluster1-pxc-db -n db --type='merge' -p='{"spec":{"pxc":{"resources":{"limits":{"memory":"4Gi"}}}}}'

# 4. Connection limit reached
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'PASSWORD' \
  -e "SET GLOBAL max_connections = 500;"
```

### Daily Maintenance
```bash
# Check cluster health
kubectl get pxc -n db && kubectl get pods -n db

# Monitor resource usage
kubectl top pods -n db

# Check backup status
kubectl get pxc-backups -n db | head -5

# Review slow queries
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p'PASSWORD' \
  -e "SHOW STATUS LIKE 'Slow_queries';"
```

---

💡 **Pro Tips:**
- Always test changes in non-production first
- Keep regular backups before major operations
- Monitor resource usage during scaling operations
- Use `kubectl describe` for detailed troubleshooting
- Keep this cheatsheet handy for quick reference