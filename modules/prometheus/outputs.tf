output "workspace_id" {
  description = "AMP workspace ID"
  value       = aws_prometheus_workspace.main.id
}

output "workspace_arn" {
  description = "AMP workspace ARN"
  value       = aws_prometheus_workspace.main.arn
}

output "workspace_endpoint" {
  description = "AMP workspace endpoint for remote write"
  value       = aws_prometheus_workspace.main.prometheus_endpoint
}

output "prometheus_role_arn" {
  description = "IAM role ARN for Prometheus service account"
  value       = aws_iam_role.prometheus.arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN"
  value       = var.create_oidc_provider ? aws_iam_openid_connect_provider.cluster[0].arn : var.oidc_provider_arn
}
