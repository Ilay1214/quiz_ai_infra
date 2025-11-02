# infra/live/prod/k8s/apps/terragrunt.hcl (עדכון)
terraform {
  source = "${get_repo_root()}/infra/modules/argocd"
}
include "root" {
  path   = "${get_repo_root()}/infra/live/terragrunt.hcl"
  expose = true
}


dependency "eks" {
  config_path = "../../eks"
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
inputs = {
  environment = include.root.locals.environment
  enable_apps = true

  app_manifest_paths = [
    # אפליקציית הפרוד (Application שמתקין את הצ'ארט שלך)
    "${get_repo_root()}/infra/argocd/prod/prod_argocd_values.yaml"
  ]
}

dependencies {
  paths = [
    "../ingress-nginx"
  ]
}
