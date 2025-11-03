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

