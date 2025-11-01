# GitOps-Enabled Kubernetes Platform with Terragrunt

## 📋 Overview

This project implements a complete GitOps-enabled Kubernetes platform for multiple environments (dev and prod) using Terragrunt, Terraform, and ArgoCD. It provides automated infrastructure provisioning, application deployment, and continuous delivery workflows.

## 🏗️ Architecture



## 🚀 Features

- **Multi-Environment Support**: Separate EKS clusters for dev and prod environments
- **GitOps with ArgoCD**: Automated application deployment and synchronization
- **Ingress Controller**: NGINX Ingress with AWS Network Load Balancer integration
- **Secret Management**: External Secrets Operator integrated with AWS Secrets Manager
- **Infrastructure as Code**: Complete infrastructure managed with Terragrunt/Terraform
- **CI/CD Pipelines**: GitHub Actions for building, pushing images, and updating deployments
- **Helm Charts**: Generic and reusable Helm chart for application deployment

## 📁 Project Structure

```
project_circle/
├── .github/
│   └── workflows/
│       ├── build-and-deploy.yml     # CI/CD for application
│       └── terragrunt-deploy.yml    # Infrastructure deployment
├── infra/
│   ├── argocd/
│   │   ├── dev/
│   │   │   ├── dev_argocd_values.yaml     # Dev application
│   │   │   └── stage_argocd_values.yaml   # Staging application
│   │   └── prod/
│   │       └── prod_argocd_values.yaml    # Prod application
│   ├── live/
│   │   ├── dev/                    # Dev environment
│   │   │   ├── vpc/
│   │   │   ├── iam/
│   │   │   ├── eks/
│   │   │   ├── k8s/
│   │   │   └── secrets/
│   │   ├── prod/                   # Prod environment
│   │   │   ├── vpc/
│   │   │   ├── iam/
│   │   │   ├── eks/
│   │   │   ├── k8s/
│   │   │   └── secrets/
│   │   └── terragrunt.hcl          # Root Terragrunt config
│   ├── modules/
│   │   ├── argocd/
│   │   ├── aws-load-balancer-controller/
│   │   ├── ecr/
│   │   ├── eks/
│   │   ├── eso-aws-config/
│   │   ├── external-secrets/
│   │   ├── iam/
│   │   ├── ingress-nginx/
│   │   └── vpc/
│   └── quiz-ai-helm/               # Application Helm chart
│       ├── Chart.yaml
│       ├── templates/
│       ├── development_values.yaml
│       ├── staging_values.yaml
│       └── production_values.yaml
└── README.md
```

## 🔧 Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured
- Terraform >= 1.6.0
- Terragrunt >= 0.54.0
- kubectl
- Helm 3
- ArgoCD CLI (optional)
- Docker (for local development)

## 🛠️ Setup Instructions

### 1. Configure AWS Credentials

```bash
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_REGION=eu-central-1
```

### 2. Update Configuration

Edit `infra/live/terragrunt.hcl` to update:
- `aws_account_id`: Your AWS account ID
- `github_repo`: Your GitHub repository
- `aws_region`: Your preferred AWS region

### 3. Bootstrap Infrastructure

#### Deploy Dev Environment

```bash
cd infra/live/dev
terragrunt run-all apply
```

#### Deploy Prod Environment

```bash
cd infra/live/prod
terragrunt run-all apply
```

### 4. Configure kubectl

```bash
# Dev cluster
aws eks update-kubeconfig --name dev-eks-cluster --region eu-central-1

# Prod cluster
aws eks update-kubeconfig --name prod-eks-cluster --region eu-central-1
```

### 5. Access ArgoCD

#### Get ArgoCD admin password

```bash
# Dev environment
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Prod environment (switch context first)
kubectl config use-context prod-eks-cluster
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

#### Port forward to access ArgoCD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access ArgoCD at: https://localhost:8080
- Username: admin
- Password: (from the command above)

### 6. Deploy Applications

Applications are automatically deployed via ArgoCD when manifests are applied. The applications will sync from the GitHub repository.

## 🔄 CI/CD Workflow

### Build and Deploy Pipeline

1. **Push to branch** triggers the workflow
2. **Build Docker images** for backend and frontend
3. **Push to ECR** with environment-specific tags
4. **Update Helm values** with new image tags
5. **ArgoCD syncs** the changes automatically

### Branch Strategy

- `main` → Production environment
- `staging` → Staging environment (in dev cluster)
- `develop` → Development environment (in dev cluster)

## 🔐 Secret Management

### Create secrets in AWS Secrets Manager

```bash
aws secretsmanager create-secret \
  --name quiz-ai/dev/database \
  --secret-string '{"username":"admin","password":"secret"}'
```

### Create ExternalSecret resource

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  secretStoreRef:
    name: aws-cluster-secret-store
    kind: ClusterSecretStore
  target:
    name: app-env
  data:
    - secretKey: DB_USERNAME
      remoteRef:
        key: quiz-ai/dev/database
        property: username
```

## 🌐 Ingress Configuration

The Ingress controller is configured with AWS Network Load Balancer. Access your applications via:

```bash
# Get the Load Balancer URL
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

## 📊 Monitoring and Troubleshooting

### Check pod status

```bash
kubectl get pods -A
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Check ArgoCD application status

```bash
argocd app get quiz-ai-dev
argocd app sync quiz-ai-dev
```

### Terragrunt commands

```bash
# Plan changes
terragrunt plan

# Apply with approval
terragrunt apply

# Destroy resources
terragrunt destroy

# Run all modules
terragrunt run-all apply
```

## 🔒 Security Considerations

1. **IRSA (IAM Roles for Service Accounts)**: Used for AWS service authentication
2. **Network Policies**: Implement Kubernetes network policies for pod-to-pod communication
3. **Secrets Management**: All sensitive data stored in AWS Secrets Manager
4. **RBAC**: Implement proper Role-Based Access Control in Kubernetes
5. **Private Endpoints**: EKS API server accessible via private endpoints

## 📝 GitHub Actions Secrets Required

Configure these secrets in your GitHub repository:

- `AWS_ACCESS_KEY_ID`: AWS access key for deployments
- `AWS_SECRET_ACCESS_KEY`: AWS secret access key
- `ARGOCD_SERVER`: ArgoCD server URL (optional)
- `ARGOCD_TOKEN`: ArgoCD authentication token (optional)

## 🧹 Cleanup

To destroy all resources:

```bash
# Destroy dev environment
cd infra/live/dev
terragrunt run-all destroy

# Destroy prod environment
cd infra/live/prod
terragrunt run-all destroy
```

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Test in dev environment
4. Submit a pull request
5. After approval, merge to main

## 📄 License

This project is for educational/assignment purposes.

## 🆘 Support

For issues or questions:
1. Check the troubleshooting section
2. Review AWS CloudWatch logs
3. Check ArgoCD application status
4. Review GitHub Actions logs

## 🎯 Next Steps

- [ ] Implement Prometheus and Grafana for monitoring
- [ ] Add Istio service mesh
- [ ] Implement GitOps for infrastructure changes
- [ ] Add automated testing in CI/CD pipeline
- [ ] Implement backup and disaster recovery
- [ ] Add cost optimization with Karpenter

---

**Author**: Ilay
**Project**: GitOps Kubernetes Platform
**Environment**: AWS EKS with Terragrunt