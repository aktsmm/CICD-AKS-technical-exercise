# Phase 03: kubectl 環境設定 - 2025-10-29

## 📋 概要

Kubernetes クラスター管理を効率化するため、kubectl コマンドラインツールを Windows 環境の PATH に追加し、簡単にコマンド実行できるようにしました。

---

## 🎯 目的

- **効率化**: フルパス指定なしで kubectl コマンドを実行
- **開発体験向上**: Kubernetes リソース管理を簡易化
- **標準化**: 一般的な Kubernetes 管理フローに準拠

---

## 🔧 実施内容

### 1. kubectl の既存インストール確認

kubectl は Azure CLI によって既にインストール済みでした。

**インストール場所**:

```text
C:\Users\vainf\.azure-kubectl\kubectl.exe
```

**確認コマンド**:

```powershell
C:\Users\vainf\.azure-kubectl\kubectl.exe version --client
```

**結果**:

```text
Client Version: v1.34.1
Kustomize Version: v5.7.1
```

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
}
```

**結果**: ✅ 現在のセッションで kubectl コマンドが使用可能に

### 4. ユーザー環境変数に永続的に追加

新しい PowerShell ウィンドウでも kubectl を使えるように、ユーザー環境変数を更新しました。

**実行コマンド**:

```powershell
[System.Environment]::SetEnvironmentVariable(
    'PATH',
    "C:\Users\vainf\.azure-kubectl;$([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::User))",
    [System.EnvironmentVariableTarget]::User
)
```

**結果**: ✅ 永続的に PATH 設定完了

### 5. 動作確認

**実行コマンド**:

```powershell
kubectl version --client
```

**結果**:

```text
Client Version: v1.34.1
Kustomize Version: v5.7.1
```

✅ **フルパス指定なしで kubectl コマンドが正常に動作**

---

## ✅ 効果

### Before（設定前）

```powershell
# フルパスを毎回指定
C:\Users\vainf\.azure-kubectl\kubectl.exe get pods
C:\Users\vainf\.azure-kubectl\kubectl.exe get svc
C:\Users\vainf\.azure-kubectl\kubectl.exe logs deployment/guestbook-app
```

### After（設定後）

```powershell
# シンプルなコマンドで実行可能
kubectl get pods
kubectl get svc
kubectl logs deployment/guestbook-app
```

---

## 📚 よく使う kubectl コマンド集

### クラスター情報

```powershell
# AKS認証情報取得
az aks get-credentials --resource-group rg-wiz-exercise-001 --name aks-wiz-dev

# クラスター情報
kubectl cluster-info

# ノード一覧
kubectl get nodes -o wide
```

### Pod 管理

```powershell
# Pod一覧
kubectl get pods

# ラベルでフィルタリング
kubectl get pods -l app=guestbook

# Pod詳細情報
kubectl describe pod <pod-name>

# Podログ確認
kubectl logs <pod-name>
kubectl logs -l app=guestbook --tail=50
kubectl logs -f deployment/guestbook-app  # リアルタイム監視
```

### Service & Ingress

```powershell
# Service一覧
kubectl get svc

# 全NamespaceのService
kubectl get svc --all-namespaces

# Ingress確認
kubectl get ingress

# Ingress詳細
kubectl describe ingress guestbook-ingress
```

### Deployment 管理

```powershell
# Deployment一覧
kubectl get deployments

# Deployment詳細
kubectl describe deployment guestbook-app

# スケーリング（レプリカ数変更）
kubectl scale deployment guestbook-app --replicas=3

# ローリングアップデート状態確認
kubectl rollout status deployment/guestbook-app

# ロールバック
kubectl rollout undo deployment/guestbook-app
```

### リソース監視

```powershell
# ノードのリソース使用率
kubectl top nodes

# Podのリソース使用率
kubectl top pods

# イベント確認（時系列）
kubectl get events --sort-by='.lastTimestamp'

# 特定リソースの監視（watch）
kubectl get pods -w
```

### トラブルシューティング

```powershell
# Pod内でシェル起動
kubectl exec -it <pod-name> -- /bin/sh

# ローカルからPodへポートフォワード
kubectl port-forward deployment/guestbook-app 8080:3000
# → http://localhost:8080 でアクセス可能

# ConfigMap確認
kubectl get configmap
kubectl describe configmap <configmap-name>

# Secret確認（値は表示されない）
kubectl get secrets
kubectl describe secret <secret-name>
```

---

## 🔍 技術的背景

### PATH 環境変数のスコープ

**Windows の環境変数は 3 つのスコープで管理されます**:

| スコープ                   | 適用範囲           | 権限要否   |
| -------------------------- | ------------------ | ---------- |
| **System (マシン全体)**    | すべてのユーザー   | 管理者権限 |
| **User (ユーザー単位)**    | 現在のユーザーのみ | 不要       |
| **Process (プロセス単位)** | 現在のプロセスのみ | 不要       |

今回は **User スコープ**に追加したため:

- ✅ 現在のユーザーのすべての新規セッションで有効
- ✅ 他のユーザーには影響なし
- ✅ 管理者権限不要

### PowerShell での環境変数操作

#### 一時的な変更（現在のセッションのみ）

```powershell
$env:PATH = "C:\new\path;$env:PATH"
```

#### 永続的な変更（ユーザースコープ）

```powershell
[System.Environment]::SetEnvironmentVariable(
    'PATH',
    "C:\new\path;$env:PATH",
    [System.EnvironmentVariableTarget]::User
)
```

#### 永続的な変更（システムスコープ）

```powershell
# 管理者権限必要
[System.Environment]::SetEnvironmentVariable(
    'PATH',
    "C:\new\path;$env:PATH",
    [System.EnvironmentVariableTarget]::Machine
)
```

---

---

## 📝 ドキュメント相互参照

`docs/ENVIRONMENT_INFO.md` にも kubectl コマンド例が記載されています。

**該当セクション**: 「kubectl コマンド例」

```markdown
# クラスター接続

az aks get-credentials --resource-group rg-wiz-exercise-001 --name aks-wiz-dev

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

## 🚀 応用編（オプション）

### 1. PowerShell エイリアス設定

よく使うコマンドをさらに短縮できます。

**設定方法**:

```powershell
# PowerShellプロファイル編集
notepad $PROFILE

# 以下を追加して保存
Set-Alias -Name k -Value kubectl

function kgp { kubectl get pods @args }
function kgs { kubectl get svc @args }
function kgi { kubectl get ingress @args }
function kd { kubectl describe @args }
function kl { kubectl logs @args }
```

**使用例**:

```powershell
k get pods                      # kubectl get pods
kgp -l app=guestbook            # kubectl get pods -l app=guestbook
kl deployment/guestbook-app     # kubectl logs deployment/guestbook-app
kd deployment guestbook-app     # kubectl describe deployment guestbook-app
```

### 2. kubectl オートコンプリート

タブキーでコマンド補完が可能になります。

```powershell
# PowerShellプロファイルに追加
kubectl completion powershell | Out-String | Invoke-Expression
```

**効果**:

- `kubectl get po<Tab>` → `kubectl get pods`
- リソース名も補完候補に表示

### 3. kubectx / kubens ツール

複数のクラスター・Namespace を管理する場合に便利です。

**インストール**:

```powershell
# Scoopを使用（未インストールの場合は scoop.sh を参照）
scoop install kubectx
```

**使用例**:

```powershell
# コンテキスト（クラスター）切り替え
kubectx                    # 一覧表示
kubectx aks-wiz-dev        # 切り替え

# Namespace切り替え
kubens                     # 一覧表示
kubens default             # 切り替え
kubens ingress-nginx       # Ingress Controller namespace
```

---

## 📊 完了ステータス

| 項目                     | 状態    | バージョン/詳細          |
| ------------------------ | ------- | ------------------------ |
| **kubectl インストール** | ✅ 完了 | v1.34.1                  |
| **PATH 設定（一時）**    | ✅ 完了 | 現在のセッションで有効   |
| **PATH 設定（永続化）**  | ✅ 完了 | User スコープに追加      |
| **動作確認**             | ✅ 完了 | `version --client` 成功  |
| **ドキュメント更新**     | ✅ 完了 | ENVIRONMENT_INFO.md 記載 |

---

## 🔗 関連ドキュメント

- **[ENVIRONMENT_INFO.md](../docs/ENVIRONMENT_INFO.md)** - 環境情報全体（kubectl コマンド例を含む）
- **[Phase02\_アプリデプロイ問題と解決\_2025-10-29.md](./Phase02_アプリデプロイ問題と解決_2025-10-29.md)** - アプリケーションデプロイのトラブルシューティング
- **[Phase01\_インフラデプロイ失敗\_2025-01-29.md](./Phase01_インフラデプロイ失敗_2025-01-29.md)** - インフラストラクチャデプロイ履歴

---

**作成日**: 2025 年 10 月 29 日  
**ステータス**: ✅ 完了  
**影響範囲**: ローカル開発環境（PATH 設定のみ）
