import {
  to = module.eks.module.kms.aws_kms_alias.this["cluster"]
  id = "alias/eks/prod-eks-cluster"
}

# (תיעוד) כבר ייבאת את ה-Log Group בהצלחה. משאיר כאן למקרה שתרצה לשחזר:
# import {
#   to = module.eks.aws_cloudwatch_log_group.this[0]
#   id = "/aws/eks/prod-eks-cluster/cluster"
# }
