# Grafana Data Migration

This directory contains scripts to migrate Grafana data from one Kubernetes cluster to another using `kubectl cp`. The migration process uses your local machine as intermediary storage.

## Overview

The migration process consists of two steps:
1. **Backup**: Copy Grafana data from source cluster (DigitalOcean) to local directory
2. **Restore**: Copy local backup to target cluster (Azure)

## Prerequisites

- `kubectl` configured with access to both source and target clusters
- Appropriate permissions to access pods in the `observability` namespace
- Sufficient local disk space for the backup (typically a few GB)

## Usage

### Step 1: Backup from DigitalOcean Cluster

```bash
# Set the source cluster context (optional, if not set uses current context)
export SOURCE_CLUSTER="do-cluster"

# Run backup script
./backup-grafana.sh
```

The script will:
- Detect the Grafana pod in the `observability` namespace
- Create a timestamped backup directory (e.g., `grafana-backup-20250110-120000`)
- Copy `/var/lib/grafana` from the pod to the local directory

### Step 2: Restore to Azure Cluster

```bash
# Set the target cluster context
export TARGET_CLUSTER="aks-cluster"

# Run restore script with backup directory name
./restore-grafana.sh grafana-backup-20250110-120000
```

The script will:
- Verify the backup directory exists
- Detect the Grafana pod in the target cluster
- Copy the backup data to `/var/lib/grafana` in the pod
- Prompt for confirmation before overwriting existing data

### Restart Grafana Pod (Recommended)

After restoring, restart the Grafana pod to ensure all changes are loaded:

```bash
kubectl delete pod <grafana-pod-name> -n observability
```

The pod will be automatically recreated by the deployment/statefulset.

## Environment Variables

- `SOURCE_CLUSTER`: Kubernetes context name for source cluster (DigitalOcean)
- `TARGET_CLUSTER`: Kubernetes context name for target cluster (Azure)
- `NAMESPACE`: Kubernetes namespace (default: `observability`)

## Important Warnings

⚠️ **This migration overwrites all Grafana data including:**
- Users and organizations
- API keys and service accounts
- Dashboards and data sources
- Alert rules and notification channels
- Preferences and settings

**Best Practices:**
- Works best when migrating the entire Grafana instance to a new environment
- Ensure you have a backup before restoring
- Test the restore process in a non-production environment first
- Consider stopping Grafana during the restore to avoid data corruption

## Troubleshooting

### Pod Not Found

If the script cannot find the Grafana pod, verify:
- The namespace is correct (default: `observability`)
- Grafana is deployed and running
- You have permissions to list pods

```bash
kubectl get pods -n observability -l "app.kubernetes.io/name=grafana"
```

### Copy Fails

If `kubectl cp` fails:
- Ensure the pod is in `Ready` state
- Check available disk space in the pod
- Verify network connectivity to the cluster
- Try copying a smaller test file first

### Data Not Appearing

After restore:
- Restart the Grafana pod
- Check Grafana logs: `kubectl logs <pod-name> -n observability`
- Verify the data was copied correctly: `kubectl exec <pod-name> -n observability -- ls -la /var/lib/grafana`

## Alternative: Direct Cluster-to-Cluster Migration

If both clusters are accessible from your machine, you can also perform a direct migration:

```bash
# On source cluster
kubectl cp observability/grafana-0:/var/lib/grafana ./grafana-backup

# Switch to target cluster
kubectl config use-context aks-cluster

# On target cluster
kubectl cp ./grafana-backup observability/grafana-0:/var/lib/grafana
```

The scripts automate this process with better error handling and safety checks.

