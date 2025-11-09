# This file has been split into multiple files for better organization:
# - namespace.tf: MySQL namespace
# - secrets.tf: All secrets (MinIO backup, MySQL cluster secrets)
# - operator.tf: Percona Operator Helm release
# - cluster.tf: Percona XtraDB Cluster Helm release and backup patch
# - monitoring.tf: MySQL exporter deployment, service, and monitoring user setup

