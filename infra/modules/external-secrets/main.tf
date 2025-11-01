resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  version          = "0.10.4" 
  create_namespace = true

  set = [{
    name  = "installCRDs"
    value = true
  },
  {
    name  = "serviceAccount.create"
    value = true
  },
  {
    name  = "serviceAccount.name"
    value = "external-secrets"
  },
  {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.irsa_role_arn
  }
  ]
}