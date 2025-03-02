#!/bin/bash

# Exit on error
set -e

# Default values
NAMESPACE="default"
RELEASE_NAME="golang-example"
VALUES_FILE="values.yaml"
CHART_PATH="../../charts/golang"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -n|--namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    -r|--release)
      RELEASE_NAME="$2"
      shift
      shift
      ;;
    -f|--values)
      VALUES_FILE="$2"
      shift
      shift
      ;;
    -c|--chart)
      CHART_PATH="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if namespace exists, create if not
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
  echo "Creating namespace: $NAMESPACE"
  kubectl create namespace $NAMESPACE
fi

# Deploy using Helm
echo "Deploying $RELEASE_NAME to namespace $NAMESPACE using values from $VALUES_FILE"
helm upgrade --install $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  --values $VALUES_FILE \
  --wait

echo "Deployment complete!"
echo "To access the application, run:"
echo "  kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME 8080:8080"
echo "Then visit http://localhost:8080 in your browser." 