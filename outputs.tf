output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}

output "vpc_cni_addon_version" {
  description = "VPC CNI add-on version"
  value       = module.eks.vpc_cni_addon_version
}

output "coredns_addon_version" {
  description = "CoreDNS add-on version"
  value       = module.eks.coredns_addon_version
}

output "kube_proxy_addon_version" {
  description = "kube-proxy add-on version"
  value       = module.eks.kube_proxy_addon_version
}

output "prometheus_workspace_id" {
  description = "Amazon Managed Prometheus workspace ID"
  value       = module.prometheus.workspace_id
}

output "prometheus_workspace_endpoint" {
  description = "Amazon Managed Prometheus workspace endpoint"
  value       = module.prometheus.workspace_endpoint
}

output "prometheus_role_arn" {
  description = "IAM role ARN for Prometheus service account"
  value       = module.prometheus.prometheus_role_arn
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
