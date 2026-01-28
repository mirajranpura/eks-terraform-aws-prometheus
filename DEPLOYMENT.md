# Deployment Guide

Complete guide for deploying this EKS cluster with AWS Managed Prometheus monitoring.

## Quick Start

```bash
# 1. Configure AWS credentials
export AWS_PROFILE=your-profile

# 2. Initialize and deploy infrastructure
terraform init
terraform apply

# 3. Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster

# 4. Deploy Prometheus monitoring
./scripts/deploy-prometheus.sh

# 5. Verify deployment
kubectl get nodes
kubectl get pods -A
kubectl get pods -n prometheus
```

## Detailed Steps

### 1. Prerequisites

Install required tools:
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) >= 2.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28
- [envsubst](https://www.gnu.org/software/gettext/) (for deployment script)

Configure AWS credentials:
```bash
aws configure --profile your-profile
# Or use environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_REGION="us-west-2"
```

### 2. Customize Configuration (Optional)

Copy and edit the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to customize:
- Region and availability zones
- VPC CIDR blocks
- Node group size and instance types
- Cluster name

### 3. Deploy Infrastructure

Initialize Terraform:
```bash
terraform init
```

Review the plan:
```bash
terraform plan
```

Apply the configuration:
```bash
terraform apply
```

This will create:
- VPC with public and private subnets
- NAT Gateways for private subnet internet access
- EKS cluster with Kubernetes 1.30
- Managed node group with 2 t3.medium instances
- EKS managed add-ons (VPC CNI, CoreDNS, kube-proxy)
- AWS Managed Prometheus workspace
- IAM roles and OIDC provider for IRSA

**Estimated time:** 15-20 minutes

### 4. Configure kubectl

Get the cluster configuration:
```bash
aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster --profile your-profile
```

Or use the Terraform output:
```bash
$(terraform output -raw configure_kubectl)
```

Verify access:
```bash
kubectl get nodes
kubectl get pods -A
```

### 5. Deploy Prometheus Monitoring

#### Option A: Automated Deployment (Recommended)

```bash
./scripts/deploy-prometheus.sh
```

#### Option B: Manual Deployment

See [k8s/README.md](k8s/README.md) for manual deployment instructions.

### 6. Verify Monitoring

Check Prometheus pod:
```bash
kubectl get pods -n prometheus
kubectl logs -n prometheus -l app=prometheus-server
```

Port-forward to Prometheus UI:
```bash
kubectl port-forward -n prometheus svc/prometheus-server 9090:9090
```

Visit http://localhost:9090 and check:
- Status → Targets (should show 2 healthy CoreDNS targets)
- Graph → Query `coredns_dns_requests_total`

### 7. Access AWS Managed Prometheus

Get workspace details:
```bash
terraform output prometheus_workspace_id
terraform output prometheus_workspace_endpoint
```

Query metrics from AMP:
- Use AWS Console → Amazon Managed Service for Prometheus
- Connect Grafana with AMP data source
- Use AWS SDK/CLI with SigV4 authentication

## Post-Deployment

### Deploy Your Applications

```bash
kubectl create namespace my-app
kubectl apply -f your-app-manifests.yaml
```

### Set Up Grafana (Optional)

1. Deploy Grafana to EKS or use Grafana Cloud
2. Add AMP as data source:
   - Type: Prometheus
   - URL: `<prometheus_workspace_endpoint>`
   - Auth: SigV4 auth
   - Region: us-west-2
3. Import CoreDNS dashboard (ID: 7279)

### Configure Additional Monitoring

Edit `k8s/prometheus-config.yaml` to add more scrape targets:
```yaml
scrape_configs:
  - job_name: 'my-app'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - my-namespace
```

Then redeploy:
```bash
./scripts/deploy-prometheus.sh
```

## Maintenance

### Upgrade Kubernetes Version

1. Update `variables.tf`:
   ```hcl
   variable "cluster_version" {
     default = "1.31"  # Increment by one minor version
   }
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

3. Update node group (if needed):
   ```bash
   aws eks update-nodegroup-version \
     --cluster-name my-eks-cluster \
     --nodegroup-name my-eks-cluster-node-group \
     --region us-west-2
   ```

### Update EKS Add-ons

Check available versions:
```bash
aws eks describe-addon-versions --addon-name vpc-cni --kubernetes-version 1.30
```

Update in Terraform:
```hcl
variable "vpc_cni_version" {
  default = "v1.20.5-eksbuild.1"  # New version
}
```

Apply:
```bash
terraform apply
```

### Scale Node Group

Edit `terraform.tfvars`:
```hcl
node_desired_size = 3
node_min_size = 2
node_max_size = 5
```

Apply:
```bash
terraform apply
```

## Cleanup

### Remove Prometheus

```bash
kubectl delete namespace prometheus
```

### Destroy Infrastructure

```bash
terraform destroy
```

**Warning:** This will delete all resources including the EKS cluster, VPC, and AMP workspace.

## Troubleshooting

### Terraform Issues

**State lock error:**
```bash
terraform force-unlock <lock-id>
```

**Provider version conflicts:**
```bash
rm -rf .terraform
terraform init -upgrade
```

### EKS Access Issues

**kubectl connection timeout:**
- Check security group rules
- Verify VPC endpoint configuration
- Ensure IAM permissions

**Nodes not joining:**
- Check NAT Gateway connectivity
- Verify IAM role permissions
- Check node group configuration

### Prometheus Issues

**Pod not starting:**
```bash
kubectl describe pod -n prometheus <pod-name>
kubectl logs -n prometheus <pod-name>
```

**IRSA authentication errors:**
- Verify IAM role ARN in ServiceAccount annotation
- Check OIDC provider configuration
- Ensure IAM role trust policy is correct

**Metrics not in AMP:**
- Check remote write configuration
- Verify IAM role has AMP write permissions
- Check Prometheus logs for remote write errors

## Cost Optimization

### Development Environment

For non-production use:
- Use single NAT Gateway (edit VPC module)
- Use t3.small instances
- Scale down to 1 node
- Delete when not in use

### Production Environment

- Use Spot instances for non-critical workloads
- Enable cluster autoscaler
- Use EKS Auto Mode (when available)
- Monitor AMP ingestion costs
- Set up cost alerts

## Security Best Practices

- [ ] Enable EKS audit logging
- [ ] Restrict API endpoint access
- [ ] Use private subnets for nodes
- [ ] Enable pod security policies
- [ ] Rotate IAM credentials regularly
- [ ] Use AWS Secrets Manager for secrets
- [ ] Enable VPC flow logs
- [ ] Set up AWS GuardDuty
- [ ] Use IRSA for pod IAM permissions
- [ ] Regular security scanning with tools like kube-bench

## Monitoring Best Practices

- [ ] Set up CloudWatch alarms for cluster health
- [ ] Monitor node resource utilization
- [ ] Track pod restart counts
- [ ] Monitor AMP ingestion costs
- [ ] Set up Grafana dashboards
- [ ] Configure alerting rules in Prometheus
- [ ] Monitor CoreDNS query patterns
- [ ] Track API server latency

## Support

For issues or questions:
1. Check [README.md](README.md) for general information
2. See [k8s/README.md](k8s/README.md) for Kubernetes deployment details
3. Review [scripts/README.md](scripts/README.md) for script documentation
4. Check AWS documentation for service-specific issues

## Additional Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [AWS Managed Prometheus User Guide](https://docs.aws.amazon.com/prometheus/latest/userguide/)
