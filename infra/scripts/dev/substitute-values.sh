#!/bin/bash
# substitute-values.sh - Dev Environment
# Fetch infra outputs with Terragrunt and substitute into ArgoCD/manifests files.

set -e

echo -e "\033[33mFetching infrastructure values from Terraform/Terragrunt...\033[0m"

# Resolve repo paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_PATH="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# --- VPC outputs ---
echo -e "\033[36mGetting VPC outputs...\033[0m"
cd "${INFRA_PATH}/live/dev/vpc"

# Basic IDs
VPC_ID=$(terragrunt output -raw vpc_id 2>/dev/null | tail -1)

# Public subnets → CSV without spaces and wrapped in quotes (for NLB annotation if needed)
PUBLIC_SUBNET_IDS_JSON=$(terragrunt output -json public_subnets 2>/dev/null)
PUBLIC_SUBNET_IDS_NO_SPACES=$(echo "$PUBLIC_SUBNET_IDS_JSON" | jq -r '. | join(",")')
PUBLIC_SUBNET_IDS_YAML="\"${PUBLIC_SUBNET_IDS_NO_SPACES}\""

# Private subnets → same treatment
PRIVATE_SUBNET_IDS_JSON=$(terragrunt output -json private_subnets 2>/dev/null)
PRIVATE_SUBNET_IDS_NO_SPACES=$(echo "$PRIVATE_SUBNET_IDS_JSON" | jq -r '. | join(",")')
PRIVATE_SUBNET_IDS_YAML="\"${PRIVATE_SUBNET_IDS_NO_SPACES}\""

# --- EKS outputs ---
echo -e "\033[36mGetting EKS outputs...\033[0m"
cd "${INFRA_PATH}/live/dev/eks"

CLUSTER_NAME=$(terragrunt output -raw cluster_name 2>/dev/null | tail -1)
ESO_IRSA_ROLE_ARN=$(terragrunt output -raw eso_irsa_role_arn 2>/dev/null | tail -1)
CLUSTER_AUTOSCALER_IRSA_ROLE_ARN=$(terragrunt output -raw cluster_autoscaler_irsa_role_arn 2>/dev/null | tail -1)
OIDC_ISSUER=$(terragrunt output -raw cluster_oidc_issuer_url 2>/dev/null | tail -1)

# --- AWS account/region ---
AWS_REGION="eu-central-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Back to script dir
cd "${SCRIPT_DIR}"

echo -e "\n\033[32mInfrastructure Values:\033[0m"
echo "  VPC_ID: ${VPC_ID}"
echo "  CLUSTER_NAME: ${CLUSTER_NAME}"
echo "  AWS_REGION: ${AWS_REGION}"
echo "  AWS_ACCOUNT_ID: ${AWS_ACCOUNT_ID}"
echo "  PUBLIC_SUBNET_IDS: ${PUBLIC_SUBNET_IDS_YAML}"
echo "  PRIVATE_SUBNET_IDS: ${PRIVATE_SUBNET_IDS_YAML}"
echo "  ESO_IRSA_ROLE_ARN: ${ESO_IRSA_ROLE_ARN}"
echo "  CLUSTER_AUTOSCALER_IRSA_ROLE_ARN: ${CLUSTER_AUTOSCALER_IRSA_ROLE_ARN}"
echo "  OIDC_ISSUER: ${OIDC_ISSUER}"

substitute_values() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        echo -e "  \033[31mFile not found: ${file_path}\033[0m"
        return
    fi
    
    echo -e "  \033[90mProcessing: ${file_path}\033[0m"
    
    # Create a temporary file
    local tmp_file="${file_path}.tmp"
    
    # Perform literal replacements (no regex)
    cp "$file_path" "$tmp_file"
    
    # Use sed with literal string replacement
    sed -i "s|\${VPC_ID}|${VPC_ID}|g" "$tmp_file"
    sed -i "s|\${CLUSTER_NAME}|${CLUSTER_NAME}|g" "$tmp_file"
    sed -i "s|\${AWS_REGION}|${AWS_REGION}|g" "$tmp_file"
    sed -i "s|\${AWS_ACCOUNT_ID}|${AWS_ACCOUNT_ID}|g" "$tmp_file"
    sed -i "s|\${PUBLIC_SUBNET_IDS}|${PUBLIC_SUBNET_IDS_YAML}|g" "$tmp_file"
    sed -i "s|\${PRIVATE_SUBNET_IDS}|${PRIVATE_SUBNET_IDS_YAML}|g" "$tmp_file"
    sed -i "s|\${ESO_IRSA_ROLE_ARN}|${ESO_IRSA_ROLE_ARN}|g" "$tmp_file"
    sed -i "s|\${CLUSTER_AUTOSCALER_IRSA_ROLE_ARN}|${CLUSTER_AUTOSCALER_IRSA_ROLE_ARN}|g" "$tmp_file"
    sed -i "s|\${OIDC_ISSUER}|${OIDC_ISSUER}|g" "$tmp_file"
    
    # Move the temp file back
    mv "$tmp_file" "$file_path"
}

echo -e "\n\033[33mSubstituting values in YAML files...\033[0m"

# Define all files that need substitution
ALL_FILES=(
    # ArgoCD application files
    "../../argocd/dev/external-secrets-operator.yaml"
    "../../argocd/dev/external-secrets-config.yaml"
    "../../argocd/dev/ingress-nginx.yaml"
    "../../argocd/dev/quiz-ai-dev.yaml"
    "../../argocd/dev/quiz-ai-stage.yaml"
    
    # Manifests files
    "../../manifests/dev/cluster-secret-store.yaml"
    "../../manifests/dev/external-secrets-dev.yaml"
    "../../manifests/dev/external-secrets-stage.yaml"
)

for rel_path in "${ALL_FILES[@]}"; do
    file_path="${SCRIPT_DIR}/${rel_path}"
    substitute_values "$file_path"
done

echo -e "\n\033[32mSubstitution completed successfully!\033[0m"
echo -e "\033[32mYou can now apply/sync your ArgoCD applications.\033[0m"

# Optional: quick sanity check on a sample substituted file
ESO_FILE="${SCRIPT_DIR}/../../argocd/dev/external-secrets-operator.yaml"
if [ -f "$ESO_FILE" ]; then
    echo -e "\n\033[96mPreview of IRSA annotation in external-secrets-operator.yaml:\033[0m"
    grep "eks.amazonaws.com/role-arn" "$ESO_FILE" | while read -r line; do
        echo "  $line"
    done
fi
