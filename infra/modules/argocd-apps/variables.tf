variable "app_manifest_path" {
  type        = string
  default     = ""
  description = "Single ArgoCD Application manifest path"
}

variable "app_manifest_paths" {
  type        = list(string)
  default     = []
  description = "List of ArgoCD Application manifest paths"
}
