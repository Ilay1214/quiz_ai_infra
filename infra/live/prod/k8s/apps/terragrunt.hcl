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
    # Wave 1: External Secrets Operator (with CRDs)
    "${get_repo_root()}/infra/argocd/prod/external-secrets-operator.yaml",
    
    # Wave 2: AWS Load Balancer Controller
    "${get_repo_root()}/infra/argocd/prod/aws-load-balancer-controller.yaml",
    
    # Wave 3: NGINX Ingress Controller
    "${get_repo_root()}/infra/argocd/prod/ingress-nginx.yaml",
    
    # Wave 4: Edge Ingress (ALB -> NGINX)
    "${get_repo_root()}/infra/argocd/prod/edge-ingress.yaml",
    
    # Wave 5: External Secrets Configuration
    "${get_repo_root()}/infra/argocd/prod/external-secrets-config.yaml",
    
    # Wave 6: Production Application
    "${get_repo_root()}/infra/argocd/prod/prod_argocd_values.yaml"
  ]
}

dependencies {
  paths = [
    "../argocd"
    # ingress-nginx removed - now managed by ArgoCD
  ]
}
