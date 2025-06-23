# Mailu Mail Server Setup for Kubernetes

This guide explains how to install and configure Mailu mail server on your Kubernetes cluster using Helm charts, and how to integrate it with Laravel applications.

## Overview

Mailu is a simple yet full-featured mail server as a set of Docker images. It provides:

- **IMAP and POP3** server (Dovecot)
- **SMTP** server (Postfix) 
- **Webmail client** (Roundcube)
- **Admin interface** for managing domains, users, and aliases
- **Antispam** (Rspamd) and **Antivirus** (ClamAV)
- **Auto-configuration** for email clients
- **Let's Encrypt** integration for TLS certificates

## Prerequisites

- Kubernetes cluster with ingress controller installed
- Helm 3 installed
- `kubectl` configured to access your cluster
- Domain name with DNS records configured
- At least 4GB RAM and 20GB disk space recommended

## Installation

### Add Mailu Helm Repository

```bash
helm repo add mailu https://mailu.github.io/helm-charts/
helm repo update
```

### Create Namespace

```bash
kubectl create namespace mailu
```

### Configure DNS Records

Before installation, ensure these DNS records are configured for your domain:

```dns
# A records (replace with your cluster's external IP)
mail.terapeas.com.     IN A     <YOUR_CLUSTER_IP>
autodiscover.terapeas.com. IN A <YOUR_CLUSTER_IP>
autoconfig.terapeas.com.   IN A <YOUR_CLUSTER_IP>

# MX record
terapeas.com.          IN MX 10 mail.terapeas.com.

# SPF record
terapeas.com.          IN TXT   "v=spf1 mx ~all"

# DMARC record  
_dmarc.terapeas.com.   IN TXT   "v=DMARC1; p=none; rua=mailto:postmaster@terapeas.com"

# DKIM record (will be generated after installation)
# default._domainkey.terapeas.com. IN TXT "v=DKIM1; ..."
```

### Generate Secret Key

First, generate a secret key for Mailu:

```bash
# Generate a secure random key
openssl rand -base64 16
# Example output: 0jh9lg2Z3ZMnO6uD7u32bQ
```

### Get Default Values and Customize

First, get the default values file:

```bash
# Get default values from the chart
helm show values mailu/mailu > values.yaml
```

Now edit the `values.yaml` file to customize for your environment. Key settings to modify:

```yaml
# Essential settings to configure:
domain: terapeas.com
hostnames: ["mail.terapeas.com"]
secretKey: "your-generated-secret-key"
subnet: "10.42.0.0/16"  # Adjust for your cluster network

# Ingress configuration
ingress:
  enabled: true
  ingressClassName: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"

# External service for mail ports
front:
  externalService:
    enabled: true
    type: LoadBalancer
    
# Use existing Redis if available
redis:
  enabled: false  # Set to true if you don't have existing Redis
  
# Database configuration
mariadb:
  enabled: false  # Use external database if preferred
postgresql:
  enabled: false
```

Install Mailu with Helm:

```bash
helm install mailu mailu/mailu \
  --namespace mailu \
  --values values.yaml \
  --version 1.0.1
```

### Verify Installation

Check if all pods are running:

```bash
kubectl get pods -n mailu
kubectl get svc -n mailu
kubectl get ingress -n mailu
```

## Initial Configuration

### Access Admin Interface

1. Get the admin interface URL:
```bash
echo "https://mail.terapeas.com/admin"
```

2. Create the initial admin account:
```bash
# Connect to the admin pod
kubectl exec -it -n mailu deployment/mailu-admin -- flask mailu admin admin terapeas.com 'YourSecurePassword'
```

### Configure DKIM

1. Access the admin interface at `https://mail.terapeas.com/admin`
2. Login with your admin credentials
3. Go to Mail domains → terapeas.com → Details
4. Click "Generate keys" to create DKIM keys
5. Copy the DKIM public key and add it as a DNS TXT record:

```dns
default._domainkey.terapeas.com. IN TXT "v=DKIM1; k=rsa; p=YOUR_PUBLIC_KEY_HERE"
```

### Create Mail Users

In the admin interface:
1. Go to Mail domains → terapeas.com → Users
2. Click "Add user"
3. Fill in the user details (email, password, quota, etc.)
4. Save the user

## Service Configuration

### SMTP/IMAP Ports

The mail ports are automatically exposed through the `front.externalService` configuration in your values.yaml. If you configured it as shown above, the service will be created automatically.

Get the external IP for your DNS records:

```bash
kubectl get svc -n mailu
```

Look for the LoadBalancer service and note the external IP. Update your DNS A records to point to this IP.

## Laravel Integration

### Install Laravel Mail Package

If not already installed, add the mail configuration to your Laravel application.

### Configure Laravel Mail Settings

Update your Laravel `.env` file with Mailu SMTP settings:

```env
# Mail Configuration
MAIL_MAILER=smtp
MAIL_HOST=mail.terapeas.com
MAIL_PORT=587
MAIL_USERNAME=your-app@terapeas.com
MAIL_PASSWORD=YourUserPassword
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=your-app@terapeas.com
MAIL_FROM_NAME="${APP_NAME}"

# Optional: For testing with local development
# MAIL_HOST=localhost
# MAIL_PORT=1025  # If using MailHog or similar for local testing
```

### Update Laravel Mail Configuration

Edit `config/mail.php` if needed:

```php
<?php

return [
    'default' => env('MAIL_MAILER', 'smtp'),
    
    'mailers' => [
        'smtp' => [
            'transport' => 'smtp',
            'host' => env('MAIL_HOST', 'smtp.mailgun.org'),
            'port' => env('MAIL_PORT', 587),
            'encryption' => env('MAIL_ENCRYPTION', 'tls'),
            'username' => env('MAIL_USERNAME'),
            'password' => env('MAIL_PASSWORD'),
            'timeout' => null,
            'local_domain' => env('MAIL_EHLO_DOMAIN'),
        ],
    ],
    
    'from' => [
        'address' => env('MAIL_FROM_ADDRESS', 'hello@example.com'),
        'name' => env('MAIL_FROM_NAME', 'Example'),
    ],
];
```

### Test Email Sending

Create a test route or command to verify email sending:

```php
// In routes/web.php or a controller
Route::get('/test-email', function () {
    try {
        Mail::raw('Test email from Laravel via Mailu', function ($message) {
            $message->to('test@terapeas.com')
                   ->subject('Test Email');
        });
        
        return 'Email sent successfully!';
    } catch (\Exception $e) {
        return 'Email failed: ' . $e->getMessage();
    }
});
```

### Laravel Queue Configuration (Optional)

For better performance, use queued emails:

```php
// In your Laravel application
Mail::to($user->email)->queue(new WelcomeEmail($user));
```

Make sure to run the queue worker:

```bash
php artisan queue:work
```

## Security Configuration

### Firewall Rules

Ensure your firewall allows the following ports:

```bash
# Mail ports
25    # SMTP
587   # SMTP Submission
465   # SMTPS
143   # IMAP  
993   # IMAPS
110   # POP3
995   # POP3S

# Web interface
80    # HTTP (redirects to HTTPS)
443   # HTTPS
```

### Rate Limiting

Configure rate limiting in your Mailu values:

```yaml
authRatelimit: "10/minute;1000/hour"
messageRatelimit: "200/day"
```

### Fail2Ban Integration (Optional)

If running on VMs, you can integrate with Fail2Ban for additional security.

## Monitoring and Maintenance

### Health Checks

Monitor Mailu components:

```bash
# Check pod status
kubectl get pods -n mailu

# Check logs
kubectl logs -n mailu deployment/mailu-admin
kubectl logs -n mailu deployment/mailu-front
kubectl logs -n mailu deployment/mailu-imap

# Check service endpoints
kubectl get endpoints -n mailu
```

### Backup Configuration

Create regular backups of your Mailu data:

```bash
# Backup persistent volume data
kubectl exec -n mailu deployment/mailu-admin -- tar czf /tmp/mailu-backup.tar.gz /data

# Copy backup out of container
kubectl cp mailu/mailu-admin-pod:/tmp/mailu-backup.tar.gz ./mailu-backup-$(date +%Y%m%d).tar.gz
```

### Log Monitoring

Monitor important logs:

```bash
# Mail delivery logs
kubectl logs -n mailu deployment/mailu-front -f

# Authentication logs  
kubectl logs -n mailu deployment/mailu-admin -f

# Antispam logs
kubectl logs -n mailu deployment/mailu-rspamd -f
```

## Troubleshooting

### Common Issues

1. **Email not being delivered**:
   - Check DNS records (MX, A, SPF, DKIM, DMARC)
   - Verify firewall rules
   - Check spam folder on receiving end

2. **Cannot connect to SMTP/IMAP**:
   - Verify LoadBalancer service has external IP
   - Check if ports are accessible from outside
   - Verify user credentials

3. **Web interface not accessible**:
   - Check ingress configuration
   - Verify TLS certificates
   - Check pod logs for errors

4. **High memory usage**:
   - Adjust resource limits
   - Consider disabling ClamAV if not needed
   - Monitor with `kubectl top pods -n mailu`

### Debug Commands

```bash
# Get detailed pod information
kubectl describe pod -n mailu <pod-name>

# Check service connectivity
kubectl exec -n mailu deployment/mailu-admin -- nslookup mail.terapeas.com

# Test SMTP connectivity
kubectl exec -n mailu deployment/mailu-admin -- telnet localhost 25

# Check database connectivity (if using external DB)
kubectl exec -n mailu deployment/mailu-admin -- python -c "from mailu import db; print('DB OK' if db else 'DB Error')"
```

## Upgrading Mailu

### Backup Before Upgrade

```bash
# Create backup
kubectl exec -n mailu deployment/mailu-admin -- tar czf /tmp/pre-upgrade-backup.tar.gz /data
kubectl cp mailu/mailu-admin-pod:/tmp/pre-upgrade-backup.tar.gz ./mailu-backup-pre-upgrade.tar.gz
```

### Perform Upgrade

```bash
# Update Helm repository
helm repo update

# Upgrade Mailu
helm upgrade mailu mailu/mailu \
  --namespace mailu \
  --values mailu-values.yaml \
  --version <NEW_VERSION>

# Verify upgrade
kubectl get pods -n mailu
kubectl logs -n mailu deployment/mailu-admin
```

## Uninstallation

If you need to remove Mailu:

```bash
# Uninstall Helm release
helm uninstall mailu -n mailu

# Remove PVCs (WARNING: This will delete all mail data!)
kubectl delete pvc -n mailu --all

# Remove namespace
kubectl delete namespace mailu
```

## Production Recommendations

1. **Use PostgreSQL** instead of SQLite for production
2. **Enable backups** for both database and mail data
3. **Monitor resource usage** and adjust limits accordingly
4. **Set up proper DNS records** including SPF, DKIM, and DMARC
5. **Use dedicated storage class** with backup capabilities
6. **Implement monitoring** with Prometheus/Grafana
7. **Regular security updates** by keeping Helm chart updated
8. **Configure log retention** to manage disk usage

## Integration with Existing Infrastructure

### Using with Prometheus Monitoring

If you have Prometheus installed (see [METRICS.md](METRICS.md)):

```bash
# Add ServiceMonitor for Mailu metrics
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mailu-metrics
  namespace: observability
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: mailu
  endpoints:
  - port: http
    path: /metrics
EOF
```

### Using with Existing PostgreSQL

If you have PostgreSQL installed (see [MYSQL.md](MYSQL.md) for database setup patterns):

```yaml
# In mailu-values.yaml
database:
  type: "postgresql"
  host: "postgresql.default.svc.cluster.local"
  port: 5432
  name: "mailu"
  username: "mailu"
  password: "your-secure-password"
```

This completes the Mailu mail server setup for Kubernetes with Laravel integration guide. 