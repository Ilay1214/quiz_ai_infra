# Production Deployment Order

## One-Command Deployment
All components deploy in a single ArgoCD sync with deterministic ordering via sync waves.

## Infrastructure Stack (Terraform/Terragrunt)
1. **VPC** - `terragrunt apply` in `prod/vpc/`
2. **IAM** - `terragrunt apply` in `prod/iam/` (includes OIDC/IRSA roles)
3. **EKS** - `terragrunt apply` in `prod/eks/`
4. **ArgoCD** - `terragrunt apply` in `prod/k8s/argocd/` (installs ArgoCD only)
5. **Apps** - `terragrunt apply` in `prod/k8s/apps/` (deploys all ArgoCD applications)

## Kubernetes Stack (ArgoCD Managed)
All components deployed automatically via ArgoCD sync waves:

- **Wave 1**: External Secrets Operator (with CRDs) - Installs operator and CRDs in one step
- **Wave 2**: AWS Load Balancer Controller - Sets up ALB controller with IRSA
- **Wave 3**: NGINX Ingress Controller - Deploys NGINX as ClusterIP service
- **Wave 4**: Edge Ingress - Creates ALB pointing to NGINX
- **Wave 5**: External Secrets Config - Creates ClusterSecretStore and ExternalSecrets
- **Wave 6**: Quiz AI Application - Deploys the production application

## Traffic Flow
Internet → ALB (internet-facing) → NGINX Ingress Controller → Quiz AI Services

## Key Points
- CRDs are installed with External Secrets operator (Wave 1) - no manual second pass needed
- All Kubernetes add-ons are owned by ArgoCD, not Terraform
- Single `terragrunt run-all apply` from `prod/` directory deploys everything
- ArgoCD handles retry logic and health checks automatically
- No mock endpoints used during actual deployment
