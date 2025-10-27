# DigitalOcean Kubernetes Setup Guide

## Initial Setup

### Install doctl
  ```bash
  brew install doctl
  ```

### Login to DigitalOcean
  ```bash
  doctl auth init
  ```

### Configure Kubernetes
  ```bash
  doctl kubernetes cluster kubeconfig save 8d3b8269-750d-4fa0-84ad-aeb9a20bb746
  ```

## Package Management

### Install Helm
  ```bash
  brew install helm
  ```

## Google Cloud Artifact Registry Setup

1. In Google Cloud Console:
   - Navigate to IAM & Admin → Service Accounts
   - Create a service account (e.g., do-image-puller)
   - Assign the Artifact Registry Reader role (roles/artifactregistry.reader)
   - Generate and download JSON key


  // add iam policy binding so that cicd can push image to artifact registry
   ```bash
   gcloud artifacts repositories add-iam-policy-binding algo \
    --location=asia-southeast1 \
    --project=vortechron \
    --member=serviceAccount:do-image-puller@vortechron.iam.gserviceaccount.com \
    --role=roles/artifactregistry.writer
   ```

2. Create Kubernetes Secret:
  ```bash
  kubectl create secret docker-registry gcp-artifact-registry-secret \
    --docker-server="asia-southeast1-docker.pkg.dev" \
    --docker-username=_json_key \
    --docker-password="$(cat k8s/credentials/vortechron-644c486fcd80.json)" \
    --docker-email="sayaamiruladli@gmail.com"
  ```

3. Verify Secret:
  ```bash
  kubectl get secret gcp-artifact-registry-secret --output=yaml
  ```

4. Reference in Deployments:
  ```yaml
  imagePullSecrets:
    - name: gcp-artifact-registry-secret
  ```

5. Apply Secret:
  ```bash
  kubectl apply -f helm/mysql/secret.yaml
  ```

## Deployment

### Apply Infrastructure
  ```bash
  kubectl apply -R -f infra
  ```

## HTTPS and Domain Configuration

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

then apply issuer


1. Install Ingress Controller:
  ```bash
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace
  ```

2. DNS Configuration:
   - Add domain to DNS records
   - Set TTL to 30 seconds

3. Install and Configure cert-manager:
  ```bash
  # Verify installation
  kubectl get all -n cert-manager
  
  # Apply cluster issuer
  kubectl apply -f k8s/infra/cert-manager/issuer.yml
  
  # Verify issuer
  kubectl get issuer
  
  # Apply ingress configuration
  kubectl apply -f infra/ingress/ingress.yml
  ```

## Metrics API Setup

1. Add metrics-server using Helm:
  ```bash
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
  
  helm upgrade --install metrics-server metrics-server/metrics-server \
    --namespace observability \
    --set args="{--kubelet-preferred-address-types=InternalIP}" \
    --set apiService.create=true
  ```

2. Verify Installation:
  ```bash
  kubectl get deployment metrics-server -n kube-system
  
  # Test metrics collection
  kubectl top nodes
  kubectl top pods
  ```
