#!/bin/bash
# Script to apply all ArgoCD applications in the correct order

set -e

echo -e "\n\033[36m========================================\033[0m"
echo -e "\033[36m   Applying ArgoCD Applications\033[0m"
echo -e "\033[36m========================================\n\033[0m"

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ARGOCD_DIR="$SCRIPT_DIR/../argocd/prod"

# Ensure kubectl is configured
echo -e "\033[33mChecking kubectl connection...\033[0m"
if kubectl get nodes >/dev/null 2>&1; then
    echo -e "\033[32m✓ kubectl is configured and connected\033[0m"
else
    echo -e "\033[31m✗ Error: kubectl not configured\033[0m"
    echo -e "\033[33mPlease run: aws eks update-kubeconfig --name prod-eks-cluster --region eu-central-1\033[0m"
    exit 1
fi

# Check if ArgoCD is installed
echo -e "\n\033[33mChecking ArgoCD installation...\033[0m"
if kubectl get namespace argocd >/dev/null 2>&1; then
    echo -e "\033[32m✓ ArgoCD namespace exists\033[0m"
    
    # Check if ArgoCD CRDs are installed
    if ! kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
        echo -e "\033[31m✗ ArgoCD CRDs not found\033[0m"
        echo -e "\033[33mPlease install ArgoCD first:\033[0m"
        echo "  kubectl create namespace argocd"
        echo "  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
        exit 1
    fi
else
    echo -e "\033[31m✗ ArgoCD namespace not found\033[0m"
    echo -e "\033[33mInstalling ArgoCD...\033[0m"
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    echo -e "\033[33mWaiting for ArgoCD to be ready (60 seconds)...\033[0m"
    sleep 60
fi

echo -e "\n\033[36mApplying ArgoCD applications in order...\033[0m"

# Apply applications in order (respecting sync waves)
declare -a apps=(
    "external-secrets-operator.yaml:1:External Secrets Operator"
    "aws-load-balancer-controller.yaml:2:AWS Load Balancer Controller"
    "ingress-nginx.yaml:3:NGINX Ingress Controller"
    "edge-ingress.yaml:4:Edge ALB Ingress"
    "external-secrets-config.yaml:5:External Secrets Configuration"
    "quiz-ai-prod.yaml:6:Quiz AI Application"
)

for app_info in "${apps[@]}"; do
    IFS=':' read -r app wave description <<< "$app_info"
    
    echo -e "\n--------------------------------------------------"
    echo -e "\033[33mWave $wave: $description\033[0m"
    echo -e "\033[90mFile: $app\033[0m"
    
    app_path="$ARGOCD_DIR/$app"
    if [ -f "$app_path" ]; then
        if kubectl apply -f "$app_path"; then
            echo -e "\033[32m✓ Applied successfully\033[0m"
        else
            echo -e "\033[31m✗ Failed to apply\033[0m"
            echo -e "\033[33mContinuing with next application...\033[0m"
        fi
        
        # Wait between applications (except for the last one)
        if [ "$wave" != "6" ]; then
            echo -e "\033[90mWaiting 5 seconds before next application...\033[0m"
            sleep 5
        fi
    else
        echo -e "\033[31m✗ File not found: $app_path\033[0m"
    fi
done

echo -e "\n\033[32m========================================\033[0m"
echo -e "\033[32m   All ArgoCD Applications Applied!\033[0m"
echo -e "\033[32m========================================\n\033[0m"

# Show application status
echo -e "\033[33mApplication Status:\033[0m"
if kubectl get applications -n argocd >/dev/null 2>&1; then
    kubectl get applications -n argocd
else
    echo -e "\033[33m  No applications found or ArgoCD not accessible\033[0m"
fi

echo -e "\n--------------------------------------------------"
echo -e "\033[36mUseful Commands:\033[0m"

echo -e "\n\033[33mTo watch sync status:\033[0m"
echo "  kubectl get applications -n argocd -w"

echo -e "\n\033[33mTo get the ALB URL:\033[0m"
echo "  kubectl get ingress -n ingress-nginx edge-to-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"

echo -e "\n\033[33mTo check pod status:\033[0m"
echo "  kubectl get pods --all-namespaces"

echo -e "\n\033[33mTo force sync an application:\033[0m"
echo "  kubectl patch application APP_NAME -n argocd --type merge -p '{\"operation\":{\"sync\":{}}}'"
echo -e "  \033[90m(Replace APP_NAME with your application name)\033[0m"

echo -e "\n\033[33mTo get ArgoCD admin password:\033[0m"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

echo -e "\n\033[33mTo port-forward ArgoCD UI:\033[0m"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then access: https://localhost:8080"

echo -e "\n========================================\n"

# Try to get ALB URL
echo -e "\033[33mWaiting for ALB to be provisioned...\033[0m"
max_attempts=12
attempt=0

while [ $attempt -lt $max_attempts ]; do
    alb_url=$(kubectl get ingress -n ingress-nginx edge-to-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    
    if [ -n "$alb_url" ]; then
        echo -e "\n\033[32m✓ Application URL:\033[0m \033[36mhttp://$alb_url\033[0m"
        echo -e "  Frontend: http://$alb_url/"
        echo -e "  Backend API: http://$alb_url/api/health"
        break
    fi
    
    ((attempt++))
    if [ $attempt -lt $max_attempts ]; then
        echo -e "  \033[90mALB not ready yet, waiting 10 seconds... (attempt $attempt/$max_attempts)\033[0m"
        sleep 10
    else
        echo -e "  \033[33mALB is taking longer than expected. Check manually later.\033[0m"
    fi
done

echo -e "\n\033[32mDeployment complete!\n\033[0m"
