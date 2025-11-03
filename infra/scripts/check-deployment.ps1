# Manual deployment checkup script

Write-Host "=== DEPLOYMENT STATUS CHECK ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check ArgoCD Applications
Write-Host "1. ArgoCD Applications Status:" -ForegroundColor Yellow
kubectl get applications -n argocd
Write-Host ""

# 2. Check all pods
Write-Host "2. All Pods Status:" -ForegroundColor Yellow
kubectl get pods -A | Select-String -Pattern "external-secrets|ingress-nginx|aws-load-balancer|quiz-ai"
Write-Host ""

# 3. Check Ingress status
Write-Host "3. Ingress Resources:" -ForegroundColor Yellow
kubectl get ingress -A
Write-Host ""

# 4. Check ALB specifically
Write-Host "4. Edge Ingress (ALB) Details:" -ForegroundColor Yellow
kubectl describe ingress edge-to-nginx -n ingress-nginx
Write-Host ""

# 5. Check AWS Load Balancer Controller logs
Write-Host "5. AWS Load Balancer Controller Status:" -ForegroundColor Yellow
$albPod = kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -o jsonpath='{.items[0].metadata.name}'
if ($albPod) {
    Write-Host "  Pod: $albPod"
    kubectl logs -n kube-system $albPod --tail=20
} else {
    Write-Host "  AWS Load Balancer Controller pod not found!" -ForegroundColor Red
}
Write-Host ""

# 6. Check services
Write-Host "6. Services:" -ForegroundColor Yellow
kubectl get svc -n ingress-nginx
kubectl get svc -n quiz-ai-prod
Write-Host ""

# 7. Check if ALB is being created in AWS
Write-Host "7. Check AWS ALBs (requires AWS CLI):" -ForegroundColor Yellow
aws elbv2 describe-load-balancers --region eu-central-1 --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-ingressn') || contains(Tags[?Key=='ingress.k8s.aws/stack'].Value, 'edge')].[LoadBalancerName, State.Code, DNSName]" --output table
Write-Host ""

# 8. Check ArgoCD sync status
Write-Host "8. ArgoCD Sync Status:" -ForegroundColor Yellow
kubectl get applications -n argocd -o wide
Write-Host ""

# 9. Check for any errors in ingress-nginx
Write-Host "9. NGINX Controller Status:" -ForegroundColor Yellow
$nginxPod = kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}'
if ($nginxPod) {
    Write-Host "  Pod: $nginxPod"
    kubectl logs -n ingress-nginx $nginxPod --tail=10
}
Write-Host ""

Write-Host "=== ARGOCD ACCESS ===" -ForegroundColor Cyan
Write-Host ""

# Get ArgoCD password
Write-Host "ArgoCD Admin Password:" -ForegroundColor Yellow
$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'
if ($password) {
    $decodedPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
    Write-Host "  Username: admin" -ForegroundColor Green
    Write-Host "  Password: $decodedPassword" -ForegroundColor Green
} else {
    Write-Host "  Password secret not found!" -ForegroundColor Red
}
Write-Host ""

Write-Host "To access ArgoCD UI:" -ForegroundColor Yellow
Write-Host "  1. Run port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor Cyan
Write-Host "  2. Access: https://localhost:8080" -ForegroundColor Cyan
Write-Host "  3. Login with admin and the password above" -ForegroundColor Cyan
Write-Host ""

Write-Host "=== TROUBLESHOOTING COMMANDS ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "Force sync an app:" -ForegroundColor Gray
Write-Host '  kubectl patch application edge-ingress -n argocd --type merge -p ''{"operation":{"sync":{}}}''' 
Write-Host ""
Write-Host "Check AWS Load Balancer Controller webhook:" -ForegroundColor Gray
Write-Host "  kubectl get validatingwebhookconfigurations"
Write-Host "  kubectl get mutatingwebhookconfigurations"
Write-Host ""
Write-Host "Check IngressClass:" -ForegroundColor Gray
Write-Host "  kubectl get ingressclass"
Write-Host ""
Write-Host "Restart AWS Load Balancer Controller:" -ForegroundColor Gray
Write-Host "  kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system"
Write-Host ""
Write-Host "Check events for edge-ingress:" -ForegroundColor Gray
Write-Host "  kubectl get events -n ingress-nginx --field-selector involvedObject.name=edge-to-nginx"
