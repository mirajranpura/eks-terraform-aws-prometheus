# Kubernetes Manifests for Prometheus

This directory contains Kubernetes manifests for deploying Prometheus to monitor CoreDNS with AWS Managed Prometheus (AMP).

## Files

- `prometheus-namespace.yaml` - Creates the prometheus namespace
- `prometheus-serviceaccount.yaml` - ServiceAccount with IRSA annotation (requires substitution)
- `prometheus-rbac.yaml` - ClusterRole and ClusterRoleBinding for Prometheus
- `prometheus-config.yaml` - ConfigMap with Prometheus configuration (requires substitution)
- `prometheus-deployment.yaml` - Prometheus server deployment

## Deployment

### Option 1: Using the Deployment Script (Recommended)

The easiest way to deploy is using the provided script that automatically substitutes Terraform outputs:

```bash
# From the project root directory
./scripts/deploy-prometheus.sh
```

This script will:
1. Fetch Terraform outputs (IAM role ARN, AMP workspace endpoint, region)
2. Substitute values into the manifests
3. Apply all manifests to your EKS cluster

### Option 2: Manual Deployment

If you prefer to deploy manually:

1. **Get Terraform outputs:**
   ```bash
   terraform output prometheus_role_arn
   terraform output prometheus_workspace_endpoint
   terraform output aws_region
   ```

2. **Substitute values in the manifests:**
   
   In `prometheus-serviceaccount.yaml`, replace:
   ```yaml
   ${PROMETHEUS_ROLE_ARN}
   ```
   with your actual IAM role ARN.

   In `prometheus-config.yaml`, replace:
   ```yaml
   ${AMP_WORKSPACE_ENDPOINT}
   ${AWS_REGION}
   ```
   with your actual AMP endpoint and region.

3. **Apply the manifests:**
   ```bash
   kubectl apply -f prometheus-namespace.yaml
   kubectl apply -f prometheus-serviceaccount.yaml
   kubectl apply -f prometheus-rbac.yaml
   kubectl apply -f prometheus-config.yaml
   kubectl apply -f prometheus-deployment.yaml
   ```

### Option 3: Using envsubst

```bash
# Export variables
export PROMETHEUS_ROLE_ARN=$(terraform output -raw prometheus_role_arn)
export AMP_WORKSPACE_ENDPOINT=$(terraform output -raw prometheus_workspace_endpoint)
export AWS_REGION=$(terraform output -raw aws_region)

# Apply with substitution
kubectl apply -f prometheus-namespace.yaml
envsubst < prometheus-serviceaccount.yaml | kubectl apply -f -
kubectl apply -f prometheus-rbac.yaml
envsubst < prometheus-config.yaml | kubectl apply -f -
kubectl apply -f prometheus-deployment.yaml
```

## Verification

Check that Prometheus is running:

```bash
kubectl get pods -n prometheus
```

View Prometheus logs:

```bash
kubectl logs -n prometheus -l app=prometheus-server
```

Port-forward to access Prometheus UI:

```bash
kubectl port-forward -n prometheus svc/prometheus-server 9090:9090
```

Then visit http://localhost:9090 in your browser.

## Verify CoreDNS Monitoring

Check that CoreDNS targets are being scraped:

1. Port-forward to Prometheus (see above)
2. Visit http://localhost:9090/targets
3. Look for the "coredns" job with healthy targets

Query CoreDNS metrics:

```bash
# Via port-forward
curl 'http://localhost:9090/api/v1/query?query=coredns_dns_requests_total'
```

## Cleanup

To remove Prometheus:

```bash
kubectl delete -f .
```

Or delete the namespace (removes everything):

```bash
kubectl delete namespace prometheus
```

## Troubleshooting

### Prometheus pod not starting

Check events:
```bash
kubectl describe pod -n prometheus <pod-name>
```

### IRSA not working

Verify the IAM role ARN annotation:
```bash
kubectl get sa prometheus-server -n prometheus -o yaml
```

Check pod logs for AWS authentication errors:
```bash
kubectl logs -n prometheus <pod-name> | grep -i "error\|auth"
```

### Metrics not appearing in AMP

1. Check remote write configuration in the ConfigMap
2. Verify IAM role has AMP write permissions
3. Check Prometheus logs for remote write errors:
   ```bash
   kubectl logs -n prometheus <pod-name> | grep remote_write
   ```

## Configuration

### Scrape Interval

Default: 15 seconds. To change, edit `prometheus-config.yaml`:

```yaml
global:
  scrape_interval: 30s  # Change this value
```

### Remote Write Settings

To adjust remote write performance, edit `prometheus-config.yaml`:

```yaml
remote_write:
  - url: ...
    queue_config:
      max_samples_per_send: 1000  # Samples per batch
      max_shards: 200             # Parallel shards
      capacity: 2500              # Queue capacity
```

## Additional Monitoring

To monitor additional components, add new scrape configs to `prometheus-config.yaml`:

```yaml
scrape_configs:
  - job_name: 'coredns'
    # ... existing config ...
  
  - job_name: 'my-app'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - my-namespace
    # ... add relabel configs ...
```
