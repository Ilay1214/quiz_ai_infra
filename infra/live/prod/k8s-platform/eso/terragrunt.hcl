# External Secrets Operator deployment for production
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
  
  # Production configuration
  chart_version  = "0.10.4"
  replica_count  = 2
  cpu_request    = "50m"
  memory_request = "64Mi"
  cpu_limit      = "200m"
  memory_limit   = "256Mi"
}
