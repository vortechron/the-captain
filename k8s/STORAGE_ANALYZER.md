# Kubernetes Storage Usage Analyzer

This tool helps you analyze storage usage across your Kubernetes cluster, identifying which pods, PVCs, and nodes are using the most storage space.

## Features

The analyzer provides the following information:

- **Persistent Volume Claims (PVCs)** sorted by size
- **Pods Using Storage** via PVC mounts, sorted by usage
- **Current Ephemeral Storage Usage** for pods (requires metrics-server)
- **StatefulSets and Their Storage** requirements
- **Node Filesystem Usage** for all cluster nodes

## Requirements

- `kubectl` installed and configured to access your cluster
- `jq` for JSON processing
- `bc` for simple calculations
- Proper RBAC permissions to read cluster resources
- For detailed metrics: Kubernetes metrics-server installed

## Usage

Simply run the script from the command line:

```bash
./storage-usage-analyzer.sh
```

You can also specify a namespace to analyze only that namespace:

```bash
./storage-usage-analyzer.sh --namespace=my-namespace
```

## Output Example

The tool produces color-coded output based on storage usage:
- **Red**: High storage usage (10Gi+ or TiB scale)
- **Yellow**: Medium storage usage (1-10Gi)
- **Green**: Low storage usage (<1Gi)

Example output:

```
Kubernetes Storage Usage Analyzer
Analyzing storage usage in the cluster...

Fetching namespaces...
Found 6 namespaces
--------------------------------------------------------
1. Persistent Volume Claims (PVCs) by Size

NAMESPACE       PVC NAME                SIZE            STORAGE CLASS    STATUS
monitoring      prometheus-data         50Gi            standard         Bound
database        postgres-data           20Gi            ssd              Bound
app             app-storage             5Gi             standard         Bound
...

--------------------------------------------------------
2. Pods Using the Most Storage (by PVC Mounts)

NAMESPACE       POD NAME                VOLUME NAME             PVC NAME                SIZE
monitoring      prometheus-0            data                    prometheus-data         50Gi
database        postgres-0              postgres-storage        postgres-data           20Gi
...
```

## Extending the Script

You can customize and extend this script for your specific needs:

- Add support for storage usage trends over time
- Integrate with Prometheus for historical data
- Add alerts for high storage usage
- Generate reports in different formats (JSON, CSV)

## Troubleshooting

If you encounter errors:

1. **Permission issues** - Make sure you have proper RBAC permissions
2. **Missing metrics** - Install the Kubernetes metrics-server
3. **jq or bc not found** - Install these utilities
4. **No data in certain sections** - Some metrics may require additional components
   
## Additional Tools

For more comprehensive storage monitoring, consider:

- Installing the Kubernetes metrics-server
- Setting up Prometheus with node-exporter
- Using Grafana for visualization
- Implementing a proper logging solution (e.g., ELK stack)

## Notes on Storage Management

After identifying your storage usage patterns:

1. **Right-size your PVCs** - Adjust the size of your PVCs based on actual usage
2. **Implement storage quotas** - Set up namespace quotas to prevent overconsumption
3. **Clean up unused PVCs** - Regularly check for and remove unused PVCs
4. **Optimize StatefulSet storage** - Review and optimize storage for StatefulSets
5. **Consider storage classes** - Use appropriate storage classes for different workloads 