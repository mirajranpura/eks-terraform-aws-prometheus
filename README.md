# EKS Cluster with Terraform

This Terraform project creates an AWS EKS cluster with a managed node group in private subnets.

## Architecture

- **VPC**: Custom VPC with CIDR 10.0.0.0/16
- **Public Subnets**: 2 subnets (10.0.1.0/24, 10.0.2.0/24) with Internet Gateway
- **Private Subnets**: 2 subnets (10.0.10.0/24, 10.0.20.0/24) with NAT Gateways
- **EKS Cluster**: Kubernetes cluster in private subnets
- **Managed Node Group**: EC2 instances in private subnets

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
├── modules/
│   ├── vpc/                   # VPC module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── eks/                   # EKS module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
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

View outputs:

```bash
terraform output
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` when prompted.

## Cost Considerations

This setup includes:
- 2 NAT Gateways (~$0.045/hour each)
- EKS cluster (~$0.10/hour)
- EC2 instances (varies by instance type)
- Data transfer costs

Estimated monthly cost: ~$150-200 (depending on usage)

## Security Notes

- Nodes are in private subnets (no direct internet access)
- NAT Gateways provide outbound internet for updates
- EKS API endpoint is public by default (can be restricted)
- Security groups control traffic flow
- IAM roles follow least privilege principle

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

## Additional Resources

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
