# The Captain - Kubernetes & Helm Tools

## Helm Charts

### Installation

To install the charts repository (locally):

- git clone this repo

  // locally
  ```bash
  $ helm plugin add https://github.com/zoobab/helm_file_repo
  $ helm repo add the-captain file:///Users/amiruladli/Projects/the-captain/packaged_charts
  $ helm repo update
  ```

  or

  ```bash
  $ helm repo add the-captain https://vortechron.github.io/the-captain-charts/
  $ helm repo update
  ```

To install a specific chart:

  ```bash
  $ helm install some-release my-charts/<chart>
  ```

## Kubernetes Tools

This repository also includes several useful tools for managing Kubernetes clusters:

### Storage Usage Analyzer

A powerful tool that helps you identify which resources in your Kubernetes cluster are using the most storage. Perfect for optimizing resource usage and identifying potential waste.

```bash
$ k8s/storage-usage-analyzer.sh
```

For more information, see the [Kubernetes Tools documentation](k8s/README-k8s-tools.md).

### Storage Management Resources

- [Storage Management Best Practices](k8s/STORAGE.md)
- [Metrics Setup Guide](k8s/METRICS.md)
- [Database Tools](k8s/MYSQL.md)

## Security

Any security related issues should be reported to the maintainer of the chart.