# MySQL Backup Workaround for Operator 1.18.0

## Issue Summary

Percona XtraDB Cluster Operator version 1.18.0 has a known bug where backup jobs fail because the garbd connection string doesn't include port `:4567` in the gcomm URL.

### Error Symptom
```
ERROR: failed to open gcomm backend connection: 110: failed to reach primary view (pc.wait_prim_timeout)
Failed to open channel 'cluster1-pxc-db-pxc' at 'gcomm://cluster1-pxc-db-pxc-1.cluster1-pxc-db-pxc?gmcast.listen_addr=tcp://0.0.0.0:4567'
Error: local version is empty
```

### Root Cause
The operator's backup script constructs the garbd gcomm URL as:
- **Current (broken)**: `gcomm://cluster1-pxc-db-pxc-1.cluster1-pxc-db-pxc`
- **Should be**: `gcomm://cluster1-pxc-db-pxc-1.cluster1-pxc-db-pxc:4567`

The missing port `:4567` causes garbd to fail connecting to the Galera cluster.

## Permanent Solution

**Upgrade to Percona XtraDB Cluster Operator 1.19.0 or later** which includes fixes for this issue.

Update `terraform/modules/mysql/operator.tf`:
```hcl
resource "helm_release" "pxc_operator" {
  # ... other config ...
  chart   = "pxc-operator"
  version = "1.19.0"  # or later
}
```

## Temporary Workaround Options

### Option 1: Manual Backup via kubectl exec

Use xtrabackup directly from a PXC pod:

```bash
#!/bin/bash
# Manual backup script

NAMESPACE="db"
CLUSTER="cluster1-pxc-db"
BACKUP_NAME="manual-backup-$(date +%Y%m%d-%H%M%S)"
S3_BUCKET="db-backup"
S3_ENDPOINT="https://minio.aks.terapeas.com"

# Get credentials
XTRABACKUP_PASSWORD=$(kubectl get secret ${CLUSTER}-secrets -n ${NAMESPACE} -o jsonpath='{.data.xtrabackup}' | base64 -d)
AWS_ACCESS_KEY=$(kubectl get secret minio-backup-secret -n ${NAMESPACE} -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
AWS_SECRET_KEY=$(kubectl get secret minio-backup-secret -n ${NAMESPACE} -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)

# Run backup from PXC pod
kubectl exec -n ${NAMESPACE} ${CLUSTER}-pxc-0 -c pxc -- bash -c "
  xtrabackup --backup \
    --user=xtrabackup \
    --password='${XTRABACKUP_PASSWORD}' \
    --stream=xbstream \
    --target-dir=/tmp/backup | \
  AWS_ACCESS_KEY_ID='${AWS_ACCESS_KEY}' \
  AWS_SECRET_ACCESS_KEY='${AWS_SECRET_KEY}' \
  xbcloud put \
    --storage=s3 \
    --s3-endpoint='${S3_ENDPOINT}' \
    --s3-bucket='${S3_BUCKET}' \
    '${BACKUP_NAME}'
"
```

### Option 2: Custom Backup Job

Create a custom Kubernetes Job that bypasses the operator:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: manual-mysql-backup
  namespace: db
spec:
  template:
    spec:
      serviceAccountName: percona-xtradb-cluster-operator
      containers:
      - name: xtrabackup
        image: percona/percona-xtrabackup:8.0.35-33.1
        command:
        - /bin/bash
        - -c
        - |
          set -ex

          # Use direct pod IP with port 4567
          POD_IP=$(kubectl get pod cluster1-pxc-db-pxc-1 -n db -o jsonpath='{.status.podIP}')

          # Run garbd with explicit port
          garbd \
            --address "gcomm://${POD_IP}:4567?gmcast.listen_addr=tcp://0.0.0.0:4567" \
            --group cluster1-pxc-db-pxc \
            --donor cluster1-pxc-db-pxc-1 \
            --sst xtrabackup-v2
        env:
        - name: PXC_PASS
          valueFrom:
            secretKeyRef:
              name: cluster1-pxc-db-secrets
              key: xtrabackup
      restartPolicy: Never
  backoffLimit: 3
```

### Option 3: Patch Operator Image (Advanced)

Build a custom operator image with the fix:

1. Clone the operator repository
2. Modify the backup script to include `:4567` in gcomm URLs
3. Build and push custom image
4. Update Terraform to use custom image

## Testing Backups

After implementing a workaround, test with:

```bash
# Using the backup script
cd /path/to/k8s/infra/db/scripts
./backup.sh --name test-backup-$(date +%Y%m%d)

# Monitor progress
kubectl get pxc-backups -n db -w

# Check logs if it fails
kubectl logs -n db -l percona.com/backup-name=<BACKUP_NAME>
```

## Monitoring

Set up alerts for backup failures:

```yaml
# Prometheus alert example
- alert: MySQLBackupFailing
  expr: |
    kube_job_status_failed{namespace="db",job=~"xb-.*"} > 0
  for: 5m
  annotations:
    summary: "MySQL backup job {{ $labels.job }} failed"
```

## References

- [Percona Operator GitHub Issue #1832](https://github.com/percona/percona-xtradb-cluster-operator/issues/1832)
- [SST Backup Failure Analysis](./SST_BACKUP_FAILURE_ANALYSIS.md)
- [Percona XtraDB Cluster Documentation](https://docs.percona.com/percona-xtradb-cluster/8.0/)

## Timeline

- **2025-11-08**: Last successful automated backup (before operator restart)
- **2025-11-09**: Issue identified after PXC pod restart
- **Fix Applied**: Documentation added, awaiting operator upgrade

