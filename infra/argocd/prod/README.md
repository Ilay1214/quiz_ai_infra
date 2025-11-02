# Production ArgoCD Infrastructure Management

## Overview
This directory contains ArgoCD Application manifests for managing production infrastructure components.

## Migration from Terraform to ArgoCD (November 2024)

### Components Migrated
1. **AWS Load Balancer Controller** - Now managed via ArgoCD/Helm instead of Terraform
2. **Edge Ingress (ALB)** - Migrated from static YAML to Helm chart deployed via ArgoCD
3. **IngressClass for ALB** - Included in edge-ingress Helm chart

### Architecture

```
Internet Traffic
       ↓
   ALB (Edge)        ← Managed by ArgoCD (edge-ingress app)
       ↓
  NGINX Ingress      ← Still managed by Terraform
       ↓
  Application Pods
```

### Files Structure

- `root-infra-app.yaml` - Root ArgoCD application that manages all infrastructure apps
- `aws-load-balancer-controller.yaml` - ArgoCD app for AWS Load Balancer Controller
- `edge-ingress.yaml` - ArgoCD app for edge ALB ingress
- `prod_argocd_values.yaml` - Application deployment configuration (quiz-ai)

### Key Changes

1. **Terraform Changes**:
   - Disabled: `infra/live/prod/k8s/aws-load-balancer-controller/` (renamed to `.disabled`)
   - Modified: `infra/live/prod/k8s/ingress-nginx/terragrunt.hcl` - removed AWS LBC dependency
   - Modified: `infra/live/prod/k8s/argocd/terragrunt.hcl` - enabled apps deployment

2. **New Helm Chart**:
   - Created: `infra/helm/edge-ingress/` - Helm chart for edge ingress and ALB IngressClass

3. **ArgoCD Configuration**:
   - Uses existing IRSA ServiceAccount (no new SA creation)
   - Relies on subnet autodiscovery via VPC tags
   - Automated sync and self-heal enabled for all apps

### Prerequisites

1. **VPC Subnet Tags** (already configured):
   ```
   Public Subnets:
   - kubernetes.io/cluster/prod-eks-cluster = shared
   - kubernetes.io/role/elb = 1

   Private Subnets:
   - kubernetes.io/cluster/prod-eks-cluster = shared
   - kubernetes.io/role/internal-elb = 1
   ```

2. **Existing IRSA** for AWS Load Balancer Controller:
   - ServiceAccount: `aws-load-balancer-controller` in `kube-system`
   - IAM Role with necessary permissions already created by Terraform

### Deployment Process

1. **Apply Terragrunt changes**:
   ```bash
   cd infra/live/prod
   terragrunt run-all apply
   ```

2. **Verify ArgoCD Applications**:
   ```bash
   kubectl get applications -n argocd
   ```

3. **Check ALB creation**:
   ```bash
   kubectl get ingress -n ingress-nginx edge-to-nginx
   ```

### Rollback Procedure

If rollback is needed:

1. Delete ArgoCD applications:
   ```bash
   kubectl delete application -n argocd edge-ingress
   kubectl delete application -n argocd aws-load-balancer-controller
   kubectl delete application -n argocd prod-infrastructure
   ```

2. Restore Terraform configuration:
   - Rename `.disabled` file back to `terragrunt.hcl` in aws-load-balancer-controller
   - Restore ingress-nginx dependencies
   - Disable ArgoCD apps in terragrunt

### Validation

After deployment, verify:

1. **AWS Load Balancer Controller pods**:
   ```bash
   kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```

2. **ALB creation and status**:
   ```bash
   kubectl get ingress -n ingress-nginx edge-to-nginx -o wide
   ```

3. **Test connectivity**:
   ```bash
   curl -I http://<ALB-DNS-NAME>/
   ```
   Should return a response (404 is expected if no default backend)

### Notes

- The edge ingress uses a simple health check on `/` path
- Target type is set to `ip` for better pod-to-pod communication
- The controller handles TargetGroupBinding automatically
- No hardcoded subnet IDs - relies on tag-based discovery
