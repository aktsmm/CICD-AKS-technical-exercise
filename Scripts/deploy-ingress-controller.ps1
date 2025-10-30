# ====================================
# NGINX Ingress Controller デプロイスクリプト
# ====================================

Write-Host "🚀 NGINX Ingress Controller をデプロイします..." -ForegroundColor Cyan

# AKS認証情報を取得
az aks get-credentials `
  --resource-group rg-bbs-cicd-aks001 `
  --name aks-dev `
  --overwrite-existing

# NGINX Ingress Controller をインストール（Azure用）
az aks command invoke `
  --resource-group rg-bbs-cicd-aks001 `
  --name aks-dev `
  --command "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml"

Write-Host "⏳ Ingress Controller のデプロイを待機中..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# デプロイ確認
az aks command invoke `
  --resource-group rg-bbs-cicd-aks001 `
  --name aks-dev `
  --command "kubectl get pods -n ingress-nginx"

# LoadBalancer External IP 取得まで待機
Write-Host "⏳ External IP が割り当てられるまで待機中..." -ForegroundColor Yellow
$maxAttempts = 20
$attempt = 1

while ($attempt -le $maxAttempts) {
    $result = az aks command invoke `
      --resource-group rg-bbs-cicd-aks001 `
      --name aks-dev `
      --command "kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'" `
      --query "logs" -o tsv
    
    if ($result -and $result -ne "<pending>") {
        Write-Host "✅ Ingress Controller External IP: $result" -ForegroundColor Green
        break
    }
    
    Write-Host "  試行 $attempt/$maxAttempts - まだIPが割り当てられていません..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
    $attempt++
}

if ($attempt -gt $maxAttempts) {
    Write-Host "⚠️ タイムアウト: External IP の取得に失敗しました" -ForegroundColor Red
} else {
    Write-Host "🎉 NGINX Ingress Controller のデプロイが完了しました！" -ForegroundColor Green
}
