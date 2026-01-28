variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS cluster"
  type        = list(string)
}

variable "node_group_name" {
  description = "EKS node group name"
  type        = string
}

variable "node_instance_types" {
  description = "EC2 instance types for nodes"
  type        = list(string)
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
}

variable "vpc_cni_version" {
  description = "VPC CNI add-on version (leave empty for latest)"
  type        = string
  default     = null
}

variable "coredns_version" {
  description = "CoreDNS add-on version (leave empty for latest)"
  type        = string
  default     = null
}

variable "kube_proxy_version" {
  description = "kube-proxy add-on version (leave empty for latest)"
  type        = string
  default     = null
}
