# ClusterSecretStore for production
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/infra/modules/eks-addons/cluster-secret-store"
}

dependency "eso" {
  config_path = "../eso"
}

inputs = {
  secret_store_name   = "aws-secrets-manager"  # Keep the same name apps are using
  aws_region          = "eu-central-1"
  eso_service_account = dependency.eso.outputs.service_account
  eso_namespace       = dependency.eso.outputs.namespace
  eso_crds_ready      = dependency.eso.outputs.crds_ready
}
