# Terraform Configuration Fixes

This document explains the fixes applied to resolve two common Terraform issues with Helm releases and Kubernetes deployments.

## Issues Fixed

### 1. Pods Not Restarting After Terraform Apply

**Problem**: When Terraform updates Helm releases or Kubernetes deployments, pods don't automatically restart unless the pod template changes.

**Solution**: Added timestamp-based annotations to force pod restarts:
- **Helm Releases**: Added `podAnnotations` with `terraform.io/last-updated: timestamp()` to the values
- **Kubernetes Deployments**: Added the same annotation to the pod template metadata

When Terraform runs `apply`, the timestamp changes, which triggers Kubernetes to recreate the pods with the new configuration.

### 2. Unsync with Remote Provider (Always Shows Changes)

**Problem**: Terraform always shows changes that weren't made, indicating drift between Terraform state and the actual Kubernetes resources.

**Solution**: Added proper Helm release configuration:
- `atomic = true`: Ensures rollback on failure
- `wait = true`: Waits for resources to be ready
- `wait_for_jobs = true`: Waits for Helm jobs to complete
- `timeout = 600`: Sets a 10-minute timeout
- `reuse_values = false`: **Critical** - This ensures Terraform replaces ALL values with the ones specified, preventing drift from default chart values
- `force_update = false`: Prevents unnecessary updates
- `cleanup_on_fail = true`: Cleans up failed releases

The `reuse_values = false` setting is particularly important because:
- Helm charts have many default values that Terraform doesn't track
- When `reuse_values = true`, Terraform only updates specified values, leaving defaults unchanged
- This causes drift when defaults change or when resources are modified outside Terraform
- Setting it to `false` ensures Terraform manages ALL values, keeping state in sync

## Files Modified

1. `terraform/main.tf`:
   - Updated `helm_release.ingress_nginx_repo`
   - Updated `helm_release.cert_manager`

2. `terraform/modules/prometheus/main.tf`:
   - Updated `helm_release.prometheus`

3. `terraform/modules/loki/main.tf`:
   - Updated `helm_release.loki`

4. `terraform/modules/promtail/main.tf`:
   - Updated `helm_release.promtail`

5. `terraform/modules/grafana/main.tf`:
   - Updated `helm_release.grafana`

6. `terraform/modules/minio/main.tf`:
   - Updated `kubernetes_deployment.minio` with timestamp annotation
   - Added lifecycle management to ignore replica changes

## Usage

After these changes:

1. **First Apply**: Run `terraform plan` to see the changes. You may see many changes as Terraform syncs with the actual state.

2. **Review Changes**: Carefully review the plan to ensure no unexpected changes.

3. **Apply**: Run `terraform apply` to sync the state. Pods will restart automatically due to the timestamp annotations.

4. **Future Applies**: Subsequent applies should show minimal or no changes unless you actually modify the configuration.

## Important Notes

- **Timestamp Annotations**: The `timestamp()` function runs on every plan/apply, which will always show the annotation as changed. This is intentional to force pod restarts. If you want to avoid unnecessary restarts, you can remove the timestamp annotations and manually restart pods when needed.

- **reuse_values = false**: This setting means Terraform will overwrite ALL Helm values, not just the ones you specify. Make sure all important values are explicitly set in your Terraform configuration.

- **Lifecycle Management**: The MinIO deployment includes `lifecycle.ignore_changes` for replicas to prevent Terraform from reverting manual scaling operations.

## Troubleshooting

If you still see drift issues:

1. **Check for manual changes**: Resources modified outside Terraform will show as drift
2. **Review Helm chart defaults**: Some charts have dynamic defaults that change based on cluster state
3. **Use terraform refresh**: Run `terraform refresh` to sync state without applying changes
4. **Check provider versions**: Ensure you're using compatible provider versions

## Alternative: Selective Pod Restarts

If you want more control over pod restarts, you can:

1. Remove the timestamp annotations
2. Manually restart pods when needed: `kubectl rollout restart deployment/<name> -n <namespace>`
3. Or use a null_resource with local-exec to trigger restarts only when specific values change

