# Laravel v2 Example - Kubernetes Deployment Template

This directory contains deployment files for a Laravel application with Inertia.js SSR support, serving as a template for creating Kubernetes deployments for similar Laravel projects.

## Source
Files copied from "chai: chat ai, a chatgpt clone" project.

## Architecture
- **Laravel with Octane**: Uses Swoole server for high performance
- **Inertia.js SSR**: Optional server-side rendering (configurable via `INERTIA_SSR_ENABLED`)
- **Multi-stage Docker build**: Separates asset compilation from runtime

## Files Overview

### .helm/
Helm chart configuration for Kubernetes deployment:

#### storage.yml
- PersistentVolumeClaim for Laravel storage
- 10Gi storage allocation for application files

#### values.yml  
Complete Helm values configuration including:
- **Image**: GCP Artifact Registry configuration
- **Ingress**: Traefik with Let's Encrypt SSL
- **Storage**: Persistent volumes for Laravel storage directories
- **Web deployment**: Octane with Inertia SSR support
- **Worker deployment**: Queue workers with autoscaling
- **WebSocket**: Laravel Reverb support (optional)
- **Scheduler**: Laravel cron jobs via CronJob
- **Database migration**: Init container for migrations
- **Secret management**: Environment variables from Kubernetes secrets

### Dockerfile.octane
Multi-stage Docker build:
1. **Assets stage**: Compiles frontend assets with `npm run build:ssr`
2. **Runtime stage**: PHP 8.3 FPM Alpine with Octane, includes Node.js for SSR

Key features:
- SOAP extension support
- Performance optimizations for Swoole
- Asset compilation and SSR bundle copying
- Production-ready cleanup (removes tests, dev dependencies)

### docker-entrypoint.sh
Container startup script:
- Conditionally starts Inertia SSR server based on `INERTIA_SSR_ENABLED` 
- Launches Laravel Octane with Swoole on port 80
- Handles graceful shutdown of SSR process

### GITHUB_SECRETS.md
Documents required GitHub Actions secrets for CI/CD:
- GCP service account for Artifact Registry
- Kubernetes config for Hetzner cluster
- Application secrets (DB, mail, OAuth, Stripe)
- Helm repository configuration

## Usage as Template

When adapting for other Laravel projects:

1. **Check Inertia.js usage**: Verify if project uses Inertia SSR
   - Look for `bootstrap/ssr/` directory
   - Check for `build:ssr` npm script
   - Adjust `INERTIA_SSR_ENABLED` accordingly

2. **Modify dependencies**: Update Dockerfile based on project needs
   - Remove SOAP extension if not required
   - Add other PHP extensions as needed
   - Adjust npm build commands

3. **Customize Helm values**: Adapt `.helm/values.yml` for your project
   - Update image repository and tags
   - Modify ingress hostnames and TLS certificates  
   - Adjust resource limits based on project needs
   - Configure storage requirements
   - Enable/disable components (workers, websockets, nginx)
   - Update secret references and environment variables

4. **Update secrets**: Customize GitHub secrets based on project requirements
   - Remove unused secrets (Stripe, Google OAuth, etc.)
   - Add project-specific secrets
   - Update secret names in values.yml

5. **Environment variables**: Ensure `.env.production` contains required variables

## Deployment Flow
1. Trigger on git tags (`v*`) or manual dispatch
2. Build multi-stage Docker image
3. Push to GCP Artifact Registry  
4. Deploy to Kubernetes cluster via Helm