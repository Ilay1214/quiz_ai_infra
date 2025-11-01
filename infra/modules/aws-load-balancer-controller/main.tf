module "aws_lbc_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.6"

  role_name                              = "${var.environment}-aws-lbc-irsa"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "kubernetes_service_account" "aws_lbc" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.aws_lbc_irsa.iam_role_arn
    }
  }
}

resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1" 
  wait       = true
  timeout    = 600
  set = [
    { name = "clusterName", value = var.cluster_name },
    { name = "region",      value = var.region },
    { name = "vpcId",       value = var.vpc_id },

    { name = "serviceAccount.create", value = "false" },
    { name = "serviceAccount.name",   value = "aws-load-balancer-controller" },


    { name = "replicaCount",                  value = "2" },
    { name = "resources.requests.cpu",        value = "100m" },
    { name = "resources.requests.memory",     value = "128Mi" }
  ]

  depends_on = [kubernetes_service_account.aws_lbc]
}
