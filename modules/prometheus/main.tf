# Amazon Managed Service for Prometheus (AMP) Workspace
resource "aws_prometheus_workspace" "main" {
  alias = var.workspace_alias

  tags = {
    Name = var.workspace_alias
  }
}

# OIDC Provider for EKS (if not already exists)
data "tls_certificate" "cluster" {
  url = var.cluster_oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "cluster" {
  count = var.create_oidc_provider ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = var.cluster_oidc_issuer_url

  tags = {
    Name = "${var.cluster_name}-oidc-provider"
  }
}

# IAM Role for Prometheus Service Account (for remote write to AMP)
resource "aws_iam_role" "prometheus" {
  name = "${var.cluster_name}-prometheus-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.create_oidc_provider ? aws_iam_openid_connect_provider.cluster[0].arn : var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.prometheus_namespace}:${var.prometheus_service_account}"
          "${replace(var.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name = "${var.cluster_name}-prometheus-role"
  }
}

# IAM Policy for Prometheus to write to AMP
resource "aws_iam_role_policy" "prometheus_amp_remote_write" {
  name = "AMPRemoteWritePolicy"
  role = aws_iam_role.prometheus.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:RemoteWrite",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata"
        ]
        Resource = aws_prometheus_workspace.main.arn
      }
    ]
  })
}
