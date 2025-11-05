terraform {
  required_version = ">= 1.3.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

# AWS Load Balancer Controller Helm Release
resource "helm_release" "aws_load_balancer_controller" {
  name       = var.release_name
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  namespace  = var.namespace

  create_namespace = false  # Should already exist (kube-system)
  wait            = true
  wait_for_jobs   = true
  timeout         = 600

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      cluster_name          = var.cluster_name
      region               = var.aws_region
      vpc_id               = var.vpc_id
      alb_controller_irsa_role_arn = var.alb_controller_irsa_role_arn
      replica_count        = var.replica_count
      cpu_request          = var.cpu_request
      memory_request       = var.memory_request
    })
  ]

  depends_on = [var.eks_cluster_id]
}

# Tag VPC and subnets for auto-discovery
resource "null_resource" "subnet_tags" {
  count = var.enable_subnet_tagging ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      aws ec2 create-tags --resources ${join(" ", var.public_subnet_ids)} \
        --tags Key=kubernetes.io/role/elb,Value=1 \
               Key=kubernetes.io/cluster/${var.cluster_name},Value=shared
      
      aws ec2 create-tags --resources ${join(" ", var.private_subnet_ids)} \
        --tags Key=kubernetes.io/role/internal-elb,Value=1 \
               Key=kubernetes.io/cluster/${var.cluster_name},Value=shared
      
      aws ec2 create-tags --resources ${var.vpc_id} \
        --tags Key=kubernetes.io/cluster/${var.cluster_name},Value=shared
    EOT
  }
}
