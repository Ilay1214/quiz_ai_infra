
include "root" {
  path   = "${get_repo_root()}/infra/live/terragrunt.hcl"
  expose = true
}

locals {
  aws_region = try(include.root.locals.aws_region, "eu-central-1")
}

dependency "eks" {
  config_path = "../../eks"
  mock_outputs = {
    cluster_name  = "mock-cluster"
    cluster_endpoint  = "https://mock-cluster-endpoint"
    cluster_certificate_authority_data = "bW9jay1jYS1kYXRh"
    eso_irsa_role_arn = "arn:aws:iam::111122223333:role/mock-eso-irsa"
    alb_controller_irsa_role_arn       = "arn:aws:iam::111122223333:role/mock-alb-irsa"
  }
  mock_outputs_allowed_terraform_commands = ["validate","plan","init"]
}

dependency "iam" {
  config_path = "../../iam"
  mock_outputs = {
    eso_policy_arn = "arn:aws:iam::111122223333:policy/mock-eso"
  }
  mock_outputs_allowed_terraform_commands = ["validate","plan","init"]
}

dependency "vpc" {
  config_path = "../../vpc"
  mock_outputs = {
    vpc_id         = "vpc-000000"
    public_subnets = ["subnet-aaa","subnet-bbb","subnet-ccc"]
  }
  mock_outputs_allowed_terraform_commands = ["validate","plan","init"]
}


generate "provider_k8s" {
  path      = "provider_k8s.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
data "aws_eks_cluster_auth" "this" {
  name = "${dependency.eks.outputs.cluster_name}"
}

provider "kubernetes" {
  host  = "${dependency.eks.outputs.cluster_endpoint}"
  token = data.aws_eks_cluster_auth.this.token
  insecure = true
}

provider "helm" {
  kubernetes = {
    host = "${dependency.eks.outputs.cluster_endpoint}"
    token = data.aws_eks_cluster_auth.this.token
    insecure = true
    load_config_file = false
  }
}
EOF
}

terraform {
  source = "${get_repo_root()}/infra/modules/external-secrets"
}

inputs = {
  enable_k8s = false  # Disable - External Secrets now fully managed by ArgoCD
  create_crd_resources = true
  manage_namespaces  = false
  irsa_role_arn  = dependency.eks.outputs.eso_irsa_role_arn
  create_cluster_secret_store = false
  region  = local.aws_region
  sa_name = "external-secrets"
  sa_namespace  = "external-secrets"
  secret_store_name = "aws-secrets-manager"
  mysql_ca_property = "MYSQL_SSL_CA"



  namespaces = {}  # Namespaces managed by ArgoCD
}

dependencies {
  paths = ["../../eks","../../iam","../../vpc"]
}
