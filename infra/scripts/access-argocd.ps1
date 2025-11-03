# Quick ArgoCD access script

Write-Host "=== ArgoCD Access Setup ===" -ForegroundColor Cyan
Write-Host ""

# Get password
Write-Host "Getting ArgoCD admin password..." -ForegroundColor Yellow
$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'
if ($password) {
    $decodedPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  ArgoCD Credentials:" -ForegroundColor Green
    Write-Host "  Username: admin" -ForegroundColor Yellow
    Write-Host "  Password: $decodedPassword" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Copy password to clipboard if possible
    try {
        $decodedPassword | Set-Clipboard
        Write-Host "  (Password copied to clipboard)" -ForegroundColor Gray
    } catch {
        # Clipboard not available
    }
} else {
    Write-Host "  ArgoCD password secret not found!" -ForegroundColor Red
    Write-Host "  Make sure ArgoCD is installed." -ForegroundColor Yellow
    exit 1
}

Write-Host "Starting port-forward to ArgoCD..." -ForegroundColor Yellow
Write-Host "  URL: https://localhost:8080" -ForegroundColor Cyan
Write-Host "  (Accept the self-signed certificate warning)" -ForegroundColor Gray
Write-Host ""
Write-Host "Press Ctrl+C to stop port-forwarding" -ForegroundColor Yellow
Write-Host ""

# Start port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
