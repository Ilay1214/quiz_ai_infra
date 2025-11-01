resource "helm_release" "ingress_nginx" { 
    name             = "ingress-nginx" 
    repository       = "https://kubernetes.github.io/ingress-nginx" 
    chart            = "ingress-nginx" 
    namespace        = var.namespace 
    create_namespace = true 
    version          = "4.8.3"

    set = [
        {
            name  = "controller.service.type"
            value = "LoadBalancer"
        },
        {
            name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
            value = "nlb"
        },
        {
            name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
            value = "internet-facing"
        },
        {
            name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
            value = "true"
        },
        {
            name  = "controller.publishService.enabled"
            value = "true"
        },
        {
            name  = "controller.ingressClassResource.default"
            value = "true"
        },
        {
            name  = "controller.metrics.enabled"
            value = "true"
        }
    ]
}