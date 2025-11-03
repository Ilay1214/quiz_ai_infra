#!/bin/bash
# Bash script: delete ArgoCD apps in reverse order and wait for ALB cleanup

set -euo pipefail

echo -e "\n\033[36m========================================\033[0m"
echo -e "\033[36m   Destroying ArgoCD Applications\033[0m"
echo -e "\033[36m========================================\033[0m\n"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFRA_PATH="$(dirname "$SCRIPT_DIR")"
ARGO_NS="argocd"

# Validate kubectl
if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found in PATH" >&2
  exit 1
fi

# Try to fetch values from Terragrunt outputs (used to identify ALB)
VPC_ID=""
CLUSTER_NAME=""
if [ -d "$INFRA_PATH/live/prod/vpc" ]; then
  pushd "$INFRA_PATH/live/prod/vpc" >/dev/null || true
  VPC_ID=$(terragrunt output -raw vpc_id 2>/dev/null || true)
  popd >/dev/null || true
fi
if [ -d "$INFRA_PATH/live/prod/eks" ]; then
  pushd "$INFRA_PATH/live/prod/eks" >/dev/null || true
  CLUSTER_NAME=$(terragrunt output -raw cluster_name 2>/dev/null || true)
  popd >/dev/null || true
fi

echo "VPC_ID: ${VPC_ID:-<unknown>}"
echo "CLUSTER_NAME: ${CLUSTER_NAME:-<unknown>}"

delete_app() {
  local name="$1"
  echo -e "\n\033[33mDeleting ArgoCD Application: $name\033[0m"
  kubectl delete application "$name" -n "$ARGO_NS" --ignore-not-found || true
  kubectl wait --for=delete application/"$name" -n "$ARGO_NS" --timeout=120s || true
}

ingress_safeguard() {
  echo -e "\n\033[33mEnsuring edge Ingress is deleted (safeguard)\033[0m"
  kubectl delete ingress edge-to-nginx -n ingress-nginx --ignore-not-found || true
}

count_cluster_albs() {
  # Returns count of ALBs in VPC tagged for this cluster
  local count=0
  local arns
  if [ -n "${VPC_ID:-}" ]; then
    arns=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID' && Type=='application'].LoadBalancerArn" --output text 2>/dev/null || true)
  else
    arns=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?Type=='application'].LoadBalancerArn" --output text 2>/dev/null || true)
  fi
  if [ -z "${arns:-}" ]; then echo 0; return; fi
  for arn in $arns; do
    [ -z "$arn" ] && continue
    tags_json=$(aws elbv2 describe-tags --resource-arns "$arn" --output json 2>/dev/null || true)
    if [ -n "${CLUSTER_NAME:-}" ]; then
      if echo "$tags_json" | jq -e \
        ".TagDescriptions[0].Tags[] | select((.Key==\"elbv2.k8s.aws/cluster\" and .Value==\"$CLUSTER_NAME\") or (.Key==\"kubernetes.io/cluster/$CLUSTER_NAME\"))" \
        >/dev/null 2>&1; then
        count=$((count+1))
      fi
    else
      # If cluster name unknown, assume ALB is relevant (since filtered by VPC when available)
      count=$((count+1))
    fi
  done
  echo "$count"
}

MAX_ATTEMPTS="${MAX_ATTEMPTS:-30}"
SLEEP_SECONDS="${SLEEP_SECONDS:-10}"

# Reverse order (6 -> 1)
delete_app "quiz-ai-prod"               # Wave 6
delete_app "external-secrets-config"    # Wave 5
delete_app "edge-ingress"               # Wave 4 (deletes Ingress)
ingress_safeguard                         # Ensure ingress is gone

# Wait for ALB deletion before removing controllers
echo -e "\n\033[36mWaiting for ALB(s) to be deleted by the controller...\033[0m"
for (( i=1; i<=MAX_ATTEMPTS; i++ )); do
  remaining=$(count_cluster_albs)
  if [ "$remaining" -eq 0 ]; then
    echo -e "\033[32mNo ALBs tagged for cluster remain.\033[0m"
    break
  fi
  echo -e "\033[90m  Still found ${remaining} ALB(s). Waiting ${SLEEP_SECONDS}s... (${i}/${MAX_ATTEMPTS})\033[0m"
  sleep "$SLEEP_SECONDS"
done

delete_app "ingress-nginx"              # Wave 3
delete_app "aws-load-balancer-controller" # Wave 2
delete_app "external-secrets-operator"  # Wave 1

echo -e "\n\033[32mAll ArgoCD applications deleted (reverse order).\033[0m"
echo -e "\033[32mYou can now destroy EKS/VPC with Terragrunt safely.\033[0m"
