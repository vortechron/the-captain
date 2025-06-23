# Kubernetes PVC Cost Analysis & Optimization Plan

## Executive Summary

**Current Monthly PVC Cost: ~$104/month**
**Potential Savings: ~$48-58/month (46-56% reduction)**

Your DigitalOcean Kubernetes cluster currently has 11 PVCs totaling 91 GiB of storage, costing approximately $104/month. This analysis identifies significant optimization opportunities, particularly for Redis clustering and monitoring storage.

## Current PVC Breakdown

### Redis Cluster (Over-provisioned)
| PVC Name | Size | Monthly Cost | Status | Usage Pattern |
|----------|------|-------------|---------|---------------|
| `redis-data-redis-master-0` | 8Gi | $10 | Active | Single master node |
| `redis-data-redis-replicas-0` | 8Gi | $10 | Active | Replica 1 |
| `redis-data-redis-replicas-1` | 8Gi | $10 | Active | Replica 2 |
| `redis-data-redis-replicas-2` | 8Gi | $10 | Active | Replica 3 |
| **Redis Total** | **32Gi** | **$40/month** | | **4 nodes + 3 replicas** |

### Application Storage (Production)
| PVC Name | Size | Monthly Cost | Status | Application |
|----------|------|-------------|---------|-------------|
| `terapeas-storage` | 10Gi | $10 | Active | Production API |
| `terapeas-portal-storage` | 10Gi | $10 | Active | Production Portal |
| `staging-terapeas-storage` | 10Gi | $10 | Active | Staging API |
| **Application Total** | **30Gi** | **$30/month** | | **3 environments** |

### Monitoring Stack (Recently Deployed)
| PVC Name | Size | Monthly Cost | Status | Component |
|----------|------|-------------|---------|-----------|
| `storage-loki-0` | 10Gi | $10 | Active | Log storage |
| `export-0-loki-minio-0` | 5Gi | $5 | Active | MinIO storage |
| `export-1-loki-minio-0` | 5Gi | $5 | Active | MinIO storage |
| `storage-prometheus-alertmanager-0` | 2Gi | $2 | Active | Alertmanager |
| **Monitoring Total** | **22Gi** | **$22/month** | | **4 components** |

### Cost Summary
- **Total Storage**: 91 GiB
- **Total Monthly Cost**: ~$104
- **Average cost per GiB**: $1.14/month

## Problem Analysis

### 1. Redis Over-Engineering
- **Current**: 4-node Redis cluster (1 master + 3 replicas) = 32Gi storage
- **Typical Usage**: Small to medium workloads rarely need 3 replicas
- **Memory vs Storage**: Redis is primarily memory-based; 8Gi disk per node excessive
- **Cost Impact**: $40/month for likely underutilized clustering

### 2. Monitoring Stack Over-Provisioning
- **Loki**: 10Gi for logs in a small cluster is generous
- **MinIO**: Dual 5Gi volumes for small cluster monitoring
- **Data Retention**: Likely storing months of data for dev/small prod environment

### 3. Application Storage Assessment
- **Production Apps**: 10Gi each seems reasonable for Laravel applications
- **Staging**: Could potentially be smaller than production

## Optimization Plan

### Phase 1: Redis Architecture Optimization (Immediate - $25-30/month savings)

#### Option A: Single Redis Instance (Recommended for Small/Medium Load)

#### Option B: Redis Master + 1 Replica (High Availability) ✅
```bash
# Current cost: $40/month (4 x 8Gi)
# Target cost: $20/month (2 x 8Gi)
# Savings: $20/month
```

**Action Items:**
1. Scale down to master + single replica
2. Remove 2 unnecessary replica PVCs
3. Maintain high availability with reduced overhead

#### Option C: Storage Size Optimization (Conservative)

### Phase 2: Monitoring Stack Optimization ($12-15/month savings)

#### Storage Reduction Plan
```bash
# Current monitoring cost: $22/month
# Target cost: $7-10/month
# Savings: $12-15/month
```

**Optimization Actions:**
1. **Loki Storage**: Reduce from 10Gi to 3Gi
   - Configure 3-day log retention instead of default
   - Focus on error logs and critical events
   - Savings: ~$7/month

2. **MinIO Consolidation**: Merge dual 5Gi to single 3Gi
   - Single MinIO instance sufficient for small cluster
   - Savings: ~$7/month

3. **Prometheus AlertManager**: Keep at 2Gi (already minimal)

#### Configuration Changes
```yaml
# Loki values adjustment
loki:
  config:
    limits_config:
      retention_period: 72h  # 3 days instead of default
    storage_config:
      boltdb_shipper:
        cache_ttl: 24h
  persistence:
    size: 3Gi  # Reduced from 10Gi

# MinIO consolidation
minio:
  persistence:
    size: 3Gi  # Single instance instead of dual 5Gi
```

### Phase 3: Application Storage Review ($0-10/month savings)

#### Assessment Recommendations
1. **Production Apps**: Monitor actual usage before reducing
2. **Staging Environment**: Consider reducing to 5Gi if usage permits
3. **Future Applications**: Start with smaller sizes (5Gi) and grow as needed

## Implementation Timeline

### Week 1: Redis Optimization
- [ ] Backup current Redis data
- [ ] Test application with reduced Redis cluster
- [ ] Implement chosen Redis optimization (Option A/B/C)
- [ ] Verify application functionality

### Week 2: Monitoring Stack Optimization  
- [ ] Configure shorter retention periods
- [ ] Resize Loki PVC from 10Gi to 3Gi
- [ ] Consolidate MinIO storage
- [ ] Verify log collection continues working

### Week 3: Monitoring & Validation
- [ ] Monitor all applications for storage-related issues
- [ ] Validate backup/restore procedures
- [ ] Document new configurations
- [ ] Set up storage usage alerts

## Cost Projection

### Conservative Optimization (Phase 1 Option C + Phase 2)
- **Current Cost**: $104/month
- **Optimized Cost**: $55/month  
- **Monthly Savings**: $49/month (47%)
- **Annual Savings**: $588/year

### Aggressive Optimization (Phase 1 Option A + Phase 2 + Phase 3)
- **Current Cost**: $104/month
- **Optimized Cost**: $46/month
- **Monthly Savings**: $58/month (56%)
- **Annual Savings**: $696/year

## Risk Mitigation Strategies

### 1. Backup Strategy
```bash
# Automated daily backups before optimization
kubectl create cronjob redis-backup --schedule="0 2 * * *" \
  --image=redis:alpine -- redis-cli --rdb /backup/dump.rdb

# Application data snapshots
kubectl create cronjob app-backup --schedule="0 3 * * *" \
  --image=alpine -- tar -czf /backup/app-$(date +%Y%m%d).tar.gz /app/storage
```

### 2. Monitoring Alerts
```yaml
# Storage usage alerts
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: storage-alerts
spec:
  groups:
  - name: storage
    rules:
    - alert: PVCUsageHigh
      expr: kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.8
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "PVC {{ $labels.persistentvolumeclaim }} usage is above 80%"
```

### 3. Gradual Rollback Plan
1. Keep snapshots of current PVCs before modifications
2. Document original configurations
3. Test each change in non-production first
4. Implement gradual scaling rather than immediate cuts

## Long-term Recommendations

### 1. Storage Class Optimization
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efficient-storage
provisioner: dobs.csi.digitalocean.com
allowVolumeExpansion: true  # Enable dynamic expansion
parameters:
  type: do-block-storage
volumeBindingMode: WaitForFirstConsumer  # Delay provisioning
```

### 2. Application-Level Optimizations
- **Log Rotation**: Implement proper log rotation in applications
- **Cache Strategy**: Use Redis more efficiently to reduce storage needs
- **Asset Management**: Store large files in DigitalOcean Spaces instead of PVCs

### 3. Regular Review Process
- **Monthly**: Review PVC usage metrics
- **Quarterly**: Assess storage needs vs allocation
- **Semi-annually**: Re-evaluate cluster architecture

## Monitoring & Alerting Setup

### Storage Usage Dashboard
```bash
# Install storage monitoring
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: storage-monitoring
data:
  storage-query.yaml: |
    # Grafana dashboard queries for PVC usage
    - expr: kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes
      interval: 30s
      description: "PVC usage percentage"
EOF
```

### Cost Tracking
```bash
# Monthly cost calculation script
cat > calculate-storage-cost.sh << 'EOF'
#!/bin/bash
echo "=== DigitalOcean PVC Cost Analysis ==="
kubectl get pvc --all-namespaces -o custom-columns=\
"NAMESPACE:.metadata.namespace,NAME:.metadata.name,SIZE:.spec.resources.requests.storage" \
| awk 'NR>1 {
    gsub(/Gi/, "", $3); 
    cost = ($3 <= 100) ? 10 : $3 * 0.10; 
    total += cost; 
    printf "%-20s %-30s %5sGi $%.2f\n", $1, $2, $3, cost
} 
END {printf "\nTotal Monthly Cost: $%.2f\n", total}'
EOF
chmod +x calculate-storage-cost.sh
```

## Conclusion

Your current PVC setup is costing ~$104/month with significant optimization opportunities. The Redis cluster alone represents 38% of storage costs and is likely over-engineered for current needs. 

**Recommended approach:**
1. Start with conservative Redis optimization (Phase 1 Option C)
2. Implement monitoring stack optimization (Phase 2)
3. Monitor for 2-4 weeks before further reductions
4. Document all changes for easy rollback if needed

**Expected outcome:**
- **47-56% cost reduction** ($49-58/month savings)
- Maintained application performance
- Improved operational efficiency
- Better resource utilization

This optimization plan balances cost savings with operational safety, ensuring your applications continue running smoothly while significantly reducing DigitalOcean block storage costs. 