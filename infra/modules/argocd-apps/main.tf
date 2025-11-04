locals {
  manifests = length(var.app_manifest_paths) > 0 ? var.app_manifest_paths : (
    var.app_manifest_path != "" ? [var.app_manifest_path] : []
  )
}

# Only create ArgoCD Application 
resource "kubernetes_manifest" "app" {
  for_each = toset(local.manifests)
  manifest = yamldecode(file(each.value))

  # Handle deletion of resources with finalizers
  wait {
    fields = {
      # Wait for the Application to be fully deleted
      "metadata.deletionTimestamp" = "*"
    }
  }

  # Force removal of finalizers on destroy
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kubectl patch application ${self.manifest.metadata.name} -n ${self.manifest.metadata.namespace} \
        --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>nul || exit 0
    EOT
    on_failure = continue
  }
}
