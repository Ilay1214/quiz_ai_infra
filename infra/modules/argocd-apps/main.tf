locals {
  manifests = length(var.app_manifest_paths) > 0 ? var.app_manifest_paths : (
    var.app_manifest_path != "" ? [var.app_manifest_path] : []
  )
}

# Only create ArgoCD Application resources, don't install ArgoCD itself
resource "kubernetes_manifest" "app" {
  for_each = toset(local.manifests)
  manifest = yamldecode(file(each.value))
}
