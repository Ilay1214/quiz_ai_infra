#!/bin/bash
# Script to dynamically substitute all values from Terraform outputs
# This script fetches infrastructure values and substitutes them in ArgoCD YAML files

set -e  # Exit on error

echo -e "\033[33mFetching infrastructure values from Terraform...\033[0m"

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFRA_PATH="$(dirname $SCRIPT_DIR)"

# Get VPC outputs
echo -e "\033[36mGetting VPC outputs...\033[0m"
cd "$INFRA_PATH/live/prod/vpc"
VPC_ID=$(terragrunt output -raw vpc_id 2>/dev/null | tail -n 1)
PUBLIC_SUBNET_IDS=$(terragrunt output -json public_subnets 2>/dev/null | jq -r 'join(", ")')
PRIVATE_SUBNET_IDS=$(terragrunt output -json private_subnets 2>/dev/null | jq -r 'join(", ")')

# Get EKS outputs
echo -e "\033[36mGetting EKS outputs...\033[0m"
cd "$INFRA_PATH/live/prod/eks"
CLUSTER_NAME=$(terragrunt output -raw cluster_name 2>/dev/null | tail -n 1)
ESO_IRSA_ROLE_ARN=$(terragrunt output -raw eso_irsa_role_arn 2>/dev/null | tail -n 1)
ALB_CONTROLLER_IRSA_ROLE_ARN=$(terragrunt output -raw alb_controller_irsa_role_arn 2>/dev/null | tail -n 1)
CLUSTER_AUTOSCALER_IRSA_ROLE_ARN=$(terragrunt output -raw cluster_autoscaler_irsa_role_arn 2>/dev/null | tail -n 1)
OIDC_ISSUER=$(terragrunt output -raw cluster_oidc_issuer_url 2>/dev/null | tail -n 1)

# Get AWS account and region
AWS_REGION=${AWS_REGION:-"eu-central-1"}  # Use environment variable or default
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Return to script directory
cd "$SCRIPT_DIR"

# Display values
echo -e "\n\033[32mInfrastructure Values:\033[0m"
echo "  VPC_ID: $VPC_ID"
echo "  CLUSTER_NAME: $CLUSTER_NAME"
echo "  AWS_REGION: $AWS_REGION"
echo "  AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
echo "  PUBLIC_SUBNET_IDS: $PUBLIC_SUBNET_IDS"
echo "  PRIVATE_SUBNET_IDS: $PRIVATE_SUBNET_IDS"
echo "  ESO_IRSA_ROLE_ARN: $ESO_IRSA_ROLE_ARN"
echo "  ALB_CONTROLLER_IRSA_ROLE_ARN: $ALB_CONTROLLER_IRSA_ROLE_ARN"
echo "  CLUSTER_AUTOSCALER_IRSA_ROLE_ARN: $CLUSTER_AUTOSCALER_IRSA_ROLE_ARN"

# Function to substitute values in a file
substitute_values() {
    local file_path=$1
    
    if [ ! -f "$file_path" ]; then
        echo -e "  \033[31mFile not found: $file_path\033[0m"
        return
    fi
    
    echo -e "  \033[90mProcessing: $file_path\033[0m"
    
    # Create a temporary file
    local temp_file=$(mktemp)
    
    # Perform substitutions
    sed \
        -e "s|\${VPC_ID}|$VPC_ID|g" \
        -e "s|\${CLUSTER_NAME}|$CLUSTER_NAME|g" \
        -e "s|\${AWS_REGION}|$AWS_REGION|g" \
        -e "s|\${AWS_ACCOUNT_ID}|$AWS_ACCOUNT_ID|g" \
        -e "s|\${PUBLIC_SUBNET_IDS}|$PUBLIC_SUBNET_IDS|g" \
        -e "s|\${PRIVATE_SUBNET_IDS}|$PRIVATE_SUBNET_IDS|g" \
        -e "s|\${ESO_IRSA_ROLE_ARN}|$ESO_IRSA_ROLE_ARN|g" \
        -e "s|\${ALB_CONTROLLER_IRSA_ROLE_ARN}|$ALB_CONTROLLER_IRSA_ROLE_ARN|g" \
        -e "s|\${CLUSTER_AUTOSCALER_IRSA_ROLE_ARN}|$CLUSTER_AUTOSCALER_IRSA_ROLE_ARN|g" \
        -e "s|\${OIDC_ISSUER}|$OIDC_ISSUER|g" \
        "$file_path" > "$temp_file"
    
    # Move the temporary file to the original location
    mv "$temp_file" "$file_path"
}

echo -e "\n\033[33mSubstituting values in YAML files...\033[0m"

# List of files to process
argocd_files=(
    "../argocd/prod/aws-load-balancer-controller.yaml"
    "../argocd/prod/external-secrets-operator.yaml"
    "../argocd/prod/ingress-nginx.yaml"
    "../argocd/prod/quiz-ai-prod.yaml"
    "../argocd/prod/external-secrets-config.yaml"
    "../argocd/prod/edge-ingress.yaml"
)

manifest_files=(
    "../manifests/edge-alb-ingress.yaml"
    "../manifests/cluster-secret-store.yaml"
    "../manifests/external-secrets.yaml"
)

# Process all files
all_files=("${argocd_files[@]}" "${manifest_files[@]}")

for file in "${all_files[@]}"; do
    file_path="$SCRIPT_DIR/$file"
    substitute_values "$file_path"
done

echo -e "\n\033[32mSubstitution completed successfully!\033[0m"
echo -e "\033[32mYou can now apply the ArgoCD applications.\033[0m"
