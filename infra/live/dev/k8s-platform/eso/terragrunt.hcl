# External Secrets Operator deployment for development
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/infra/modules/eks-addons/eso"
}

dependency "eks" {
  config_path = "../../eks"
}

dependency "vpc" {
  config_path = "../../vpc"
}

inputs = {
  eks_cluster_id    = dependency.eks.outputs.cluster_name
  eso_irsa_role_arn = dependency.eks.outputs.eso_irsa_role_arn
  
  # Development configuration (lighter resources)
  chart_version  = "0.10.4"
  replica_count  = 1
  cpu_request    = "25m"
  memory_request = "32Mi"
  cpu_limit      = "100m"
  memory_limit   = "128Mi"
}
