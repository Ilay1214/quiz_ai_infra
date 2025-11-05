# AWS Load Balancer Controller for production
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/infra/modules/eks-addons/alb-controller"
}

dependency "eks" {
  config_path = "../../eks"
}

dependency "vpc" {
  config_path = "../../vpc"
}

inputs = {
  cluster_name                 = dependency.eks.outputs.cluster_name
  eks_cluster_id               = dependency.eks.outputs.cluster_name
  aws_region                   = "eu-central-1"
  vpc_id                       = dependency.vpc.outputs.vpc_id
  public_subnet_ids            = dependency.vpc.outputs.public_subnets
  private_subnet_ids           = dependency.vpc.outputs.private_subnets
  alb_controller_irsa_role_arn = dependency.eks.outputs.alb_controller_irsa_role_arn
  
  # Production configuration
  chart_version         = "1.7.1"
  replica_count         = 2
  cpu_request           = "100m"
  memory_request        = "128Mi"
  enable_subnet_tagging = true  # Enable auto-discovery tagging
}
