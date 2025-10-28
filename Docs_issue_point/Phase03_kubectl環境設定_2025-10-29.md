# Phase 03: kubectl 環境設定 - 2025-10-29

## 📋 概要

Kubernetes クラスター管理を効率化するため、kubectl コマンドラインツールを Windows 環境にインストールし、PATH 環境変数に追加しました。

---

## 🎯 目的

- **効率化**: フルパス指定なしで kubectl コマンドを実行可能に
- **開発体験向上**: Kubernetes リソース管理を簡易化
- **標準化**: 一般的な Kubernetes 管理フローに準拠

---

## 🔧 実施内容

### 1. kubectl の既存インストール確認

kubectl は以前の Azure CLI コマンドで既にインストールされていました。

**インストール場所**:

```
C:\Users\vainf\.azure-kubectl\kubectl.exe
```

**確認コマンド**:

```powershell
C:\Users\vainf\.azure-kubectl\kubectl.exe version --client
```

**結果**:

- Client Version: v1.34.1
- Kustomize Version: v5.7.1

### 2. PATH 環境変数の確認

**実行コマンド**:

```powershell
$env:PATH
```

**結果**: `C:\Users\vainf\.azure-kubectl` が PATH に含まれていないことを確認

### 3. 現在のセッションに PATH を追加

一時的に現在の PowerShell セッションで kubectl を使用可能にしました。

**実行コマンド**:

```powershell
$kubectlPath = "C:\Users\vainf\.azure-kubectl"
if (-not ($env:PATH -like "*$kubectlPath*")) {
    $env:PATH = "$kubectlPath;$env:PATH"
    Write-Host "kubectl PATH added for this session"
} else {
    Write-Host "kubectl PATH already exists"
}
```

**結果**: ✅ 現在のセッションで kubectl コマンドが使用可能に

### 4. ユーザー環境変数に永続的に追加

新しい PowerShell ウィンドウでも kubectl を使えるように、ユーザー環境変数の PATH を更新しました。

**実行コマンド**:

```powershell
[System.Environment]::SetEnvironmentVariable(
    'PATH',
    "C:\Users\vainf\.azure-kubectl;$([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::User))",
    [System.EnvironmentVariableTarget]::User
)
Write-Host "✅ User PATH permanently updated"
```

**結果**: ✅ 永続的に PATH 設定完了

### 5. 動作確認

**実行コマンド**:

```powershell
kubectl version --client
```

**結果**:

```
Client Version: v1.34.1
Kustomize Version: v5.7.1
```

✅ **フルパス指定なしで kubectl コマンドが正常に動作**

---

## ✅ 効果

### Before（設定前）

```powershell
# フルパスを毎回指定する必要があった
C:\Users\vainf\.azure-kubectl\kubectl.exe get pods
C:\Users\vainf\.azure-kubectl\kubectl.exe get svc
C:\Users\vainf\.azure-kubectl\kubectl.exe logs deployment/guestbook
```

### After（設定後）

```powershell
# 短いコマンドで実行可能
kubectl get pods
kubectl get svc
kubectl logs deployment/guestbook
```

---

## 📚 よく使う kubectl コマンド

### クラスター情報

```powershell
# クラスター接続設定
az aks get-credentials --resource-group rg-wiz-exercise --name aks-wiz-dev

# クラスター情報表示
kubectl cluster-info

# ノード一覧
kubectl get nodes
```

### Pod 管理

```powershell
# Pod一覧
kubectl get pods

# アプリのPod確認
kubectl get pods -l app=guestbook

# Pod詳細
kubectl describe pod <pod-name>

# Podログ
kubectl logs <pod-name>
kubectl logs -l app=guestbook --tail=50
```

### Service & Ingress

```powershell
# Service一覧
kubectl get svc

# すべてのNamespaceのService
kubectl get svc --all-namespaces

# Ingress確認
kubectl get ingress

# Ingress詳細
kubectl describe ingress guestbook-ingress
```

### デプロイ管理

```powershell
# Deployment一覧
kubectl get deployments

# Deployment詳細
kubectl describe deployment guestbook

# Deploymentスケーリング
kubectl scale deployment guestbook --replicas=3
```

### リソース監視

```powershell
# リソース使用状況
kubectl top nodes
kubectl top pods

# イベント確認
kubectl get events --sort-by='.lastTimestamp'
```

### トラブルシューティング

```powershell
# Pod内でコマンド実行
kubectl exec -it <pod-name> -- /bin/sh

# ポートフォワード（ローカルテスト）
kubectl port-forward deployment/guestbook 8080:3000

# ログをリアルタイム監視
kubectl logs -f deployment/guestbook
```

---

## 🔍 技術的詳細

### PATH 環境変数の仕組み

**Windows の環境変数スコープ**:

1. **System (マシン全体)**: すべてのユーザーに適用
2. **User (ユーザー単位)**: 現在のユーザーのみに適用
3. **Process (プロセス単位)**: 現在の実行プロセスのみ

今回は **User スコープ**に追加したため、以下の特性があります:

- ✅ 現在のユーザーのすべての新規セッションで有効
- ✅ 他のユーザーには影響なし
- ✅ 管理者権限不要

### PowerShell での環境変数操作

**一時的な変更（現在のセッションのみ）**:

```powershell
$env:PATH = "C:\new\path;$env:PATH"
```

**永続的な変更（ユーザースコープ）**:

```powershell
[System.Environment]::SetEnvironmentVariable(
    'PATH',
    "C:\new\path;$env:PATH",
    [System.EnvironmentVariableTarget]::User
)
```

**永続的な変更（システムスコープ - 管理者権限必要）**:

```powershell
[System.Environment]::SetEnvironmentVariable(
    'PATH',
    "C:\new\path;$env:PATH",
    [System.EnvironmentVariableTarget]::Machine
)
```

---

## 📝 環境情報の更新

`docs/ENVIRONMENT_INFO.md` の kubectl コマンド例セクションに、PATH 設定後の簡易コマンドを既に記載済みです。

**該当セクション**: "kubectl コマンド例" (Line 227-240)

```markdown
# クラスター接続

az aks get-credentials --resource-group rg-wiz-exercise --name aks-wiz-dev

# Pod 確認

kubectl get pods -l app=guestbook

# Service 確認

kubectl get svc

# Ingress 確認

kubectl get ingress

# ログ確認

kubectl logs -l app=guestbook --tail=50
```

---

## 🎓 学習ポイント

### kubectl の重要性

kubectl は Kubernetes クラスター管理の標準ツールであり、以下の操作を実行できます:

1. **リソース管理**: Pod、Service、Deployment などの作成・更新・削除
2. **監視**: リアルタイムログ、メトリクス、イベント確認
3. **デバッグ**: Pod 内コマンド実行、ポートフォワード
4. **スケーリング**: レプリカ数の増減
5. **ロールアウト**: デプロイメントの更新とロールバック

### PATH 環境変数の重要性

- **開発効率**: コマンド実行が簡潔に
- **ドキュメント**: 共有可能な標準コマンド形式
- **自動化**: スクリプトでの利用が容易

---

## 🚀 次のステップ（オプション）

### 1. kubectl エイリアス設定

PowerShell プロファイルにエイリアスを追加してさらに効率化:

```powershell
# PowerShellプロファイル編集
notepad $PROFILE

# 以下を追加
Set-Alias -Name k -Value kubectl

function kgp { kubectl get pods @args }
function kgs { kubectl get svc @args }
function kgi { kubectl get ingress @args }
function kl { kubectl logs @args }
```

保存後、新しいセッションで使用:

```powershell
k get pods        # kubectl get pods
kgp -l app=guestbook  # kubectl get pods -l app=guestbook
kl deployment/guestbook  # kubectl logs deployment/guestbook
```

### 2. kubectl オートコンプリート設定

PowerShell でタブ補完を有効化:

```powershell
# PowerShellプロファイルに追加
kubectl completion powershell | Out-String | Invoke-Expression
```

### 3. kubectx / kubens（コンテキスト切り替え）

複数クラスターを管理する場合に便利:

```powershell
# Scoopでインストール
scoop install kubectx

# 使用例
kubectx              # コンテキスト一覧
kubectx aks-wiz-dev  # コンテキスト切り替え
kubens default       # Namespace切り替え
```

---

## 📊 ステータス

| 項目                        | 状態    | 備考                       |
| --------------------------- | ------- | -------------------------- |
| **kubectl インストール**    | ✅ 完了 | v1.34.1                    |
| **PATH 設定（セッション）** | ✅ 完了 | 現在のセッションで有効     |
| **PATH 設定（永続化）**     | ✅ 完了 | User スコープに追加        |
| **動作確認**                | ✅ 完了 | version コマンド実行成功   |
| **ドキュメント更新**        | ✅ 完了 | ENVIRONMENT_INFO.md に記載 |

---

## 🔗 関連ドキュメント

- [ENVIRONMENT_INFO.md](../docs/ENVIRONMENT_INFO.md) - 環境情報（kubectl コマンド例を含む）
- [Phase02\_アプリデプロイ問題と解決\_2025-10-29.md](./Phase02_アプリデプロイ問題と解決_2025-10-29.md) - アプリデプロイトラブルシューティング
- [Phase01\_インフラデプロイ失敗\_2025-01-29.md](./Phase01_インフラデプロイ失敗_2025-01-29.md) - インフラデプロイ履歴

---

**作成日**: 2025 年 10 月 29 日  
**ステータス**: ✅ 完了  
**影響範囲**: 開発環境のみ（ローカル PATH 設定）
