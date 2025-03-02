# Golang Gin API Application

This is a simple Golang Gin API application that can serve both API endpoints and web content. This example demonstrates how to build, deploy, and manage a Golang application using Docker and Kubernetes with Helm.

## Project Structure

```
.
├── .helm/                  # Helm deployment files
│   ├── deploy.sh           # Deployment script
│   └── values.yaml         # Helm values for deployment
├── Dockerfile              # Docker image definition
├── go.mod                  # Go module definition
├── go.sum                  # Go module checksums
├── main.go                 # Main application code
└── README.md               # This file
```

## Features

- RESTful API endpoints using Gin framework
- Health check endpoint for Kubernetes probes
- Environment variable configuration
- Docker containerization
- Kubernetes deployment with Helm

## API Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check endpoint
- `GET /api/hello` - Sample API endpoint returning "Hello, World!"
- `GET /api/ping` - Sample API endpoint returning "pong"

## Prerequisites

- Docker
- Kubernetes cluster
- Helm
- Go 1.21 or later (for local development)

## Local Development

1. Clone the repository
2. Install dependencies:
   ```bash
   go mod download
   ```
3. Run the application:
   ```bash
   go run main.go
   ```
4. Access the API at http://localhost:8080

## Building the Docker Image

Build the Docker image using the provided Dockerfile:

```bash
docker build -t golang-example .
```

Run the container locally:

```bash
docker run -p 8080:8080 golang-example
```

## Deploying to Kubernetes

### Using the Deployment Script

The easiest way to deploy is using the provided script:

```bash
cd .helm
./deploy.sh --namespace my-namespace
```

### Manual Deployment with Helm

1. Navigate to the `.helm` directory:
   ```bash
   cd .helm
   ```

2. Deploy using Helm:
   ```bash
   helm upgrade --install golang-example ../../charts/golang \
     --namespace my-namespace \
     --values values.yaml
   ```

3. Check the deployment status:
   ```bash
   kubectl get pods -n my-namespace
   ```

## Configuration

The application can be configured using environment variables:

- `PORT` - The port to listen on (default: 8080)
- `GIN_MODE` - Gin mode (debug, release, test) (default: release)

These can be set in the Helm values file under the `env` section.

## Customizing the Helm Deployment

Edit the `.helm/values.yaml` file to customize your deployment:

- Change the image repository and tag
- Adjust resource limits and requests
- Configure ingress settings
- Add environment variables
- Set up ConfigMaps and Secrets

## Scaling

The application can be scaled manually:

```bash
kubectl scale deployment golang-example --replicas=3 -n my-namespace
```

Or enable autoscaling in the Helm values:

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

## Troubleshooting

- Check pod logs:
  ```bash
  kubectl logs -f deployment/golang-example -n my-namespace
  ```

- Check pod status:
  ```bash
  kubectl describe pod -l app.kubernetes.io/name=golang -n my-namespace
  ```

- Port forward to test locally:
  ```bash
  kubectl port-forward svc/golang-example 8080:8080 -n my-namespace
  ```

## License

MIT