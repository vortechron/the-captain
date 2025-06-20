# Kubernetes Storage Management for Small Deployments

This guide provides strategies for managing storage efficiently in Kubernetes for small startups with limited resources, particularly when running monitoring stacks like Loki-Grafana-Prometheus.

## Storage Challenges for Small Deployments

Small startups often face these storage constraints:
- Limited physical storage on nodes
- Budget constraints for cloud storage
- Need to balance monitoring capabilities with resource usage

## Storage Optimization Strategies

### 1. Right-size Persistent Volumes

When deploying components that require persistent storage:

  ```bash
  # Example: Reduce Prometheus storage from default
  helm upgrade prometheus prometheus-community/prometheus \
    --namespace observability \
    --set server.persistentVolume.enabled=true \
    --set server.persistentVolume.size=5Gi \  # Reduced from 10Gi
    --set alertmanager.persistentVolume.enabled=true \
    --set alertmanager.persistentVolume.size=1Gi
  ```

For Loki, configure smaller chunks and retention periods:

  ```bash
  helm upgrade loki grafana/loki-stack --namespace=observability \
    --set loki.config.storage_config.boltdb_shipper.active_index_directory=/data/loki/index \
    --set loki.config.storage_config.boltdb_shipper.cache_location=/data/loki/index_cache \
    --set loki.config.storage_config.boltdb_shipper.cache_ttl=24h \
    --set loki.config.limits_config.retention_period=7d \  # Reduced retention
    --set loki.persistence.size=5Gi
  ```

### 2. Configure Data Retention

Adjust retention periods based on your actual needs:

#### Prometheus Retention

  ```bash
  # Set retention time to 5 days instead of default 15
  helm upgrade prometheus prometheus-community/prometheus \
    --namespace observability \
    --set server.retention=6h \
    --reuse-values
  ```

#### Loki Retention

  ```bash
  # Configure shorter retention directly with helm upgrade
  helm upgrade loki grafana/loki-stack \
    --namespace observability \
    --set loki.config.limits_config.retention_period=6h \
    --set loki.config.compactor.retention_enabled=true \
    --reuse-values
  ```

### 3. Implement Storage Classes with Volume Expansion

Create a storage class that allows volume expansion:

  ```bash
  cat <<EOF | kubectl apply -f -
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: standard-expandable
  provisioner: kubernetes.io/aws-ebs  # Change based on your cloud provider
  allowVolumeExpansion: true
  parameters:
    type: gp2
    fsType: ext4
  EOF
  ```

Use this storage class for your PVCs when installing components:

  ```bash
  # Example: Use custom storage class for Prometheus
  helm upgrade prometheus prometheus-community/prometheus \
    --namespace observability \
    --set server.persistentVolume.storageClass=standard-expandable \
    --set server.persistentVolume.size=5Gi
  ```

### 4. Configure Metrics Scraping Selectively

Reduce the volume of metrics collected by configuring Prometheus to scrape only what you need:

  ```bash
  # Configure Prometheus with selective scraping using helm upgrade
  helm upgrade prometheus prometheus-community/prometheus \
    --namespace observability \
    --set server.persistentVolume.size=5Gi \
    --set server.retention=7d \
    --set "serverFiles.prometheus\.yml.scrape_configs[0].job_name=kubernetes-apiservers" \
    --set "serverFiles.prometheus\.yml.scrape_configs[0].kubernetes_sd_configs[0].role=endpoints" \
    --set "serverFiles.prometheus\.yml.scrape_configs[0].scheme=https" \
    --set "serverFiles.prometheus\.yml.scrape_configs[0].tls_config.ca_file=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt" \
    --set "serverFiles.prometheus\.yml.scrape_configs[0].bearer_token_file=/var/run/secrets/kubernetes.io/serviceaccount/token" \
    --set "serverFiles.prometheus\.yml.scrape_configs[0].relabel_configs[0].source_labels[0]=__meta_kubernetes_namespace" \
    --set "serverFiles.prometheus\.yml.scrape_configs[0].relabel_configs[0].source_labels[1]=__meta_kubernetes_service_name" \
    --set "serverFiles.prometheus\.yml.scrape_configs[0].relabel_configs[0].source_labels[2]=__meta_kubernetes_endpoint_port_name" \
    --set "serverFiles.prometheus\.yml.scrape_configs[0].relabel_configs[0].action=keep" \
    --set "serverFiles.prometheus\.yml.scrape_configs[0].relabel_configs[0].regex=default;kubernetes;https" \
    --set "serverFiles.prometheus\.yml.scrape_configs[1].job_name=kubernetes-pods" \
    --set "serverFiles.prometheus\.yml.scrape_configs[1].kubernetes_sd_configs[0].role=pod" \
    --set "serverFiles.prometheus\.yml.scrape_configs[1].relabel_configs[0].source_labels[0]=__meta_kubernetes_namespace" \
    --set "serverFiles.prometheus\.yml.scrape_configs[1].relabel_configs[0].action=keep" \
    --set "serverFiles.prometheus\.yml.scrape_configs[1].relabel_configs[0].regex=default|kube-system|observability"
  ```

### 5. Configure Log Collection Selectively

For Loki, reduce log volume by filtering logs at the source with Promtail:

  ```bash
  # Configure Promtail with selective log collection using helm upgrade
  helm upgrade promtail grafana/promtail \
    --namespace observability \
    --set "config.clients[0].url=http://loki-stack:3100/loki/api/v1/push" \
    --set "config.scrape_configs[0].job_name=kubernetes" \
    --set "config.scrape_configs[0].kubernetes_sd_configs[0].role=pod" \
    --set "config.scrape_configs[0].relabel_configs[0].source_labels[0]=__meta_kubernetes_namespace" \
    --set "config.scrape_configs[0].relabel_configs[0].action=keep" \
    --set "config.scrape_configs[0].relabel_configs[0].regex=default|kube-system|observability" \
    --set "config.scrape_configs[0].relabel_configs[1].source_labels[0]=__meta_kubernetes_pod_label_app" \
    --set "config.scrape_configs[0].relabel_configs[1].action=drop" \
    --set "config.scrape_configs[0].relabel_configs[1].regex=high-volume-app"
  ```

## Storage Monitoring and Management

### Monitor Storage Usage

Set up alerts for storage usage:

  ```bash
  # Configure Prometheus alerts for storage monitoring
  helm upgrade prometheus prometheus-community/prometheus \
    --namespace observability \
    --set "serverFiles.alerting_rules\.yml.groups[0].name=storage" \
    --set "serverFiles.alerting_rules\.yml.groups[0].rules[0].alert=PersistentVolumeUsageCritical" \
    --set "serverFiles.alerting_rules\.yml.groups[0].rules[0].expr=kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.85" \
    --set "serverFiles.alerting_rules\.yml.groups[0].rules[0].for=5m" \
    --set "serverFiles.alerting_rules\.yml.groups[0].rules[0].labels.severity=critical" \
    --set "serverFiles.alerting_rules\.yml.groups[0].rules[0].annotations.summary=PV usage critical ({{ \$labels.namespace }}/{{ \$labels.persistentvolumeclaim }})" \
    --set "serverFiles.alerting_rules\.yml.groups[0].rules[0].annotations.description=PV is using {{ \$value | humanizePercentage }} of its capacity."
  ```

### Implement Storage Cleanup Jobs

Create a periodic job to clean up old data:

  ```bash
  cat <<EOF | kubectl apply -f -
  apiVersion: batch/v1
  kind: CronJob
  metadata:
    name: prometheus-cleanup
    namespace: observability
  spec:
    schedule: "0 1 * * *"  # Run at 1 AM daily
    jobTemplate:
      spec:
        template:
          spec:
            containers:
            - name: prometheus-cleaner
              image: curlimages/curl:7.82.0
              command:
              - /bin/sh
              - -c
              - |
                # Clean up old series
                curl -X POST http://prometheus-server:9090/api/v1/admin/tsdb/clean_tombstones
                # Additional cleanup commands as needed
            restartPolicy: OnFailure
EOF
  ```

## Emergency Storage Recovery

### Temporarily Reduce Retention

If storage is critically low:

  ```bash
  # For Prometheus - reduce retention immediately
  helm upgrade prometheus prometheus-community/prometheus \
    --namespace observability \
    --set server.retention=2d \
    --reuse-values
  
  # Execute cleanup command
  kubectl exec -it -n observability deploy/prometheus-server -- sh -c 'promtool tsdb clean --delete-delay=30m /data/prometheus'
  
  # For Loki - reduce retention immediately
  helm upgrade loki grafana/loki-stack \
    --namespace observability \
    --set loki.config.limits_config.retention_period=2d \
    --reuse-values
  ```

### Expand PVCs (if storage class supports it)

  ```bash
  kubectl patch pvc prometheus-server -n observability -p '{"spec":{"resources":{"requests":{"storage":"8Gi"}}}}'
  ```

## Best Practices for Small Deployments

1. **Start small**: Begin with minimal retention periods and increase as needed
2. **Monitor your monitoring**: Set up alerts for monitoring system resource usage
3. **Use aggregation**: Configure recording rules in Prometheus to store aggregated metrics for longer periods
4. **Regular maintenance**: Schedule periodic reviews of storage usage and adjust configurations
5. **Consider remote storage**: For critical metrics, consider using remote storage options like Thanos or Cortex

## Recommended Configurations for Resource-Constrained Environments

### Minimal Prometheus Setup

  ```bash
  helm upgrade prometheus prometheus-community/prometheus \
    --namespace observability \
    --install \
    --set server.persistentVolume.size=5Gi \
    --set server.retention=5d \
    --set alertmanager.persistentVolume.size=1Gi \
    --set alertmanager.retention=24h \
    --set server.resources.requests.cpu=100m \
    --set server.resources.requests.memory=256Mi \
    --set server.resources.limits.cpu=200m \
    --set server.resources.limits.memory=512Mi
  ```

### Minimal Loki Setup

  ```bash
  helm upgrade loki grafana/loki-stack \
    --namespace observability \
    --install \
    --set loki.persistence.enabled=true \
    --set loki.persistence.size=5Gi \
    --set loki.config.limits_config.retention_period=7d \
    --set loki.resources.requests.cpu=100m \
    --set loki.resources.requests.memory=128Mi \
    --set loki.resources.limits.cpu=200m \
    --set loki.resources.limits.memory=256Mi
  ```

### Minimal Grafana Setup

  ```bash
  helm upgrade grafana grafana/grafana \
    --namespace observability \
    --install \
    --set persistence.enabled=true \
    --set persistence.size=1Gi \
    --set resources.requests.cpu=50m \
    --set resources.requests.memory=64Mi \
    --set resources.limits.cpu=100m \
    --set resources.limits.memory=128Mi
  ```

By implementing these strategies, small startups can maintain effective monitoring while keeping storage usage under control.

