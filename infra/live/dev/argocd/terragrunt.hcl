terraform { source = "${get_repo_root()}/infra/modules/argocd" }
include "root" { path = find_in_parent_folders() }
inputs = {
  environment       = "dev"
  app_manifest_path = "${get_repo_root()}/infra/argocd/dev/dev_argocd_values.yaml"
}