# Percona MySQL Deployment Log & Learning Guide

This document chronicles the complete deployment process, troubleshooting steps, and commands used to deploy Percona Operator for MySQL (PXC) on Kubernetes.

## Initial Assessment & Planning

### 1. Cluster Analysis
```bash
# Check cluster nodes and resources
kubectl get nodes -o wide
kubectl get storageclass
kubectl top nodes

# Results:
# - 2-node DigitalOcean cluster (pool-5fgjpitv7-2kzqn, pool-ka650xe32-l4ue0)
# - DigitalOcean Block Storage available
# - ~7-10% CPU usage, 40-70% memory utilization
# - Sufficient resources for MySQL deployment
```

### 2. Existing Infrastructure Review
```bash
# Check existing MinIO setup
ls /Users/amiruladli/Projects/the-captain/k8s/infra/minio/
cat /Users/amiruladli/Projects/the-captain/k8s/infra/minio/secret.yaml

# Results:
# - MinIO already deployed at https://minio.terapeas.com
# - Credentials available: minioadmin / Mpft0qBAEX2yIFXCqe/Ez5kAXZ89cabLEzI90jMtCRg=
# - Target bucket: db-backup
```

## Initial Setup

### 3. Directory Structure Creation
```bash
# Create namespace and directory
mkdir -p /Users/amiruladli/Projects/the-captain/k8s/infra/db

# Create namespace manifest
cat > namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: db
  labels:
    name: db
EOF

# Create MinIO secret for backups
cat > minio-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: minio-backup-secret
  namespace: db
type: Opaque
data:
  ACCESS_KEY_ID: bWluaW9hZG1pbg==  # minioadmin (base64)
  SECRET_ACCESS_KEY: TXBmdDBxQkFFWDJ5SUZYQ3FlL0V6NWtBWFo4OWNhYkxFekk5MGpNdENSZz0=  # (base64)
EOF
```

### 4. Helm Repository Setup
```bash
# Add Percona Helm repository
helm repo add percona https://percona.github.io/percona-helm-charts/
helm repo update

# Check available charts
helm search repo percona
```

## First Deployment Attempt (Failed)

### 5. Initial Operator Installation
```bash
# Install operator (successful)
helm upgrade --install pxc-operator percona/pxc-operator \
  --namespace db \
  --values pxc-operator-values.yaml \
  --wait \
  --timeout 300s

# Verify operator
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=pxc-operator -n db --timeout=300s
```

### 6. Complex Cluster Configuration (Failed)
```bash
# First attempt with full configuration
helm upgrade --install cluster1 percona/pxc-db \
  --namespace db \
  --values cluster1-values.yaml \
  --wait \
  --timeout 600s

# Error: Helm values format issues
# - Image configuration format incorrect
# - Secrets template errors
```

## Troubleshooting Phase

### 7. Values File Format Issues
**Problem**: Helm template errors with image configuration
```yaml
# Wrong format:
pxc:
  image: percona/percona-xtradb-cluster:8.0.35-27.1

# Correct format:
pxc:
  image:
    repository: percona/percona-xtradb-cluster
    tag: 8.0.35-27.1
```

**Solution**: Updated image configurations across all components

### 8. TLS Safety Check Issues
**Problem**: 
```bash
kubectl describe pxc cluster1-pxc-db -n db
# Error: check safe defaults: TLS must be enabled. Set spec.unsafeFlags.tls to true
```

**Solution**: Added unsafe flags to disable TLS requirement
```yaml
unsafeFlags:
  tls: true
```

### 9. MySQL Container CrashLoopBackOff
**Problem**: MySQL pods crashing repeatedly
```bash
kubectl logs cluster1-pxc-db-pxc-0 -c pxc -n db --tail=50
kubectl describe pod cluster1-pxc-db-pxc-0 -n db

# Observations:
# - MySQL initialization process failing
# - Complex configuration causing issues
# - Resource constraints possible
```

**Solution**: Simplified to minimal configuration approach

## Minimal Configuration Success

### 10. Simplified Approach
Created minimal configuration file (`cluster1-values-minimal.yaml`):
```yaml
# Key changes:
# - Single node deployment (size: 1)
# - Reduced resource requirements
# - Disabled backups initially
# - Added all necessary unsafe flags
```

### 11. Safety Check Iterations
**First issue**: PXC size safety check
```bash
# Error: check safe defaults: PXC size must be at least 3
# Solution: Added unsafeFlags.pxcSize: true
```

**Second issue**: HAProxy size safety check
```bash
# Error: check safe defaults: HAProxy size must be at least 2
# Solution: Added unsafeFlags.proxySize: true
```

### 12. Final Working Configuration
```yaml
unsafeFlags:
  tls: true        # Disable TLS requirement
  pxcSize: true    # Allow single MySQL node
  proxySize: true  # Allow single HAProxy node
```

## Successful Deployment

### 13. Clean Installation
```bash
# Remove previous failed attempts
helm uninstall cluster1 -n db
kubectl delete pvc --all -n db
kubectl delete pxc --all -n db

# Fresh installation with minimal config
helm install cluster1 percona/pxc-db \
  --namespace db \
  --values cluster1-values-minimal.yaml \
  --wait \
  --timeout 600s
```

### 14. Monitoring Deployment
```bash
# Watch cluster initialization
kubectl get pxc -n db
kubectl get pods -n db

# Status progression:
# 1. error (safety checks)
# 2. initializing (pods starting)
# 3. ready (cluster operational)
```

### 15. Connection Testing
```bash
# Retrieve root password
ROOT_PASSWORD=$(kubectl -n db get secrets cluster1-pxc-db-secrets -o jsonpath="{.data.root}" | base64 --decode)

# Test MySQL connection
kubectl -n db exec cluster1-pxc-db-pxc-0 -c pxc -- mysql -uroot -p"$ROOT_PASSWORD" -e "SELECT 'MySQL connection successful!' as status, @@version as version;"

# Result: MySQL 8.0.42-33.1 running successfully
```

## Key Learning Points

### Configuration Complexity
1. **Start Simple**: Begin with minimal configuration, add complexity gradually
2. **Safety Checks**: Percona Operator has strict production defaults
3. **Unsafe Flags**: Required for non-production deployments
4. **Resource Requirements**: Even minimal setup needs adequate resources

### Troubleshooting Methodology
1. **Check Events**: `kubectl describe` for detailed error messages
2. **Review Logs**: Container logs reveal initialization issues
3. **Iterative Approach**: Fix one error at a time
4. **Clean State**: Remove failed deployments completely before retry

### Production Considerations
```bash
# For production deployment:
# 1. Enable TLS (remove unsafeFlags.tls)
# 2. Use 3+ MySQL nodes (remove unsafeFlags.pxcSize)
# 3. Use 2+ HAProxy nodes (remove unsafeFlags.proxySize)
# 4. Configure proper resource limits
# 5. Enable backups with MinIO
# 6. Set up monitoring
```

## Final Architecture

### Deployed Components
- **Namespace**: `db`
- **Operator**: 1 pod managing PXC clusters
- **MySQL**: 1 pod (Percona XtraDB Cluster 8.0.42)
- **HAProxy**: 1 pod for load balancing
- **Storage**: 8Gi DigitalOcean Block Storage per MySQL pod

### Service Endpoints
```bash
# Internal cluster access
cluster1-pxc-db-haproxy.db.svc.cluster.local:3306

# Port forward for external access
kubectl port-forward svc/cluster1-pxc-db-haproxy 3306:3306 -n db
```

### Status Verification
```bash
# Use custom status script
./status.sh

# Manual checks
kubectl get pxc -n db
kubectl get pods -n db
kubectl get svc -n db
kubectl get pvc -n db
```

## Next Steps for Production

### 1. Scale to Production Configuration
```bash
# Update cluster1-values-simple.yaml for production:
# - Set pxc.size: 3
# - Set haproxy.size: 2  
# - Remove unsafe flags
# - Enable TLS
# - Configure proper resource limits
```

### 2. Enable MinIO Backups
```bash
# Use cluster1-values-simple.yaml with:
# - Daily backups at 02:00 UTC
# - PITR with 60-second binlog uploads
# - MinIO S3-compatible storage
```

### 3. Monitoring Setup
```bash
# Consider enabling:
# - PMM (Percona Monitoring and Management)
# - Custom monitoring with Prometheus/Grafana
# - Log aggregation
```

## Files Generated

### Core Configuration
- `cluster1-values-minimal.yaml` - Working minimal deployment
- `cluster1-values-simple.yaml` - Full production ready config with backups
- `pxc-operator-values.yaml` - Operator configuration

### Infrastructure
- `namespace.yaml` - Kubernetes namespace
- `minio-secret.yaml` - MinIO credentials

### Scripts
- `install.sh` - Automated installation
- `uninstall.sh` - Clean removal
- `status.sh` - Status checking and connection info

### Documentation
- `README.md` - Main documentation
- `DEPLOYMENT_LOG.md` - This troubleshooting guide

## Commands Reference

### Basic Operations
```bash
# Get cluster status
kubectl get pxc -n db

# Check pods
kubectl get pods -n db

# Get root password
kubectl get secret cluster1-pxc-db-secrets -n db -o jsonpath='{.data.root}' | base64 -d

# Connect to MySQL
kubectl port-forward svc/cluster1-pxc-db-haproxy 3306:3306 -n db
mysql -h 127.0.0.1 -P 3306 -u root -p

# Check logs
kubectl logs cluster1-pxc-db-pxc-0 -c pxc -n db
```

### Helm Operations
```bash
# Install operator
helm upgrade --install pxc-operator percona/pxc-operator --namespace db --values pxc-operator-values.yaml

# Install cluster
helm upgrade --install cluster1 percona/pxc-db --namespace db --values cluster1-values-minimal.yaml

# Upgrade cluster
helm upgrade cluster1 percona/pxc-db --namespace db --values cluster1-values-simple.yaml

# Uninstall
helm uninstall cluster1 -n db
helm uninstall pxc-operator -n db
```

### Troubleshooting
```bash
# Describe cluster for errors
kubectl describe pxc cluster1-pxc-db -n db

# Check operator logs
kubectl logs deployment/pxc-operator -n db

# Check pod events
kubectl describe pod <pod-name> -n db

# Clean restart
helm uninstall cluster1 -n db
kubectl delete pvc --all -n db
kubectl delete pxc --all -n db
```

This deployment taught us the importance of understanding operator safety checks, proper Helm values formatting, and the value of incremental complexity when troubleshooting Kubernetes deployments.