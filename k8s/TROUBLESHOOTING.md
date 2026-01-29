# Prometheus Troubleshooting Guide

This guide helps you verify that Prometheus is collecting CoreDNS metrics and sending them to AWS Managed Prometheus (AMP).

## Prerequisites

- `kubectl` configured to access your EKS cluster
- `aws` CLI configured with appropriate credentials
- `curl` or similar HTTP client

## AWS CLI Profile Setup

If you use multiple AWS profiles, set your profile as an environment variable:

```bash
# Set your AWS profile (optional, skip if using default profile)
export AWS_PROFILE=your-profile-name

# Verify profile is set
echo $AWS_PROFILE

# Test AWS access
aws sts get-caller-identity
```

Alternatively, you can add `--profile your-profile-name` to each AWS CLI command.

**For the rest of this guide:**
- If you set `AWS_PROFILE` environment variable, omit the `--profile` flag
- If you didn't set the environment variable, add `--profile your-profile-name` to each `aws` command

## 1. Check Prometheus Server Status

### Verify Prometheus Pod is Running

```bash
kubectl get pods -n prometheus
```

Expected output:
```
NAME                                 READY   STATUS    RESTARTS   AGE
prometheus-server-5bf679d6bc-qq2tv   1/1     Running   0          17h
```

### Check Prometheus Logs

```bash
kubectl logs -n prometheus -l app=prometheus --tail=50
```

Look for any errors related to scraping or remote_write.

**Note:** The correct label is `app=prometheus`, not `app=prometheus-server`.

## 2. Access Prometheus UI via Port-Forward

### Start Port-Forward

```bash
kubectl port-forward -n prometheus svc/prometheus-server 9090:9090
```

Keep this terminal open. Open a new terminal for the following commands.

### Check Prometheus Targets

Verify that CoreDNS targets are being discovered and scraped:

```bash
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep -A 30 "coredns"
```

Look for:
- `"health": "up"` - indicates successful scraping
- `"lastError": ""` - no errors
- Port `9153` in the scrapeUrl

### Query CoreDNS Metrics

Check if CoreDNS metrics are available in Prometheus:

```bash
# Query total DNS requests
curl -s 'http://localhost:9090/api/v1/query?query=coredns_dns_requests_total' | python3 -m json.tool

# Query DNS request rate (last 5 minutes)
curl -s 'http://localhost:9090/api/v1/query?query=rate(coredns_dns_requests_total[5m])' | python3 -m json.tool

# Query DNS cache hits
curl -s 'http://localhost:9090/api/v1/query?query=coredns_cache_hits_total' | python3 -m json.tool

# Query DNS cache misses
curl -s 'http://localhost:9090/api/v1/query?query=coredns_cache_misses_total' | python3 -m json.tool
```

### Access Prometheus UI in Browser

Open your browser and navigate to:
```
http://localhost:9090
```

Navigate to:
- **Status → Targets** to see all scrape targets
- **Graph** to query metrics manually

Example queries to try:
```promql
# Total DNS requests
coredns_dns_requests_total

# DNS request rate
rate(coredns_dns_requests_total[5m])

# DNS requests by type
sum by (type) (coredns_dns_requests_total)

# DNS response codes
coredns_dns_responses_total
```

## 3. Verify Remote Write to AMP

### Check Remote Write Configuration

```bash
kubectl get configmap prometheus-config -n prometheus -o yaml | grep -A 10 "remote_write:"
```

Verify:
- AMP workspace endpoint URL is correct
- Region matches your AWS region
- SigV4 authentication is configured

### Check Remote Write Queue Metrics

Query Prometheus for remote write statistics:

```bash
# Check remote write queue length
curl -s 'http://localhost:9090/api/v1/query?query=prometheus_remote_storage_queue_length' | python3 -m json.tool

# Check remote write success rate
curl -s 'http://localhost:9090/api/v1/query?query=rate(prometheus_remote_storage_succeeded_samples_total[5m])' | python3 -m json.tool

# Check remote write failures
curl -s 'http://localhost:9090/api/v1/query?query=rate(prometheus_remote_storage_failed_samples_total[5m])' | python3 -m json.tool

# Check remote write retries
curl -s 'http://localhost:9090/api/v1/query?query=rate(prometheus_remote_storage_retried_samples_total[5m])' | python3 -m json.tool
```

### Get AMP Workspace Details

```bash
# Get workspace ID from Terraform output
WORKSPACE_ID=$(terraform output -raw prometheus_workspace_id)
AWS_REGION=$(terraform output -raw aws_region)

echo "Workspace ID: $WORKSPACE_ID"
echo "Region: $AWS_REGION"

# Describe the workspace
# If using AWS_PROFILE environment variable:
aws amp describe-workspace --workspace-id $WORKSPACE_ID --region $AWS_REGION

# Or with explicit profile:
# aws amp describe-workspace --workspace-id $WORKSPACE_ID --region $AWS_REGION --profile your-profile-name
```

## 4. Query Metrics from AMP

### Using AWS CLI

**Note:** The `aws amp query-metrics` command is not available in all AWS CLI versions. Use alternative methods below.

#### Method 1: Check Workspace Status

```bash
# Set variables
WORKSPACE_ID=$(terraform output -raw prometheus_workspace_id)
AWS_REGION=$(terraform output -raw aws_region)

# Describe the workspace
# If using AWS_PROFILE environment variable:
aws amp describe-workspace \
  --workspace-id $WORKSPACE_ID \
  --region $AWS_REGION

# Or with explicit profile:
# aws amp describe-workspace \
#   --workspace-id $WORKSPACE_ID \
#   --region $AWS_REGION \
#   --profile your-profile-name
```

#### Method 2: Check Prometheus Logs for Remote Write Success

```bash
# Check Prometheus logs for remote write activity
kubectl logs -n prometheus -l app=prometheus --tail=200 | grep -i "remote\|write"
```

Look for messages like:
- `"Starting WAL watcher"` - Remote write is configured
- `"Done replaying WAL"` - Remote write has sent historical data
- No error messages about authentication or connection failures

### Using awscurl (Alternative Method)

**Note:** Direct querying of AMP requires additional setup. The recommended approach is to:

1. **Use Grafana** connected to your AMP workspace for querying metrics
2. **Verify remote write** is working by checking Prometheus logs
3. **Monitor remote write metrics** in Prometheus itself

#### Verify Remote Write is Working

```bash
# Check Prometheus logs for successful remote write
kubectl logs -n prometheus -l app=prometheus --tail=200 | grep "remote_name"

# Look for these indicators:
# - "Starting WAL watcher" - Remote write initialized
# - "Done replaying WAL" - Historical data sent
# - No authentication or connection errors
```

### Verify Data Ingestion

Check if AMP workspace is active and receiving data:

```bash
# Describe workspace status
WORKSPACE_ID=$(terraform output -raw prometheus_workspace_id)
AWS_REGION=$(terraform output -raw aws_region)

# If using AWS_PROFILE environment variable:
aws amp describe-workspace \
  --workspace-id $WORKSPACE_ID \
  --region $AWS_REGION

# Or with explicit profile:
# aws amp describe-workspace \
#   --workspace-id $WORKSPACE_ID \
#   --region $AWS_REGION \
#   --profile your-profile-name

# Check for "statusCode": "ACTIVE"
```

**Verify Remote Write in Prometheus:**

```bash
# Port-forward to Prometheus
kubectl port-forward -n prometheus svc/prometheus-server 9090:9090 &

# Check if remote write metrics exist (may be empty if using SigV4)
curl -s 'http://localhost:9090/api/v1/query?query=up{job="coredns"}' | python3 -m json.tool

# Check Prometheus logs for remote write activity
kubectl logs -n prometheus -l app=prometheus --tail=100 | grep -i "remote_name\|WAL"
```

## 5. Common Issues and Solutions

### Issue: Prometheus Pod Not Running

**Symptoms:**
- Pod status is `CrashLoopBackOff` or `Error`

**Solution:**
```bash
# Check pod events
kubectl describe pod -n prometheus -l app=prometheus-server

# Check logs for errors
kubectl logs -n prometheus -l app=prometheus-server --previous
```

### Issue: CoreDNS Targets Down

**Symptoms:**
- Targets show `health: "down"`
- Error: `Get "http://10.0.x.x:9153/metrics": EOF`

**Solution:**
```bash
# Verify CoreDNS pods are running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check if CoreDNS exposes metrics port
kubectl get svc -n kube-system kube-dns -o yaml | grep -A 5 "ports:"

# Verify CoreDNS configuration
kubectl get configmap coredns -n kube-system -o yaml
```

### Issue: Remote Write Failures

**Symptoms:**
- `prometheus_remote_storage_failed_samples_total` is increasing
- Logs show authentication or connection errors

**Solution:**
```bash
# Check IAM role annotation
kubectl get sa prometheus-server -n prometheus -o yaml | grep eks.amazonaws.com/role-arn

# Verify IAM role has correct permissions
aws iam get-role --role-name $(terraform output -raw prometheus_role_name)

# Check if role policy allows AMP access
aws iam list-attached-role-policies --role-name $(terraform output -raw prometheus_role_name)
```

### Issue: No Data in AMP

**Symptoms:**
- Prometheus shows successful remote writes
- AMP queries return no data or cannot query directly

**Important Notes:**
1. **Direct querying of AMP** requires Grafana or specialized tools
2. **Remote write verification** should be done via Prometheus logs
3. **Data ingestion** can have a 1-2 minute delay

**Solution:**
```bash
# 1. Verify remote write is configured and running
kubectl logs -n prometheus -l app=prometheus --tail=200 | grep "remote_name"

# Look for:
# - "Starting WAL watcher" (remote write initialized)
# - "Done replaying WAL" (data sent successfully)
# - No error messages

# 2. Check IAM role has correct permissions
kubectl get sa prometheus-server -n prometheus -o yaml | grep eks.amazonaws.com/role-arn

# 3. Verify workspace is active
# If using AWS_PROFILE environment variable:
aws amp describe-workspace \
  --workspace-id $(terraform output -raw prometheus_workspace_id) \
  --region $(terraform output -raw aws_region)

# Or with explicit profile:
# aws amp describe-workspace \
#   --workspace-id $(terraform output -raw prometheus_workspace_id) \
#   --region $(terraform output -raw aws_region) \
#   --profile your-profile-name

# 4. Set up Grafana to query AMP (recommended approach)
# Follow AWS documentation: https://docs.aws.amazon.com/prometheus/latest/userguide/AMP-onboard-query-standalone-grafana.html
```

## 6. Useful Prometheus Queries

### CoreDNS Performance Metrics

```promql
# DNS request rate per second
rate(coredns_dns_requests_total[5m])

# DNS requests by query type
sum by (type) (rate(coredns_dns_requests_total[5m]))

# DNS response time (99th percentile)
histogram_quantile(0.99, rate(coredns_dns_request_duration_seconds_bucket[5m]))

# Cache hit ratio
sum(rate(coredns_cache_hits_total[5m])) / 
(sum(rate(coredns_cache_hits_total[5m])) + sum(rate(coredns_cache_misses_total[5m])))

# DNS errors
rate(coredns_dns_responses_total{rcode!="NOERROR"}[5m])
```

### Prometheus Health Metrics

```promql
# Scrape duration
scrape_duration_seconds{job="coredns"}

# Samples scraped per scrape
scrape_samples_scraped{job="coredns"}

# Failed scrapes
up{job="coredns"} == 0

# Remote write lag
prometheus_remote_storage_queue_highest_sent_timestamp_seconds - time()
```

## 7. Clean Up Port-Forward

When done troubleshooting:

```bash
# Find the port-forward process
ps aux | grep "port-forward.*prometheus"

# Kill the process (replace PID with actual process ID)
kill <PID>

# Or use pkill
pkill -f "port-forward.*prometheus"
```

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [AWS Managed Prometheus Documentation](https://docs.aws.amazon.com/prometheus/)
- [CoreDNS Metrics](https://github.com/coredns/coredns/tree/master/plugin/metrics)
- [Prometheus Remote Write](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write)


## 8. Validation Summary

Based on testing, here's what works and what to expect:

### ✅ Working Commands

1. **Check Prometheus Pod Status**
   ```bash
   kubectl get pods -n prometheus
   ```

2. **Check Prometheus Logs**
   ```bash
   kubectl logs -n prometheus -l app=prometheus --tail=50
   ```

3. **Port-Forward to Prometheus**
   ```bash
   kubectl port-forward -n prometheus svc/prometheus-server 9090:9090
   ```

4. **Query CoreDNS Metrics Locally**
   ```bash
   curl -s 'http://localhost:9090/api/v1/query?query=coredns_dns_requests_total' | python3 -m json.tool
   ```

5. **Check Prometheus Targets**
   ```bash
   curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep -A 30 "coredns"
   ```

6. **Verify AMP Workspace**
   ```bash
   # If using AWS_PROFILE environment variable:
   aws amp describe-workspace \
     --workspace-id $(terraform output -raw prometheus_workspace_id) \
     --region $(terraform output -raw aws_region)
   
   # Or with explicit profile:
   # aws amp describe-workspace \
   #   --workspace-id $(terraform output -raw prometheus_workspace_id) \
   #   --region $(terraform output -raw aws_region) \
   #   --profile your-profile-name
   ```

7. **Check Remote Write Configuration**
   ```bash
   kubectl get configmap prometheus-config -n prometheus -o yaml | grep -A 10 "remote_write:"
   ```

8. **Verify IAM Role Annotation**
   ```bash
   kubectl get sa prometheus-server -n prometheus -o yaml | grep eks.amazonaws.com/role-arn
   ```

### ⚠️ Important Notes

1. **Remote Write Metrics**: Prometheus may not expose `prometheus_remote_storage_*` metrics when using SigV4 authentication. This is normal.

2. **AMP Querying**: Direct querying of AMP requires:
   - Grafana setup with AMP data source
   - Or AWS SigV4 proxy
   - The `aws amp query-metrics` command is not available in standard AWS CLI

3. **Verification Method**: The best way to verify remote write is working:
   - Check Prometheus logs for "Starting WAL watcher" and "Done replaying WAL"
   - No error messages in logs
   - AMP workspace status is "ACTIVE"

4. **Data Delay**: There can be a 1-2 minute delay between Prometheus scraping and data appearing in AMP.

### 🔧 Recommended Verification Workflow

```bash
# 0. Set AWS profile (if needed)
export AWS_PROFILE=your-profile-name  # Optional, skip if using default

# 1. Check Prometheus is running
kubectl get pods -n prometheus

# 2. Verify CoreDNS targets are up
kubectl port-forward -n prometheus svc/prometheus-server 9090:9090 &
sleep 3
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep '"health"'

# 3. Verify metrics are being collected
curl -s 'http://localhost:9090/api/v1/query?query=coredns_dns_requests_total' | python3 -m json.tool

# 4. Check remote write is configured
kubectl logs -n prometheus -l app=prometheus --tail=200 | grep "remote_name"

# 5. Verify AMP workspace is active
aws amp describe-workspace \
  --workspace-id $(terraform output -raw prometheus_workspace_id) \
  --region us-west-2

# 6. Clean up
pkill -f "port-forward.*prometheus"
```

### 📊 Setting Up Grafana for AMP

To query metrics from AMP, set up Grafana:

1. **Install Grafana** (locally or on EKS)
2. **Add AMP as a data source** in Grafana
3. **Configure SigV4 authentication** with your AWS credentials
4. **Query metrics** using PromQL in Grafana dashboards

Reference: [AWS AMP with Grafana](https://docs.aws.amazon.com/prometheus/latest/userguide/AMP-onboard-query-standalone-grafana.html)
