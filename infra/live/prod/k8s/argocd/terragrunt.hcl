# infra/live/prod/k8s/argocd/terragrunt.hcl
include "root" {
  path   = "${get_repo_root()}/infra/live/terragrunt.hcl"
  expose = true
}

locals {
  raw_environment = try(include.root.locals.environment, "prod")
  environment     = (local.raw_environment == "" || local.raw_environment == "/") ? "prod" : local.raw_environment
  env_sanitized = replace(replace(replace(local.environment, " ", "-"), "/", "-"), "\\", "-")
}

dependency "eks" {
  config_path  = "../../eks"   
  skip_outputs = false
}

generate "provider_k8s" {
  path      = "provider_k8s.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF


data "aws_eks_cluster_auth" "this" {
  name = "${dependency.eks.outputs.cluster_name}"
}

provider "kubernetes" {
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes = {
    host                   = "${dependency.eks.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
    token                  = data.aws_eks_cluster_auth.this.token
    load_config_file       = false
  }
}
EOF
}

terraform {
  source = "${get_repo_root()}/infra/modules/argocd"
}

inputs = {
  environment        = local.env_sanitized
  enable_apps        = false  # Don't create apps here, just install ArgoCD
  app_manifest_path  = ""
  app_manifest_paths = []
}
