# Kubernetes Tools

This directory contains several useful tools and scripts for managing Kubernetes clusters, particularly focused on helping with storage management, monitoring, and common administrative tasks.

## Available Tools

- **[Storage Usage Analyzer](STORAGE_ANALYZER.md)**: Find which pods and PVCs are using the most storage in your cluster
- **Storage Management Guides**: Best practices for managing storage in Kubernetes ([STORAGE.md](STORAGE.md))
- **Monitoring Setup**: Guidelines for setting up metrics in Kubernetes ([METRICS.md](METRICS.md))
- **Database Tools**: Quick reference for MySQL ([MYSQL.md](MYSQL.md)) and Redis ([REDIS.md](REDIS.md)) in Kubernetes

## Storage Usage Analyzer

The storage analyzer is a powerful tool that helps you identify which Kubernetes resources are consuming the most storage in your cluster. This can help you:

- Find pods that might be wasting resources
- Identify PVCs that could be resized
- Pinpoint StatefulSets with excessive storage requirements
- Monitor node-level disk usage
- Track ephemeral storage consumption

### Quick Start

1. Make the script executable:

```bash
chmod +x storage-usage-analyzer.sh
```

2. Run the analyzer:

```bash
./storage-usage-analyzer.sh
```

3. For a specific namespace:

```bash
./storage-usage-analyzer.sh --namespace=my-namespace
```

### Example Output

```
Kubernetes Storage Usage Analyzer
Analyzing storage usage in the cluster...

Fetching namespaces...
Found 3 namespaces
--------------------------------------------------------
1. Persistent Volume Claims (PVCs) by Size

NAMESPACE       PVC NAME                SIZE            STORAGE CLASS    STATUS
database        mysql-data              10Gi            standard         Bound
monitoring      prometheus-data         8Gi             standard         Bound
app             application-data        2Gi             standard         Bound

--------------------------------------------------------
2. Pods Using the Most Storage (by PVC Mounts)

NAMESPACE       POD NAME                VOLUME NAME             PVC NAME                SIZE
database        mysql-0                 data                    mysql-data              10Gi
monitoring      prometheus-server-0     prometheus-storage      prometheus-data         8Gi
app             app-deployment-abcd1    app-storage             application-data        2Gi
```

### Prerequisites

- `kubectl` installed and configured
- `jq` for JSON processing
- `bc` for calculations

For detailed metrics:
- Kubernetes metrics-server installed

## Future Tools (Coming Soon)

We're working on additional tools:

- Log rotation and management scripts
- Backup and restore automation
- Cluster maintenance helpers
- Deployment automation templates

## Contributing

Feel free to add your own scripts and tools to this directory. Please follow these guidelines:

1. Create thorough documentation
2. Include usage examples
3. Add error handling
4. Test thoroughly before submitting
5. Add a mention of your tool to this README 