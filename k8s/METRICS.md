# Kubernetes Metrics Monitoring

This guide explains how to set up comprehensive metrics monitoring for your Kubernetes cluster using Prometheus with the existing Grafana installation.

## Overview

A complete metrics monitoring solution for Kubernetes includes:

1. **Prometheus** - For metrics collection and storage
2. **Grafana** - For metrics visualization (already installed, see [LGTM.md](LGTM.md))
3. **kube-state-metrics** - For Kubernetes object metrics
4. **node-exporter** - For node-level metrics

## Installation

### Prerequisites

- Kubernetes cluster running version 1.16+
- Helm 3 installed
- `kubectl` configured to communicate with your cluster
- Grafana already installed in the `observability` namespace (as per [LGTM.md](LGTM.md))

### Install Prometheus and Exporters

Since Grafana is already installed, we'll install only Prometheus and the necessary exporters:

  ```bash
  # Add Prometheus community Helm repository
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update

  # Install Prometheus (includes node-exporter and kube-state-metrics)
  helm install prometheus prometheus-community/prometheus \
    --namespace observability \
    --set server.persistentVolume.enabled=true \
    --set server.persistentVolume.size=10Gi
  
  # If needed, install kube-state-metrics separately (not necessary if installed with Prometheus)
  # helm install kube-state-metrics prometheus-community/kube-state-metrics \
  #   --namespace observability
  
  # Note: node-exporter is already included in the Prometheus chart
  # Do not install node-exporter separately as it will conflict with the one included in Prometheus
  # If you did, uninstall it with: helm uninstall node-exporter -n observability
  ```

Notes after installation:

prom
```
The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
prometheus-server.observability.svc.cluster.local


Get the Prometheus server URL by running these commands in the same shell:
  export POD_NAME=$(kubectl get pods --namespace observability -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
  kubectl --namespace observability port-forward $POD_NAME 9090


The Prometheus alertmanager can be accessed via port 9093 on the following DNS name from within your cluster:
prometheus-alertmanager.observability.svc.cluster.local


Get the Alertmanager URL by running these commands in the same shell:
  export POD_NAME=$(kubectl get pods --namespace observability -l "app.kubernetes.io/name=alertmanager,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
  kubectl --namespace observability port-forward $POD_NAME 9093
#################################################################################
######   WARNING: Pod Security Policy has been disabled by default since    #####
######            it deprecated after k8s 1.25+. use                        #####
######            (index .Values "prometheus-node-exporter" "rbac"          #####
###### .          "pspEnabled") with (index .Values                         #####
######            "prometheus-node-exporter" "rbac" "pspAnnotations")       #####
######            in case you still need it.                                #####
#################################################################################


The Prometheus PushGateway can be accessed via port 9091 on the following DNS name from within your cluster:
prometheus-prometheus-pushgateway.observability.svc.cluster.local


Get the PushGateway URL by running these commands in the same shell:
  export POD_NAME=$(kubectl get pods --namespace observability -l "app=prometheus-pushgateway,component=pushgateway" -o jsonpath="{.items[0].metadata.name}")
  kubectl --namespace observability port-forward $POD_NAME 9091
```

```
kube-state-metrics is a simple service that listens to the Kubernetes API server and generates metrics about the state of the objects.
The exposed metrics can be found here:
https://github.com/kubernetes/kube-state-metrics/blob/master/docs/README.md#exposed-metrics

The metrics are exported on the HTTP endpoint /metrics on the listening port.
In your case, kube-state-metrics.observability.svc.cluster.local:8080/metrics

They are served either as plaintext or protobuf depending on the Accept header.
They are designed to be consumed either by Prometheus itself or by a scraper that is compatible with scraping a Prometheus client endpoint.
```

```
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace observability -l "app.kubernetes.io/name=prometheus-node-exporter,app.kubernetes.io/instance=node-exporter" -o jsonpath="{.items[0].metadata.name}")
  echo "Visit http://127.0.0.1:9100 to use your application"
  kubectl port-forward --namespace observability $POD_NAME 9100
```

### Verify Installation

  ```bash
  # Check if all pods are running
  kubectl get pods -n observability -l "app=prometheus"
  kubectl get pods -n observability -l "app.kubernetes.io/name=kube-state-metrics"
  kubectl get pods -n observability -l "app.kubernetes.io/name=prometheus-node-exporter"
  ```

## Configure Grafana to Use Prometheus

### Add Prometheus as a Data Source in Grafana

1. Access your existing Grafana instance (see [LGTM.md](LGTM.md) for access instructions)
2. Navigate to Configuration > Data Sources
3. Click "Add data source"
4. Select "Prometheus"
5. Set the URL to `http://prometheus-server.observability.svc.cluster.local`
6. Click "Save & Test"

## Expose Prometheus via Ingress (Optional)

  ```bash
  cat <<EOF | kubectl apply -f -
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: prometheus-ingress
    namespace: observability
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
  spec:
    tls:
      - hosts:
          - prometheus.yourdomain.com
        secretName: prometheus-tls
    rules:
      - host: prometheus.yourdomain.com
        http:
          paths:
            - path: /
              pathType: Prefix
              backend:
                service:
                  name: prometheus-server
                  port:
                    number: 80
  EOF
  ```

## Important Metrics to Monitor

### Cluster Health
- Node status
- Pod status
- Deployment status
- Resource utilization (CPU, Memory)

### Node Metrics
- CPU usage
- Memory usage
- Disk I/O
- Network I/O

### Pod Metrics
- CPU/Memory requests vs limits
- Restart count
- Ready status

### Application Metrics
- Request rate
- Error rate
- Latency
- Saturation

## Useful Grafana Dashboards

Import these dashboard IDs in your existing Grafana:

1. Kubernetes Cluster Overview: 10856
2. Node Exporter Full: 1860
3. Kubernetes Capacity Planning: 5228
4. Kubernetes Resource Requests: 13770

To import a dashboard:
1. Go to Grafana
2. Click on "+" icon and select "Import"
3. Enter the dashboard ID
4. Select the Prometheus data source you configured

## Integration with Loki

Your existing Loki installation (as per [LGTM.md](LGTM.md)) can be used alongside Prometheus for a complete observability stack:
- Prometheus: metrics
- Loki: logs

This provides a comprehensive monitoring solution with both metrics and logs in a single Grafana interface.

## Troubleshooting

### Common Issues

1. **Prometheus targets down**:
   ```bash
   kubectl get endpoints -n observability prometheus-server
   kubectl describe endpoints -n observability prometheus-server
   ```

2. **Grafana can't connect to Prometheus**:
   - Verify the Prometheus service name and port
   - Check network policies if applicable
   - Ensure the URL in the Grafana data source is correct

3. **Resource constraints**:
   ```bash
   kubectl top nodes
   kubectl top pods -n observability
   ```

4. **Pending node-exporter pods**:
   - If you see pending node-exporter pods with the error "node(s) didn't have free ports", you might have installed node-exporter twice.
   - The Prometheus chart already includes node-exporter, so installing it separately will cause conflicts.
   - Fix by uninstalling the separate node-exporter: `helm uninstall node-exporter -n observability`

### View Component Logs

  ```bash
  # Prometheus logs
  kubectl logs -f -n observability -l "app=prometheus,component=server"
  
  # kube-state-metrics logs
  kubectl logs -f -n observability -l "app.kubernetes.io/name=kube-state-metrics"
  ```

## Uninstall

If needed, you can uninstall the Prometheus components while keeping Grafana:

  ```bash
  # Uninstall Prometheus
  helm uninstall prometheus -n observability
  
  # Uninstall kube-state-metrics
  helm uninstall kube-state-metrics -n observability
  
  # Uninstall node-exporter
  helm uninstall node-exporter -n observability
  ```

Note: This will not affect your existing Grafana and Loki installations.

