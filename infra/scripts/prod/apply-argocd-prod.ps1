# Simple script to apply ArgoCD applications in order

# Configure kubectl
Write-Host "Configuring kubectl..."
aws eks update-kubeconfig --name prod-eks-cluster --region eu-central-1

# Check if ArgoCD is installed
kubectl get namespace argocd
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing ArgoCD..."
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    Write-Host "Waiting 60 seconds for ArgoCD to be ready..."
    Start-Sleep -Seconds 60
}

# Apply all ArgoCD applications in order
$baseDir = "C:\Users\ilai4\Desktop\work\project_circle\infra\argocd\prod"

Write-Host "Applying external-secrets-operator (Wave 1)..."
kubectl apply -f "$baseDir\external-secrets-operator.yaml"
Start-Sleep -Seconds 5

Write-Host "Applying aws-load-balancer-controller (Wave 2)..."
kubectl apply -f "$baseDir\aws-load-balancer-controller.yaml"
Start-Sleep -Seconds 5

Write-Host "Applying ingress-nginx (Wave 3)..."
kubectl apply -f "$baseDir\ingress-nginx.yaml"
Start-Sleep -Seconds 5

Write-Host "Applying edge-ingress (Wave 4)..."
kubectl apply -f "$baseDir\edge-ingress.yaml"
Start-Sleep -Seconds 5

Write-Host "Applying external-secrets-config (Wave 5)..."
kubectl apply -f "$baseDir\external-secrets-config.yaml"
Start-Sleep -Seconds 5

Write-Host "Applying quiz-ai-prod (Wave 6)..."
kubectl apply -f "$baseDir\quiz-ai-prod.yaml"

Write-Host ""
Write-Host "Done! All applications applied."
Write-Host ""
Write-Host "Check status with:"
Write-Host "  kubectl get applications -n argocd"
Write-Host ""
Write-Host "Get ALB URL with:"
Write-Host "  kubectl get ingress -n ingress-nginx edge-to-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
