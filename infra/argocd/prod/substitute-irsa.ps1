# Script to substitute IRSA role ARNs from Terraform outputs

# Get the IRSA role ARNs from Terraform outputs
cd $PSScriptRoot\..\..\live\prod\eks
$ESO_ROLE = terragrunt output -raw eso_irsa_role_arn | Select-Object -Last 1
$ALB_ROLE = terragrunt output -raw alb_controller_irsa_role_arn | Select-Object -Last 1

cd $PSScriptRoot

# Substitute in AWS Load Balancer Controller
(Get-Content aws-load-balancer-controller.yaml) -replace '\${ALB_CONTROLLER_IRSA_ROLE_ARN}', $ALB_ROLE | Set-Content aws-load-balancer-controller.yaml.tmp
Move-Item -Force aws-load-balancer-controller.yaml.tmp aws-load-balancer-controller.yaml

# Substitute in External Secrets Operator
(Get-Content external-secrets-operator.yaml) -replace '\${ESO_IRSA_ROLE_ARN}', $ESO_ROLE | Set-Content external-secrets-operator.yaml.tmp
Move-Item -Force external-secrets-operator.yaml.tmp external-secrets-operator.yaml

Write-Host "IRSA role ARNs substituted successfully:"
Write-Host "ESO Role: $ESO_ROLE"
Write-Host "ALB Controller Role: $ALB_ROLE"
