# Golang Helm Chart

A Helm chart for deploying Golang applications on Kubernetes.

## Introduction

This chart bootstraps a Golang application deployment on a Kubernetes cluster using the Helm package manager.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+

## Installing the Chart

To install the chart with the release name `my-golang-app`:

```bash
helm install my-golang-app ./charts/golang
```

The command deploys the Golang application on the Kubernetes cluster with default configuration. The [Parameters](#parameters) section lists the parameters that can be configured during installation.

## Uninstalling the Chart

To uninstall/delete the `my-golang-app` deployment:

```bash
helm delete my-golang-app
```

## Parameters

### Global parameters

| Name                      | Description                                     | Value |
| ------------------------- | ----------------------------------------------- | ----- |
| `replicaCount`            | Number of replicas                              | `1`   |
| `nameOverride`            | String to partially override golang.fullname    | `""`  |
| `fullnameOverride`        | String to fully override golang.fullname        | `""`  |
| `imagePullSecrets`        | Image pull secrets                              | `[]`  |

### Application parameters

| Name                         | Description                                                                                | Value                 |
| ---------------------------- | ------------------------------------------------------------------------------------------ | --------------------- |
| `app.image.repository`       | Image repository                                                                           | `""`                  |
| `app.image.tag`              | Image tag                                                                                  | `""`                  |
| `app.image.pullPolicy`       | Image pull policy                                                                          | `IfNotPresent`        |
| `app.command`                | Override default container command                                                         | `[]`                  |
| `app.envSecretName`          | Name of the secret containing environment variables                                        | `""`                  |
| `app.resources`              | Resource limits and requests                                                               | `{}`                  |
| `app.extraEnv`               | Additional environment variables                                                           | `[]`                  |
| `app.extraVolumeMounts`      | Additional volume mounts                                                                   | `[]`                  |
| `app.healthcheck.enabled`    | Enable healthcheck                                                                         | `true`                |
| `app.healthcheck.period`     | Period seconds for healthcheck                                                             | `10`                  |
| `app.healthcheck.path`       | Path for HTTP healthcheck                                                                  | `/health`             |

### Service parameters

| Name                      | Description                                     | Value       |
| ------------------------- | ----------------------------------------------- | ----------- |
| `service.type`            | Service type                                    | `ClusterIP` |
| `service.port`            | Service port                                    | `8080`      |
| `service.annotations`     | Service annotations                             | `{}`        |

### Ingress parameters

| Name                      | Description                                     | Value                    |
| ------------------------- | ----------------------------------------------- | ------------------------ |
| `ingress.enabled`         | Enable ingress                                  | `false`                  |
| `ingress.className`       | Ingress class name                              | `""`                     |
| `ingress.annotations`     | Ingress annotations                             | `{}`                     |
| `ingress.hosts`           | Ingress hosts                                   | `[{"host": "chart-example.local", "paths": [{"path": "/", "pathType": "ImplementationSpecific"}]}]` |
| `ingress.tls`             | Ingress TLS configuration                       | `[]`                     |

### ConfigMap and Secret parameters

| Name                      | Description                                     | Value       |
| ------------------------- | ----------------------------------------------- | ----------- |
| `configMap.enabled`       | Enable ConfigMap                                | `false`     |
| `configMap.data`          | ConfigMap data                                  | `{}`        |
| `secret.enabled`          | Enable Secret                                   | `false`     |
| `secret.data`             | Secret data                                     | `{}`        |

### Autoscaling parameters

| Name                                          | Description                                                            | Value   |
| --------------------------------------------- | ---------------------------------------------------------------------- | ------- |
| `autoscaling.enabled`                         | Enable autoscaling                                                     | `false` |
| `autoscaling.minReplicas`                     | Minimum number of replicas                                             | `1`     |
| `autoscaling.maxReplicas`                     | Maximum number of replicas                                             | `10`    |
| `autoscaling.targetCPUUtilizationPercentage`  | Target CPU utilization percentage                                      | `80`    |
| `autoscaling.behavior`                        | Scaling behavior                                                       | `{}`    |
| `autoscaling.customMetrics`                   | Custom metrics for autoscaling                                         | `[]`    |

### PDB parameters

| Name                      | Description                                     | Value       |
| ------------------------- | ----------------------------------------------- | ----------- |
| `pdb.enabled`             | Enable PDB                                      | `false`     |
| `pdb.minAvailable`        | Minimum available pods                          | `1`         |
| `pdb.maxUnavailable`      | Maximum unavailable pods                        | `""`        |

### RBAC parameters

| Name                      | Description                                     | Value       |
| ------------------------- | ----------------------------------------------- | ----------- |
| `rbac.create`             | Create RBAC resources                           | `false`     |
| `rbac.rules`              | RBAC rules                                      | `[]`        |
| `serviceAccount.create`   | Create service account                          | `true`      |
| `serviceAccount.annotations` | Service account annotations                  | `{}`        |
| `serviceAccount.name`     | Service account name                            | `""`        |

### Other parameters

| Name                      | Description                                     | Value       |
| ------------------------- | ----------------------------------------------- | ----------- |
| `extraVolumes`            | Extra volumes                                   | `[]`        |
| `extraContainers`         | Extra containers                                | `[]`        |
| `extraInitContainers`     | Extra init containers                           | `[]`        |
| `podAnnotations`          | Pod annotations                                 | `{}`        |
| `podSecurityContext`      | Pod security context                            | `{}`        |
| `securityContext`         | Container security context                      | `{}`        |
| `nodeSelector`            | Node selector                                   | `{}`        |
| `tolerations`             | Tolerations                                     | `[]`        |
| `affinity`                | Affinity                                        | `{}`        |

## Example

```yaml
# values.yaml
replicaCount: 2

app:
  image:
    repository: my-golang-app
    tag: "1.0.0"
  
  envSecretName: "my-golang-env"
  
  extraEnv:
    - name: DEBUG
      value: "false"
    - name: LOG_LEVEL
      value: "info"

ingress:
  enabled: true
  hosts:
    - host: my-golang-app.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Creating Environment Variables Secret

Create a secret for your environment variables:

```bash
kubectl create secret generic my-golang-env \
  --from-literal=API_KEY=your-api-key \
  --from-literal=DATABASE_URL=your-database-url
```

Then reference it in your values:

```yaml
app:
  envSecretName: "my-golang-env"
``` 