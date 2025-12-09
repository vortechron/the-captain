# MySQL Setup Summary

## Overview
This document summarizes the setup of a simple MySQL instance using the Bitnami MySQL Helm chart on your Kubernetes cluster.

## Configuration
We created a custom values file `.helm/mysql-values.yml` with the following settings:

- **Chart**: `bitnami/mysql`
- **Image Tag**: `8.0` (Resolves to the latest MySQL 8.0.x version)
- **Database Name**: `iworld`
- **Username**: `vortechron`
- **Password**: `TiLPszdF24sjT0k5`
- **Root Password**: `TiLPszdF24sjT0k5`
- **Resources**:
  - **Limits**: 500m CPU, 512Mi Memory
  - **Requests**: 100m CPU, 128Mi Memory
- **Persistence**: 1Gi Storage

## Installation Process & Troubleshooting

### 1. Initial Configuration
We started by creating the `.helm/mysql-values.yml` file with your requested credentials and resource limits.

### 2. Image Tag Resolution
The default image tag in the Helm chart (`9.4.0`) was invalid. We attempted to use specific tags (`8.4.3`, `8.0.40`) which also failed to pull.
**Resolution**: We set the image tag to `8.0`, which successfully pulled the correct image.

### 3. Volume Conflict
During the first successful pod startup, the MySQL container crashed with an "Access Denied" error.
**Cause**: An existing PersistentVolumeClaim (`data-mysql-0`) from 6 months ago was present. This volume contained a database initialized with a different password, causing the new instance to fail authentication.
**Resolution**: With your approval, we deleted the old `data-mysql-0` PVC.

### 4. Final Installation
After deleting the old volume, we re-ran the Helm install command. A new volume was created, and the database was successfully initialized with the correct credentials.

## Connection Details

You can connect to this database from within your cluster using:

- **Host**: `mysql.default.svc.cluster.local`
- **Port**: `3306`
- **Username**: `vortechron`
- **Password**: `TiLPszdF24sjT0k5`
- **Database**: `iworld`

## Verification commands

Check pod status:
```bash
kubectl get pods -l app.kubernetes.io/name=mysql
```

Check logs:
```bash
kubectl logs mysql-0
```
