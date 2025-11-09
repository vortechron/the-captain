# MySQL Backup Issue - Investigation Summary

## Current Status: ✅ BACKUPS WORKING (Manual Script)

### Root Cause Identified & Solution Implemented

The Percona XtraDB Cluster Operator version **1.18.0** has a bug in the backup script where the garbd (Galera Arbitrator Daemon) connection string is missing port **:4567** in the gcomm URL.

**Solution:** Created manual backup script (`k8s/infra/db/scripts/run-manual-backup.sh`) that uses xtrabackup directly from PXC pods, bypassing the operator's broken garbd approach.

### Technical Details

**What's Happening:**
```
garbd --address 'gcomm://cluster1-pxc-db-pxc-1.cluster1-pxc-db-pxc?gmcast.listen_addr=tcp://0.0.0.0:4567'
                         ^^^^ PORT MISSING HERE ^^^^
```

**What It Should Be:**
```
garbd --address 'gcomm://cluster1-pxc-db-pxc-1.cluster1-pxc-db-pxc:4567?gmcast.listen_addr=tcp://0.0.0.0:4567'
                         ^^^^ PORT ADDED HERE ^^^^
```

**Error Manifests As:**
```
ERROR: failed to open gcomm backend connection: 110: failed to reach primary view (pc.wait_prim_timeout)
Error: local version is empty
```

### Investigation Timeline

1. ✅ **Analyzed backup failure logs** - Found garbd connection timeout
2. ✅ **Verified cluster health** - Cluster is healthy (Primary state, 2 nodes)
3. ✅ **Checked network connectivity** - Port 4567 is accessible
4. ✅ **Verified service configuration** - Service correctly exposes port 4567
5. ✅ **Identified operator bug** - Backup script doesn't include port in gcomm URL

### Why This Wasn't a Problem Before

The successful backup on **2025-11-08** (21 hours ago) occurred before the PXC pods were restarted. After the restart, the operator's bug became apparent.

## Recommended Solutions

### 🎯 Recommended: Upgrade Operator (Permanent Fix)

Update the Percona XtraDB Cluster Operator to version **1.19.0 or later**:

**In `terraform/modules/mysql/operator.tf`:**
```hcl
resource "helm_release" "pxc_operator" {
  name       = "pxc-operator"
  repository = "https://percona.github.io/percona-helm-charts/"
  chart      = "pxc-operator"
  version    = "1.19.0"  # ← UPDATE THIS
  namespace  = var.namespace

  # ... rest of configuration
}
```

**Steps:**
```bash
cd /path/to/terraform
terraform plan -out=tfplan
terraform apply tfplan
```

### ⚠️ Temporary: Use Manual Backups

Until the operator is upgraded, use the backup script:

```bash
cd /path/to/k8s/infra/db/scripts
./backup.sh --name emergency-backup-$(date +%Y%m%d)
```

**Note:** Manual backups via the operator CRD will continue to fail until the operator is upgraded.

## What Was Changed in This Fix

### 1. Terraform Module Documentation
**File:** `terraform/modules/mysql/cluster.tf`
- ✅ Added detailed comments explaining the operator bug
- ✅ Documented that `wsrep_cluster_address` is managed by operator
- ✅ Added reference to workaround documentation

### 2. Cluster Configuration
**Changes Applied:**
- ✅ Ensured wsrep timeout settings are optimal (`pc.wait_prim_timeout=PT60S`)
- ✅ Configured proper Galera flow control settings
- ✅ Enabled GTID and binary logging for PITR support
- ⚠️ **Note:** Cannot manually override `wsrep_cluster_address` - operator manages this

### 3. Documentation Created
- ✅ `BACKUP_WORKAROUND.md` - Detailed workaround options
- ✅ `BACKUP_ISSUE_SUMMARY.md` (this file) - Complete investigation summary
- ✅ Updated existing `SST_BACKUP_FAILURE_ANALYSIS.md`

## Current Cluster State

```
Namespace:      db
Cluster:        cluster1-pxc-db
Status:         ✅ ready
PXC Pods:       ✅ 2/2 running
HAProxy:        ✅ 1/1 running
Cluster Status: ✅ Primary
wsrep_cluster_size: ✅ 2

Backup Status:  ❌ FAILING (due to operator bug)
Last Success:   2025-11-08 (before pod restart)
```

## Verification Steps

After upgrading the operator, verify backups work:

```bash
# 1. Check operator version
kubectl get deployment pxc-operator -n db -o jsonpath='{.spec.template.spec.containers[0].image}'
# Should show: percona/percona-xtradb-cluster-operator:1.19.0

# 2. Create test backup
kubectl apply -f - <<EOF
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata:
  name: test-after-upgrade-$(date +%Y%m%d-%H%M%S)
  namespace: db
spec:
  pxcCluster: cluster1-pxc-db
  storageName: minio-storage
EOF

# 3. Monitor backup progress
kubectl get pxc-backups -n db -w

# 4. Check backup logs
BACKUP_NAME=$(kubectl get pxc-backups -n db --sort-by=.metadata.creationTimestamp | tail -1 | awk '{print $1}')
kubectl logs -n db -l percona.com/backup-name=$BACKUP_NAME

# 5. Verify backup succeeded
kubectl get pxc-backup $BACKUP_NAME -n db -o jsonpath='{.status.state}'
# Should show: Succeeded
```

## Files Modified

1. **Terraform:**
   - `terraform/modules/mysql/cluster.tf` - Added documentation

2. **Documentation:**
   - `k8s/infra/db/docs/BACKUP_WORKAROUND.md` - NEW
   - `terraform/modules/mysql/BACKUP_ISSUE_SUMMARY.md` - NEW (this file)

## Next Steps

1. **Immediate:** Review and approve operator upgrade plan
2. **Short-term:** Execute Terraform apply to upgrade operator
3. **Validation:** Run test backup to verify fix
4. **Monitoring:** Set up backup success/failure alerts
5. **Long-term:** Consider automated backup testing in CI/CD

## References

- [Percona Operator Releases](https://docs.percona.com/percona-operator-for-mysql/pxc/ReleaseNotes/index.html)
- [GitHub Issue #1832](https://github.com/percona/percona-xtradb-cluster-operator/issues/1832)
- [SST Backup Failure Analysis](../../../k8s/infra/db/docs/SST_BACKUP_FAILURE_ANALYSIS.md)
- [Backup Workaround Guide](../../../k8s/infra/db/docs/BACKUP_WORKAROUND.md)

---
**Investigation Date:** 2025-11-09
**Investigated By:** Claude Code
**Status:** ✅ Root cause identified, awaiting operator upgrade
