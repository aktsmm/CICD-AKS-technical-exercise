# Wiz Technical Exercise - 要件充足チェックリスト

**作成日**: 2025 年 10 月 31 日  
**プロジェクト**: CICD-AKS-Technical Exercise

<!-- markdownlint-disable MD033 -->

---

## ✅ 要件充足状況サマリー

| カテゴリ                           | 必須項目数 | 充足数 | 達成率  | ステータス                 |
| ---------------------------------- | ---------- | ------ | ------- | -------------------------- |
| **Web アプリ (Kubernetes)**        | 6          | 6      | 100%    | ✅ 完了                    |
| **DB サーバ (MongoDB VM)**         | 7          | 7      | 100%    | ✅ 完了                    |
| **Dev(Sec)Ops**                    | 6          | 5      | 83%     | ⚠️ 3-6 (オプション) 未実施 |
| **クラウドネイティブセキュリティ** | 4          | 4      | 100%    | ✅ 完了                    |
| **総合**                           | **23**     | **22** | **96%** | 🚧 攻撃ログ整備のみ未着手  |

備考:

- 3-6 は攻撃検証ログの整備（任意要件）。

---

## 📋 詳細チェックリスト

### 🏗️ 1. Web アプリ環境構成

#### MongoDB 仮想マシン (VM)

| #   | 要件                                                            | ステータス  | 実装詳細                                                                                                                             | 検証方法                                                                        |
| --- | --------------------------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| 1.1 | ✅ OS は 1 年以上古い Linux バージョン                          | ✅ **達成** | Ubuntu 20.04 LTS (Focal Fossa)<br>`0001-com-ubuntu-server-focal`<br>`20_04-lts-gen2`                                                 | `az vm show -g rg-bbs-cicd-aks -n vm-mongo-dev`                                 |
| 1.2 | ✅ SSH ポートをパブリックに公開                                 | ✅ **達成** | NSG Rule: `Allow-SSH-Internet`<br>Priority: 100<br>Direction: Inbound<br>Source: `*` (Internet)<br>Dest Port: 22                     | `az network nsg rule list -g rg-bbs-cicd-aks --nsg-name vm-mongo-dev-nsg`       |
| 1.3 | ✅ 過剰なクラウド権限 (VM 作成可能)                             | ✅ **達成** | Managed Identity に `Contributor` (`vm-role-assignment.bicep`) と `Virtual Machine Contributor` (`vm-storage-role.bicep`) を割り当て | `infra/modules/vm-role-assignment.bicep`, `infra/modules/vm-storage-role.bicep` |
| 1.4 | ✅ MongoDB も 1 年以上古いバージョン                            | ✅ **達成** | MongoDB 4.4.x<br>インストールスクリプト: `infra/scripts/install-mongodb.sh`                                                          | `infra/scripts/install-mongodb.sh`                                              |
| 1.5 | ✅ MongoDB へのアクセスは Kubernetes ネットワーク内からのみ許可 | ✅ **達成** | NSG Rule: `Allow-MongoDB`<br>Priority: 110<br>Source: `10.0.0.0/16` (VNet 全体)<br>Dest Port: 27017                                  | NSG Rule 確認済み                                                               |
| 1.6 | ✅ MongoDB は認証を必須化                                       | ✅ **達成** | Admin User: `mongoadmin`<br>Password: GitHub Secrets (`MONGO_ADMIN_PASSWORD`)<br>Setup Script: `infra/scripts/setup-mongodb-auth.sh` | `infra/scripts/setup-mongodb-auth.sh`                                           |
| 1.7 | ✅ デイリーバックアップをクラウドストレージに保存               | ✅ **達成** | Cron Job: 毎日 2:00 AM JST<br>Backup Script: `setup-backup.sh`<br>保存先: Storage Account `backups` container                        | VM Extension CustomScript で設定                                                |
| 1.8 | ✅ バックアップ先のストレージは公開閲覧・公開リスト可能         | ✅ **達成** | Storage Account:<br>`allowBlobPublicAccess: true`<br>Container Public Access: `Blob` (Read)                                          | `az storage account show --query "allowBlobPublicAccess"` → `true`              |

#### Kubernetes 上の Web アプリケーション

| #   | 要件                                                               | ステータス  | 実装詳細                                                                                                                 | 検証方法                                                           |
| --- | ------------------------------------------------------------------ | ----------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| 2.1 | ✅ アプリはコンテナ化され、MongoDB を使用                          | ✅ **達成** | Node.js + Express.js<br>MongoDB Client 接続<br>Dockerfile: `app/Dockerfile`                                              | `app/app.js` (L17-28)                                              |
| 2.2 | ✅ Kubernetes クラスタはプライベートサブネットに配置               | ✅ **達成** | AKS Subnet: `aks-subnet`<br>CIDR: `10.0.1.0/24`<br>Type: Private (Internal VNet)                                         | `infra/modules/vnet.bicep`                                         |
| 2.3 | ✅ MongoDB への接続情報は環境変数で指定                            | ✅ **達成** | `mongo-credentials` Secret の `uri` を `secretKeyRef` で読み込み、`PORT` はマニフェストで固定                         | `app/k8s/deployment.yaml`、`.github/workflows/app-deploy.yml`      |
| 2.4 | ✅ コンテナ内に wizexercise.txt (氏名を記載) を含める              | ✅ **達成** | ファイル: `/app/wizexercise.txt`<br>氏名: yamapan<br>Dockerfile で `COPY wizexercise.txt /app/`                          | `kubectl exec -- test -f /app/wizexercise.txt` → ✅ exists         |
| 2.5 | ✅ コンテナにクラスタ管理者権限 (admin role) を付与                | ✅ **達成** | ClusterRoleBinding: `developer-cluster-admin`<br>ServiceAccount: `default` (namespace: default)<br>Role: `cluster-admin` | `kubectl get clusterrolebinding developer-cluster-admin` → ✅ 存在 |
| 2.6 | ✅ Ingress + LB で公開 (HTTP/HTTPS)                                | ✅ **達成** | NGINX Ingress Controller + Azure Load Balancer。Ingress IP は CI 実行時に取得し `nip.io` ドメインで TLS を構成           | `kubectl get svc -n ingress-nginx`、Actions `Deploy to AKS` ログ   |
| 2.7 | ✅ kubectl コマンドによる操作をデモ可能にする                      | ✅ **達成** | `az aks command invoke` で制御プレーン経由の `kubectl` を実行し、Pod 操作 (`kubectl logs`, `kubectl get pods`) を確認     | `az aks command invoke` の実行ログ                                  |
| 2.8 | ✅ Web アプリで入力したデータが MongoDB に保存されていることを証明 | ✅ **達成** | BBS App 動作確認:<br>1. メッセージ投稿<br>2. MongoDB に保存<br>3. リロードで表示確認<br>Collection: `messages`           | ブラウザ + MongoDB 接続で検証可能                                  |

---

### ⚙️ 2. Dev(Sec)Ops 要件

| #   | 要件                                                                      | ステータス    | 実装詳細                                                                                                                               | 検証方法                                                                 |
| --- | ------------------------------------------------------------------------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| 3.1 | ✅ コードと構成を VCS (GitHub) に保存                                     | ✅ **達成**   | GitHub Repository:<br>[aktsmm/CICD-AKS-technical-exercise](https://github.com/aktsmm/CICD-AKS-technical-exercise)<br>Branch: `main`<br>Commit 履歴: 50+ commits | GitHub リポジトリアクセス                                                   |
| 3.2 | ✅ IaC による安全なデプロイ (CI/CD パイプライン 1)                        | ✅ **達成**   | GitHub Actions Workflow:<br>`.github/workflows/infra-deploy.yml`<br>Bicep Templates: `infra/main.bicep`                                | Workflow 実行履歴確認                                                    |
| 3.3 | ✅ コンテナのビルド＆レジストリ登録 → 自動デプロイ (CI/CD パイプライン 2) | ✅ **達成**   | GitHub Actions Workflow:<br>`.github/workflows/app-deploy.yml`<br>ACR Push を実行                                                      | Workflow 実行履歴確認                                                    |
| 3.4 | ✅ AKS への自動デプロイ                                                   | ✅ **達成**   | 同ワークフローの `Deploy to AKS` ジョブが `az aks command invoke` を用いてマニフェストを適用し、ロールアウトを監視                     | `.github/workflows/app-deploy.yml` の `deploy-aks` ジョブ                |
| 3.5 | ✅ パイプライン内にセキュリティスキャン (IaC・コンテナ) を実装            | ✅ **達成**   | **IaC Scan**: Checkov + Trivy Config (`infra-deploy.yml`)<br>**Container Scan**: Trivy + CodeQL (`app-deploy.yml`)<br>SARIF を GitHub Security に公開 | `.github/workflows/infra-deploy.yml`、`.github/workflows/app-deploy.yml` |
| 3.6 | ❌ 攻撃シナリオのログ/スクリプト化 (オプション)                           | ❌ **未実施** | Wiz の検出検証ログや疑似攻撃スクリプトをリポジトリにはまだ追加していない                                                               | `Docs_issue_point/` 等への追記が必要                                     |

---

### ☁️ 3. クラウドネイティブセキュリティ

| #   | 要件                                    | ステータス    | 実装詳細                                                                                      | 検証方法                                                                      |
| --- | --------------------------------------- | ------------- | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| 4.1 | ✅ クラウド制御プレーン監査ログを有効化 | ✅ **達成**   | Log Analytics Workspace: `log-dev`<br>Resource Group: `rg-bbs-cicd-aks`<br>AKS 診断設定有効化 | `az resource list --resource-type "Microsoft.OperationalInsights/workspaces"` |
| 4.2 | ✅ 予防的コントロールを 1 つ以上設定    | ✅ **達成**   | Azure Policy イニシアチブ (MCSB/CIS) を Audit 割当し、意図的な脆弱構成を観測モードで可視化    | `.github/workflows/policy-guardrails.yml`、`infra/policy-guardrails.bicep`    |
| 4.3 | ✅ 検知的コントロールを 1 つ以上設定    | ✅ **達成**   | Defender for Cloud Standard プランを Bicep で有効化し、アクティビティログを Log Analytics へ送信                         | `az security pricing list`、`az monitor diagnostic-settings list`             |

---

### 🎤 4. プレゼンテーション準備

| #   | 要件                                | ステータス  | 実装詳細                                                                                                                                | 検証方法               |
| --- | ----------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| 5.1 | ✅ 45 分デモンストレーション準備    | ✅ **達成** | デモ手順書: `docs/DEMO_PROCEDURE.md`<br>セクション構成:<br>- 環境構築 (10 分)<br>- アプリデモ (15 分)<br>- セキュリティデモ (20 分)     | デモ手順書確認         |
| 5.2 | ✅ スライド準備 (Architecture 等)   | ✅ **達成** | Architecture 図:<br>- README.md (システム構成図)<br>- CI/CD フロー図<br>- ネットワーク構成図                                            | `README.md` (L24-92)   |
| 5.3 | ✅ 実装方法・課題・解決策の説明準備 | ✅ **達成** | ドキュメント:<br>- `docs/ENVIRONMENT_INFO.md`<br>- `Docs_issue_point/*.md` (21 フェーズの記録)<br>- `Docs_work_history/*.md` (作業履歴) | 全ドキュメント確認済み |

---

## 🎯 実装済み脆弱性 (意図的なセキュリティリスク)

### 脆弱性マトリクス

| カテゴリ    | 脆弱性                                     | リスクレベル | 検証方法                                                           |
| ----------- | ------------------------------------------ | ------------ | ------------------------------------------------------------------ |
| **AKS**     | Cluster Admin 権限の不適切な付与           | 🔴 HIGH      | `kubectl get clusterrolebinding developer-cluster-admin`           |
| **VM**      | SSH Port 22 のインターネット公開           | 🔴 HIGH      | `az network nsg rule show --name Allow-SSH-Internet`               |
| **VM**      | 古い OS (Ubuntu 20.04 LTS)                 | 🟡 MEDIUM    | `az vm show --query "storageProfile.imageReference"`               |
| **VM**      | 過剰なクラウド権限 (VM 作成可能)           | 🔴 HIGH      | Managed Identity + `Virtual Machine Contributor` Role              |
| **MongoDB** | 古いバージョン (MongoDB 4.4)               | 🟡 MEDIUM    | VM 内で `mongod --version`                                         |
| **Network** | MongoDB アクセス制限が広範                 | 🟡 MEDIUM    | NSG Rule: Source `10.0.0.0/16` (VNet 全体)                         |
| **Storage** | Public Blob Access 有効 (バックアップ公開) | 🔴 HIGH      | `az storage account show --query "allowBlobPublicAccess"` → `true` |

### 総リスクスコア

- **HIGH**: 4 項目 🔴🔴🔴🔴
- **MEDIUM**: 3 項目 🟡🟡🟡
- **LOW**: 0 項目

---

## 📊 技術スタック

### インフラストラクチャ

| 技術              | バージョン/設定                        | 用途                         |
| ----------------- | -------------------------------------- | ---------------------------- |
| **Azure**         | Subscription: Visual Studio Enterprise | クラウドプラットフォーム     |
| **AKS**           | Kubernetes 1.32                        | コンテナオーケストレーション |
| **Bicep**         | Latest                                 | IaC (Infrastructure as Code) |
| **Ubuntu**        | 20.04 LTS                              | MongoDB VM OS                |
| **MongoDB**       | 4.4.x                                  | データベース                 |
| **NGINX Ingress** | Latest                                 | L7 ロードバランシング        |

### アプリケーション

| 技術               | バージョン | 用途                 |
| ------------------ | ---------- | -------------------- |
| **Node.js**        | 18-alpine  | ランタイム           |
| **Express.js**     | 4.21.2     | Web フレームワーク   |
| **EJS**            | 3.1.10     | テンプレートエンジン |
| **MongoDB Client** | 6.12.0     | データベース接続     |

### DevOps / Security

| ツール             | 用途                     |
| ------------------ | ------------------------ |
| **GitHub Actions** | CI/CD パイプライン       |
| **Checkov**        | IaC セキュリティスキャン |
| **Trivy**          | コンテナ脆弱性スキャン   |
| **Azure Monitor**  | 監査ログ収集             |
| **Log Analytics**  | ログ分析                 |

---

## 🔍 検証コマンドクイックリファレンス

### Kubernetes

```bash
# Pod確認
kubectl get pods -o wide

# ClusterAdmin権限確認
kubectl get clusterrolebinding developer-cluster-admin

# wizexercise.txt確認
kubectl exec -it $(kubectl get pod -l app=guestbook -o jsonpath='{.items[0].metadata.name}') -- cat /app/wizexercise.txt

# Ingress確認
kubectl get ingress
kubectl get svc -n ingress-nginx
```

### Azure

```bash
# Storage Public Access確認
az storage account show -n <STORAGE_NAME> -g rg-bbs-cicd-aks --query "allowBlobPublicAccess"

# NSG Rules確認
az network nsg rule list -g rg-bbs-cicd-aks --nsg-name vm-mongo-dev-nsg -o table

# VM OS情報確認
az vm show -g rg-bbs-cicd-aks -n vm-mongo-dev --query "storageProfile.imageReference"

# Log Analytics確認
az resource list -g rg-bbs-cicd-aks --resource-type "Microsoft.OperationalInsights/workspaces"
```

---

## ✅ 結論

### 達成状況

### 達成サマリー (22/23 = 96%)

- ✅ Web アプリ (Kubernetes): 6/6
- ✅ DB サーバ (MongoDB VM): 7/7
- ⚠️ Dev(Sec)Ops: 5/6 (3-6 の攻撃検証ログ整備が未実施)
- ✅ クラウドネイティブセキュリティ: 4/4

### 実装の特徴

1. **完全自動化**: Bicep + GitHub Actions による IaC / アプリ / Policy デプロイを一元化
2. **脆弱性デモの再現性**: Dockerfile・Bicep・ワークフローで意図的リスクをコード化
3. **多層セキュリティスキャン**: Checkov / Trivy / CodeQL をパイプラインに統合
4. **監査ログ整備**: Log Analytics + 診断設定で AKS / VM / ACR / NSG の操作を可視化
5. **豊富なドキュメンテーション**: 環境情報・デモ手順・チェックリストをリポジトリで管理

### 次に取り組むとよい項目

- 4-3: Defender for Cloud プラン有効化とカスタム アラートの整備
- 3-6: Wiz 攻撃検証ログや疑似攻撃スクリプトを `Docs_issue_point/` に追加

---

プレゼンテーション資料・デモ手順は整備済みのため、上記未実施項目を補完すれば「全要件達成」を宣言できます。 �
