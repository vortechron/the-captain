# Loki-Grafana-Tempo Monitoring Stack

## Installation

### Add Grafana Helm Repository
  ```bash
  helm repo add grafana https://grafana.github.io/helm-charts
  helm repo update
  ```

### Install Loki (Log Aggregation)
  ```bash
  helm upgrade loki grafana/loki-stack --namespace=observability --create-namespace \
    --version=2.9.10 \
    --install \
    --set grafana.enabled=false \
    --set prometheus.enabled=false \
    --set tempo.enabled=false
  ```

### Install Grafana (Visualization)
  ```bash
  helm upgrade grafana grafana/grafana --namespace=observability \
    --version=6.58.6 \
    --install
  ```

### Install Promtail (Log Collection)
  ```bash
  helm upgrade promtail grafana/promtail --namespace=observability \
    --version=6.15.4 \
    --set "loki.serviceName=loki-stack" \
    --set "loki.servicePort=3100" \
    --install
  ```

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

## Uninstall Stack
  ```bash
  helm uninstall grafana -n observability
  helm uninstall loki -n observability
  helm uninstall promtail -n observability
  ```

## Troubleshooting

### View Logs
  ```bash
  kubectl logs -f -n observability --all-containers=true --since=1h --tail=100 -l app.kubernetes.io/name=grafana
  ```