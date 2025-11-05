#!/usr/bin/env pwsh
# Script to fix External Secrets Operator Helm release conflict

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "External Secrets Operator Conflict Resolution" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# Update kubeconfig
aws eks update-kubeconfig --name prod-eks-cluster --region eu-central-1

Write-Host "`nStep 1: Checking existing Helm releases..." -ForegroundColor Yellow
$releases = helm list -A --output json | ConvertFrom-Json
$esoRelease = $releases | Where-Object { $_.name -eq "external-secrets" }

if ($esoRelease) {
    Write-Host "Found existing ESO release:" -ForegroundColor Green
    Write-Host "  Name: $($esoRelease.name)" -ForegroundColor White
    Write-Host "  Namespace: $($esoRelease.namespace)" -ForegroundColor White
    Write-Host "  Status: $($esoRelease.status)" -ForegroundColor White
    Write-Host "  Chart: $($esoRelease.chart)" -ForegroundColor White
    
    Write-Host "`nStep 2: Choose resolution method:" -ForegroundColor Yellow
    Write-Host "  1. Import existing release into Terraform state (Recommended)" -ForegroundColor White
    Write-Host "  2. Delete existing release and let Terraform recreate it" -ForegroundColor White
    Write-Host "  3. Cancel and investigate manually" -ForegroundColor White
    
    $choice = Read-Host "Enter your choice (1, 2, or 3)"
    
    switch ($choice) {
        "1" {
            Write-Host "`nImporting existing release into Terraform state..." -ForegroundColor Green
            Set-Location $PSScriptRoot
            
            # Clear cache first
            if (Test-Path .terragrunt-cache) {
                Remove-Item -Recurse -Force .terragrunt-cache
            }
            
            # Initialize Terraform
            terragrunt init
            
            # Import the helm release
            $importCmd = "terragrunt import 'helm_release.external_secrets' '$($esoRelease.namespace)/$($esoRelease.name)'"
            Write-Host "Running: $importCmd" -ForegroundColor Cyan
            Invoke-Expression $importCmd
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "`nImport successful! Now run 'terragrunt plan' to verify." -ForegroundColor Green
            } else {
                Write-Host "`nImport failed. You may need to manually resolve this." -ForegroundColor Red
            }
        }
        "2" {
            $confirm = Read-Host "`nAre you sure you want to DELETE the existing release? Type 'yes' to confirm"
            if ($confirm -eq "yes") {
                Write-Host "Deleting existing ESO release..." -ForegroundColor Yellow
                helm uninstall external-secrets -n $($esoRelease.namespace)
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "ESO release deleted successfully!" -ForegroundColor Green
                    Write-Host "Waiting 30 seconds for cleanup..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 30
                    
                    # Check for leftover CRDs
                    Write-Host "Checking for leftover CRDs..." -ForegroundColor Yellow
                    kubectl get crd | Select-String "external-secrets"
                    
                    Write-Host "`nYou can now run 'terragrunt apply' to deploy ESO fresh." -ForegroundColor Green
                } else {
                    Write-Host "Failed to delete ESO release." -ForegroundColor Red
                }
            } else {
                Write-Host "Deletion cancelled." -ForegroundColor Yellow
            }
        }
        "3" {
            Write-Host "`nCancelled. Please investigate manually." -ForegroundColor Yellow
            Write-Host "Useful commands:" -ForegroundColor Cyan
            Write-Host "  helm list -n external-secrets" -ForegroundColor White
            Write-Host "  kubectl get all -n external-secrets" -ForegroundColor White
            Write-Host "  kubectl get crd | grep external-secrets" -ForegroundColor White
        }
        default {
            Write-Host "Invalid choice. Exiting." -ForegroundColor Red
        }
    }
} else {
    Write-Host "No existing ESO Helm release found." -ForegroundColor Yellow
    Write-Host "`nThis might mean:" -ForegroundColor White
    Write-Host "  - ESO was deployed without Helm" -ForegroundColor White
    Write-Host "  - ESO is in a different namespace" -ForegroundColor White
    Write-Host "  - Kubeconfig is pointing to wrong cluster" -ForegroundColor White
    
    Write-Host "`nChecking for ESO resources..." -ForegroundColor Yellow
    kubectl get namespaces | Select-String "external-secrets"
    kubectl get deployment -A | Select-String "external-secrets"
    kubectl get crd | Select-String "external-secrets"
}

Write-Host "`n==============================================" -ForegroundColor Cyan
Write-Host "Script completed!" -ForegroundColor Green
