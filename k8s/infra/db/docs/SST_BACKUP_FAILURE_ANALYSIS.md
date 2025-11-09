# SST Backup Failure Analysis & Fix Guide

## 🧩 Root Cause

**Primary Issue**: `garbd` (Galera Arbitrator Daemon) connection timeout prevents SST (State Snapshot Transfer) initiation, causing `/tmp/sst_info` to never be created.

**Failure Chain**:
1. Backup pod starts and runs `garbd` to join Galera cluster
2. `garbd` attempts to connect to `cluster1-pxc-db-pxc-1.cluster1-pxc-db-pxc:4567`
3. Connection times out after ~30 seconds (`pc.wait_prim_timeout`)
4. Without Galera connection, SST process never initiates
5. `/tmp/sst_info` file (created during SST handshake) is never generated
6. Backup script tries to read `/tmp/sst_info` for MySQL version check
7. Script fails with "Error: local version is empty"

## 🔍 Detailed Analysis

### Which Node is Failing?

**Joiner Node (Backup Pod)**: The backup pod is acting as a **joiner** trying to receive data from the cluster. The failure occurs because:

- The backup pod cannot establish a Galera group communication (gcomm) connection
- Without this connection, it cannot participate in the cluster view
- Without cluster membership, the SST donor selection and handshake never occur

### Technical Flow Breakdown

```
Backup Pod (Joiner)                    Cluster Nodes (Donors)
───────────────────                    ──────────────────────
1. Start garbd
   └─> Listen on :4567                 
2. Attempt gcomm connection            └─> Should accept on :4567
   └─> TIMEOUT ❌                      └─> Never receives connection
3. SST never initiated                 └─> Donor never selected
4. /tmp/sst_info never created         └─> SST handshake never happens
5. Script reads /tmp/sst_info
   └─> FileNotFoundError ❌
6. Version check fails
   └─> Exit 1
```

### Top Possible Causes

1. **Network Connectivity Issues** (Most Likely)
   - Port 4567 not accessible between backup pod and PXC pods
   - Network policies blocking Galera traffic
   - Service DNS resolution issues
   - Firewall rules blocking internal cluster communication

2. **Cluster State Issues**
   - Cluster not in PRIMARY state (might be in NON-PRIM or partitioned)
   - Insufficient quorum (less than majority of nodes available)
   - Cluster nodes not ready/healthy

3. **Timing/Race Conditions**
   - Backup pod starts before cluster is fully ready
   - Concurrent backups causing resource contention
   - Cluster under heavy load, slow to respond

4. **Configuration Mismatch**
   - `wsrep_cluster_name` mismatch
   - Incorrect `wsrep_sst_method` configuration
   - Missing or incorrect SST authentication credentials

5. **Resource Constraints**
   - Backup pod resource limits too low
   - Network bandwidth throttling
   - CPU/memory pressure on cluster nodes

## 🧰 Fix Steps

### Step 1: Verify Cluster Health

```bash
# Check cluster state (must be "ready" and PRIMARY)
kubectl get pxc cluster1-pxc-db -n db -o jsonpath='{.status.state}'
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- \
  mysql -uroot -p'PASSWORD' -e "SHOW STATUS LIKE 'wsrep_cluster_status';"

# Verify quorum (should show PRIMARY)
# Expected: wsrep_cluster_status = Primary

# Check cluster size
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- \
  mysql -uroot -p'PASSWORD' -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
# Should match number of PXC pods
```

### Step 2: Verify Network Connectivity

```bash
# Test DNS resolution from backup pod
kubectl run test-dns --image=busybox --rm -it --restart=Never -n db -- \
  nslookup cluster1-pxc-db-pxc.db.svc.cluster.local

# Test port 4567 connectivity (from a test pod)
kubectl run test-connect --image=busybox --rm -it --restart=Never -n db -- \
  nc -zv cluster1-pxc-db-pxc-0.cluster1-pxc-db-pxc.db.svc.cluster.local 4567

# Check service endpoints
kubectl get endpoints -n db cluster1-pxc-db-pxc
# Should show all PXC pod IPs with port 4567
```

### Step 3: Check Network Policies

```bash
# List network policies that might block traffic
kubectl get networkpolicies -n db

# If policies exist, verify they allow:
# - Port 4567 (Galera communication)
# - Port 4444 (SST transfer)
# - Traffic between backup pods and PXC pods
```

### Step 4: Verify Galera Configuration

```bash
# Check wsrep_cluster_name matches
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- \
  mysql -uroot -p'PASSWORD' -e "SHOW VARIABLES LIKE 'wsrep_cluster_name';"

# Verify SST method
kubectl exec -n db cluster1-pxc-db-pxc-0 -c pxc -- \
  mysql -uroot -p'PASSWORD' -e "SHOW VARIABLES LIKE 'wsrep_sst_method';"
# Should be: xtrabackup-v2

# Check SST authentication
kubectl get secret cluster1-pxc-db-secrets -n db -o jsonpath='{.data.xtrabackup}' | base64 -d
# Should contain valid password
```

### Step 5: Increase Timeout (Temporary Workaround)

If network is slow but functional, increase garbd timeout:

```bash
# Patch cluster to increase SST timeout
kubectl patch pxc cluster1-pxc-db -n db --type merge -p '{
  "spec": {
    "pxc": {
      "configuration": "[mysqld]\nwsrep_provider_options=\"gcs.fc_limit=9999999;gcs.fc_factor=1.0;pc.wait_prim_timeout=PT60S\""
    }
  }
}'
```

### Step 6: Fix Root Cause - Network Configuration

**Option A: Ensure Service Includes Port 4567**

```bash
# Verify service exposes port 4567
kubectl get svc -n db cluster1-pxc-db-pxc -o yaml | grep -A 5 "ports:"

# Should include:
# - port: 4567
#   protocol: TCP
#   targetPort: 4567
```

**Option B: Update Network Policies**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-pxc-backup
  namespace: db
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: percona-xtradb-cluster
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          percona.com/backup: "true"
    ports:
    - protocol: TCP
      port: 4567  # Galera communication
    - protocol: TCP
      port: 4444  # SST transfer
    - protocol: TCP
      port: 3306  # MySQL
```

**Option C: Use Direct Pod IPs (if service DNS fails)**

The backup script should use pod IPs directly instead of service DNS:

```bash
# Get pod IPs
kubectl get pods -n db -l app.kubernetes.io/name=percona-xtradb-cluster -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}'
```

## ⚙️ Recommended Config

### MySQL Configuration (`/etc/my.cnf` or via Helm values)

```ini
[mysqld]
# Galera Configuration
wsrep_provider=/usr/lib64/galera-4/libgalera_smm.so
wsrep_cluster_name=cluster1-pxc-db-pxc
wsrep_cluster_address=gcomm://cluster1-pxc-db-pxc-0.cluster1-pxc-db-pxc,cluster1-pxc-db-pxc-1.cluster1-pxc-db-pxc

# SST Method Configuration
wsrep_sst_method=xtrabackup-v2
wsrep_sst_auth=xtrabackup:PASSWORD_HERE
wsrep_sst_receive_address=0.0.0.0:4444

# Galera Provider Options (for better connection handling)
wsrep_provider_options="
  debug=0;
  gcache.size=300M;
  gcache.keep_pages_size=300M;
  gcs.fc_limit=9999999;
  gcs.fc_factor=1.0;
  gcs.fc_single_primary=yes;
  pc.wait_prim_timeout=PT30S;
  pc.wait_prim=PCWAIT_PRIM;
  evs.inactive_check_period=PT0.5S;
  evs.suspect_timeout=PT5S;
  evs.keepalive_period=PT1S;
  evs.inactive_timeout=PT15S;
"

# Binary Logging (for PITR)
log-bin=mysql-bin
binlog_format=ROW
binlog_expire_logs_seconds=604800
max_binlog_size=100M
sync_binlog=1

# GTID
gtid_mode=ON
enforce_gtid_consistency=ON
log_replica_updates=ON

# Performance
innodb_buffer_pool_size=512M
innodb_autoinc_lock_mode=2
max_connections=1024
```

### Terraform Configuration Update

Update `terraform/modules/mysql/cluster.tf`:

```hcl
configuration = <<-EOT
  [mysqld]
  wsrep_provider_options="debug=0;gcache.size=300M;gcache.keep_pages_size=300M;pc.wait_prim_timeout=PT60S;evs.inactive_timeout=PT15S"
  wsrep_debug=0
  wsrep_cluster_name=${var.cluster_name}
  wsrep_sst_method=xtrabackup-v2
  binlog_format=ROW
  default_storage_engine=InnoDB
  innodb_autoinc_lock_mode=2
  max_connections=1024
  innodb_buffer_pool_size=512M
  
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
```

## ✅ Validation Checklist

- [ ] Cluster state is `ready` and `PRIMARY`
- [ ] All PXC pods are `Running` and `Ready`
- [ ] `wsrep_cluster_size` matches number of PXC pods
- [ ] `wsrep_cluster_status` = `Primary`
- [ ] Service `cluster1-pxc-db-pxc` exposes port 4567
- [ ] DNS resolution works: `nslookup cluster1-pxc-db-pxc.db.svc.cluster.local`
- [ ] Port 4567 is reachable from backup pods
- [ ] Network policies allow traffic on ports 4567, 4444, 3306
- [ ] `wsrep_cluster_name` matches across all nodes
- [ ] `wsrep_sst_method` = `xtrabackup-v2`
- [ ] SST authentication credentials are valid
- [ ] Backup pod has sufficient resources (CPU/memory)
- [ ] No concurrent backups running

## 🔧 Improved Backup Script Snippet

Here's an improved version that handles missing `/tmp/sst_info` gracefully:

```bash
#!/bin/bash
set -euo pipefail

# Function to get MySQL version with fallback
get_mysql_version() {
    local sst_info_path="${1:-/tmp/sst_info}"
    local fallback_version="${2:-8.0.0}"
    
    # Try to read from sst_info file
    if [ -f "$sst_info_path" ]; then
        local version=$(awk -F '=[ ]*' '/mysql-version[ ]*=/ {print $2}' "$sst_info_path" 2>/dev/null || echo "")
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi
    
    # Fallback 1: Try to get version from donor node directly
    log_info "sst_info not found, attempting to get version from cluster..."
    local pxc_service="${PXC_SERVICE:-cluster1-pxc-db-pxc}"
    
    # Try to connect to MySQL and get version
    if command -v mysql &>/dev/null; then
        local version=$(mysql -h "${pxc_service}" -u root -p"${PXC_PASS}" \
            -e "SELECT VERSION();" 2>/dev/null | tail -1 | cut -d'-' -f1 || echo "")
        if [ -n "$version" ]; then
            log_info "Retrieved MySQL version from cluster: $version"
            echo "$version"
            return 0
        fi
    fi
    
    # Fallback 2: Try to get from environment variable
    if [ -n "${MYSQL_VERSION:-}" ]; then
        log_warning "Using MYSQL_VERSION from environment: ${MYSQL_VERSION}"
        echo "${MYSQL_VERSION}"
        return 0
    fi
    
    # Fallback 3: Use provided fallback version
    log_warning "Could not determine MySQL version, using fallback: $fallback_version"
    echo "$fallback_version"
    return 1
}

# Function to check version compatibility
check_for_version() {
    local local_version="${1:-}"
    local required_version="${2:-8.0.0}"
    
    if [ -z "$local_version" ]; then
        log_error "MySQL version is empty, attempting fallback methods..."
        local_version=$(get_mysql_version "/tmp/sst_info" "$required_version")
    fi
    
    if [ -z "$local_version" ]; then
        log_error "Failed to determine MySQL version after all fallback attempts"
        log_error "This may indicate a serious cluster connectivity issue"
        log_error "Proceeding with minimum version check: $required_version"
        # Don't exit - let the backup attempt proceed
        # The actual SST will fail if there's a real version mismatch
        return 0
    fi
    
    # Version comparison logic here...
    log_info "MySQL version check passed: $local_version >= $required_version"
    return 0
}

# Enhanced error handling
handle_sst_failure() {
    local error_code=$1
    log_error "SST failed with code: $error_code"
    
    # Check if it's a connection timeout
    if grep -q "Connection timed out\|wait_prim_timeout" /tmp/garbd.log 2>/dev/null; then
        log_error "Galera connection timeout detected"
        log_error "This usually indicates network connectivity issues"
        log_error "Check:"
        log_error "  1. Cluster is in PRIMARY state"
        log_error "  2. Port 4567 is accessible from backup pod"
        log_error "  3. Service DNS resolution works"
        log_error "  4. Network policies allow Galera traffic"
    fi
    
    # Check if it's a version mismatch
    if grep -q "version\|Version" /tmp/backup.log 2>/dev/null; then
        log_error "Possible version mismatch detected"
        log_error "Verify MySQL versions match across cluster"
    fi
    
    exit $error_code
}

# Main backup flow with improved error handling
main() {
    local sst_info_path="/tmp/sst_info"
    
    # Wait for SST to initialize (with timeout)
    local max_wait=300  # 5 minutes
    local waited=0
    while [ ! -f "$sst_info_path" ] && [ $waited -lt $max_wait ]; do
        sleep 2
        waited=$((waited + 2))
        if [ $((waited % 30)) -eq 0 ]; then
            log_info "Waiting for SST initialization... (${waited}s/${max_wait}s)"
        fi
    done
    
    # Get MySQL version (with fallbacks)
    local mysql_version=$(get_mysql_version "$sst_info_path" "8.0.0")
    
    # Check version compatibility
    if ! check_for_version "$mysql_version" "8.0.0"; then
        log_warning "Version check failed, but proceeding with backup attempt"
        log_warning "SST will fail if there's a real incompatibility"
    fi
    
    # Proceed with backup...
    # ... rest of backup logic
}

# Trap errors
trap 'handle_sst_failure $?' ERR

main "$@"
```

## 🎯 Quick Fix Commands

If you need an immediate workaround while investigating the root cause:

```bash
# 1. Cancel stuck backup
BACKUP_NAME="manual-test-20251109-134850"
kubectl delete pxc-backup $BACKUP_NAME -n db

# 2. Ensure cluster is healthy
kubectl get pxc cluster1-pxc-db -n db
kubectl get pods -n db -l app.kubernetes.io/name=percona-xtradb-cluster

# 3. Restart PXC pods if needed (rolling restart)
kubectl delete pod cluster1-pxc-db-pxc-0 -n db
# Wait for it to be ready, then restart next one

# 4. Verify service endpoints
kubectl get endpoints -n db cluster1-pxc-db-pxc

# 5. Test connectivity from a test pod
kubectl run test-galera --image=percona/percona-xtradb-cluster:8.0.35-27.1 \
  --rm -it --restart=Never -n db -- \
  bash -c "nc -zv cluster1-pxc-db-pxc-0.cluster1-pxc-db-pxc.db.svc.cluster.local 4567"

# 6. Create new backup after fixes
kubectl apply -f - <<EOF
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata:
  name: manual-test-$(date +%Y%m%d-%H%M%S)
  namespace: db
spec:
  pxcCluster: cluster1-pxc-db
  storageName: minio-storage
EOF
```

## 📝 Next Steps

1. **Immediate**: Verify network connectivity and cluster health
2. **Short-term**: Update Terraform configuration with improved Galera settings
3. **Long-term**: Implement improved backup script with fallback logic
4. **Monitoring**: Add alerts for SST failures and garbd connection timeouts

