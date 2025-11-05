# Hybrid Ownership Model - Infrastructure and Application Management

## Overview

This document describes the hybrid ownership model implemented for managing AWS EKS infrastructure and applications. The model separates responsibilities between Terraform (infrastructure) and ArgoCD (applications) to provide better control, security, and maintainability.

## Key Principles

1. **Single Owner per Resource**: Each Kubernetes resource has exactly one owner (either Terraform or ArgoCD)
2. **No Hardcoded Values**: AWS resource IDs (VPCs, subnets, ARNs) are never hardcoded in Git
3. **Unchanged Application Experience**: Applications continue to receive secrets via ESO exactly as before
4. **Infrastructure as Code**: All infrastructure is managed declaratively through Terraform
5. **GitOps for Applications**: All application deployments use ArgoCD with automated sync

## Ownership Matrix

### Terraform-Managed Resources

| Resource | Module Path | Description |
|----------|------------|-------------|
| External Secrets Operator | `modules/eks-addons/eso` | Helm deployment with CRDs |
| ClusterSecretStore | `modules/eks-addons/cluster-secret-store` | AWS Secrets Manager integration |
| AWS Load Balancer Controller | `modules/eks-addons/alb-controller` | ALB management (prod only) |
| IRSA Roles | Built into EKS module | IAM roles for service accounts |
| VPC/Subnet Tags | `modules/eks-addons/alb-controller` | Auto-discovery tags for ALB |

### ArgoCD-Managed Resources

| Resource | Location | Description |
|----------|----------|-------------|
| quiz-ai-helm | `argocd/{env}/quiz-ai-*.yaml` | Main application (unchanged) |
| ExternalSecrets | `manifests/{env}/external-secrets*.yaml` | Per-app secret definitions |
| NGINX Ingress | `argocd/{env}/ingress-nginx.yaml` | Ingress controller |
| Application Ingress | Within Helm charts | App-specific ingress rules |

## Directory Structure

```
infra/
├── modules/
│   └── eks-addons/
│       ├── eso/                    # ESO Helm module
│       ├── cluster-secret-store/   # ClusterSecretStore module
│       └── alb-controller/         # ALB Controller module
├── live/
│   ├── prod/
│   │   └── k8s-platform/          # Platform components
│   │       ├── eso/
│   │       ├── cluster-secret-store/
│   │       └── alb-controller/
│   └── dev/
│       └── k8s-platform/          # Platform components (no ALB)
│           ├── eso/
│           └── cluster-secret-store/
├── argocd/
│   ├── prod/
│   │   ├── apps-only.yaml         # ArgoCD parent app (excludes infra)
│   │   ├── quiz-ai-prod.yaml      # Application deployment
│   │   └── ingress-nginx.yaml     # NGINX ingress
│   └── dev/
│       ├── apps-only.yaml         # ArgoCD parent app (excludes infra)
│       ├── quiz-ai-dev.yaml       # Dev application
│       ├── quiz-ai-stage.yaml     # Stage application
│       └── ingress-nginx.yaml     # NGINX ingress
└── manifests/
    ├── prod/
    │   └── external-secrets.yaml   # App ExternalSecrets
    └── dev/
        ├── external-secrets-dev.yaml
        └── external-secrets-stage.yaml
```

## Migration Process

### Prerequisites

1. AWS CLI configured with appropriate credentials
2. kubectl with cluster access
3. Terragrunt installed
4. PowerShell (Windows) or equivalent shell

### Migration Steps

1. **Backup Current State**
   ```powershell
   .\scripts\migrate-to-terraform.ps1 -Environment prod
   ```
   This creates a backup of all existing resources before migration.

2. **Deploy Infrastructure with Terraform**
   ```bash
   # Deploy ESO
   cd infra/live/prod/k8s-platform/eso
   terragrunt apply

   # Deploy ClusterSecretStore
   cd ../cluster-secret-store
   terragrunt apply

   # Deploy ALB Controller (prod only)
   cd ../alb-controller
   terragrunt apply
   ```

3. **Update ArgoCD Applications**
   ```bash
   cd infra/live/prod/k8s/apps
   terragrunt apply  # Now uses apps-only.yaml
   ```

4. **Validate Platform**
   ```powershell
   .\scripts\validate-platform.ps1 -Environment prod
   ```

## Operational Workflows

### Adding New Applications

1. Create application manifests in `argocd/{env}/`
2. Add ExternalSecret definitions in `manifests/{env}/`
3. ExternalSecrets reference existing ClusterSecretStore `aws-secrets-manager`
4. No changes needed to infrastructure components

### Updating ESO Version

1. Update `chart_version` in `live/{env}/k8s-platform/eso/terragrunt.hcl`
2. Run `terragrunt apply` in the ESO directory
3. Validate with `validate-platform.ps1`

### Adding New Secrets

1. Add secret to AWS Secrets Manager
2. Create/update ExternalSecret manifest (ArgoCD-managed)
3. Reference the ClusterSecretStore (Terraform-managed)
4. ArgoCD syncs automatically

## Deployment Order

### Initial Infrastructure Setup

1. **VPC/EKS** → Creates cluster and OIDC provider
2. **IAM/IRSA** → Creates service account roles
3. **ESO** → Installs operator with CRDs
4. **ClusterSecretStore** → Configures AWS integration
5. **ALB Controller** → Manages load balancers (prod)
6. **ArgoCD** → Bootstrap GitOps

### Application Deployment

1. **NGINX Ingress** → Via ArgoCD
2. **Applications** → Via ArgoCD (quiz-ai-helm)
3. **ExternalSecrets** → Via ArgoCD
4. **Secret Injection** → ESO creates K8s secrets
5. **Pod Startup** → Pods mount secrets

## Validation and Health Checks

### Platform Validation Script

The `validate-platform.ps1` script checks:
- ESO deployment and CRDs
- ClusterSecretStore connectivity
- ALB Controller (prod only)
- ExternalSecret synchronization
- Application pod health
- Secret mounting

### Manual Checks

```bash
# Check ESO
kubectl get deployment -n external-secrets

# Check ClusterSecretStore
kubectl get clustersecretstore aws-secrets-manager -o yaml

# Check ExternalSecrets
kubectl get externalsecrets -A

# Check application pods
kubectl get pods -n quiz-ai-prod
```

## Troubleshooting

### Common Issues

#### ESO Not Creating Secrets
- Check ClusterSecretStore status: `kubectl describe clustersecretstore aws-secrets-manager`
- Verify IRSA role has Secrets Manager permissions
- Check ESO logs: `kubectl logs -n external-secrets deployment/external-secrets`

#### ALB Not Creating
- Verify subnet tags for auto-discovery
- Check ALB Controller logs: `kubectl logs -n kube-system deployment/aws-load-balancer-controller`
- Ensure IRSA role has necessary EC2/ELB permissions

#### ExternalSecrets Failing
- Verify secret exists in AWS Secrets Manager
- Check secret path matches ExternalSecret spec
- Ensure ClusterSecretStore is Ready

### Rollback Procedures

#### Infrastructure Rollback
```bash
# Revert Terraform changes
cd infra/live/prod/k8s-platform/eso
git checkout HEAD~ terragrunt.hcl
terragrunt apply

# Restore from backup if needed
kubectl apply -f scripts/backup/{timestamp}/
```

#### Application Rollback
- Use ArgoCD UI to rollback to previous revision
- Or revert Git commit and let ArgoCD sync

## Security Considerations

1. **IRSA Only**: All AWS access uses IRSA, no static credentials
2. **Least Privilege**: Each component has minimal required permissions
3. **Secret Rotation**: Supported through AWS Secrets Manager
4. **Audit Logging**: All changes tracked in Terraform state and Git
5. **Network Isolation**: Components use cluster-internal communication

## Benefits of This Model

### For Infrastructure Team
- Centralized control of platform components
- Version control through Terraform
- Predictable upgrades and rollbacks
- Clear ownership boundaries

### For Application Team
- No changes to application code or charts
- Secrets continue working exactly as before
- Focus on application logic, not infrastructure
- Fast deployments through GitOps

### For Security Team
- No hardcoded secrets or AWS IDs in Git
- IRSA for all AWS access
- Centralized secret management
- Clear audit trail

## FAQ

**Q: Why move ESO to Terraform?**
A: Terraform provides better control over CRDs, versions, and dependencies. It ensures ESO is always deployed before applications need it.

**Q: Do applications need changes?**
A: No, applications continue to use ExternalSecrets exactly as before. Only the management of ESO itself has moved.

**Q: What about disaster recovery?**
A: Both Terraform state and Git provide full recovery capability. The migration script creates backups before any changes.

**Q: Can we still use ArgoCD for everything?**
A: ArgoCD continues to manage all application resources. Only platform infrastructure is managed by Terraform.

## Support and Maintenance

- **Migration Issues**: Run `validate-platform.ps1` and check logs
- **Version Updates**: Update Terraform modules and run `terragrunt apply`
- **Adding Environments**: Copy platform module structure to new environment
- **Documentation**: This document and inline comments in modules
