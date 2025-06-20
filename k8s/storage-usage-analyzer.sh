#!/bin/bash
# storage-usage-analyzer.sh
# This script analyzes Kubernetes storage usage and outputs a sorted list of resources using the most storage

set -e

# Set some colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default values
SPECIFIED_NAMESPACE=""

# Help function
show_help() {
  echo -e "${BOLD}Kubernetes Storage Usage Analyzer${NC}"
  echo
  echo "This tool analyzes storage usage across your Kubernetes cluster,"
  echo "showing pods, PVCs, and other resources using the most storage."
  echo
  echo -e "${BOLD}Usage:${NC}"
  echo "  ./storage-usage-analyzer.sh [options]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo "  --namespace=NAMESPACE, -n NAMESPACE  Analyze a specific namespace only"
  echo "  --help, -h                          Show this help message"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo "  ./storage-usage-analyzer.sh                  # Analyze entire cluster"
  echo "  ./storage-usage-analyzer.sh -n kube-system   # Analyze kube-system namespace only"
  echo "  ./storage-usage-analyzer.sh --namespace=monitoring # Analyze monitoring namespace" 
  echo
  echo -e "${BOLD}Requirements:${NC}"
  echo "  - kubectl with cluster access"
  echo "  - jq for JSON processing"
  echo "  - bc for calculations"
  echo
  exit 0
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --help|-h) show_help ;;
        --namespace=*) SPECIFIED_NAMESPACE="${1#*=}"; shift ;;
        -n=*) SPECIFIED_NAMESPACE="${1#*=}"; shift ;;
        -n) SPECIFIED_NAMESPACE="$2"; shift 2 ;;
        *) echo "Unknown parameter: $1"; echo "Use --help for usage information"; exit 1 ;;
    esac
done

echo -e "${BOLD}Kubernetes Storage Usage Analyzer${NC}"
echo "Analyzing storage usage in the cluster..."
if [ -n "$SPECIFIED_NAMESPACE" ]; then
  echo "Filtering for namespace: $SPECIFIED_NAMESPACE"
fi
echo

# Function to print a separator line
separator() {
  echo -e "${YELLOW}--------------------------------------------------------${NC}"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}Error: kubectl is not installed. Please install it first.${NC}"
  exit 1
fi

# Check if user is authenticated to the cluster
if ! kubectl auth can-i get nodes &> /dev/null; then
  echo -e "${RED}Error: You don't have permission to access the cluster or you're not authenticated.${NC}"
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is not installed. Please install it first.${NC}"
  exit 1
fi

# Check if bc is installed
if ! command -v bc &> /dev/null; then
  echo -e "${RED}Error: bc is not installed. Please install it first.${NC}"
  exit 1
fi

# Get namespaces
echo -e "${BOLD}Fetching namespaces...${NC}"
if [ -n "$SPECIFIED_NAMESPACE" ]; then
  # Check if the specified namespace exists
  if ! kubectl get namespace "$SPECIFIED_NAMESPACE" &> /dev/null; then
    echo -e "${RED}Error: Namespace '$SPECIFIED_NAMESPACE' does not exist.${NC}"
    exit 1
  fi
  NAMESPACES="$SPECIFIED_NAMESPACE"
  echo "Analyzing namespace: $SPECIFIED_NAMESPACE"
else
  NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')
  echo "Found $(echo $NAMESPACES | wc -w | xargs) namespaces"
fi

# Create a temporary file to store our results
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

separator
echo -e "${BOLD}1. Persistent Volume Claims (PVCs) by Size${NC}"
echo

echo -e "NAMESPACE,PVC_NAME,SIZE,STORAGE_CLASS,STATUS" > $TEMP_FILE
for ns in $NAMESPACES; do
  kubectl get pvc -n $ns -o json | jq -r '.items[] | [.metadata.namespace, .metadata.name, .spec.resources.requests.storage, .spec.storageClassName, .status.phase] | join(",")' 2>/dev/null >> $TEMP_FILE || true
done

# Sort by storage size in descending order and display
if [ -s "$TEMP_FILE" ]; then
  # Add a header
  echo -e "${BOLD}NAMESPACE\tPVC NAME\t\tSIZE\t\tSTORAGE CLASS\tSTATUS${NC}"
  
  # Skip the first line (header) and sort by the third field (size)
  tail -n +2 $TEMP_FILE | sort -t ',' -k3 -hr | while IFS=, read -r ns name size class status; do
    size_num=$(echo $size | sed 's/[^0-9]*//g')
    unit=$(echo $size | sed 's/[0-9]*//g')
    
    # Color-code by size
    if [[ $size == *"Ti"* ]] || [[ $size == *"Gi"* && $size_num -gt 10 ]]; then
      COLOR=$RED
    elif [[ $size == *"Gi"* && $size_num -gt 1 ]]; then
      COLOR=$YELLOW
    else
      COLOR=$GREEN
    fi
    
    printf "${COLOR}%s\t%-20s\t%-10s\t%-15s\t%s${NC}\n" "$ns" "$name" "$size" "$class" "$status"
  done
else
  echo "No PVCs found in the cluster."
fi

echo
separator
echo -e "${BOLD}2. Pods Using the Most Storage (by PVC Mounts)${NC}"
echo

echo -e "NAMESPACE,POD_NAME,VOLUME_NAME,PVC_NAME,SIZE" > $TEMP_FILE
for ns in $NAMESPACES; do
  # Get all pods in the namespace
  pods=$(kubectl get pods -n $ns -o name 2>/dev/null) || continue
  
  for pod in $pods; do
    pod_name=${pod#pod/}
    volumes=$(kubectl get pod $pod_name -n $ns -o json 2>/dev/null | \
      jq -r '.spec.volumes[] | select(.persistentVolumeClaim != null) | [.name, .persistentVolumeClaim.claimName] | join(",")' 2>/dev/null) || continue
    
    while IFS=, read -r vol_name pvc_name; do
      [ -z "$vol_name" ] && continue
      echo "$ns,$pod_name,$vol_name,$pvc_name," >> $TEMP_FILE
    done <<< "$volumes"
  done
done

if [ -s "$TEMP_FILE" ]; then
  echo -e "${BOLD}NAMESPACE\tPOD NAME\t\tVOLUME NAME\t\tPVC NAME\t\tSIZE${NC}"
  
  # Join with PVC sizes and sort
  while IFS=, read -r ns pod_name vol_name pvc_name _; do
    # Skip header
    if [[ "$ns" == "NAMESPACE" ]]; then
      continue
    fi
    
    # Get PVC size
    pvc_size=$(kubectl get pvc -n $ns $pvc_name -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null || echo "N/A")
    
    # Color-code by size
    if [[ $pvc_size == *"Ti"* ]] || [[ $pvc_size == *"Gi"* && ${pvc_size//[^0-9]/} -gt 10 ]]; then
      COLOR=$RED
    elif [[ $pvc_size == *"Gi"* && ${pvc_size//[^0-9]/} -gt 1 ]]; then
      COLOR=$YELLOW
    else
      COLOR=$GREEN
    fi
    
    printf "${COLOR}%s\t%-20s\t%-20s\t%-20s\t%s${NC}\n" "$ns" "$pod_name" "$vol_name" "$pvc_name" "$pvc_size"
  done < $TEMP_FILE | sort -k5 -hr
else
  echo "No pods with PVC mounts found in the cluster."
fi

echo
separator
echo -e "${BOLD}3. Current Storage Usage (where metrics are available)${NC}"
echo

# Try to get actual PV usage from metrics if available
echo -e "NAMESPACE,POD_NAME,EPHEMERAL_STORAGE" > $TEMP_FILE
if kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods &>/dev/null; then
  for ns in $NAMESPACES; do
    kubectl get --raw "/apis/metrics.k8s.io/v1beta1/namespaces/$ns/pods" 2>/dev/null | \
    jq -r '.items[] | select(.containers[].usage | has("ephemeral-storage")) | 
      .metadata.namespace as $ns | 
      .metadata.name as $name |
      [($ns), ($name), ([.containers[].usage."ephemeral-storage"] | map(tonumber) | add | tostring)] | 
      join(",")' >> $TEMP_FILE || true
  done
  
  if [ -s "$TEMP_FILE" ] && [ "$(wc -l < $TEMP_FILE)" -gt 1 ]; then
    echo -e "${BOLD}NAMESPACE\tPOD NAME\t\tEPHEMERAL STORAGE USAGE${NC}"
    
    # Sort and display pods by ephemeral storage usage
    tail -n +2 $TEMP_FILE | sort -t ',' -k3 -hr | while IFS=, read -r ns pod_name storage; do
      # Convert storage to a readable format
      if [[ $storage -gt 1073741824 ]]; then # > 1Gi
        readable_storage=$(bc <<< "scale=2; $storage/1073741824")
        unit="Gi"
        COLOR=$RED
      elif [[ $storage -gt 104857600 ]]; then # > 100Mi
        readable_storage=$(bc <<< "scale=2; $storage/1048576")
        unit="Mi"
        COLOR=$YELLOW
      else
        readable_storage=$(bc <<< "scale=2; $storage/1048576")
        unit="Mi"
        COLOR=$GREEN
      fi
      
      printf "${COLOR}%s\t%-20s\t%s %s${NC}\n" "$ns" "$pod_name" "$readable_storage" "$unit"
    done
  else
    echo "No ephemeral storage metrics available."
  fi
else
  echo "Metrics API not available. Install metrics server for detailed usage data."
fi

echo
separator
echo -e "${BOLD}4. StatefulSets and Their Storage${NC}"
echo

echo -e "NAMESPACE,STATEFULSET_NAME,VOLUME_CLAIM_TEMPLATE,SIZE" > $TEMP_FILE
for ns in $NAMESPACES; do
  kubectl get statefulset -n $ns -o json 2>/dev/null | \
  jq -r '.items[] | .metadata.namespace as $ns | .metadata.name as $name | 
    select(.spec.volumeClaimTemplates != null) | 
    .spec.volumeClaimTemplates[] | 
    [$ns, $name, .metadata.name, .spec.resources.requests.storage] | 
    join(",")' >> $TEMP_FILE || true
done

if [ -s "$TEMP_FILE" ]; then
  echo -e "${BOLD}NAMESPACE\tSTATEFULSET NAME\t\tVOLUME CLAIM TEMPLATE\tSIZE${NC}"
  
  # Sort by size
  tail -n +2 $TEMP_FILE | sort -t ',' -k4 -hr | while IFS=, read -r ns name template size; do
    # Color-code by size
    if [[ $size == *"Ti"* ]] || [[ $size == *"Gi"* && ${size//[^0-9]/} -gt 10 ]]; then
      COLOR=$RED
    elif [[ $size == *"Gi"* && ${size//[^0-9]/} -gt 1 ]]; then
      COLOR=$YELLOW
    else
      COLOR=$GREEN
    fi
    
    printf "${COLOR}%s\t%-20s\t%-20s\t%s${NC}\n" "$ns" "$name" "$template" "$size"
  done
else
  echo "No StatefulSets with VolumeClaimTemplates found in the cluster."
fi

# Skip node information if a specific namespace was provided
if [ -z "$SPECIFIED_NAMESPACE" ]; then
  echo
  separator
  echo -e "${BOLD}5. Node Filesystem Usage${NC}"
  echo
  
  # Try to get node filesystem metrics from metrics-server
  NODE_STORAGE_FILE=$(mktemp)
  trap "rm -f $NODE_STORAGE_FILE $TEMP_FILE" EXIT
  
  if kubectl get nodes -o name &>/dev/null; then
    kubectl top nodes 2>/dev/null > $NODE_STORAGE_FILE
    
    if [ -s "$NODE_STORAGE_FILE" ]; then
      echo -e "${BOLD}NODE NAME\t\t\tCPU\t\tMEMORY\tDISK${NC}"
      
      # Skip header and sort by CPU/Memory
      tail -n +2 $NODE_STORAGE_FILE | sort -k4 -hr | while read -r node cpu cpu_p mem mem_p; do
        if [[ $mem_p == *"%"* ]]; then
          mem_value=${mem_p//%/}
          if [[ $mem_value -gt 85 ]]; then
            COLOR=$RED
          elif [[ $mem_value -gt 70 ]]; then
            COLOR=$YELLOW
          else
            COLOR=$GREEN
          fi
        else
          COLOR=$NC
        fi
        
        # Try to get filesystem usage
        node_short=${node#node/}
        disk_usage=$(kubectl get --raw /api/v1/nodes/$node_short/proxy/metrics/cadvisor | grep 'container_fs_usage_bytes{' | grep -v kubepods | head -1 | awk '{print $2}' 2>/dev/null || echo "N/A")
        
        if [[ "$disk_usage" != "N/A" ]]; then
          # Convert to GiB
          disk_usage_gi=$(echo "scale=2; $disk_usage/1073741824" | bc)
          disk_info="${disk_usage_gi}Gi"
        else
          disk_info="N/A"
        fi
        
        printf "${COLOR}%-25s\t%s(%s)\t%s(%s)\t%s${NC}\n" "$node" "$cpu" "$cpu_p" "$mem" "$mem_p" "$disk_info"
      done
    else
      echo "No node metrics available. Make sure metrics-server is installed."
      
      # Alternative: try to get disk usage from nodes directly
      echo -e "${BOLD}NODE NAME\t\t\tROOT DISK USAGE${NC}"
      for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        usage=$(kubectl debug node/$node --image=busybox -- df -h /host 2>/dev/null | grep -v Filesystem | grep "/" | head -1 || echo "N/A")
        if [[ "$usage" != "N/A" ]]; then
          usage_percent=$(echo $usage | awk '{print $5}')
          usage_value=${usage_percent//%/}
          
          if [[ $usage_value -gt 85 ]]; then
            COLOR=$RED
          elif [[ $usage_value -gt 70 ]]; then
            COLOR=$YELLOW
          else
            COLOR=$GREEN
          fi
          
          size=$(echo $usage | awk '{print $2}')
          used=$(echo $usage | awk '{print $3}')
          avail=$(echo $usage | awk '{print $4}')
          
          printf "${COLOR}%-25s\t%s/%s (%s used, %s avail)${NC}\n" "$node" "$used" "$size" "$usage_percent" "$avail"
        else
          printf "${NC}%-25s\tUnable to get disk usage${NC}\n" "$node"
        fi
      done
    fi
  else
    echo "Unable to get node information. Check your permissions."
  fi
fi

echo 
separator
echo -e "${BOLD}Storage Usage Summary Completed${NC}"
echo "For more detailed analysis, consider installing the Kubernetes metrics-server"
echo "or tools like Prometheus with node-exporter and kube-state-metrics." 