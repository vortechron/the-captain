# Debugging SSL Certificate Issues in Kubernetes

This guide walks through the process of troubleshooting and fixing SSL certificate issues in a Kubernetes cluster using cert-manager.

## Common SSL Certificate Issues

When deploying applications with HTTPS in Kubernetes, you might encounter issues where TLS certificates show as `False` or `Not Ready`. This typically happens due to:

1. Missing or misconfigured ClusterIssuer/Issuer
2. DNS configuration issues
3. Challenge validation failures
4. Ingress annotation problems

## Debugging Process

### 1. Check Certificate Status

First, check the status of your certificates to identify which ones are failing:

```bash
kubectl get certs -A
```

Look for certificates with `READY` status set to `False`.

### 2. Examine Certificate Details

For any certificates showing as `False`, examine their details:

```bash
kubectl describe cert <certificate-name> -n <namespace>
```

Look for error messages in the `Status` and `Events` sections that might indicate the issue.

### 3. Verify Certificate Request

Check if a certificate request was created:

```bash
kubectl get certificaterequest -n <namespace>
```

And examine its details:

```bash
kubectl describe certificaterequest <request-name> -n <namespace>
```

### 4. Check ClusterIssuer/Issuer

Verify that the ClusterIssuer or Issuer referenced in your certificate exists:

```bash
kubectl get clusterissuer
# or
kubectl get issuer -n <namespace>
```

If it doesn't exist, you need to create it with the appropriate configuration:

```bash
kubectl apply -f clusterissuer.yaml
```

A sample ClusterIssuer for Let's Encrypt with HTTP01 challenges looks like:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: admin@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

### 5. Check ACME Orders and Challenges

When using ACME issuers (like Let's Encrypt), examine the orders and challenges:

```bash
kubectl get orders -n <namespace>
kubectl get challenges -n <namespace>
```

For more details:

```bash
kubectl describe order <order-name> -n <namespace>
kubectl describe challenge <challenge-name> -n <namespace>
```

Challenges can fail for several reasons:
- Network connectivity issues
- Ingress controller misconfiguration
- DNS resolution problems

### 6. Verify Ingress Configuration

Ensure your Ingress is correctly annotated for cert-manager:

```bash
kubectl describe ingress <ingress-name> -n <namespace>
```

Look for annotations like:
```
cert-manager.io/cluster-issuer: letsencrypt-prod
kubernetes.io/ingress.class: nginx
```

### 7. Check Cert-Manager Logs

Examine cert-manager's logs for additional insights:

```bash
kubectl logs -f -n cert-manager --selector=app=cert-manager
```

## Case Study: Fixing a Failed Certificate

In our example case, we fixed a certificate showing as `False` by:

1. Identifying that the ClusterIssuer `letsencrypt-prod` was missing
2. Creating the ClusterIssuer with proper configuration
3. Verifying the certificate was automatically re-processed and became valid

The creation of the ClusterIssuer triggered a chain of events:
- Certificate request creation
- Challenge generation and validation
- Certificate issuance
- TLS secret creation

## Best Practices

1. Always specify the correct email address for Let's Encrypt notifications
2. Use staging environments (`https://acme-staging-v02.api.letsencrypt.org/directory`) for testing to avoid rate limits
3. Make sure your domain is publicly accessible for HTTP01 validation
4. Check ingress controller and network policies allow necessary traffic
5. For production, set reasonable renewal times (default is 2/3 of certificate lifetime)

## Useful Commands Reference

```bash
# View all certificates
kubectl get certs -A

# Check certificate details
kubectl describe cert <name> -n <namespace>

# View certificate requests
kubectl get certificaterequest -n <namespace>

# Check ACME orders
kubectl get orders -n <namespace>

# View challenges
kubectl get challenges -n <namespace>

# Verify issuer status
kubectl get clusterissuer

# Check secret was created
kubectl get secret <secret-name> -n <namespace>
```
