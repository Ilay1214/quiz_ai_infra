include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "eks" {
  config_path = "../../eks"
  mock_outputs = {
    cluster_name                       = "mock-cluster"
    cluster_endpoint                   = "https://mock-cluster-endpoint"
    cluster_certificate_authority_data = "bW9jay1jYS1kYXRh"
    eso_irsa_role_arn                  = "arn:aws:iam::111122223333:role/mock-eso-irsa"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

generate "provider_k8s" {
  path      = "provider_k8s.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.25.0" }
    helm       = { source = "hashicorp/helm",       version = ">= 2.11.0" }
  }
}

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
  source = "${get_repo_root()}/infra/modules/external-secrets"
}

inputs = {
  irsa_role_arn               = dependency.eks.outputs.eso_irsa_role_arn
  create_cluster_secret_store = true
  region                      = include.root.locals.aws_region
  sa_name                     = "external-secrets"
  sa_namespace                = "external-secrets"
  secret_store_name           = "aws-secrets-manager"
  mysql_ca_property           = "MYSQL_SSL_CA"
  namespaces = {
    quiz-ai-dev = {
      name       = "quiz-ai-dev"
      remote_key = "dev/quiz-ai/env"
    }
  }
}