# Laravel Storage Migration Plan: PVC to MinIO

## Overview
Migration plan to copy Laravel storage files from Kubernetes PVC (`terapeas-storage`) to MinIO object storage.

## Current Setup Analysis
- **PVC**: `terapeas-storage` (10Gi, ReadWriteOnce, DigitalOcean Block Storage)
- **Pod**: `terapeas-api-larakube-web-7c85cb7648-sbkjk`
- **Mount Points**:
  - `/var/www/html/storage` → `app/public` subPath
  - `/var/www/html/storage/framework` → `framework` subPath  
  - `/var/www/html/storage/framework/cache` → `framework/cache` subPath
  - `/var/www/html/storage/framework/sessions` → `framework/sessions` subPath
  - `/var/www/html/storage/framework/views` → `framework/views` subPath
  - `/var/www/html/storage/logs` → `logs` subPath
  - `/var/www/html/storage/media-library/temp` → `temp` subPath

## Migration Strategy
Using rclone in a Kubernetes Job to copy files from PVC to MinIO bucket `terapeas-local`.

## Deployment Steps

### 1. Apply rclone configuration
```bash
kubectl apply -f k8s/infra/minio/rclone-config.yaml
```

### 2. Run migration job
```bash
kubectl apply -f k8s/infra/minio/migration-job.yaml
```

### 3. Monitor migration progress
```bash
# Watch job status
kubectl get jobs laravel-storage-migration -w

# View migration logs
kubectl logs job/laravel-storage-migration -f
```

### 4. Verify migration
```bash
# Check if files were copied successfully
kubectl logs job/laravel-storage-migration | tail -20

# Clean up job after successful migration
kubectl delete job laravel-storage-migration
```

## MinIO Structure After Migration
```
terapeas-local/
└── storage/
    ├── app/public/     # Laravel public files
    ├── framework/      # Framework cache, sessions, views
    ├── logs/          # Application logs  
    └── temp/          # Media library temp files
```

## Post-Migration Tasks
1. Update Laravel `.env` configuration to use MinIO for file storage
2. Test file uploads and downloads
3. Consider updating deployment to remove PVC dependency for storage (keep for framework cache/sessions if needed)

## Rollback Plan
- Original files remain in PVC unchanged (copy operation)
- Simply revert Laravel configuration to use local storage
- No data loss risk as this is a copy operation

## Notes
- Migration is **copy-only** - original files remain in PVC
- Job will create MinIO bucket if it doesn't exist
- Includes progress monitoring and error handling
- Resource limits set to prevent cluster impact