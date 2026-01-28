variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "workspace_alias" {
  description = "AMP workspace alias"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL"
  type        = string
}

variable "create_oidc_provider" {
  description = "Whether to create OIDC provider (set to false if already exists)"
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "Existing OIDC provider ARN (required if create_oidc_provider is false)"
  type        = string
  default     = ""
}

variable "prometheus_namespace" {
  description = "Kubernetes namespace for Prometheus"
  type        = string
  default     = "prometheus"
}

variable "prometheus_service_account" {
  description = "Kubernetes service account name for Prometheus"
  type        = string
  default     = "prometheus-server"
}
