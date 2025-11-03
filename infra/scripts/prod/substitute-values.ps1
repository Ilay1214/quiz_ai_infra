# substitute-outputs.ps1
# Fetch infra outputs with Terragrunt and substitute into ArgoCD/manifests files.
# Safe string replacement (no regex), proper ALB subnets formatting.

$ErrorActionPreference = "Stop"

Write-Host "Fetching infrastructure values from Terraform/Terragrunt..." -ForegroundColor Yellow

# Resolve repo paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$infraPath = (Get-Item $scriptDir).Parent.Parent.FullName

# --- VPC outputs ---
Write-Host "Getting VPC outputs..." -ForegroundColor Cyan
Set-Location "$infraPath\live\prod\vpc"

# Basic IDs
$VPC_ID = (terragrunt output -raw vpc_id 2>$null | Select-Object -Last 1)

# Public subnets → CSV without spaces and wrapped in quotes (for ALB annotation)
$PUBLIC_SUBNET_IDS_ARR = (terragrunt output -json public_subnets 2>$null | ConvertFrom-Json)
$PUBLIC_SUBNET_IDS_NO_SPACES = ($PUBLIC_SUBNET_IDS_ARR -join ",")
$PUBLIC_SUBNET_IDS_YAML = '"' + $PUBLIC_SUBNET_IDS_NO_SPACES + '"'

# Private subnets → same treatment in case you reference them similarly
$PRIVATE_SUBNET_IDS_ARR = (terragrunt output -json private_subnets 2>$null | ConvertFrom-Json)
$PRIVATE_SUBNET_IDS_NO_SPACES = ($PRIVATE_SUBNET_IDS_ARR -join ",")
$PRIVATE_SUBNET_IDS_YAML = '"' + $PRIVATE_SUBNET_IDS_NO_SPACES + '"'

# --- EKS outputs ---
Write-Host "Getting EKS outputs..." -ForegroundColor Cyan
Set-Location "$infraPath\live\prod\eks"

$CLUSTER_NAME = (terragrunt output -raw cluster_name 2>$null | Select-Object -Last 1)
$ESO_IRSA_ROLE_ARN = (terragrunt output -raw eso_irsa_role_arn 2>$null | Select-Object -Last 1)
$ALB_CONTROLLER_IRSA_ROLE_ARN = (terragrunt output -raw alb_controller_irsa_role_arn 2>$null | Select-Object -Last 1)
$CLUSTER_AUTOSCALER_IRSA_ROLE_ARN = (terragrunt output -raw cluster_autoscaler_irsa_role_arn 2>$null | Select-Object -Last 1)
$OIDC_ISSUER = (terragrunt output -raw cluster_oidc_issuer_url 2>$null | Select-Object -Last 1)

# --- AWS account/region ---
$AWS_REGION = "eu-central-1"   # or: (aws configure get region)
$AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)

# Back to script dir
Set-Location $scriptDir

Write-Host "`nInfrastructure Values:" -ForegroundColor Green
Write-Host "  VPC_ID: $VPC_ID"
Write-Host "  CLUSTER_NAME: $CLUSTER_NAME"
Write-Host "  AWS_REGION: $AWS_REGION"
Write-Host "  AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
Write-Host "  PUBLIC_SUBNET_IDS: $PUBLIC_SUBNET_IDS_YAML"
Write-Host "  PRIVATE_SUBNET_IDS: $PRIVATE_SUBNET_IDS_YAML"
Write-Host "  ESO_IRSA_ROLE_ARN: $ESO_IRSA_ROLE_ARN"
Write-Host "  ALB_CONTROLLER_IRSA_ROLE_ARN: $ALB_CONTROLLER_IRSA_ROLE_ARN"
Write-Host "  CLUSTER_AUTOSCALER_IRSA_ROLE_ARN: $CLUSTER_AUTOSCALER_IRSA_ROLE_ARN"
Write-Host "  OIDC_ISSUER: $OIDC_ISSUER"

function Substitute-Values {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath
    )

    if (!(Test-Path $FilePath)) {
        Write-Host "  File not found: $FilePath" -ForegroundColor Red
        return
    }

    Write-Host "  Processing: $FilePath" -ForegroundColor Gray

    # Literal replacement (no regex)
    $content = Get-Content $FilePath -Raw

    $content = $content.Replace('${VPC_ID}', $VPC_ID)
    $content = $content.Replace('${CLUSTER_NAME}', $CLUSTER_NAME)
    $content = $content.Replace('${AWS_REGION}', $AWS_REGION)
    $content = $content.Replace('${AWS_ACCOUNT_ID}', $AWS_ACCOUNT_ID)

    # Subnet placeholders — use the quoted, no-spaces CSV values
    $content = $content.Replace('${PUBLIC_SUBNET_IDS}', $PUBLIC_SUBNET_IDS_YAML)
    $content = $content.Replace('${PRIVATE_SUBNET_IDS}', $PRIVATE_SUBNET_IDS_YAML)

    $content = $content.Replace('${ESO_IRSA_ROLE_ARN}', $ESO_IRSA_ROLE_ARN)
    $content = $content.Replace('${ALB_CONTROLLER_IRSA_ROLE_ARN}', $ALB_CONTROLLER_IRSA_ROLE_ARN)
    $content = $content.Replace('${CLUSTER_AUTOSCALER_IRSA_ROLE_ARN}', $CLUSTER_AUTOSCALER_IRSA_ROLE_ARN)
    $content = $content.Replace('${OIDC_ISSUER}', $OIDC_ISSUER)

    Set-Content -Path $FilePath -Value $content -NoNewline -Encoding UTF8
}

Write-Host "`nSubstituting values in YAML files..." -ForegroundColor Yellow



foreach ($rel in $allFiles) {
    $filePath = Join-Path $scriptDir $rel
    Substitute-Values -FilePath $filePath
}

Write-Host "`nSubstitution completed successfully!" -ForegroundColor Green
Write-Host "You can now apply/sync your ArgoCD applications." -ForegroundColor Green

# Optional: quick sanity check for ALB subnets on the rendered Ingress file(s)
$edgeFile = Join-Path $scriptDir "..\manifests\edge-alb-ingress.yaml"
if (Test-Path $edgeFile) {
    Write-Host "`nPreview of subnets annotation in edge-alb-ingress.yaml:" -ForegroundColor DarkCyan
    (Get-Content $edgeFile -Raw) -split "`n" | Where-Object { $_ -match 'alb\.ingress\.kubernetes\.io/subnets' } | ForEach-Object { Write-Host "  $_" }
}
