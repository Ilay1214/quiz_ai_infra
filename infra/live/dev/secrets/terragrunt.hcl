include "root" { path = find_in_parent_folders() }

dependency "eks" { config_path = "../eks" }

generate "provider_k8s" { 
  path = "provider_k8s.generated.tf" 
  if_exists = "overwrite_terragrunt" 
  contents = <<EOF 
    terraform { 
      required_providers { 
        kubernetes = { 
          source = "hashicorp/kubernetes", 
          version = ">= 2.25.0" } 
        helm = { 
          source = "hashicorp/helm", 
          version = ">= 2.11.0" }
          } 
        } 
      data "aws_eks_cluster_auth" "this" { 
        name = "${dependency.eks.outputs.cluster_name}" } 
        provider "kubernetes" { 
          host = "${dependency.eks.outputs.cluster_endpoint}" 
          cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}") 
          token = data.aws_eks_cluster_auth.this.token } 
        provider "helm" { 
          kubernetes { 
          host = "${dependency.eks.outputs.cluster_endpoint}" 
          cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}") 
          token = data.aws_eks_cluster_auth.this.token load_config_file = false } 
        } 
    EOF 
    }

terraform { source = "${get_repo_root()}/infra/modules/eso-aws-config" }

inputs = { 
  region = "eu-central-1" 
  create_cluster_secret_store = true 
  namespaces = { 
    staging = { 
      name = "quiz-ai-staging", 
      remote_key = "quiz-ai/staging/app-env" } 
      } 
}

