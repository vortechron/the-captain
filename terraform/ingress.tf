# Helm Repository for Ingress NGINX
resource "helm_release" "ingress_nginx_repo" {
  count = var.ingress_nginx_enabled ? 1 : 0

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_version
  namespace        = "ingress-nginx"
  create_namespace = true

  atomic          = false # Non-critical: disable atomic for faster applies
  wait            = var.helm_wait_enabled
  wait_for_jobs   = var.helm_wait_for_jobs_enabled
  timeout         = 60 # Minimal timeout for Helm API calls
  reuse_values    = false
  force_update    = false
  cleanup_on_fail = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }

  # Removed timestamp annotation to prevent unnecessary pod restarts
  # which cause scheduling issues when CPU is constrained

  depends_on = [azurerm_kubernetes_cluster.main]
}

# Helm Release for cert-manager
resource "helm_release" "cert_manager" {
  count = var.cert_manager_enabled ? 1 : 0

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true

  atomic          = false # Non-critical: disable atomic for faster applies
  wait            = var.helm_wait_enabled
  wait_for_jobs   = var.helm_wait_for_jobs_enabled
  timeout         = 60 # Minimal timeout for Helm API calls
  reuse_values    = false
  force_update    = false
  cleanup_on_fail = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  # Note: cert-manager webhooks restart automatically when configuration changes
  # No need for manual pod restart annotations

  depends_on = [azurerm_kubernetes_cluster.main]
}

# ClusterIssuer for Let's Encrypt (optional - only if create_cluster_issuer is true)
resource "kubernetes_manifest" "cluster_issuer" {
  count = var.cert_manager_enabled && var.minio_create_cluster_issuer ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.minio_cluster_issuer_name
    }
    spec = {
      acme = {
        email = var.minio_cert_manager_email
        privateKeySecretRef = {
          name = "${var.minio_cluster_issuer_name}-account-key"
        }
        server = "https://acme-v02.api.letsencrypt.org/directory"
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}





