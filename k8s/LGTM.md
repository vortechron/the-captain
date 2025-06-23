# Loki-Grafana-Promtail Monitoring Stack

**Current Versions:**
- **Grafana**: Chart v9.2.7 (App v12.0.2)
- **Loki**: Chart v6.30.1 (App v3.5.0)
- **Promtail**: Chart v6.15.4 (App v2.9.3)

**💰 Cost Optimized Configuration:**
- **Loki Storage**: 3Gi PVC (optimized from 10Gi)
- **Log Retention**: 3 days (72 hours) to minimize storage usage
- **MinIO**: Not required - Loki uses filesystem storage
- **Monthly Cost**: ~$5/month for monitoring stack

## Installation

### Add Grafana Helm Repository
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### Install Loki (Log Aggregation)
```bash
helm upgrade loki grafana/loki --namespace=observability --create-namespace \
  --version=6.30.1 \
  --install \
  -f k8s/loki-simple-values.yaml
```

**⚠️ Post-Installation Optimization:**
After installation, optimize storage and retention:
```bash
# Scale down Loki
kubectl scale statefulset loki --replicas=0 -n observability

# Delete the default 10Gi PVC
kubectl delete pvc storage-loki-0 -n observability

# Update StatefulSet for 3Gi storage and 3-day retention
kubectl get statefulset loki -n observability -o yaml > loki-backup.yaml
sed 's/storage: 10Gi/storage: 3Gi/g' loki-backup.yaml | kubectl apply -f -

# Add retention policy to Loki config
kubectl patch configmap loki -n observability --type merge -p='{"data":{"config.yaml":"auth_enabled: false\ncommon:\n  path_prefix: /var/loki\n  replication_factor: 1\n  storage:\n    filesystem:\n      chunks_directory: /var/loki/chunks\n      rules_directory: /var/loki/rules\nlimits_config:\n  retention_period: 72h\n  reject_old_samples: true\n  reject_old_samples_max_age: 168h\nschema_config:\n  configs:\n  - from: \"2020-10-24\"\n    index:\n      period: 24h\n      prefix: index_\n    object_store: filesystem\n    schema: v11\n    store: boltdb-shipper\nserver:\n  http_listen_port: 3100"}}'

# Scale back up
kubectl scale statefulset loki --replicas=1 -n observability
```

### Install Grafana (Visualization)
```bash
helm upgrade grafana grafana/grafana --namespace=observability \
  --version=9.2.7 \
  --install
```

### Install Promtail (Log Collection)
```bash
helm upgrade promtail grafana/promtail --namespace=observability \
  --version=6.15.4 \
  --install \
  -f k8s/promtail-values.yaml
```

## Features

### Promtail Advantages
- **Automatic JSON parsing**: Detects and extracts all JSON fields from logs automatically
- **Universal compatibility**: Works with any JSON structure from any application
- **Efficient log collection**: Native integration with Loki for optimal performance
- **Kubernetes native**: Automatically discovers and collects logs from all pods
- **Flexible configuration**: Easy to configure for different log formats and sources

### What You Get in Grafana
- **Detected Fields panel**: Shows all JSON fields dynamically for easy filtering
- **Easy filtering**: Use queries like `{level_name="ERROR"}` or `{method="POST"}`
- **Automatic field extraction**: Nested objects are automatically available as filterable fields
- **Real-time log streaming**: See logs as they happen with full JSON structure
- **Pod annotation support**: Add `prometheus.io/scrape: "true"` to pods for enhanced log parsing

## Access Grafana

### Get Admin Password
```bash
kubectl get secret --namespace observability grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

### Access via Port Forwarding
```bash
export POD_NAME=$(kubectl get pods --namespace observability -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace observability port-forward $POD_NAME 3000
```

### Access via Ingress (External URL)
```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: observability
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - hosts:
        - grafana.vortechron.com
      secretName: grafana-tls
  rules:
    - host: grafana.vortechron.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 80
EOF
```

## Configuration

### Loki Configuration
Loki is configured using `k8s/loki-simple-values.yaml` with the following settings:
- **SingleBinary mode**: Optimized for single-node development clusters
- **Multi-tenancy disabled**: `auth_enabled: false` for simplified setup
- **Filesystem storage**: Local storage for development environments (3Gi PVC)
- **3-day retention**: `retention_period: 72h` to optimize storage costs
- **Minimal resource usage**: Disabled unnecessary cache and monitoring components
- **Single replica**: Ideal for resource-constrained environments
- **No MinIO required**: Uses filesystem storage directly, avoiding MinIO overhead

### Promtail Configuration
Promtail is configured using `k8s/promtail-values.yaml` with:
- **Automatic JSON parsing**: `json: expressions: {}` for universal JSON support
- **Kubernetes pod discovery**: Automatically finds and collects logs from all pods
- **Enhanced parsing for annotated pods**: Special handling for pods with `prometheus.io/scrape: "true"`
- **Multiple timestamp formats**: Supports various timestamp formats including Laravel's format
- **Comprehensive labeling**: Extracts common fields like level, method, route, user_id, etc.

### Grafana Datasource
Configure Loki datasource in Grafana with:
- **URL**: `http://loki-gateway.observability.svc.cluster.local/`
- **No authentication required** (multi-tenancy disabled)

## Enhanced Log Collection

### For Better JSON Parsing
Add this annotation to your pods for enhanced log parsing:
```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
```

### Example Laravel Pod Configuration
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-laravel-app
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
    spec:
      containers:
      - name: app
        image: my-laravel-app:latest
        # ... other configuration
```

## Cost Optimization

### Check for Orphaned PVCs
Sometimes Helm installations create unused MinIO PVCs. Check and clean them up:
```bash
# Check for unused MinIO PVCs
kubectl get pvc -n observability | grep minio

# Verify they're not being used
kubectl describe pvc export-0-loki-minio-0 -n observability | grep "Used By"

# Delete if unused (saves $10/month)
kubectl delete pvc export-0-loki-minio-0 export-1-loki-minio-0 -n observability
```

### Monitor Storage Usage
```bash
# Check actual storage usage inside Loki pod
kubectl exec -n observability loki-0 -c loki -- df -h | grep loki

# Monitor PVC costs
kubectl get pvc --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,SIZE:.spec.resources.requests.storage" | awk 'NR>1 {gsub(/Gi/, "", $3); cost = ($3 <= 100) ? 10 : $3 * 0.10; total += cost; printf "%-20s %-30s %5sGi $%.2f\n", $1, $2, $3, cost} END {printf "\nTotal Monthly Cost: $%.2f\n", total}'
```

### Expected Monthly Costs
- **Loki (3Gi)**: $3/month
- **Prometheus AlertManager (2Gi)**: $2/month  
- **Total Monitoring Stack**: ~$5/month

## Uninstall Stack
```bash
helm uninstall grafana -n observability
helm uninstall loki -n observability
helm uninstall promtail -n observability

# Clean up any remaining PVCs
kubectl delete pvc --all -n observability
```

## Troubleshooting

### View Grafana Logs
```bash
kubectl logs -f -n observability --all-containers=true --since=1h --tail=100 -l app.kubernetes.io/name=grafana
```

### View Promtail Logs
```bash
kubectl logs -f -n observability -l app=promtail
```

### View Loki Logs
```bash
kubectl logs -f -n observability -l app=loki
```

### Check Promtail Status
```bash
kubectl get pods -n observability -l app=promtail
kubectl describe pod -n observability -l app=promtail
```

### Test Log Collection
```bash
# Check if logs are being collected and parsed
kubectl logs -n observability -l app=promtail | grep -i "json\|adding target"
```

### Verify Loki is Receiving Logs
```bash
# Port forward to Loki
kubectl port-forward -n observability svc/loki-gateway 3100:80 &

# Query recent logs
curl "http://127.0.0.1:3100/loki/api/v1/query_range" --data-urlencode 'query={job="kubernetes-pods"}' --data-urlencode 'start=1h' | jq '.data.result'
```

### Verify Retention Policy
```bash
# Check if retention policy is active
kubectl logs loki-0 -n observability -c loki | grep -i retention

# Should show: retentionHours=72
```

### Backup Before Optimization
```bash
# Always backup before making changes
kubectl exec -n observability loki-0 -c loki -- tar -czf /tmp/loki-backup.tar.gz /var/loki
kubectl cp observability/loki-0:/tmp/loki-backup.tar.gz ./loki-backup.tar.gz -c loki
kubectl get configmap loki -n observability -o yaml > loki-config-backup.yaml
```