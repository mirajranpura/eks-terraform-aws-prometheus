# EKS Cluster with Terraform

This Terraform project creates an AWS EKS cluster with a managed node group in private subnets, along with AWS Managed Prometheus for monitoring CoreDNS.

## Architecture

- **VPC**: Custom VPC with CIDR 10.0.0.0/16
- **Public Subnets**: 2 subnets (10.0.1.0/24, 10.0.2.0/24) with Internet Gateway
- **Private Subnets**: 2 subnets (10.0.10.0/24, 10.0.20.0/24) with NAT Gateways
- **EKS Cluster**: Kubernetes 1.30 cluster in private subnets
- **Managed Node Group**: 2 t3.medium EC2 instances in private subnets
- **EKS Add-ons**: VPC CNI, CoreDNS, kube-proxy (managed versions)
- **AWS Managed Prometheus**: Monitoring workspace for CoreDNS metrics
- **Prometheus Server**: In-cluster Prometheus with remote write to AMP

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- kubectl (for cluster access)

## Project Structure

```
.
├── main.tf                    # Root module
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example variables file
├── README.md                  # This file
├── DEPLOYMENT.md              # Deployment guide
├── .gitignore                 # Git ignore rules
├── .terraform.lock.hcl        # Terraform dependency lock
├── k8s/                       # Kubernetes manifests
│   ├── README.md              # K8s deployment documentation
│   ├── TROUBLESHOOTING.md     # K8s troubleshooting guide
│   ├── prometheus-namespace.yaml
│   ├── prometheus-serviceaccount.yaml
│   ├── prometheus-rbac.yaml
│   ├── prometheus-config.yaml
│   └── prometheus-deployment.yaml
├── scripts/                   # Deployment automation
│   ├── README.md              # Scripts documentation
│   └── deploy-prometheus.sh   # Prometheus deployment script
└── modules/
    ├── vpc/                   # VPC module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── eks/                   # EKS module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── prometheus/            # AWS Managed Prometheus module
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Usage

### 1. Configure Variables

Copy the example variables file and customize:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your desired values.

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to create the resources.

### 5. Configure kubectl

After the cluster is created, configure kubectl:

```bash
aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster
```

Or use the output command:

```bash
terraform output -raw configure_kubectl | bash
```

### 6. Verify Cluster Access

```bash
kubectl get nodes
kubectl get pods -A
```

### 7. Deploy Prometheus for Monitoring

Use the provided deployment script that automatically substitutes Terraform outputs:

```bash
./scripts/deploy-prometheus.sh
```

Or manually apply the manifests (see [k8s/README.md](k8s/README.md) for details):

```bash
# Get Terraform outputs
export PROMETHEUS_ROLE_ARN=$(terraform output -raw prometheus_role_arn)
export AMP_WORKSPACE_ENDPOINT=$(terraform output -raw prometheus_workspace_endpoint)
export AWS_REGION=$(terraform output -raw aws_region)

# Apply with substitution
kubectl apply -f k8s/prometheus-namespace.yaml
envsubst < k8s/prometheus-serviceaccount.yaml | kubectl apply -f -
kubectl apply -f k8s/prometheus-rbac.yaml
envsubst < k8s/prometheus-config.yaml | kubectl apply -f -
kubectl apply -f k8s/prometheus-deployment.yaml
```

Verify Prometheus is running:

```bash
kubectl get pods -n prometheus
```

### 8. Verify CoreDNS Monitoring

Check that Prometheus is scraping CoreDNS metrics:

```bash
# Port-forward to Prometheus
kubectl port-forward -n prometheus svc/prometheus-server 9090:9090

# In another terminal, query metrics
curl 'http://localhost:9090/api/v1/query?query=coredns_dns_requests_total'
```

## Monitoring with AWS Managed Prometheus

### Access AMP Workspace

The Terraform deployment creates an AWS Managed Prometheus workspace. Get the details:

```bash
terraform output prometheus_workspace_id
terraform output prometheus_workspace_endpoint
```

### Query Metrics from AMP

You can query metrics from AWS Managed Prometheus using:

1. **AWS Console**: Navigate to Amazon Managed Service for Prometheus
2. **Grafana**: Connect Grafana to AMP using the workspace endpoint
3. **AWS CLI**: Use the AMP Query API with SigV4 authentication

### Available CoreDNS Metrics

Key metrics being collected:

- `coredns_dns_requests_total`: Total DNS requests by type
- `coredns_dns_responses_total`: Total DNS responses by rcode
- `coredns_dns_request_duration_seconds`: DNS request latency
- `coredns_cache_hits_total`: DNS cache hit count
- `coredns_cache_misses_total`: DNS cache miss count
- `coredns_forward_requests_total`: Forwarded DNS requests

### Setting Up Grafana (Optional)

To visualize metrics in Grafana:

1. Install Grafana (locally or in EKS)
2. Add AMP as a data source:
   - Type: Prometheus
   - URL: `<prometheus_workspace_endpoint>/api/v1/query`
   - Auth: SigV4 auth with AWS credentials
   - Region: us-west-2
3. Import CoreDNS dashboard (ID: 5926 or 7279)

## Customization

### Change Region

Edit `terraform.tfvars`:

```hcl
aws_region = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b"]
```

### Adjust Node Group Size

Edit `terraform.tfvars`:

```hcl
node_desired_size = 3
node_min_size = 2
node_max_size = 5
node_instance_types = ["t3.large"]
```

### Modify Network Configuration

Edit `terraform.tfvars`:

```hcl
vpc_cidr = "10.1.0.0/16"
public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.20.0/24"]
```

## Outputs

After applying, you'll get:

- `vpc_id`: VPC identifier
- `cluster_name`: EKS cluster name
- `cluster_endpoint`: EKS API endpoint
- `configure_kubectl`: Command to configure kubectl
- `vpc_cni_addon_version`: VPC CNI add-on version
- `coredns_addon_version`: CoreDNS add-on version
- `kube_proxy_addon_version`: kube-proxy add-on version
- `prometheus_workspace_id`: AMP workspace ID
- `prometheus_workspace_endpoint`: AMP workspace endpoint
- `prometheus_role_arn`: IAM role ARN for Prometheus

View outputs:

```bash
terraform output
```

## Cleanup

To destroy all resources:

```bash
# Delete Prometheus deployment first
kubectl delete -f k8s/

# Then destroy Terraform resources
terraform destroy
```

Type `yes` when prompted.

**Note**: Ensure all Kubernetes resources are deleted before destroying the cluster to avoid orphaned resources.

## Cost Considerations

This setup includes:
- 2 NAT Gateways (~$0.045/hour each = ~$65/month)
- EKS cluster (~$0.10/hour = ~$73/month)
- 2 t3.medium EC2 instances (~$0.0416/hour each = ~$60/month)
- AWS Managed Prometheus workspace (~$0.30/month for ingestion + storage)
- Data transfer costs (varies)

Estimated monthly cost: ~$200-250 (depending on usage and data transfer)

**Cost Optimization Tips**:
- Use Spot instances for non-production workloads
- Consider single NAT Gateway for dev environments
- Monitor AMP ingestion costs
- Use EKS Auto Mode for production (when available)

## Security Notes

- Nodes are in private subnets (no direct internet access)
- NAT Gateways provide outbound internet for updates
- EKS API endpoint is public by default (can be restricted)
- Security groups control traffic flow
- IAM roles follow least privilege principle
- IRSA (IAM Roles for Service Accounts) used for Prometheus
- Prometheus uses SigV4 authentication for AMP remote write
- OIDC provider enables secure pod-level IAM permissions

## Troubleshooting

### Nodes not joining cluster

Check:
- NAT Gateway connectivity
- Security group rules
- IAM role permissions

### kubectl connection issues

Verify:
- AWS credentials are configured
- kubectl is updated to cluster config
- Cluster endpoint is accessible

### Prometheus not scraping CoreDNS

Check:
- Prometheus pod is running: `kubectl get pods -n prometheus`
- CoreDNS pods are healthy: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
- Check Prometheus targets: Port-forward and visit http://localhost:9090/targets
- View Prometheus logs: `kubectl logs -n prometheus <pod-name>`

### Metrics not appearing in AMP

Verify:
- IAM role has correct permissions
- Remote write configuration is correct in ConfigMap
- Check Prometheus logs for remote write errors
- Ensure OIDC provider is properly configured

### EKS Add-on Issues

Check add-on status:
```bash
aws eks describe-addon --cluster-name my-eks-cluster --addon-name vpc-cni --region us-west-2
aws eks describe-addon --cluster-name my-eks-cluster --addon-name coredns --region us-west-2
aws eks describe-addon --cluster-name my-eks-cluster --addon-name kube-proxy --region us-west-2
```

## Additional Resources

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [AWS Managed Prometheus](https://docs.aws.amazon.com/prometheus/latest/userguide/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [CoreDNS Metrics](https://coredns.io/plugins/metrics/)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

## Features

✅ Production-ready EKS cluster with Kubernetes 1.30  
✅ High availability across 2 availability zones  
✅ Managed EKS add-ons (VPC CNI, CoreDNS, kube-proxy)  
✅ Private node placement with NAT Gateway egress  
✅ AWS Managed Prometheus for metrics storage  
✅ CoreDNS monitoring with Prometheus  
✅ IRSA for secure pod-level IAM permissions  
✅ Infrastructure as Code with Terraform modules  
✅ Git version control for all configurations
