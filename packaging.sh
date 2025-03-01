#!/bin/bash

# Set working directory to the script's location
cd "$(dirname "$0")"

# Ensure charts directory exists
CHARTS_DIR="charts"
if [ ! -d "$CHARTS_DIR" ]; then
  echo "Error: '$CHARTS_DIR' directory not found!"
  exit 1
fi

# Create a directory for packaged charts if it doesn't exist
PACKAGED_DIR="packaged_charts"
rm -rf "$PACKAGED_DIR"
mkdir -p "$PACKAGED_DIR"

# Package all Helm charts in the charts/ directory
echo "Packaging Helm charts..."
for chart in "$CHARTS_DIR"/*/; do
  if [ -f "$chart/Chart.yaml" ]; then
    helm package "$chart" --destination "$PACKAGED_DIR"
  else
    echo "Skipping '$chart' (no Chart.yaml found)"
  fi
done

# Generate/update the Helm repository index
echo "Generating Helm repository index..."
helm repo index "$PACKAGED_DIR"

# Output completion message
echo "Packaging complete! Charts are stored in '$PACKAGED_DIR'."
