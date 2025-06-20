# Redis Storage Cleanup

This document explains how to clean up unused Persistent Volume Claims (PVCs) after switching Redis from a clustered deployment to standalone mode.

## Problem

When you change your Redis deployment from replicated mode (the default) to standalone mode using:

```bash
helm upgrade redis bitnami/redis --set architecture=standalone
```

The Helm chart will remove the replica StatefulSet, but it will **not** automatically delete the PVCs that were used by the replicas. This is a safety feature to prevent accidental data loss.

These orphaned PVCs continue to:
1. Consume storage resources
2. Incur costs (if using cloud storage)
3. Count against your storage quotas
4. Show up in resource listings, causing confusion

## Solution

The `free-redis-replica-storage.sh` script in this directory helps you safely delete these unused PVCs.

### Prerequisites

Before running the script, ensure:

1. Your Redis standalone instance is working properly
2. You have backed up any important data (if needed)
3. You have the necessary permissions to delete PVCs

### Usage

1. Make the script executable:
   ```bash
   chmod +x free-redis-replica-storage.sh
   ```

2. Run the script:
   ```bash
   ./free-redis-replica-storage.sh
   ```

3. The script will:
   - Identify Redis replica PVCs
   - Show you which PVCs will be deleted
   - Ask for confirmation before proceeding
   - Delete the PVCs and report results

### Manual Cleanup

If you prefer to clean up manually, you can:

1. Identify the Redis replica PVCs:
   ```bash
   kubectl get pvc | grep redis-replicas
   ```

2. Check that they are not in use:
   ```bash
   kubectl describe pvc REPLICA_PVC_NAME | grep "Used By"
   ```
   The result should show `Used By: <none>`

3. Delete each PVC:
   ```bash
   kubectl delete pvc REPLICA_PVC_NAME
   ```

### Verifying Cleanup

After running the script, verify that only the master PVC remains:

```bash
kubectl get pvc | grep redis
```

You should only see the `redis-data-redis-master-0` PVC, and the replica PVCs should be gone.

## When Switching Back to Replicated Mode

If you later decide to switch back to replicated mode:

```bash
helm upgrade redis bitnami/redis --set architecture=replication
```

New PVCs will be created automatically for the replicas. The data will be synced from the master to the replicas.

## Troubleshooting

If you encounter issues deleting PVCs:

1. **PVC in use**: Make sure no pods are using the PVC
   ```bash
   kubectl describe pvc REPLICA_PVC_NAME | grep "Used By"
   ```

2. **Finalizers blocking deletion**: You may need to remove finalizers
   ```bash
   kubectl patch pvc REPLICA_PVC_NAME -p '{"metadata":{"finalizers":null}}'
   ```

3. **Permission issues**: Make sure you have the necessary RBAC permissions to delete PVCs 