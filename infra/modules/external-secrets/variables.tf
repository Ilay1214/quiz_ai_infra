variable "irsa_role_arn" { type = string }

variable "region" { type = string }
variable "secret_store_name" { type = string }
variable "create_cluster_secret_store" { type = bool}
variable "sa_name" { type = string}
variable "sa_namespace" { type = string}
variable "namespaces" { type = map(object({ name = string, remote_key = string })) }
variable "mysql_ca_property" { type = string}

variable "enable_k8s" {
  type    = bool
  default = true
  }

variable "create_crd_resources" {
  description = "Whether to create CRD-dependent resources (ClusterSecretStore, ExternalSecret). Set to false on first run, then true after External Secrets Operator is installed."
  type        = bool
  default     = false
}

variable "manage_namespaces" {
  description = "Whether this module should create namespaces. Set to false if namespaces are managed externally (e.g., by Argo CD)."
  type        = bool
  default     = false
}

variable "enable_aws_load_balancer_controller" {
  description = "Install AWS Load Balancer Controller via Helm"
  type        = bool
  default     = false
}

variable "alb_controller_irsa_role_arn" {
  description = "IRSA role ARN for AWS Load Balancer Controller service account"
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "EKS cluster name required by AWS Load Balancer Controller chart"
  type        = string
  default     = null
}

variable "enable_ingress_nginx" {
  description = "Install NGINX Ingress Controller via Helm"
  type        = bool
  default     = false
}

variable "nginx_namespace" {
  description = "Namespace where NGINX Ingress Controller will be installed"
  type        = string
  default     = "ingress-nginx"
}

variable "nginx_service_name" {
  description = "Service name of the NGINX Ingress Controller"
  type        = string
  default     = "ingress-nginx-controller"
}

variable "enable_edge_alb_to_nginx" {
  description = "Create an ALB Ingress (class alb) that forwards to NGINX controller service"
  type        = bool
  default     = false
}

variable "edge_ingress_annotations" {
  description = "Extra annotations to apply on the edge ALB Ingress"
  type        = map(string)
  default     = {}
}

variable "create_alb_ingress_class" {
  description = "Whether to create the IngressClass named 'alb'. Set to false if it already exists."
  type        = bool
  default     = true
}