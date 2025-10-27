# Required GitHub Secrets

Configure these secrets in your GitHub repository settings (Settings → Secrets and variables → Actions):

## Required Secrets

### GCP Authentication
- `GCP_SA_KEY` - Base64 encoded GCP service account JSON key with permissions for:
  - Artifact Registry (push images)
  - GKE cluster access

### Kubernetes Configuration  
- `KUBECONFIG` - Base64 encoded kubeconfig file for your Hetzner cluster
  ```bash
  # To encode your kubeconfig:
  cat /Users/amiruladli/.kube/vortechron-hetzner.yaml | base64
  ```

### Application Secrets
- `SSH_PRIVATE_KEY` - SSH private key for Docker build (current: ~/.ssh/id_rsa)
- `DB_PASSWORD` - Database password 
- `MAIL_PASSWORD` - Email service password
- `GOOGLE_CLIENT_SECRET` - Google OAuth client secret
- `STRIPE_SECRET` - Stripe API secret key

### Helm Repository
- `HELM_REPO_URL` - URL to your the-captain Helm repository

## Workflow Triggers

The pipeline triggers on:
1. **Git tags** starting with `v` (e.g., `v1.2.3`)
2. **Manual dispatch** with custom image tag input

## Environment Files

Ensure `.env.production` exists in your repository root with production environment variables.