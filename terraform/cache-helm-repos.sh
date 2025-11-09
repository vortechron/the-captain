#!/bin/bash
# Cache Helm repositories to speed up Terraform applies
# This script adds and updates all Helm repositories used by Terraform

set -e

echo "🔄 Caching Helm repositories for faster Terraform applies..."
echo ""

# List of Helm repositories used in Terraform
REPOS=(
  "https://kubernetes.github.io/ingress-nginx|ingress-nginx"
  "https://charts.jetstack.io|cert-manager"
  "https://grafana.github.io/helm-charts|grafana"
  "https://prometheus-community.github.io/helm-charts|prometheus-community"
  "https://percona.github.io/percona-helm-charts/|percona"
)

for REPO in "${REPOS[@]}"; do
  URL=$(echo $REPO | cut -d'|' -f1)
  NAME=$(echo $REPO | cut -d'|' -f2)
  
  echo "📦 Adding/updating repository: $NAME"
  helm repo add "$NAME" "$URL" 2>/dev/null || helm repo update "$NAME"
done

echo ""
echo "🔄 Updating all repositories..."
helm repo update

echo ""
echo "✅ Helm repositories cached successfully!"
echo ""
echo "💡 Tip: Run this script before 'terraform apply' to avoid 30-60s delays per Helm release"
echo "💡 You can also add this to your CI/CD pipeline or run it periodically"

