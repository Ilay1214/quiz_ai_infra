# Quiz AI Infrastructure - AWS EKS Platform

## 📋 Project Overview

**Quiz AI** is an interactive educational platform that helps users learn through AI-powered quizzes. This repository contains the complete infrastructure-as-code (IaC) implementation for deploying the Quiz AI application on AWS EKS.

The infrastructure leverages **Terragrunt** for DRY infrastructure management, **ArgoCD** for GitOps-based continuous delivery, and **External Secrets Operator** for secure secret management. The platform supports both development and production environments with different optimization strategies.

## 🏗️ Architecture

### Infrastructure Stack
- **AWS EKS**: Managed Kubernetes clusters for dev and prod environments
- **VPC**: Isolated networks with public/private subnets across 3 AZs
- **ArgoCD**: GitOps continuous delivery for Kubernetes applications
- **External Secrets Operator**: Synchronizes secrets from AWS Secrets Manager
- **NGINX Ingress**: Kubernetes ingress controller with AWS Load Balancer integration
- **IAM/IRSA**: Fine-grained AWS permissions for Kubernetes workloads

### Traffic Flow

**Production Environment:**
```
Internet → AWS ALB → NGINX Ingress Controller → Application Services → Pods
                            ↓
            External Secrets Operator → AWS Secrets Manager
```

**Development Environment:**
```
Internet → AWS NLB → NGINX Ingress Controller → Application Services → Pods
                            ↓
            External Secrets Operator → AWS Secrets Manager
```

## 🚀 Features

- **Multi-Environment Support**: Separate EKS clusters with optimized configurations
  - **Production**: High availability with ALB → NGINX ingress chain
  - **Development**: Cost-optimized with NLB and minimal resources
- **GitOps with ArgoCD**: Automated deployments with proper sync waves
- **Hybrid Management Model**: 
  - Infrastructure components managed by Terragrunt
  - Applications deployed via ArgoCD
- **Unified Secret Management**: Both environments use same secrets from AWS Secrets Manager
- **Docker Hub Integration**: Development uses public images, no ECR required
- **IRSA Authentication**: Pod-level AWS permissions without storing credentials
- **Multiple Apps in Dev**: Supports both dev and staging apps in single cluster

## 📁 Repository Structure

```
quiz_ai_infra/
├── infra/
│   ├── argocd/                     # ArgoCD application manifests
│   │   ├── dev/                     # Dev environment apps
│   │   │   ├── apps-only.yaml       # Parent app for dev applications
│   │   │   ├── ingress-nginx.yaml   # NLB ingress (Wave 1)
│   │   │   ├── quiz-ai-dev.yaml     # Dev app (Wave 2)
│   │   │   └── quiz-ai-stage.yaml   # Stage app (Wave 2)
│   │   └── prod/                    # Prod environment apps
│   │       ├── apps-only.yaml       # Parent app for prod applications
│   │       ├── ingress-nginx.yaml   # ClusterIP NGINX (Wave 1)
│   │       ├── edge-ingress.yaml    # ALB configuration (Wave 2)
│   │       └── quiz-ai-prod.yaml    # Production app (Wave 3)
│   ├── live/                        # Terragrunt live configurations
│   │   ├── terragrunt.hcl           # Root configuration
│   │   ├── dev/                     # Dev environment
│   │   │   ├── vpc/                 # Network setup (10.1.0.0/16)
│   │   │   ├── iam/                 # IAM roles and policies
│   │   │   ├── eks/                 # EKS cluster (t3.large on-demand)
│   │   │   ├── k8s/                 # Kubernetes resources
│   │   │   │   ├── argocd/          # ArgoCD bootstrap
│   │   │   │   └── apps/            # Deploy ArgoCD applications
│   │   │   └── k8s-platform/        # Platform components
│   │   │       ├── eso/             # External Secrets Operator
│   │   │       └── cluster-secret-store/ # ClusterSecretStore
│   │   └── prod/                    # Prod environment
│   │       ├── vpc/                 # Network setup (10.0.0.0/16)
│   │       ├── iam/                 # IAM roles and policies
│   │       ├── ecr/                 # Container registry
│   │       ├── eks/                 # EKS cluster (t3.medium on-demand)
│   │       ├── k8s/                 # Kubernetes resources
│   │       │   ├── argocd/          # ArgoCD bootstrap
│   │       │   └── apps/            # Deploy ArgoCD applications
│   │       └── k8s-platform/        # Platform components
│   │           ├── eso/             # External Secrets Operator
│   │           ├── alb-controller/  # AWS Load Balancer Controller
│   │           └── cluster-secret-store/ # ClusterSecretStore
│   ├── modules/                     # Terraform modules
│   │   ├── argocd/                  # ArgoCD installation
│   │   ├── argocd-apps/             # ArgoCD application deployment
│   │   ├── aws-load-balancer-controller/
│   │   ├── ecr/                     # ECR repositories
│   │   ├── eks/                     # EKS cluster module
│   │   ├── eso-aws-config/          # External Secrets AWS config
│   │   ├── external-secrets/        # ESO installation
│   │   ├── iam/                     # IAM resources
│   │   ├── ingress-nginx/           # NGINX ingress
│   │   └── vpc/                     # VPC module
│   ├── manifests/                   # Raw Kubernetes manifests
│   ├── quiz-ai-helm/                # Application Helm chart
│   │   ├── Chart.yaml
│   │   ├── templates/
│   │   ├── development_values.yaml
│   │   ├── staging_values.yaml
│   │   └── production_values.yaml
│   └── scripts/                     # Automation scripts
│       ├── dev/
│       └── prod/
│           ├── access-argocd.ps1
│           ├── apply-argocd-prod.ps1
│           └── substitute-values.ps1
└── README.md

## 🚀 Quick Start

### Minimal Setup for Development
```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/quiz_ai_infra.git
cd quiz_ai_infra

# 2. Configure AWS credentials
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_REGION=eu-central-1

# 3. Update configuration
# Edit infra/live/terragrunt.hcl with your AWS account ID

# 4. Deploy dev environment
cd infra/live/dev
terragrunt run-all apply --terragrunt-non-interactive

# 5. Configure kubectl
aws eks update-kubeconfig --name dev-eks-cluster --region eu-central-1

# 6. Access application
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
# Visit http://localhost:8080
```

## 🔧 Prerequisites

### Required Tools
- **AWS CLI** (v2.0+): For AWS authentication and resource management
- **Terraform** (>= 1.6.0): Infrastructure provisioning
- **Terragrunt** (>= 0.54.0): Terraform wrapper for DRY configurations
- **kubectl** (v1.28+): Kubernetes cluster management
- **Helm** (v3.0+): Kubernetes package manager
- **PowerShell** or **Bash**: For running automation scripts

### Optional Tools
- **ArgoCD CLI**: For managing ArgoCD applications from command line
- **k9s**: Terminal UI for Kubernetes clusters
- **Docker**: For local container testing

### AWS Permissions Required
- EKS cluster creation and management
- VPC and networking resources
- IAM roles and policies creation
- ECR repository management (prod only)
- Secrets Manager read/write
- S3 access for Terraform state

## 🛠️ Setup Instructions

### 1. Initial Setup

#### Configure AWS Credentials
```bash
# Linux/macOS
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_REGION=eu-central-1

# Windows PowerShell
$env:AWS_ACCESS_KEY_ID="your-access-key"
$env:AWS_SECRET_ACCESS_KEY="your-secret-key"
$env:AWS_REGION="eu-central-1"
```

#### Fix Windows Long Path Issues (if on Windows)
```powershell
# Set Terragrunt download directory to avoid long path issues
$env:TERRAGRUNT_DOWNLOAD_DIR = "C:\tg"
[System.Environment]::SetEnvironmentVariable("TERRAGRUNT_DOWNLOAD_DIR", "C:\tg", [System.EnvironmentVariableTarget]::User)

# Enable long paths in Git
git config --global core.longpaths true
```

### 2. Configure Project Settings

Edit `infra/live/terragrunt.hcl` and update the locals block:
```hcl
locals {
  aws_account_id = "YOUR_AWS_ACCOUNT_ID"  # e.g., "123456789012"
  github_repo    = "YOUR_GITHUB_REPO"     # e.g., "username/quiz_ai_infra"
  aws_region     = "eu-central-1"         # Or your preferred region
}
```

**Important**: The Terraform state is stored in S3. Ensure the bucket exists or update the backend configuration.

## 🌐 Deployment Instructions

### Development Environment - Complete Setup

```powershell
# Step 1: Deploy VPC
cd infra/live/dev/vpc
terragrunt apply

# Step 2: Deploy IAM
cd ../iam
terragrunt apply

# Step 3: Deploy EKS Cluster (takes ~15 minutes)
cd ../eks
terragrunt apply

# Step 4: Update kubeconfig
aws eks update-kubeconfig --region eu-central-1 --name dev-eks-cluster

# Step 5: Deploy ArgoCD
cd ../k8s/argocd
terragrunt apply

# Step 6: Deploy External Secrets Operator
cd ../../k8s-platform/eso
terragrunt apply

# Step 7: Wait for CRDs to be ready (60 seconds)
Start-Sleep -Seconds 60
kubectl get crd | Select-String "external-secrets.io"

# Step 8: Deploy ClusterSecretStore
cd ../cluster-secret-store
terragrunt apply

# Step 9: Deploy ArgoCD Applications
cd ../../k8s/apps
terragrunt apply

# Step 10: Get NLB endpoint
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

### Production Environment - Complete Setup

```powershell
# Step 1: Deploy VPC
cd infra/live/prod/vpc
terragrunt apply

# Step 2: Deploy IAM
cd ../iam
terragrunt apply

# Step 3: Deploy ECR (Production only)
cd ../ecr
terragrunt apply

# Step 4: Deploy EKS Cluster (takes ~15 minutes)
cd ../eks
terragrunt apply

# Step 5: Update kubeconfig
aws eks update-kubeconfig --region eu-central-1 --name prod-eks-cluster

# Step 6: Deploy ArgoCD
cd ../k8s/argocd
terragrunt apply

# Step 7: Deploy External Secrets Operator
cd ../../k8s-platform/eso
terragrunt apply

# Step 8: Deploy ALB Controller (Production only)
cd ../alb-controller
terragrunt apply

# Step 9: Wait for CRDs (60 seconds)
Start-Sleep -Seconds 60
kubectl get crd | Select-String "external-secrets.io"

# Step 10: Deploy ClusterSecretStore
cd ../cluster-secret-store
terragrunt apply

# Step 11: Deploy ArgoCD Applications
cd ../../k8s/apps
terragrunt apply

# Step 12: Get ALB endpoint
kubectl get ingress -n ingress-nginx edge-ingress
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

### 6. Deploy Applications via ArgoCD

#### Production Applications (with Sync Waves)
Applications deploy in this order:
1. **Wave 1**: External Secrets Operator (installs CRDs)
2. **Wave 2**: AWS Load Balancer Controller
3. **Wave 3**: NGINX Ingress Controller
4. **Wave 4**: Edge Ingress (ALB configuration)
5. **Wave 5**: External Secrets Config (ClusterSecretStore)
6. **Wave 6**: Quiz AI Application

```bash
# Apply all prod ArgoCD apps
cd infra/scripts/prod
./apply-argocd-prod.ps1  # Windows
# or
./apply-argocd-prod.sh   # Linux/macOS

# Or manually sync specific app
argocd app sync quiz-ai-prod
argocd app sync external-secrets-operator
```

#### Development Applications
```bash
# Dev environment hosts two apps:
argocd app sync quiz-ai-dev    # Development instance
argocd app sync quiz-ai-stage  # Staging instance
```

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

### AWS Secrets Manager Structure
```
prod/quiz-ai/           # Production secrets
├── app-env             # Application environment variables
├── mysql-url           # Database connection string
└── mysql-ca            # Database SSL certificate

dev/quiz-ai/            # Development secrets (optional)
└── shared/             # Shared between dev and stage
```

### Create Secrets
```bash
# Create application secrets
aws secretsmanager create-secret \
  --name prod/quiz-ai/app-env \
  --secret-string '{"API_KEY":"your-key","JWT_SECRET":"your-secret"}'

# Create database URL
aws secretsmanager create-secret \
  --name prod/quiz-ai/mysql-url \
  --secret-string "mysql://user:pass@host:3306/dbname?ssl-mode=REQUIRED"
```

### External Secrets Configuration
The External Secrets Operator automatically syncs secrets from AWS Secrets Manager:

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-central-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: app-env
  namespace: quiz-ai-prod
spec:
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: app-env
  dataFrom:
    - extract:
        key: prod/quiz-ai/app-env
```

## 🌐 Ingress & Load Balancer Configuration

### Production Environment (ALB → NGINX)
```bash
# Get ALB URL (internet-facing)
kubectl get ingress -n ingress-nginx edge-ingress

# Example URL format:
# http://k8s-ingressn-edgetong-xxxxx.eu-central-1.elb.amazonaws.com/
```

### Development Environment (NLB → NGINX)
```bash
# Get NLB URL
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Port forwarding for local access
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

### Application Routes
- `/` - Frontend application
- `/api/*` - Backend API endpoints
- `/health` - Health check endpoint
- `/stage` - Staging app (dev cluster only)


## 📪 Troubleshooting Guide

### Common Issues and Solutions

#### 1. External Secrets CRD Not Found
```bash
# Check if CRDs are installed
kubectl get crd | grep external-secrets

# If missing, wait for operator to install them
kubectl wait --for=condition=Established \
  --timeout=60s crd/externalsecrets.external-secrets.io
```

#### 2. NGINX 504 Gateway Timeout
```bash
# Restart NGINX controller to restore connectivity
kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx

# Check endpoints
kubectl get endpoints -n quiz-ai-prod

# Test direct pod access
kubectl port-forward -n quiz-ai-prod pod/<pod-name> 8080:80
```

#### 3. ArgoCD Sync Issues
```bash
# Check application status
argocd app get quiz-ai-prod

# Force sync with prune
argocd app sync quiz-ai-prod --prune --force

# Check sync waves order
kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,WAVE:.metadata.annotations.argocd\.argoproj\.io/sync-wave"
```

#### 4. Terragrunt Long Path Issues (Windows)
```powershell
# Clear cache
Get-ChildItem -Path . -Recurse -Directory -Filter ".terragrunt-cache" | Remove-Item -Recurse -Force

# Ensure environment variable is set
echo $env:TERRAGRUNT_DOWNLOAD_DIR
```

#### 5. IRSA Authentication Issues
```bash
# Check service account annotation
kubectl get sa external-secrets-sa -n external-secrets -o yaml

# Verify IRSA role trust policy
aws iam get-role --role-name prod-eso-irsa

# Check pod identity webhook
kubectl get mutatingwebhookconfigurations pod-identity-webhook
```

### Useful Commands

```bash
# View all resources in a namespace
kubectl get all -n quiz-ai-prod

# Check events for debugging
kubectl get events -n quiz-ai-prod --sort-by='.lastTimestamp'

# View ingress routes
kubectl describe ingress -n quiz-ai-prod

# Check external secrets sync status
kubectl get externalsecrets -A

# View ArgoCD app details in UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## 🔒 Security Considerations

1. **IRSA (IAM Roles for Service Accounts)**: Used for AWS service authentication
2. **Network Policies**: Implement Kubernetes network policies for pod-to-pod communication
3. **Secrets Management**: All sensitive data stored in AWS Secrets Manager
4. **RBAC**: Implement proper Role-Based Access Control in Kubernetes
5. **Private Endpoints**: EKS API server accessible via private endpoints

## 📊 Environment Specifications

### Development Environment
- **VPC CIDR**: 10.1.0.0/16
- **Instance Type**: t3.large (on-demand)
- **Node Count**: 1-2 nodes
- **Namespaces**: 
  - `app-dev` - Development application
  - `quiz-ai-stage` - Staging application
  - `ingress-nginx` - Ingress controller
  - `external-secrets` - Secrets operator
  - `argocd` - GitOps controller
- **Load Balancer**: NLB (Network Load Balancer)
- **Container Registry**: Docker Hub (public images)
- **Resource Limits**: Minimal (1 replica per component)

### Production Environment  
- **VPC CIDR**: 10.0.0.0/16
- **Instance Type**: t3.medium (on-demand)
- **Node Count**: 2-5 nodes (with autoscaling)
- **Namespaces**:
  - `quiz-ai-prod` - Production application
  - `ingress-nginx` - Ingress controller
  - `external-secrets` - Secrets operator
  - `argocd` - GitOps controller
- **Load Balancer**: ALB → NGINX (dual-layer)
- **Container Registry**: Amazon ECR
- **Resource Limits**: HA (2+ replicas)

## 🛡️ Important Notes

1. **State Management**: Terraform state is stored in S3. Never delete the state bucket.
2. **Dependency Order**: Infrastructure modules have dependencies. Use `terragrunt run-all` to handle automatically.
3. **IRSA Roles**: Each AWS-integrated service uses its own IRSA role for security.
4. **Sync Waves**: ArgoCD applications deploy in waves to ensure proper dependency resolution.
5. **Secret Rotation**: Update secrets in AWS Secrets Manager; ESO will auto-sync within 30 seconds.

## 🧹 Cleanup Instructions

### Complete Environment Removal

**Development:**
```powershell
cd infra/live/dev
terragrunt run-all destroy --terragrunt-non-interactive
```

**Production:**
```powershell
cd infra/live/prod
terragrunt run-all destroy --terragrunt-non-interactive
```

**⚠️ Warning**: This will permanently delete all resources including:
- EKS clusters and workloads
- VPCs and subnets
- IAM roles and policies
- ECR repositories (prod)
- All Kubernetes resources
- Application data

## 📝 GitHub Actions Configuration

If setting up CI/CD pipelines, configure these GitHub secrets:

### Required Secrets
- `AWS_ACCESS_KEY_ID`: AWS access key for deployments
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `AWS_ACCOUNT_ID`: Your AWS account ID
- `AWS_REGION`: Target AWS region (e.g., eu-central-1)

### Optional Secrets
- `ARGOCD_SERVER`: ArgoCD server URL for direct sync
- `ARGOCD_TOKEN`: ArgoCD auth token
- `SLACK_WEBHOOK`: For deployment notifications
- `DOCKER_USERNAME`: For Docker Hub (if not using ECR)
- `DOCKER_PASSWORD`: Docker Hub password

### Example Workflow
```yaml
name: Deploy to EKS
on:
  push:
    branches: [main, develop]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}
      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --name prod-eks-cluster
      - name: Deploy
        run: |
          kubectl apply -f manifests/
```

## 🆘 Support & Maintenance

### Logs and Monitoring
```bash
# Application logs
kubectl logs -f deployment/quiz-ai-application -n quiz-ai-prod

# Ingress controller logs  
kubectl logs -f deployment/ingress-nginx-controller -n ingress-nginx

# External Secrets Operator logs
kubectl logs -f deployment/external-secrets -n external-secrets

# ArgoCD sync logs
kubectl logs -f deployment/argocd-application-controller -n argocd
```

### Health Checks
```bash
# Cluster health
kubectl get nodes
kubectl top nodes

# Application health
kubectl get pods -n quiz-ai-prod
kubectl describe deployment quiz-ai-application -n quiz-ai-prod
```


## 📚 About Quiz AI

Quiz AI is an educational platform that leverages artificial intelligence to create personalized learning experiences through interactive quizzes. The platform consists of:

- **Frontend**: React-based web application for user interaction
- **Backend**: Node.js API server handling quiz logic and AI integration
- **Database**: MySQL database for persistent storage
- **Infrastructure**: Cloud-native deployment on AWS EKS

This repository manages the complete infrastructure deployment, enabling:
- Automated deployments through GitOps
- Zero-downtime updates
- Secure secret management
- Multi-environment support
- Cost-optimized resource allocation

## 🔗 Key Technologies

- **Terragrunt/Terraform**: Infrastructure as Code
- **AWS EKS**: Managed Kubernetes
- **ArgoCD**: GitOps continuous delivery
- **External Secrets Operator**: AWS Secrets Manager integration
- **NGINX Ingress**: Traffic routing
- **Helm**: Package management
- **Docker Hub/ECR**: Container registries

## 📧 Contact

**Repository**: [github.com/Ilay1214/quiz_ai_infra](https://github.com/Ilay1214/quiz_ai_infra)  
**Project**: Quiz AI Infrastructure  
**Last Updated**: November 2025  
**Platform**: AWS EKS with GitOps