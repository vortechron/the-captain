#!/bin/bash
set -e

# Check if version argument is provided
# if [ -z "$1" ]; then
#   echo "Usage: ./deploy-production.sh <version>"
#   echo "Example: ./deploy-production.sh 1.0.3"
#   exit 1
# fi

# Set image tag from command line argument
# export IMAGE_TAG="$1"
export IMAGE_TAG="1.0.0"
echo "🚀 Deploying version: $IMAGE_TAG"

# Set GCP variables
export GCP_REGION="asia-southeast1"
export GCP_PROJECT="vortechron"
export GCP_REPO="chai"

# Set Kubernetes config
export KUBECONFIG=/Users/amiruladli/.kube/vortechron-hetzner.yaml

# Set AI provider API keys (these should be set in environment before running script)
export OPENAI_API_KEY="${OPENAI_API_KEY}"
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}"
export DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY}"
export GROK_API_KEY="${GROK_API_KEY}"
export GEMINI_API_KEY="${GEMINI_API_KEY}"

# Set MinIO credentials (these should be set in environment before running script)
export MINIO_ACCESS_KEY_ID="${MINIO_ACCESS_KEY_ID}"
export MINIO_SECRET_ACCESS_KEY="${MINIO_SECRET_ACCESS_KEY}"

# Set Stripe credentials (these should be set in environment before running script)  
export STRIPE_SECRET="${STRIPE_SECRET}"

echo "📦 Building and pushing Docker images..."

# Build and push Octane image
echo "🔨 Building APP image..."
docker build \
  --platform linux/amd64 \
  -f Dockerfile.octane \
  --build-arg SSH_PRIVATE_KEY="$(cat ~/.ssh/id_rsa)" \
  -t $GCP_REGION-docker.pkg.dev/$GCP_PROJECT/$GCP_REPO/app:$IMAGE_TAG \
  .

# echo "⬆️ Pushing API image..."
docker push $GCP_REGION-docker.pkg.dev/$GCP_PROJECT/$GCP_REPO/app:$IMAGE_TAG

echo "🛥️ Deploying to Kubernetes with Helm..."

# Apply secrets and storage
echo "🔑 Applying secrets and storage..."
kubectl apply -f .helm/storage.yml

kubectl create configmap chai-app-larakube-env \
  --from-env-file=.env.production \
  --dry-run=client -o yaml | \
  kubectl label --local -f - app.kubernetes.io/managed-by=Helm -o yaml | \
  kubectl annotate --local -f - meta.helm.sh/release-name=chai-app -o yaml | \
  kubectl annotate --local -f - meta.helm.sh/release-namespace=default -o yaml | \
  kubectl apply -f -

# kubectl create secret generic chai-vonage-private-key \
#   --from-file=vonage.key \
#   --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic chai-secrets \
  --from-literal=db-password=RDhcHICH57ZAwZISmzNc \
  --from-literal=mail-password="pkhy sqcp gldq ideo" \
  --from-literal=google-client-secret="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" \
  --from-literal=stripe-secret="$STRIPE_SECRET" \
  --from-literal=openai-api-key="$OPENAI_API_KEY" \
  --from-literal=anthropic-api-key="$ANTHROPIC_API_KEY" \
  --from-literal=deepseek-api-key="$DEEPSEEK_API_KEY" \
  --from-literal=grok-api-key="$GROK_API_KEY" \
  --from-literal=gemini-api-key="$GEMINI_API_KEY" \
  --from-literal=minio-access-key-id="$MINIO_ACCESS_KEY_ID" \
  --from-literal=minio-secret-access-key="$MINIO_SECRET_ACCESS_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# Update Helm repo
# echo "📊 Updating Helm repositories..."
# helm repo add the-captain file:///Users/amiruladli/Projects/the-captain/packaged_charts
# helm repo update

# Deploy the applications
echo "🚢 Deploying APP..."
helm upgrade $GCP_REPO-app \
    -f .helm/values.yml \
    --set image.tag=$IMAGE_TAG \
    --install \
    the-captain/larakube

echo "🔄 Restarting deployments to ensure latest version..."
# kubectl rollout restart deployment $GCP_REPO-app-larakube-web
# kubectl rollout restart deployment $GCP_REPO-worker-laravel-worker

echo "✅ Deployment completed successfully!"
echo "🔍 You can check the status with: kubectl get pods" 