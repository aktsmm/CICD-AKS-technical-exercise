# 環境情報 - Wiz Technical Exercise

**作成日**: 2025年10月29日  
**最終更新**: 2025年10月29日  
**プロジェクト**: Wiz Technical Exercise - Cloud Security Demo

---

## 📋 目次

1. [Azure サブスクリプション情報](#azure-サブスクリプション情報)
2. [デプロイされたリソース概要](#デプロイされたリソース概要)
3. [ネットワーク構成](#ネットワーク構成)
4. [Kubernetes (AKS) 環境](#kubernetes-aks-環境)
5. [MongoDB 仮想マシン](#mongodb-仮想マシン)
6. [コンテナレジストリ (ACR)](#コンテナレジストリ-acr)
7. [アプリケーション情報](#アプリケーション情報)
8. [CI/CD パイプライン](#cicd-パイプライン)
9. [アクセス情報](#アクセス情報)
10. [セキュリティ設定](#セキュリティ設定)

---

## Azure サブスクリプション情報

### 基本情報

| 項目 | 値 |
|------|-----|
| **サブスクリプション名** | Visual Studio Enterprise |
| **サブスクリプションID** | `832c4080-181c-476b-9db0-b3ce9596d40a` |
| **テナントID** | `04879edd-d806-4f5d-86b8-d3a171c883fa` |
| **リージョン** | Japan East |
| **リソースグループ** | `rg-wiz-exercise` |

### 確認コマンド

```bash
az account show
az group show --name rg-wiz-exercise
```

---

## デプロイされたリソース概要

### リソース一覧

| リソース名 | タイプ | 用途 | 状態 |
|----------|--------|------|------|
| **aks-wiz-dev** | AKS Cluster | Kubernetesクラスター | ✅ Running |
| **acrwizdev** | Container Registry | Dockerイメージ管理 | ✅ Active |
| **vm-mongo-dev** | Virtual Machine | MongoDBサーバー | ✅ Running |
| **vnet-wiz-dev** | Virtual Network | ネットワーク基盤 | ✅ Active |
| **log-wiz-dev** | Log Analytics | 監視・ログ収集 | ✅ Active |
| **stwizdevdacheo6jrka7w** | Storage Account | バックアップストレージ | ✅ Active |

### リソース構成図

```
┌─────────────────────────────────────────────────────────┐
│              Azure Subscription                          │
│         (Visual Studio Enterprise)                       │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Resource Group: rg-wiz-exercise                 │  │
│  │                                                  │  │
│  │  ┌──────────────────────────────────────────┐  │  │
│  │  │  Virtual Network: vnet-wiz-dev           │  │  │
│  │  │  Address Space: 10.0.0.0/16              │  │  │
│  │  │                                          │  │  │
│  │  │  ┌─────────────────────────────────┐   │  │  │
│  │  │  │ Subnet: snet-aks (10.0.1.0/24)  │   │  │  │
│  │  │  │                                 │   │  │  │
│  │  │  │  ┌──────────────────────────┐  │   │  │  │
│  │  │  │  │ AKS Cluster              │  │   │  │  │
│  │  │  │  │ aks-wiz-dev              │  │   │  │  │
│  │  │  │  │ - 2 Nodes (Standard_DS2) │  │   │  │  │
│  │  │  │  │ - Kubernetes 1.32        │  │   │  │  │
│  │  │  │  │                          │  │   │  │  │
│  │  │  │  │  [Guestbook App Pods]   │  │   │  │  │
│  │  │  │  │  [NGINX Ingress]        │  │   │  │  │
│  │  │  │  └──────────────────────────┘  │   │  │  │
│  │  │  └─────────────────────────────────┘   │  │  │
│  │  │                                          │  │  │
│  │  │  ┌─────────────────────────────────┐   │  │  │
│  │  │  │ Subnet: snet-vm (10.0.2.0/24)   │   │  │  │
│  │  │  │                                 │   │  │  │
│  │  │  │  ┌──────────────────────────┐  │   │  │  │
│  │  │  │  │ VM: vm-mongo-dev         │  │   │  │  │
│  │  │  │  │ - Ubuntu 20.04 LTS       │  │   │  │  │
│  │  │  │  │ - MongoDB 4.4            │  │   │  │  │
│  │  │  │  │ - Public IP: 172.192.25.0│  │   │  │  │
│  │  │  │  └──────────────────────────┘  │   │  │  │
│  │  │  └─────────────────────────────────┘   │  │  │
│  │  └──────────────────────────────────────────┘  │  │
│  │                                                  │  │
│  │  ┌──────────────────────────────────────────┐  │  │
│  │  │ ACR: acrwizdev.azurecr.io                │  │  │
│  │  │ - SKU: Basic                             │  │  │
│  │  │ - Images: guestbook (v3, v4, SHA tags)   │  │  │
│  │  └──────────────────────────────────────────┘  │  │
│  │                                                  │  │
│  │  ┌──────────────────────────────────────────┐  │  │
│  │  │ Storage: stwizdevdacheo6jrka7w           │  │  │
│  │  │ - MongoDB Backups                        │  │  │
│  │  │ - Public Access: Enabled (Vulnerable)    │  │  │
│  │  └──────────────────────────────────────────┘  │  │
│  │                                                  │  │
│  │  ┌──────────────────────────────────────────┐  │  │
│  │  │ Log Analytics: log-wiz-dev               │  │  │
│  │  │ - Container Insights                     │  │  │
│  │  │ - Activity Logs                          │  │  │
│  │  └──────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘

External Access:
  → http://20.18.117.80 (Ingress + Azure LB)
  → ssh://172.192.25.0:22 (MongoDB VM - Vulnerable)
```

---

## ネットワーク構成

### Virtual Network

| 項目 | 値 |
|------|-----|
| **名前** | vnet-wiz-dev |
| **アドレス空間** | 10.0.0.0/16 |
| **リージョン** | Japan East |

### サブネット構成

| サブネット名 | アドレス範囲 | 用途 | 接続リソース |
|------------|------------|------|------------|
| **snet-aks** | 10.0.1.0/24 | AKSノード | AKSクラスター (2ノード) |
| **snet-vm** | 10.0.2.0/24 | 仮想マシン | MongoDB VM |

### ネットワークセキュリティグループ (NSG)

#### vm-mongo-dev-nsg

| ルール名 | 方向 | プロトコル | ポート | ソース | 優先度 | 目的 |
|---------|------|----------|-------|--------|--------|------|
| SSH | Inbound | TCP | 22 | * | 300 | SSH アクセス (Vulnerable) |
| MongoDB | Inbound | TCP | 27017 | 10.0.0.0/16 | 310 | AKSからのDB接続 |

### パブリックIPアドレス

| 名前 | IPアドレス | 用途 |
|------|----------|------|
| **vm-mongo-dev-pip** | 172.192.25.0 | MongoDB VM |
| **ingress-nginx-controller** | 20.18.117.80 | Ingress LoadBalancer |

---

## Kubernetes (AKS) 環境

### クラスター情報

| 項目 | 値 |
|------|-----|
| **クラスター名** | aks-wiz-dev |
| **Kubernetesバージョン** | 1.32.7 |
| **リージョン** | Japan East |
| **ネットワークプラグイン** | Azure CNI |
| **DNS サービスIP** | 10.1.0.10 |
| **サービスCIDR** | 10.1.0.0/16 |
| **SKU Tier** | Free |

### ノードプール

| 名前 | VMサイズ | ノード数 | OS | 状態 |
|------|---------|---------|-----|------|
| **nodepool1** | Standard_DS2_v2 | 2 | Ubuntu 22.04.5 LTS | ✅ Ready |

**ノード詳細**:

```
Node 1: aks-nodepool1-28174749-vmss000000
  - Kubelet Version: v1.32.7
  - OS: Ubuntu 22.04.5 LTS
  - Status: Ready

Node 2: aks-nodepool1-28174749-vmss000001
  - Kubelet Version: v1.32.7
  - OS: Ubuntu 22.04.5 LTS
  - Status: Ready
```

### デプロイされたアプリケーション

#### Namespace: default

| リソース | 名前 | レプリカ | イメージ | 状態 |
|---------|------|---------|---------|------|
| **Deployment** | guestbook-app | 2/2 | acrwizdev.azurecr.io/guestbook:v4 | ✅ Running |
| **Service** | guestbook-service | ClusterIP | - | ✅ Active |
| **Ingress** | guestbook-ingress | nginx | - | ✅ Active |

#### Namespace: ingress-nginx

| リソース | 名前 | タイプ | EXTERNAL-IP | 状態 |
|---------|------|--------|-------------|------|
| **Service** | ingress-nginx-controller | LoadBalancer | 20.18.117.80 | ✅ Active |
| **Deployment** | ingress-nginx-controller | 1/1 | - | ✅ Running |

### Pod詳細

```bash
# アプリケーションPod
NAME                             READY   STATUS    RESTARTS   AGE
guestbook-app-5d497466c4-fhdtn   1/1     Running   0          45m
guestbook-app-5d497466c4-k48gv   1/1     Running   0          45m

# Ingress Controller Pod
NAME                                        READY   STATUS    AGE
ingress-nginx-controller-66cb9865b5-dbwbk   1/1     Running   48m
```

### kubectl コマンド例

```bash
# クラスター接続
az aks get-credentials --resource-group rg-wiz-exercise --name aks-wiz-dev

# Pod確認
kubectl get pods -l app=guestbook

# Service確認
kubectl get svc

# Ingress確認
kubectl get ingress

# ログ確認
kubectl logs -l app=guestbook --tail=50
```

---

## MongoDB 仮想マシン

### VM 基本情報

| 項目 | 値 |
|------|-----|
| **VM名** | vm-mongo-dev |
| **VMサイズ** | Standard_B2s (2 vCPU, 4GB RAM) |
| **OS** | Ubuntu 20.04 LTS |
| **パブリックIP** | 172.192.25.0 |
| **プライベートIP** | 10.0.2.4 |
| **管理ポート** | SSH (22) - **Vulnerable** |

### MongoDB 設定

| 項目 | 値 |
|------|-----|
| **バージョン** | MongoDB 4.4 (1年以上古い - Vulnerable) |
| **ポート** | 27017 |
| **認証** | 有効 |
| **アクセス元** | Kubernetes ネットワーク (10.0.0.0/16) |
| **データディレクトリ** | /var/lib/mongodb |
| **ログ** | /var/log/mongodb/mongod.log |

### バックアップ設定

- **バックアップ先**: Azure Storage Account (`stwizdevdacheo6jrka7w`)
- **頻度**: デイリー
- **保持期間**: 7日間
- **セキュリティ**: **Public Access有効 (Vulnerable)**

### 接続情報

**アプリケーションからの接続**:

```bash
MONGO_URI=mongodb://10.0.2.4:27017/guestbook
```

**VM管理アクセス**:

```bash
# SSH接続 (Vulnerable - Public Access)
ssh azureuser@172.192.25.0

# MongoDBステータス確認
sudo systemctl status mongod

# MongoDB接続テスト
mongo --host 10.0.2.4 --port 27017
```

### 意図的な脆弱性 (デモ用)

- ⚠️ SSHポートがパブリックに公開
- ⚠️ 過剰なクラウド権限 (VM作成可能)
- ⚠️ 1年以上古いMongoDB バージョン
- ⚠️ 1年以上古いOS バージョン

---

## コンテナレジストリ (ACR)

### ACR 基本情報

| 項目 | 値 |
|------|-----|
| **レジストリ名** | acrwizdev |
| **Login Server** | acrwizdev.azurecr.io |
| **SKU** | Basic |
| **管理者アカウント** | 無効 (Managed Identity使用) |
| **Public Network Access** | 有効 |

### イメージ一覧

| リポジトリ | タグ | ビルド日時 | 用途 |
|----------|------|----------|------|
| **guestbook** | v3 | 2025-10-28 | 初期動作確認版 |
| **guestbook** | v4 | 2025-10-28 | UI更新版 |
| **guestbook** | latest | 2025-10-28 | 最新版エイリアス |
| **guestbook** | f137a12... | 2025-10-29 | CI/CD自動ビルド (Commit SHA) |

### ACR操作コマンド

```bash
# ログイン
az acr login --name acrwizdev

# イメージ一覧
az acr repository list --name acrwizdev

# タグ一覧
az acr repository show-tags --name acrwizdev --repository guestbook

# イメージビルド
az acr build --registry acrwizdev --image guestbook:v5 .
```

### AKSとの統合

```bash
# ACRをAKSにアタッチ (既に設定済み)
az aks update \
  --resource-group rg-wiz-exercise \
  --name aks-wiz-dev \
  --attach-acr acrwizdev
```

---

## アプリケーション情報

### アプリケーション構成

| コンポーネント | 技術スタック | バージョン |
|--------------|------------|----------|
| **フロントエンド** | EJS (Embedded JavaScript) | 3.1.9 |
| **バックエンド** | Node.js + Express | 18 / 4.18.2 |
| **データベース** | MongoDB | 4.4 |
| **スタイリング** | Vanilla CSS | - |

### 依存関係 (package.json)

```json
{
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^7.6.3",
    "body-parser": "^1.20.2",
    "ejs": "^3.1.9"
  }
}
```

### アプリケーション機能

1. **メッセージ投稿**: ユーザー名とメッセージを入力
2. **メッセージ一覧**: MongoDB から取得して表示
3. **ヘルスチェック**: `/health` エンドポイント
4. **Wizファイル表示**: `/wizfile` エンドポイント (デモ用)

### 環境変数

```bash
PORT=3000
MONGO_URI=mongodb://10.0.2.4:27017/guestbook
```

### Dockerイメージ構成

**Dockerfile**:

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY wizexercise.txt /app/wizexercise.txt
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

### 意図的な脆弱性 (デモ用)

- ⚠️ Kubernetes クラスタ管理者権限の付与 (RBAC)
- ⚠️ 環境変数に直接接続文字列を記載

---

## CI/CD パイプライン

### GitHub Actions ワークフロー

#### 1. インフラデプロイ (`infra-deploy.yml`)

**トリガー**:
- `infra/**` の変更
- 手動実行 (workflow_dispatch)

**ジョブ構成**:

1. **Scan IaC for Security Issues**
   - Wiz CLI によるBicepスキャン
   - セキュリティ脆弱性の検出

2. **Deploy Azure Infrastructure**
   - Bicep によるインフラデプロイ
   - パラメータファイル: `parameters.json`
   - 出力: インフラ情報をArtifactに保存

**主要リソース**:
- AKS クラスター
- MongoDB VM
- Virtual Network
- Storage Account
- Log Analytics

#### 2. アプリデプロイ (`app-deploy.yml`)

**トリガー**:
- `app/**` の変更
- 手動実行 (workflow_dispatch)

**ジョブ構成**:

1. **Scan Container Image**
   - Trivyによるコンテナスキャン
   - 脆弱性レポート (SARIF形式)

2. **Build and Push to ACR**
   - Dockerイメージビルド (Commit SHAタグ)
   - ACRへプッシュ
   - `latest` タグも同時作成

3. **Deploy to AKS**
   - Kubernetesマニフェスト更新
   - 動的イメージタグの適用
   - ローリングアップデート

### パイプライン実行履歴

| ワークフロー | 最終実行 | 状態 | 実行時間 |
|------------|---------|------|---------|
| Deploy Infrastructure | 2025-10-28 | ✅ Success | 3m 29s |
| Build and Deploy Application | 2025-10-29 | ✅ Success | 4m 46s |

### GitHub Secrets

| シークレット名 | 用途 |
|--------------|------|
| **AZURE_CREDENTIALS** | Azure Service Principal (JSON) |

**設定内容**:

```json
{
  "clientId": "<client-id>",
  "clientSecret": "<client-secret>",
  "subscriptionId": "832c4080-181c-476b-9db0-b3ce9596d40a",
  "tenantId": "04879edd-d806-4f5d-86b8-d3a171c883fa"
}
```

### 自動化フロー

```
コード変更 (app/ または infra/)
    ↓
Git Push to main
    ↓
GitHub Actions 自動トリガー
    ↓
セキュリティスキャン (Wiz / Trivy)
    ↓
ビルド & テスト
    ↓
Azure デプロイ
    ↓
検証 & 通知
```

---

## アクセス情報

### Webアプリケーション

| 項目 | 値 |
|------|-----|
| **URL** | http://20.18.117.80 |
| **プロトコル** | HTTP |
| **認証** | なし |
| **ポート** | 80 (Ingress), 3000 (Pod) |

**エンドポイント**:

- `/` - メインページ (掲示板)
- `/post` - メッセージ投稿 (POST)
- `/health` - ヘルスチェック
- `/wizfile` - Wizファイル表示 (デモ用)

### 管理アクセス

#### Azure ポータル

- URL: https://portal.azure.com
- リソースグループ: `rg-wiz-exercise`

#### AKS クラスター

```bash
# kubectl アクセス設定
az aks get-credentials \
  --resource-group rg-wiz-exercise \
  --name aks-wiz-dev \
  --overwrite-existing

# ダッシュボード (オプション)
kubectl proxy
# http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

#### MongoDB VM (SSH)

```bash
ssh azureuser@172.192.25.0
# ⚠️ Vulnerable: パブリックSSHアクセス
```

---

## セキュリティ設定

### 実装済みセキュリティコントロール

#### 1. 予防的コントロール

- ✅ **Network Security Groups (NSG)**: MongoDB アクセス制限
- ✅ **Private Network**: AKSはプライベートサブネット
- ✅ **ACR統合**: Managed Identity による認証
- ✅ **MongoDB認証**: 認証有効化

#### 2. 検知的コントロール

- ✅ **Log Analytics**: クラスター監視
- ✅ **Container Insights**: コンテナメトリクス
- ✅ **Activity Logs**: Azure操作ログ

#### 3. CI/CDセキュリティ

- ✅ **Wiz CLI**: IaCスキャン (Bicep)
- ✅ **Trivy**: コンテナイメージスキャン
- ✅ **SARIF Upload**: セキュリティレポート

### 意図的な脆弱性 (デモ用)

以下は**Wiz課題要件**に従った意図的な脆弱性設定です:

#### 🔴 Critical

1. **MongoDB VM - パブリックSSHアクセス**
   - ポート22がインターネットに公開
   - NSGルールで `Source: *` を許可

2. **Storage Account - Public Access**
   - MongoDBバックアップが公開閲覧可能
   - 公開リスト可能

3. **過剰なクラウド権限**
   - VMに対してVM作成権限を付与
   - 最小権限の原則に違反

#### 🟡 High

4. **古いソフトウェアバージョン**
   - MongoDB 4.4 (1年以上古い)
   - Ubuntu 20.04 LTS (1年以上古い)

5. **Kubernetes - 過剰なRBAC権限**
   - アプリコンテナにクラスタ管理者権限
   - `rbac-vulnerable.yaml` で設定

### セキュリティスキャン結果

#### Wiz CLI (IaC)

- スキャン対象: Bicepファイル
- 検出: 設計上の脆弱性
- レポート: GitHub Actions Annotations

#### Trivy (コンテナ)

- スキャン対象: Dockerイメージ
- 検出: 依存関係の脆弱性
- 重要度: CRITICAL, HIGH
- レポート: SARIF形式でGitHub Security

---

## 確認コマンド集

### Azure リソース確認

```bash
# サブスクリプション確認
az account show

# リソースグループ確認
az group show --name rg-wiz-exercise

# 全リソース一覧
az resource list --resource-group rg-wiz-exercise --output table

# AKS詳細
az aks show --resource-group rg-wiz-exercise --name aks-wiz-dev

# VM詳細
az vm show --resource-group rg-wiz-exercise --name vm-mongo-dev

# ACR詳細
az acr show --name acrwizdev
```

### Kubernetes 確認

```bash
# クラスター接続
az aks get-credentials --resource-group rg-wiz-exercise --name aks-wiz-dev

# ノード確認
kubectl get nodes -o wide

# Pod確認
kubectl get pods --all-namespaces

# Service確認
kubectl get svc --all-namespaces

# Ingress確認
kubectl get ingress

# リソース使用状況
kubectl top nodes
kubectl top pods
```

### アプリケーション確認

```bash
# アプリPod確認
kubectl get pods -l app=guestbook

# ログ確認
kubectl logs -l app=guestbook --tail=100

# Pod詳細
kubectl describe pod -l app=guestbook

# アプリ動作確認
curl http://20.18.117.80/health
```

### MongoDB 確認

```bash
# VM接続
ssh azureuser@172.192.25.0

# MongoDB状態
sudo systemctl status mongod

# ログ確認
sudo tail -f /var/log/mongodb/mongod.log

# データベース確認
mongo --host localhost --port 27017
> show dbs
> use guestbook
> db.messages.find()
```

---

## トラブルシューティング

### よくある問題と解決方法

#### 1. Podが起動しない

```bash
# Pod状態確認
kubectl get pods -l app=guestbook

# 詳細ログ
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# イベント確認
kubectl get events --sort-by='.lastTimestamp'
```

#### 2. アプリにアクセスできない

```bash
# Ingress確認
kubectl get ingress
kubectl describe ingress guestbook-ingress

# Service確認
kubectl get svc
kubectl get endpoints

# LoadBalancer IP確認
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

#### 3. MongoDBに接続できない

```bash
# VM確認
az vm show --resource-group rg-wiz-exercise --name vm-mongo-dev
az vm get-instance-view --resource-group rg-wiz-exercise --name vm-mongo-dev

# ネットワーク確認
az network nsg rule list --resource-group rg-wiz-exercise --nsg-name vm-mongo-dev-nsg

# Pod内から接続テスト
kubectl exec -it <pod-name> -- curl -v telnet://10.0.2.4:27017
```

---

## 関連ドキュメント

- [AZURE_SETUP_INFO.md](./AZURE_SETUP_INFO.md) - Azure初期セットアップ情報
- [../Docs_work_history/](../Docs_work_history/) - 作業履歴
- [../Docs_issue_point/](../Docs_issue_point/) - トラブルシューティング
- [../README.md](../README.md) - プロジェクト概要

---

**最終更新**: 2025年10月29日  
**管理者**: Wiz Technical Exercise Team  
**ステータス**: ✅ Production Ready
