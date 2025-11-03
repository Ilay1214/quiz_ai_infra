# Script to dynamically substitute all values from Terraform outputs
# This script fetches infrastructure values and substitutes them in ArgoCD YAML files

Write-Host "Fetching infrastructure values from Terraform..." -ForegroundColor Yellow

# Navigate to the respective Terraform directories
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$infraPath = Split-Path -Parent $scriptDir

# Get VPC outputs
Write-Host "Getting VPC outputs..." -ForegroundColor Cyan
Set-Location "$infraPath\live\prod\vpc"
$VPC_ID = (terragrunt output -raw vpc_id 2>$null | Select-Object -Last 1)
$PUBLIC_SUBNET_IDS = (terragrunt output -json public_subnets 2>$null | ConvertFrom-Json) -join ", "
$PRIVATE_SUBNET_IDS = (terragrunt output -json private_subnets 2>$null | ConvertFrom-Json) -join ", "

# Get EKS outputs
Write-Host "Getting EKS outputs..." -ForegroundColor Cyan
Set-Location "$infraPath\live\prod\eks"
$CLUSTER_NAME = (terragrunt output -raw cluster_name 2>$null | Select-Object -Last 1)
$ESO_IRSA_ROLE_ARN = (terragrunt output -raw eso_irsa_role_arn 2>$null | Select-Object -Last 1)
$ALB_CONTROLLER_IRSA_ROLE_ARN = (terragrunt output -raw alb_controller_irsa_role_arn 2>$null | Select-Object -Last 1)
$CLUSTER_AUTOSCALER_IRSA_ROLE_ARN = (terragrunt output -raw cluster_autoscaler_irsa_role_arn 2>$null | Select-Object -Last 1)
$OIDC_ISSUER = (terragrunt output -raw cluster_oidc_issuer_url 2>$null | Select-Object -Last 1)

# Get AWS account and region
$AWS_REGION = "eu-central-1"  # Or fetch from AWS CLI: aws configure get region
$AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)

# Return to script directory
Set-Location $scriptDir

# Display values
Write-Host "`nInfrastructure Values:" -ForegroundColor Green
Write-Host "  VPC_ID: $VPC_ID"
Write-Host "  CLUSTER_NAME: $CLUSTER_NAME"
Write-Host "  AWS_REGION: $AWS_REGION"
Write-Host "  AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
Write-Host "  PUBLIC_SUBNET_IDS: $PUBLIC_SUBNET_IDS"
Write-Host "  PRIVATE_SUBNET_IDS: $PRIVATE_SUBNET_IDS"
Write-Host "  ESO_IRSA_ROLE_ARN: $ESO_IRSA_ROLE_ARN"
Write-Host "  ALB_CONTROLLER_IRSA_ROLE_ARN: $ALB_CONTROLLER_IRSA_ROLE_ARN"
Write-Host "  CLUSTER_AUTOSCALER_IRSA_ROLE_ARN: $CLUSTER_AUTOSCALER_IRSA_ROLE_ARN"

# Function to substitute values in a file
function Substitute-Values {
    param($FilePath)
    
    if (!(Test-Path $FilePath)) {
        Write-Host "  File not found: $FilePath" -ForegroundColor Red
        return
    }
    
    Write-Host "  Processing: $FilePath" -ForegroundColor Gray
    
    $content = Get-Content $FilePath -Raw
    $content = $content -replace '\${VPC_ID}', $VPC_ID
    $content = $content -replace '\${CLUSTER_NAME}', $CLUSTER_NAME
    $content = $content -replace '\${AWS_REGION}', $AWS_REGION
    $content = $content -replace '\${AWS_ACCOUNT_ID}', $AWS_ACCOUNT_ID
    $content = $content -replace '\${PUBLIC_SUBNET_IDS}', $PUBLIC_SUBNET_IDS
    $content = $content -replace '\${PRIVATE_SUBNET_IDS}', $PRIVATE_SUBNET_IDS
    $content = $content -replace '\${ESO_IRSA_ROLE_ARN}', $ESO_IRSA_ROLE_ARN
    $content = $content -replace '\${ALB_CONTROLLER_IRSA_ROLE_ARN}', $ALB_CONTROLLER_IRSA_ROLE_ARN
    $content = $content -replace '\${CLUSTER_AUTOSCALER_IRSA_ROLE_ARN}', $CLUSTER_AUTOSCALER_IRSA_ROLE_ARN
    $content = $content -replace '\${OIDC_ISSUER}', $OIDC_ISSUER
    
    Set-Content $FilePath $content -NoNewline
}

Write-Host "`nSubstituting values in YAML files..." -ForegroundColor Yellow

# Process ArgoCD application files
$argocdFiles = @(
    "..\argocd\prod\aws-load-balancer-controller.yaml",
    "..\argocd\prod\external-secrets-operator.yaml",
    "..\argocd\prod\ingress-nginx.yaml",
    "..\argocd\prod\quiz-ai-prod.yaml",
    "..\argocd\prod\external-secrets-config.yaml",
    "..\argocd\prod\edge-ingress.yaml"
)

# Process manifest files  
$manifestFiles = @(
    "..\manifests\edge-alb-ingress.yaml",
    "..\manifests\cluster-secret-store.yaml",
    "..\manifests\external-secrets.yaml"
)

$allFiles = $argocdFiles + $manifestFiles

foreach ($file in $allFiles) {
    $filePath = Join-Path $scriptDir $file
    Substitute-Values -FilePath $filePath
}

Write-Host "`nSubstitution completed successfully!" -ForegroundColor Green
Write-Host "You can now apply the ArgoCD applications." -ForegroundColor Green
