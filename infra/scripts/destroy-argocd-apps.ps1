# destroy-argocd-apps.ps1
# Simple script to DESTROY ArgoCD-managed resources + handle finalizers (ArgoCD Applications + ALB Ingress)

$ErrorActionPreference = "Stop"

Write-Host "Configuring kubectl..."
aws eks update-kubeconfig --name prod-eks-cluster --region eu-central-1

# Base dir with your ArgoCD Application YAMLs
$baseDir = "C:\Users\ilai4\Desktop\work\project_circle\infra\argocd\prod"

function Exists-K8s {
    param([string]$ns, [string]$kind, [string]$name)
    $prev = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    try { kubectl -n $ns get $kind $name | Out-Null; return $true } catch { return $false } finally { $ErrorActionPreference = $prev }
}

function Delete-FileIfExists {
    param([string]$path)
    if (Test-Path $path) {
        Write-Host "kubectl delete -f $path"
        kubectl delete -f $path --ignore-not-found
    } else {
        Write-Host "Skip (file not found): $path" -ForegroundColor Yellow
    }
}

function Remove-AppFinalizers {
    param([Parameter(Mandatory)][string]$AppName)

    Write-Host "Removing finalizers from Application/$AppName ..." -ForegroundColor Yellow
    $prev = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    # נסיון עדין (merge)
    kubectl -n argocd patch application $AppName --type=merge -p '{"metadata":{"finalizers":[]}}' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        # נסיון חזק (JSON patch remove)
        kubectl -n argocd patch application $AppName --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' | Out-Null
    }
    $ErrorActionPreference = $prev
}

function With-AppController-Paused {
    param([ScriptBlock]$Action)
    $ns = "argocd"
    $dep = "argocd-application-controller"
    $scaledDown = $false
    try {
        # אם ה-controller קיים ורץ – נוריד ל-0 לשניה כדי שלא יוסיף finalizers מחדש
        if (Exists-K8s -ns $ns -kind "deploy" -name $dep) {
            $replicas = (kubectl -n $ns get deploy $dep -o jsonpath="{.spec.replicas}")
            if ([string]::IsNullOrEmpty($replicas)) { $replicas = "1" }
            Set-Variable -Name originalReplicas -Value $replicas -Scope Script
            Write-Host "Scaling down $dep to 0..." -ForegroundColor Yellow
            kubectl -n $ns scale deploy/$dep --replicas=0 | Out-Null
            $scaledDown = $true
        }
        & $Action
    } finally {
        if ($scaledDown) {
            Write-Host "Restoring $dep to $script:originalReplicas ..." -ForegroundColor Yellow
            kubectl -n $ns scale deploy/$dep --replicas=$script:originalReplicas | Out-Null
        }
    }
}

# --- Handle ALB controller presence (for graceful ALB cleanup) ---
$albCtrlExists = $false
try {
    kubectl -n kube-system get deploy aws-load-balancer-controller | Out-Null
    $albCtrlExists = $true
    Write-Host "AWS Load Balancer Controller found." -ForegroundColor Green
} catch {
    Write-Host "AWS Load Balancer Controller NOT found." -ForegroundColor Yellow
}

# --- If ALB controller is missing, strip the finalizer from the edge ingress to avoid hang ---
if (-not $albCtrlExists) {
    if (Exists-K8s -ns "ingress-nginx" -kind "ingress" -name "edge-to-nginx") {
        Write-Host "Controller missing; removing finalizer from ingress/edge-to-nginx..." -ForegroundColor Yellow
        $patch = '{"metadata":{"finalizers":[]}}'
        kubectl -n ingress-nginx patch ingress edge-to-nginx --type=merge -p $patch | Out-Null
    }
}

# ------------------- Destruction order (Applications) -------------------
# טיפ: נוריד finalizers + נמחק כל Application. אם מתקבלת שגיאת 'Forbidden: no new finalizers can be added if being deleted'
# נכבה זמנית את ה-controller, נסיר finalizers, נמחק, ונחזיר אותו.

$appsInOrder = @(
    "quiz-ai-prod",
    "external-secrets-config",
    "edge-ingress",
    "ingress-nginx",
    "aws-load-balancer-controller",
    "external-secrets-operator"
)

foreach ($app in $appsInOrder) {
    Write-Host "`nHandling Application/$app ..." -ForegroundColor Cyan

    # נסה להסיר finalizers ולמחוק רגיל
    Remove-AppFinalizers -AppName $app
    $prev = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    kubectl -n argocd delete application $app --wait=false | Out-Null
    $ErrorActionPreference = $prev

    Start-Sleep -Seconds 2

    # אם עדיין קיים/תקוע – נכבה controller, נסיר finalizers שוב, ונמחק
    if (Exists-K8s -ns "argocd" -kind "application" -name $app) {
        Write-Host "Application/$app still present; pausing app-controller and forcing finalizer removal..." -ForegroundColor Yellow
        With-AppController-Paused {
            Remove-AppFinalizers -AppName $app
            $prev2 = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
            kubectl -n argocd delete application $app --wait=false | Out-Null
            $ErrorActionPreference = $prev2
        }
    }
}

# ------------------- Destruction order (by files) -------------------
# אם נשארו עדיין Applications בקבצים – נריץ delete -f כגיבוי (תואם למה שהיה לך)
Write-Host "`n[Files cleanup] Deleting by files as fallback..." -ForegroundColor DarkGray
$filesInOrder = @(
    "$baseDir\quiz-ai-prod.yaml",
    "$baseDir\external-secrets-config.yaml",
    "$baseDir\edge-ingress.yaml",
    "$baseDir\ingress-nginx.yaml",
    "$baseDir\aws-load-balancer-controller.yaml",
    "$baseDir\external-secrets-operator.yaml"
)
foreach ($f in $filesInOrder) { Delete-FileIfExists $f }

Write-Host "`nDone. Core ArgoCD applications deleted (finalizers handled)." -ForegroundColor Green

Write-Host "`nCheck remaining resources:"
Write-Host "  kubectl get applications.argoproj.io -n argocd"
Write-Host "  kubectl get ing -A"
Write-Host "  kubectl -n kube-system get deploy aws-load-balancer-controller"
Write-Host ""
Write-Host "If an ALB still exists (controller was missing), delete it in AWS console/CLI."
