# infra/live/prod/k8s/apps/terragrunt.hcl (עדכון)
terraform {
  source = "${get_repo_root()}/infra/modules/argocd-apps"
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
  app_manifest_paths = [
    # Root infrastructure app that manages AWS LBC and edge ingress
    "${get_repo_root()}/infra/argocd/prod/root-infra-app.yaml",
    
    # אפליקציית הפרוד (Application שמתקין את הצ'ארט שלך)
    "${get_repo_root()}/infra/argocd/prod/prod_argocd_values.yaml"
  ]
}

dependencies {
  paths = [
    "../argocd",
    "../ingress-nginx"
  ]
}
