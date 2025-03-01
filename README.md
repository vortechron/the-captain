# Helm Charts

## Installation

To install the charts repository (locally):

- git clone this repo

  ```bash
  $ helm plugin add https://github.com/zoobab/helm_file_repo
  $ helm repo add the-captain file:///Users/amiruladli/Projects/helm/packaged_charts
  $ helm repo update
  ```

To install a specific chart:

  ```bash
  $ helm install some-release my-charts/<chart>
  ```

## Security

Any security related issues should be reported to the maintainer of the chart.