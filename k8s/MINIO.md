# MinIO Kubernetes Deployment Guide

MinIO is a high-performance, S3-compatible object storage system. This guide covers deploying MinIO on Kubernetes with persistent storage, SSL/TLS certificates, and ingress configuration.

## Architecture Overview

Our MinIO deployment includes:
- Single-instance MinIO server with persistent storage
- Separate services for API (port 9000) and Console (port 9001)  
- SSL-terminated ingress with Let's Encrypt certificates
- Resource limits for production stability

## Prerequisites

Before deploying MinIO, ensure you have:
- Kubernetes cluster with ingress controller installed
- cert-manager for SSL certificate management
- DNS records pointing to your cluster
- Storage class available (using `do-block-storage` for DigitalOcean)

## Quick Deployment

### 1. Deploy MinIO Infrastructure

Deploy all MinIO components:
```bash
kubectl apply -f k8s/infra/minio/
```

### 2. Verify Deployment

Check all resources are running:
```bash
# Check namespace
kubectl get ns minio

# Check all resources in minio namespace
kubectl get all -n minio

# Check persistent volume
kubectl get pvc -n minio

# Check ingress
kubectl get ingress -n minio
```

### 3. Update DNS Configuration

Add DNS records for your MinIO endpoints:
```
minio.yourdomain.com -> [your-cluster-ip]
minio-console.yourdomain.com -> [your-cluster-ip]
```

## Configuration Details

### Storage Configuration

The deployment uses a 20Gi persistent volume:
```yaml
# k8s/infra/minio/pvc.yaml
spec:
  resources:
    requests:
      storage: 20Gi
  storageClassName: do-block-storage
```

### Security Configuration

Default credentials are stored in Kubernetes secrets:
```bash
# View current credentials (base64 encoded)
kubectl get secret minio-secret -n minio -o yaml

# Update credentials
kubectl create secret generic minio-secret \
  --from-literal=MINIO_ROOT_USER=yourusername \
  --from-literal=MINIO_ROOT_PASSWORD=yourpassword \
  --namespace=minio \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Resource Limits

MinIO container resource allocation:
- **Requests**: 100m CPU, 256Mi memory
- **Limits**: 500m CPU, 1Gi memory

Adjust based on your workload requirements.

## Access Points

After deployment, MinIO provides two endpoints:

### MinIO API (S3-compatible)
- **URL**: https://minio.yourdomain.com
- **Port**: 9000
- **Use**: S3-compatible API for applications

### MinIO Console (Web UI)
- **URL**: https://minio-console.yourdomain.com  
- **Port**: 9001
- **Use**: Web-based administration interface

## SSL/TLS Configuration

The ingress is configured with Let's Encrypt certificates:
```yaml
# Update domains in k8s/infra/minio/ingress.yaml
spec:
  tls:
  - hosts:
    - minio.yourdomain.com
    - minio-console.yourdomain.com
```

For production, change the cert-manager issuer from `letsencrypt-staging` to `letsencrypt-prod`.

## Application Integration

### Using MinIO with Applications

Configure your applications to use MinIO as S3-compatible storage:

```bash
# Example environment variables
MINIO_ENDPOINT=https://minio.yourdomain.com
MINIO_ACCESS_KEY=yourusername
MINIO_SECRET_KEY=yourpassword
MINIO_REGION=us-east-1
MINIO_BUCKET_NAME=your-bucket
```

### Creating Buckets

Use the MinIO Console or mc client:
```bash
# Using mc client
mc alias set myminio https://minio.yourdomain.com yourusername yourpassword
mc mb myminio/your-bucket
```

## Scaling and High Availability

### Single Node Limitations
Current deployment is single-node and not suitable for high availability. For production:

### Option 1: MinIO Operator (Recommended)
```bash
# Install MinIO Operator
kubectl apply -k github.com/minio/operator/

# Create distributed MinIO tenant
kubectl apply -f - <<EOF
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: storage
  namespace: minio
spec:
  pools:
  - servers: 4
    volumesPerServer: 2
    volumeClaimTemplate:
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 20Gi
EOF
```

### Option 2: StatefulSet Deployment
For manual distributed setup, convert to StatefulSet with multiple replicas.

## Monitoring and Maintenance

### Health Checks
MinIO deployment includes liveness and readiness probes:
```yaml
livenessProbe:
  httpGet:
    path: /minio/health/live
    port: 9000
readinessProbe:
  httpGet:
    path: /minio/health/ready
    port: 9000
```

### Storage Monitoring
Monitor storage usage:
```bash
# Check PVC usage
kubectl describe pvc minio-pvc -n minio

# Monitor in MinIO Console
# Go to https://minio-console.yourdomain.com -> Monitoring
```

### Backup Strategy
Implement regular backups:
```bash
# Export bucket data using mc client
mc mirror myminio/your-bucket /backup/location

# Or setup cross-region replication
mc replicate add myminio/source-bucket/prefix \
  --remote-bucket arn:aws:s3:::destination-bucket/prefix
```

## Troubleshooting

### Common Issues

#### 1. Pod Not Starting
```bash
# Check pod logs
kubectl logs -n minio deployment/minio

# Check PVC status
kubectl get pvc -n minio
kubectl describe pvc minio-pvc -n minio
```

#### 2. Storage Issues
```bash
# Check storage class
kubectl get storageclass

# Verify node storage capacity
kubectl describe nodes
```

#### 3. Access Issues
```bash
# Check ingress status
kubectl describe ingress minio-ingress -n minio

# Verify DNS resolution
nslookup minio.yourdomain.com

# Check certificate status
kubectl describe certificate minio-tls -n minio
```

#### 4. Permission Issues
```bash
# Check secret configuration
kubectl get secret minio-secret -n minio -o yaml

# Test credentials
mc alias set test https://minio.yourdomain.com username password
```

## Security Best Practices

1. **Change Default Credentials**: Update the secret with strong passwords
2. **Network Policies**: Implement Kubernetes network policies to restrict access
3. **RBAC**: Configure role-based access control for MinIO operations  
4. **Regular Updates**: Keep MinIO image updated for security patches
5. **Backup Encryption**: Encrypt backups and use secure backup locations

## Upgrading MinIO

### Rolling Update
```bash
# Update image version in deployment
kubectl set image deployment/minio minio=minio/minio:RELEASE.2024-01-16T16-07-38Z -n minio

# Monitor rollout
kubectl rollout status deployment/minio -n minio
```

### With Helm (Alternative)
Consider migrating to Helm for easier updates:
```bash
helm repo add minio https://charts.min.io/
helm install minio minio/minio \
  --namespace minio \
  --set persistence.size=20Gi \
  --set ingress.enabled=true
```

## Performance Tuning

### Storage Optimization
```yaml
# For better I/O performance, use SSD storage class
storageClassName: do-block-storage-premium  # DigitalOcean premium SSD
```

### Memory and CPU Scaling
```yaml
# Adjust based on workload
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2
    memory: 4Gi
```

### Network Optimization
```yaml
# Increase ingress timeouts for large uploads
annotations:
  nginx.ingress.kubernetes.io/proxy-body-size: "5120m"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "600" 
  nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
```

This completes your MinIO Kubernetes deployment. The setup provides a solid foundation for S3-compatible object storage with proper security, monitoring, and scalability considerations.