#!/usr/bin/env pwsh
<#
.SYNOPSIS
    GitHub Actions用Service Principalを作成し、必要な権限をすべて付与する初回セットアップスクリプト

.DESCRIPTION
    このスクリプトは以下を実行します:
    1. Service Principalの作成(または既存のものを使用)
    2. 必要なロールの割り当て:
       - Contributor: リソース管理
       - Resource Policy Contributor: Azure Policy管理
       - User Access Administrator: 自動RBAC管理(完全自動化に必要)
    3. GitHub Secrets用のJSON出力

.PARAMETER SubscriptionId
    Azure サブスクリプションID

.PARAMETER ServicePrincipalName
    作成するService Principal名(デフォルト: sp-wizexercise-github)

.PARAMETER ResourceGroup
    対象リソースグループ名(オプション)

.EXAMPLE
    # サブスクリプションスコープで作成
    .\Setup-ServicePrincipal.ps1 -SubscriptionId "832c4080-181c-476b-9db0-b3ce9596d40a"

.EXAMPLE
    # カスタム名で作成
    .\Setup-ServicePrincipal.ps1 -SubscriptionId "832c4080-181c-476b-9db0-b3ce9596d40a" -ServicePrincipalName "sp-myproject-ci"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalName = "sp-wizexercise-github",

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = ""
)

$ErrorActionPreference = 'Stop'

Write-Host "🚀 GitHub Actions用Service Principalセットアップ開始" -ForegroundColor Cyan
Write-Host ""

# サブスクリプション設定
Write-Host "📌 サブスクリプション設定: $SubscriptionId" -ForegroundColor Yellow
az account set --subscription $SubscriptionId

if ($LASTEXITCODE -ne 0) {
    Write-Error "サブスクリプション設定に失敗しました。az login を実行してください。"
    exit 1
}

$subscriptionName = az account show --query name -o tsv
Write-Host "   ✅ サブスクリプション: $subscriptionName" -ForegroundColor Green
Write-Host ""

# スコープ設定
$scope = "/subscriptions/$SubscriptionId"
$scopeName = "Subscription: $subscriptionName"

if ($ResourceGroup) {
    $scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup"
    $scopeName = "Resource Group: $ResourceGroup"
    Write-Host "⚠️  リソースグループスコープを使用: $ResourceGroup" -ForegroundColor Yellow
    Write-Host "   注意: User Access Administratorはサブスクリプションスコープでの付与を推奨" -ForegroundColor Yellow
    Write-Host ""
}

# Service Principal作成
Write-Host "🔐 Service Principal作成/確認: $ServicePrincipalName" -ForegroundColor Yellow

$existingSp = az ad sp list --display-name $ServicePrincipalName --query "[0]" -o json 2>$null | ConvertFrom-Json

if ($existingSp) {
    Write-Host "   ℹ️  既存のService Principalが見つかりました" -ForegroundColor Cyan
    $spObjectId = $existingSp.id
    $spAppId = $existingSp.appId
    Write-Host "   App ID: $spAppId" -ForegroundColor Gray
    Write-Host "   Object ID: $spObjectId" -ForegroundColor Gray
    
    Write-Host ""
    $recreate = Read-Host "既存のService Principalを削除して再作成しますか? (y/N)"
    
    if ($recreate -eq 'y' -or $recreate -eq 'Y') {
        Write-Host "   🗑️  既存のService Principalを削除中..." -ForegroundColor Yellow
        az ad sp delete --id $spObjectId
        $existingSp = $null
    }
}

if (-not $existingSp) {
    Write-Host "   🆕 新しいService Principalを作成中..." -ForegroundColor Yellow
    
    $spCredentials = az ad sp create-for-rbac `
        --name $ServicePrincipalName `
        --role "Contributor" `
        --scopes $scope `
        --sdk-auth `
        -o json | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Service Principal作成に失敗しました"
        exit 1
    }
    
    $spObjectId = (az ad sp list --display-name $ServicePrincipalName --query "[0].id" -o tsv)
    $spAppId = $spCredentials.clientId
    
    Write-Host "   ✅ Service Principal作成完了" -ForegroundColor Green
    Write-Host "   App ID: $spAppId" -ForegroundColor Gray
    Write-Host "   Object ID: $spObjectId" -ForegroundColor Gray
} else {
    Write-Host "   ✅ 既存のService Principalを使用します" -ForegroundColor Green
    
    # 既存の場合はcredentialsを再生成
    Write-Host "   🔄 新しいClient Secretを生成中..." -ForegroundColor Yellow
    $spCredentials = az ad sp credential reset --id $spObjectId --sdk-auth -o json | ConvertFrom-Json
}

Write-Host ""

# 必要なロールを割り当て
$requiredRoles = @(
    @{
        Name = "Contributor"
        Description = "リソース管理(作成/更新/削除)"
        Scope = $scope
    },
    @{
        Name = "Resource Policy Contributor"
        Description = "Azure Policy管理(作成/更新/割り当て)"
        Scope = "/subscriptions/$SubscriptionId"  # Policyは常にサブスクリプションスコープ
    },
    @{
        Name = "User Access Administrator"
        Description = "RBAC管理(ロール割り当ての自動化)"
        Scope = "/subscriptions/$SubscriptionId"  # RBACもサブスクリプションスコープ推奨
    }
)

Write-Host "🔒 必要な権限を付与中..." -ForegroundColor Yellow
Write-Host ""

foreach ($role in $requiredRoles) {
    Write-Host "   📋 ロール: $($role.Name)" -ForegroundColor Cyan
    Write-Host "      用途: $($role.Description)" -ForegroundColor Gray
    Write-Host "      スコープ: $($role.Scope)" -ForegroundColor Gray
    
    # 既存のロール割り当てを確認
    $existingAssignment = az role assignment list `
        --assignee-object-id $spObjectId `
        --role $role.Name `
        --scope $role.Scope `
        --query "[0].id" -o tsv 2>$null
    
    if ($existingAssignment) {
        Write-Host "      ✅ 既に割り当て済み" -ForegroundColor Green
    } else {
        Write-Host "      🔄 割り当て中..." -ForegroundColor Yellow
        
        az role assignment create `
            --assignee-object-id $spObjectId `
            --assignee-principal-type ServicePrincipal `
            --role $role.Name `
            --scope $role.Scope `
            -o none
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "      ✅ 割り当て完了" -ForegroundColor Green
        } else {
            Write-Host "      ❌ 割り当て失敗" -ForegroundColor Red
            Write-Warning "ロール '$($role.Name)' の割り当てに失敗しました。手動で付与してください。"
        }
    }
    
    Write-Host ""
}

# ロール割り当て確認
Write-Host "📊 現在のロール割り当て確認..." -ForegroundColor Yellow
az role assignment list --assignee-object-id $spObjectId --output table
Write-Host ""

# GitHub Secrets用JSON生成
Write-Host "📝 GitHub Secrets設定用JSON生成..." -ForegroundColor Yellow
Write-Host ""

$githubSecretJson = @{
    clientId = $spCredentials.clientId
    clientSecret = $spCredentials.clientSecret
    subscriptionId = $SubscriptionId
    tenantId = $spCredentials.tenantId
} | ConvertTo-Json -Compress

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ セットアップ完了!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "📌 次のステップ:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. GitHubリポジトリの Settings > Secrets and variables > Actions を開く" -ForegroundColor White
Write-Host ""
Write-Host "2. 以下のSecretを作成/更新:" -ForegroundColor White
Write-Host ""
Write-Host "   Secret名: AZURE_CREDENTIALS" -ForegroundColor Cyan
Write-Host "   値:" -ForegroundColor Cyan
Write-Host $githubSecretJson -ForegroundColor Gray
Write-Host ""
Write-Host "   Secret名: AZURE_SUBSCRIPTION_ID" -ForegroundColor Cyan
Write-Host "   値: $SubscriptionId" -ForegroundColor Gray
Write-Host ""
Write-Host "3. GitHub Actionsワークフローを実行" -ForegroundColor White
Write-Host "   - すべてのワークフローが完全自動で動作します" -ForegroundColor Gray
Write-Host "   - ロール割り当ても自動で行われます(User Access Administrator権限により)" -ForegroundColor Gray
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  セキュリティに関する注意:" -ForegroundColor Yellow
Write-Host "   - Client Secretは安全に保管してください(GitHub Secretsのみに保存)" -ForegroundColor Gray
Write-Host "   - このスクリプトの出力をログに残さないでください" -ForegroundColor Gray
Write-Host "   - User Access Administrator権限は強力な権限です" -ForegroundColor Gray
Write-Host "   - 定期的にClient Secretをローテーションしてください" -ForegroundColor Gray
Write-Host ""

# クリップボードにコピー(Windows/macOS/Linux対応)
$clipboardCopied = $false
try {
    if ($IsWindows -or $env:OS -match "Windows") {
        $githubSecretJson | Set-Clipboard
        $clipboardCopied = $true
    } elseif ($IsMacOS) {
        $githubSecretJson | pbcopy
        $clipboardCopied = $true
    } elseif ($IsLinux) {
        if (Get-Command xclip -ErrorAction SilentlyContinue) {
            $githubSecretJson | xclip -selection clipboard
            $clipboardCopied = $true
        }
    }
    
    if ($clipboardCopied) {
        Write-Host "📋 AZURE_CREDENTIALS の値をクリップボードにコピーしました!" -ForegroundColor Green
        Write-Host ""
    }
} catch {
    # クリップボード操作失敗は無視
}

Write-Host "🎉 完了! GitHub Actionsが完全自動化されました!" -ForegroundColor Green
Write-Host ""
