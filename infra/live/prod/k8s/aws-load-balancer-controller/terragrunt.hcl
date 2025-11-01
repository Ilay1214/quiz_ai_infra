
include "root" {
  path   = "${get_repo_root()}/infra/live/terragrunt.hcl"
  expose = true
}

dependency "eks" {
  config_path = "../../eks"
  mock_outputs = {
    cluster_name                         = "mock-cluster"
    cluster_endpoint                     = "https://mock-cluster-endpoint"
    cluster_certificate_authority_data   = "bW9jay1jYS1kYXRh"
    oidc_provider_arn                    = "arn:aws:iam::111122223333:oidc-provider/mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan","init"]
}
download_dir = "C:/tg"
dependency "vpc" {
  config_path = "../../vpc"
  mock_outputs = {
    vpc_id = "mock-vpc-id"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan","init"]
}

generate "provider_k8s" {
  path      = "provider_k8s.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF

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
  }
}
EOF
}

terraform {
  source = "${get_repo_root()}/infra/modules/aws-load-balancer-controller"
}
inputs = {
  environment       = include.root.locals.environment
  cluster_name      = dependency.eks.outputs.cluster_name
  region            = include.root.locals.aws_region
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  vpc_id            = dependency.vpc.outputs.vpc_id
}
