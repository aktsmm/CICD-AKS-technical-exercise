# Wiz Technical Exercise - デモンストレーション手順書

<!-- markdownlint-disable MD001 MD022 MD024 MD031 MD032 MD034 MD040 -->

### 3.1 AKS 接続

```powershell
# AKS 操作 (プライベート API のため az aks command invoke を使用)
**構成要素**:
  --resource-group rg-bbs-cicd-aks `
  --name aks-dev `
  --command "kubectl get nodes -o wide" `
  --query "logs" -o tsv
```

### 3.2 ✅ アプリはコンテナ化され、MongoDB を使用

```powershell
# Pod確認
az aks command invoke `
  --resource-group rg-bbs-cicd-aks `
  --name aks-dev `
  --command "kubectl get pods -l app=guestbook -o wide" `
  --query "logs" -o tsv

# Pod詳細確認 (MongoDB接続情報)

  --resource-group rg-bbs-cicd-aks `
  --name aks-dev `
  --command "kubectl describe pod -l app=guestbook" `
  --query "logs" -o tsv | Select-String -Pattern "MONGO_URI"
```

**期待される出力**:

```
NAME                             READY   STATUS    RESTARTS   AGE   IP
guestbook-app-xxxxx              1/1     Running   0          30m   10.0.1.38
guestbook-app-yyyyy              1/1     Running   0          30m   10.0.1.16

Environment:
  MONGO_URI: mongodb://mongoadmin:***@10.0.2.x:27017/guestbook?authSource=admin
```

**アプリログ確認**:

```powershell
az aks command invoke `
  --resource-group rg-bbs-cicd-aks `
  --name aks-dev `
  --command "kubectl logs -l app=guestbook --tail=5" `
  --query "logs" -o tsv
```

**期待される出力**:

```
🚀 Server running on port 3000
✅ MongoDB接続成功
```

**説明**: Node.js アプリがコンテナ化され、MongoDB 接続成功 ✅

- Azure Kubernetes Service (AKS) - 2 nodes
- MongoDB VM (Ubuntu 20.04)
- Azure Blob Storage (バックアップ用)
- Azure Container Registry
- NGINX Ingress Controller

### 1.2 リソースグループ確認

```powershell
# リソースグループ一覧
az group list --query "[?starts_with(name, 'rg-bbs-cicd-aks')].{Name:name, Location:location, State:properties.provisioningState}" -o table

# 期待される出力
# Name                 Location   State
# rg-bbs-cicd-aks  japaneast  Succeeded
```

### 1.3 GitHub リポジトリ紹介

**URL**: https://github.com/aktsmm/CICD-AKS-technical-exercise

**構成**:

- `/infra` - Bicep IaC コード
- `/app` - Node.js アプリケーション + Kubernetes マニフェスト
- `/pipelines` - GitHub Actions ワークフロー
- `/docs` - ドキュメント

---

## 2. MongoDB VM 要件デモ (10 分)

### 2.1 ✅ OS は 1 年以上古い Linux バージョン

```powershell
# VM OS情報確認
az vm show -g rg-bbs-cicd-aks -n vm-mongo-dev --query "storageProfile.imageReference" -o json
```

**期待される出力**:

```json
{
  "offer": "0001-com-ubuntu-server-focal",
  "publisher": "Canonical",
  "sku": "20_04-lts-gen2",
  "version": "latest"
}
```

**説明**: Ubuntu 20.04 LTS (2020 年 4 月リリース) - 1 年以上古いバージョン ✅

### 2.2 ✅ SSH ポートをパブリックに公開

```powershell
# パブリックIP確認
az network public-ip show -g rg-bbs-cicd-aks -n vm-mongo-dev-pip --query "{IP:ipAddress, Method:publicIPAllocationMethod}" -o json

# NSGルール確認
az network nsg rule show -g rg-bbs-cicd-aks --nsg-name nsg-mongo-dev -n allow-ssh --query "{Priority:priority, Direction:direction, Access:access, Protocol:protocol, DestinationPortRange:destinationPortRange, SourceAddressPrefix:sourceAddressPrefix}" -o json
```

**期待される出力**:

```json
// Public IP
{
  "IP": "<MONGO_PUBLIC_IP>",
  "Method": "Static"
}

// NSG Rule
{
  "Priority": 100,
  "Direction": "Inbound",
  "Access": "Allow",
  "Protocol": "Tcp",
  "DestinationPortRange": "22",
  "SourceAddressPrefix": "*"
}
```

**説明**: SSH ポート 22 がインターネット全体に公開 ⚠️ (意図的な脆弱性)

### 2.3 ✅ 過剰なクラウド権限 (VM 作成可能)

```powershell
# Managed Identity確認
az vm identity show -g rg-bbs-cicd-aks -n vm-mongo-dev --query "principalId" -o tsv

# ロール割り当て確認
az role assignment list --assignee <PRINCIPAL_ID> --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
```

**期待される出力**:

```
Role         Scope
-----------  --------------------------------------------------------
Contributor  /subscriptions/832c4080-181c-476b-9db0-b3ce9596d40a/...
```

**説明**: Contributor ロールにより VM 作成・削除が可能 ⚠️ (過剰権限)

### 2.4 ✅ MongoDB 1 年以上古いバージョン

```powershell
# MongoDB バージョン確認
az vm run-command invoke -g rg-bbs-cicd-aks -n vm-mongo-dev --command-id RunShellScript --scripts "mongod --version | head -3"
```

**期待される出力**:

```
db version v4.4.29
Build Info: {
    "version": "4.4.29"
```

**説明**: MongoDB 4.4.29 (2024 年以前) - 1 年以上古いバージョン ✅

### 2.5 ✅ MongoDB へのアクセスは Kubernetes ネットワーク内からのみ

```powershell
# MongoDB NSG確認
az network nsg rule list -g rg-bbs-cicd-aks --nsg-name nsg-mongo-dev --query "[?destinationPortRange=='27017'].{Name:name, Priority:priority, SourceAddressPrefix:sourceAddressPrefix, Access:access}" -o table
```

**期待される出力**:

```
Name              Priority  SourceAddressPrefix  Access
--------------    --------  -------------------  ------
allow-mongodb-aks  110      10.0.1.0/24          Allow
```

**説明**: AKS Subnet (10.0.1.0/24) からのみアクセス可能 ✅

### 2.6 ✅ MongoDB は認証を必須化

```powershell
# MongoDB認証設定確認
az vm run-command invoke -g rg-bbs-cicd-aks -n vm-mongo-dev --command-id RunShellScript --scripts "grep -A 2 '^security:' /etc/mongod.conf"
```

**期待される出力**:

```
security:
  authorization: enabled
```

**認証テスト**:

```powershell
# 認証なしでアクセス (失敗するはず)
az vm run-command invoke -g rg-bbs-cicd-aks -n vm-mongo-dev --command-id RunShellScript --scripts "mongo admin --eval 'db.getUsers()'"

# 認証ありでアクセス (成功するはず)
az vm run-command invoke -g rg-bbs-cicd-aks -n vm-mongo-dev --command-id RunShellScript --scripts "mongo admin -u mongoadmin -p <PASSWORD> --eval 'db.getUsers()'"
```

**説明**: 認証必須で、mongoadmin ユーザーのみアクセス可能 ✅

### 2.7 ✅ デイリーバックアップをクラウドストレージに保存

```powershell
# Cron設定確認
az vm run-command invoke -g rg-bbs-cicd-aks -n vm-mongo-dev --command-id RunShellScript --scripts "crontab -l | grep mongodb-backup"
```

**期待される出力**:

```
0 2 * * * /usr/local/bin/mongodb-backup.sh >> /var/log/mongodb-backup.log 2>&1
```

**バックアップファイル確認**:

```powershell
# Blob Storage内のバックアップ一覧
az storage blob list --account-name stwizdevj2axc7dgverlk --container-name backups --query "[].{Name:name, Size:properties.contentLength, Modified:properties.lastModified}" -o table --auth-mode login
```

**期待される出力**:

```
Name                                   Size  Modified
-------------------------------------  ----  -------------------------
mongodb_backup_20251030_165815.tar.gz  1207  2025-10-30T16:58:17+00:00
```

**説明**: 毎日午前 2 時にバックアップ実行、Azure Blob Storage に保存 ✅

### 2.8 ✅ バックアップ先のストレージは公開閲覧可能

```powershell
# コンテナの公開設定確認
az storage container show --name backups --account-name stwizdevj2axc7dgverlk --auth-mode login --query "properties.publicAccess" -o tsv
```

**期待される出力**:

```
blob
```

**公開 URL 確認**:

```powershell
az storage blob url --account-name stwizdevj2axc7dgverlk --container-name backups --name mongodb_backup_20251030_165815.tar.gz --auth-mode login -o tsv
```

**期待される出力**:

```
https://stwizdevj2axc7dgverlk.blob.core.windows.net/backups/mongodb_backup_20251030_165815.tar.gz
```

**ブラウザでアクセスデモ**:

```powershell
Start-Process "https://stwizdevj2axc7dgverlk.blob.core.windows.net/backups/mongodb_backup_20251030_165815.tar.gz"
```

**説明**: 認証なしでバックアップファイルをダウンロード可能 ⚠️ (意図的な脆弱性)

---

## 3. Kubernetes アプリケーション要件デモ (10 分)

### 3.1 AKS 接続

```powershell
# AKS認証情報取得
az aks get-credentials --resource-group rg-bbs-cicd-aks --name aks-dev --overwrite-existing
```

### 3.2 ✅ アプリはコンテナ化され、MongoDB を使用

```powershell
# Pod確認
kubectl get pods -o wide

# Pod詳細確認 (MongoDB接続情報)
kubectl describe pod -l app=guestbook | Select-String -Pattern "MONGO_URI"
```

**期待される出力**:

```
NAME                             READY   STATUS    RESTARTS   AGE   IP
guestbook-app-846cb958c8-277xt   1/1     Running   0          30m   10.0.1.38
guestbook-app-846cb958c8-z2qmf   1/1     Running   0          30m   10.0.1.16

Environment:
  MONGO_URI: mongodb://mongoadmin:***@10.0.2.4:27017/guestbook?authSource=admin
```

**アプリログ確認**:

```powershell
kubectl logs -l app=guestbook --tail=5
```

**期待される出力**:

```
🚀 Server running on port 3000
✅ MongoDB接続成功
```

**説明**: Node.js アプリがコンテナ化され、MongoDB 接続成功 ✅

### 3.3 ✅ Kubernetes クラスタはプライベートサブネットに配置

```powershell
# AKS Subnet確認
az aks show -g rg-bbs-cicd-aks -n aks-dev --query "agentPoolProfiles[0].vnetSubnetId" -o tsv

# Subnet詳細確認
az network vnet subnet show --ids <SUBNET_ID> --query "{Name:name, AddressPrefix:addressPrefix}" -o json
```

**期待される出力**:

```json
{
  "Name": "snet-aks",
  "AddressPrefix": "10.0.1.0/24"
}
```

**説明**: AKS ノードはプライベートサブネット (10.0.1.0/24) に配置 ✅

### 3.4 ✅ MongoDB への接続情報は環境変数で指定

```powershell
# Deployment YAML確認
kubectl get deployment guestbook-app -o yaml | Select-String -Pattern "env:" -Context 0,10
```

**期待される出力**:

```yaml
env:
  - name: MONGO_URI
    valueFrom:
      secretKeyRef:
        name: mongo-credentials
        key: uri
  - name: PORT
    value: "3000"
```

**説明**: MongoDB 接続情報は Kubernetes Secret から環境変数として注入 ✅

### 3.5 ✅ コンテナ内に wizexercise.txt (氏名を記載)

```powershell
# Pod名取得
$POD_NAME = kubectl get pod -l app=guestbook -o jsonpath='{.items[0].metadata.name}'

# ファイル存在確認
kubectl exec -it $POD_NAME -- cat /app/wizexercise.txt
```

**期待される出力**:

```
氏名: やまもとたつみ
日付: 2025-10-28
CICD-AKS-Technical Exercise

===================================
このファイルへのアクセス方法:
===================================
...
```

**ブラウザからも直接アクセス可能**:

```powershell
# ブラウザで直接開く
Start-Process "http://<INGRESS_IP>/wizexercise.txt"
```

**または curl で確認**:

```powershell
# PowerShellから確認
Invoke-WebRequest -Uri "http://<INGRESS_IP>/wizexercise.txt" | Select-Object -ExpandProperty Content
```

**どのように挿入したか説明**:

1. **Dockerfile 内で COPY 命令**:
   ```dockerfile
   COPY wizexercise.txt /app/wizexercise.txt
   ```
2. **ビルド時に含まれる**: Docker build プロセスで自動的にイメージに含まれる
3. **Pod 起動時に存在**: コンテナ起動時には既にファイルが存在
4. **Express.js でエンドポイント公開**: `/wizexercise.txt` ルートでブラウザからアクセス可能

**説明**: wizexercise.txt がコンテナ内に存在し、氏名が記載されている。kubectl コマンドまたはブラウザから確認可能 ✅

### 3.6 ✅ コンテナにクラスタ管理者権限 (admin role)

```powershell
# ServiceAccount確認
kubectl get serviceaccount default -o yaml

# ClusterRoleBinding確認
kubectl get clusterrolebinding cluster-admin-binding -o yaml

# 権限テスト
kubectl auth can-i --list --as=system:serviceaccount:default:default | Select-String -Pattern "\*\.\*"
```

**期待される出力**:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: default
    namespace: default
```

**説明**: default ServiceAccount に cluster-admin 権限が付与 ⚠️ (意図的な過剰権限)

### 3.7 ✅ Ingress + ロードバランサで公開

```powershell
# Ingress確認
kubectl get ingress guestbook-ingress -o wide

# NGINX Ingress Controller確認
kubectl get svc -n ingress-nginx
```

**期待される出力**:

```
NAME                CLASS   HOSTS   ADDRESS     PORTS   AGE
guestbook-ingress   nginx   *       10.0.1.33   80      45m

NAME                       TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
ingress-nginx-controller   LoadBalancer   10.1.204.250   <INGRESS_IP>     80:30470/TCP,443:31963/TCP
```

**ブラウザでアクセスデモ**:

```powershell
Start-Process "http://<INGRESS_IP>"
```

**説明**: NGINX Ingress 経由で Azure Load Balancer から公開 ✅

### 3.8 ✅ kubectl コマンドによる操作をデモ可能

**リアルタイムデモ**:

```powershell
# Pod一覧
kubectl get pods

# Podスケール
kubectl scale deployment guestbook-app --replicas=3

# 確認
kubectl get pods -w

# 元に戻す
kubectl scale deployment guestbook-app --replicas=2
```

**説明**: kubectl による完全な操作が可能 ✅

### 3.9 ✅ Web アプリで入力したデータが MongoDB に保存されている

**Web アプリでメッセージ投稿**:

1. http://<INGRESS_IP> にアクセス
2. 名前とメッセージを入力して送信
3. 画面に表示されることを確認

**MongoDB で直接確認**:

```powershell
az vm run-command invoke -g rg-bbs-cicd-aks -n vm-mongo-dev --command-id RunShellScript --scripts "mongo guestbook -u mongoadmin -p <PASSWORD> --authenticationDatabase admin --eval 'db.messages.find().pretty()'"
```

**期待される出力**:

```javascript
{
    "_id": ObjectId("69039710d078193ee7d311be"),
    "name": "おち",
    "message": "ん",
    "createdAt": ISODate("2025-10-30T16:49:20.569Z")
}
{
    "_id": ObjectId("69039713d078193ee7d311c0"),
    "name": "くろの",
    "message": "おっぱi",
    "createdAt": ISODate("2025-10-30T16:49:23.650Z")
}
{
    "_id": ObjectId("690397b9d078193ee7d311c6"),
    "name": "bi",
    "message": "cep",
    "createdAt": ISODate("2025-10-30T16:52:09.554Z")
}
```

**説明**: Web アプリから投稿したデータが MongoDB に正しく保存されている ✅

---

## 4. DevSecOps 要件デモ (10 分)

### 4.1 ✅ コードと構成を GitHub に保存

**リポジトリ URL**: https://github.com/aktsmm/CICD-AKS-technical-exercise

**ブランチ確認**:

```powershell
cd d:\00_temp\wizwork\wiz-technical-exercise
git branch -a
git log --oneline -10
```

**期待される出力**:

```
* main
  remotes/origin/main

282f8c9 refactor: Simplify MongoDB auth setup with logging
968341e fix: Add missing newline before else statement
24fe747 fix: Fix syntax error in MongoDB readiness check loop
dabe689 feat: Add error handling and exit on MongoDB setup failures
4be92de feat: Add MongoDB readiness check before operations
```

**説明**: 全てのコードが GitHub で管理され、変更履歴が追跡可能 ✅

### 4.2 ✅ IaC (Infrastructure as Code) による安全なデプロイ

**Bicep コード紹介**:

```powershell
# Bicepファイル一覧
Get-ChildItem -Path infra -Filter *.bicep -Recurse | Select-Object Name, FullName
```

**期待される出力**:

```
Name              FullName
----              --------
main.bicep        d:\...\infra\main.bicep
vnet.bicep        d:\...\infra\modules\vnet.bicep
aks.bicep         d:\...\infra\modules\aks.bicep
vm-mongodb.bicep  d:\...\infra\modules\vm-mongodb.bicep
storage.bicep     d:\...\infra\modules\storage.bicep
```

**GitHub Actions ワークフロー確認**:

```powershell
cat .github/workflows/01.infra-deploy.yml | Select-String -Pattern "name:|uses:|run:" | Select-Object -First 20
```

**期待される出力**:

```yaml
name: Infrastructure Deploy
uses: actions/checkout@v3
uses: azure/login@v1
run: az deployment sub create ...
```

**デプロイ履歴確認**:

```powershell
Start-Process "https://github.com/aktsmm/CICD-AKS-technical-exercise/actions/workflows/01.infra-deploy.yml"
```

**説明**: Bicep による IaC と、GitHub Actions による自動デプロイを実装 ✅

### 4.3 ✅ コンテナのビルド＆レジストリ登録 → 自動デプロイ

**GitHub Actions ワークフロー確認**:

```powershell
cat .github/workflows/02-1.app-deploy.yml | Select-String -Pattern "name:|uses:|run:" | Select-Object -First 25
```

**期待される出力**:

```yaml
name: Application Deploy
uses: actions/checkout@v3
uses: azure/docker-login@v1
run: docker build -t ${{ env.ACR_NAME }}.azurecr.io/guestbook-app:${{ github.sha }} .
run: docker push ${{ env.ACR_NAME }}.azurecr.io/guestbook-app:${{ github.sha }}
run: kubectl set image deployment/guestbook-app ...
```

**Azure Container Registry 確認**:

```powershell
# ACR名取得
$ACR_NAME = az acr list -g rg-bbs-cicd-aks --query "[0].name" -o tsv

# イメージ一覧
az acr repository list --name $ACR_NAME -o table
az acr repository show-tags --name $ACR_NAME --repository guestbook-app --orderby time_desc --output table
```

**期待される出力**:

```
Result
----------
guestbook-app

Tag                                       CreatedTime
----------------------------------------  -------------------------
968341ea1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e  2025-10-30T16:45:23Z
24fe747b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f  2025-10-30T16:30:15Z
```

**説明**: コンテナビルド →ACR 登録 →AKS デプロイが自動化 ✅

### 4.4 ⚠️ セキュリティスキャン実装 (部分実装)

**Trivy スキャン設定確認**:

```powershell
cat .github/workflows/02-1.app-deploy.yml | Select-String -Pattern "trivy" -Context 2
```

**現状**:

```yaml
# - name: Run Trivy vulnerability scanner
#   uses: aquasecurity/trivy-action@master
#   with:
#     image-ref: ${{ env.ACR_NAME }}.azurecr.io/guestbook-app:${{ github.sha }}
```

**説明**: Trivy スキャンの設定はあるがコメントアウト中 ⚠️ (有効化が必要)

**改善提案**: 本番環境では必ずセキュリティスキャンを有効化すべき

---

## 5. クラウドネイティブセキュリティデモ (5 分)

### 5.1 ✅ クラウド制御プレーン監査ログ有効化

```powershell
# Azure Activity Log確認
az monitor activity-log list --resource-group rg-bbs-cicd-aks --max-events 5 --query "[].{Time:eventTimestamp, Caller:caller, Operation:operationName.value, Status:status.value}" -o table
```

**期待される出力**:

```
Time                          Caller                    Operation                                  Status
----------------------------  ------------------------  -----------------------------------------  --------
2025-10-30T16:55:12+00:00     user@example.com          Microsoft.Compute/virtualMachines/write    Succeeded
2025-10-30T16:50:08+00:00     user@example.com          Microsoft.Network/publicIPAddresses/read   Succeeded
```

**説明**: Azure Activity Log で全ての操作が記録されている ✅

### 5.2 ⚠️ 予防的コントロール (要確認)

**ネットワークセキュリティグループ (NSG)**:

```powershell
# NSGルール一覧
az network nsg rule list -g rg-bbs-cicd-aks --nsg-name nsg-mongo-dev --query "[].{Name:name, Priority:priority, Direction:direction, Access:access, Protocol:protocol, SourcePort:sourcePortRange, DestPort:destinationPortRange, Source:sourceAddressPrefix}" -o table
```

**期待される出力**:

```
Name              Priority  Direction  Access  Protocol  SourcePort  DestPort  Source
--------------    --------  ---------  ------  --------  ----------  --------  ------
allow-ssh         100       Inbound    Allow   Tcp       *           22        *
allow-mongodb-aks 110       Inbound    Allow   Tcp       *           27017     10.0.1.0/24
```

**説明**: NSG により MongoDB アクセスを AKS Subnet に制限 ✅ (予防的コントロール)

### 5.3 ⚠️ 検知的コントロール (要確認)

**Azure Monitor / Log Analytics**:

```powershell
# Log Analytics Workspace確認
az monitor log-analytics workspace list -g rg-bbs-cicd-aks --query "[].{Name:name, Location:location, RetentionDays:retentionInDays}" -o table
```

**AKS コンテナログ確認**:

```powershell
# Container Insights有効化確認
az aks show -g rg-bbs-cicd-aks -n aks-dev --query "addonProfiles.omsagent.enabled" -o tsv
```

**説明**: Log Analytics によるログ収集・分析が可能 (検知的コントロール)

### 5.4 ⚠️ Wiz のようなセキュリティツールデモ

**脆弱性一覧**:

1. **公開された SSH ポート** → ブルートフォース攻撃のリスク
2. **過剰な Managed Identity 権限** → 水平展開のリスク
3. **公開バックアップストレージ** → データ漏洩のリスク
4. **古い OS/MongoDB バージョン** → 既知の脆弱性悪用のリスク
5. **コンテナの cluster-admin 権限** → クラスタ乗っ取りのリスク

**Wiz で検知可能な項目**:

- ✅ Internet-facing SSH port (Critical)
- ✅ Excessive cloud permissions (High)
- ✅ Public storage with sensitive data (Critical)
- ✅ Outdated software versions (Medium)
- ✅ Overprivileged Kubernetes pods (High)

**説明**: これらの脆弱性を Wiz が自動検知し、優先度付けして対応を推奨 ✅

---

## 6. 課題と解決策 (5 分)

### 6.1 直面した課題

#### 課題 1: MongoDB 認証設定スクリプトの繰り返し失敗

**問題**:

- VM Extension が冪等性を持たず、再デプロイ時にスクリプトが実行されない
- MongoDB 起動待機時間が不足し接続エラー発生
- YAML 構文エラーで MongoDB が起動失敗

**解決策**:

1. **forceUpdateTag 追加** - `utcNow()`を使用して毎回 VM Extension を再実行
2. **ポーリングループ実装** - `db.adminCommand('ping')`で起動確認、最大 60 秒待機
3. **YAML indentation 修正** - sed 置換文字列に正しいインデント (2 スペース) を明示
4. **grep pattern 改善** - 正規表現でコメント行を除外
5. **ログ出力強化** - `/var/log/mongodb-auth-setup.log`に全ログ記録

**詳細ドキュメント**: `Docs_issue_point/Phase20_MongoDB認証スクリプト修正_2025-10-31.md`

#### 課題 2: AKS Private Cluster と kubectl 接続

**問題**:

- Private AKS クラスタはパブリックエンドポイントを持たない
- ローカル PC から直接接続不可

**解決策**:

- Jump Box VM 経由でアクセス
- または Azure Bastion 使用
- 今回は開発効率優先で Public API を有効化

#### 課題 3: Ingress Controller の External IP 取得遅延

**問題**:

- NGINX Ingress Controller の LoadBalancer 作成に 5-10 分かかる
- External IP 取得前にアプリデプロイすると失敗

**解決策**:

- GitHub Actions で`kubectl wait`を使用して IP 取得を待機
- タイムアウト 600 秒設定

### 6.2 学んだベストプラクティス

1. **IaC の冪等性**: インフラコードは何度実行しても同じ結果になるべき
2. **非同期処理の待機**: サービス起動時は必ずポーリングで確認
3. **ログの重要性**: トラブルシューティングには詳細なログが不可欠
4. **セキュリティとのバランス**: 開発環境でも最小権限の原則を適用すべき
5. **CI/CD の自動化**: 手動デプロイを排除し、再現性を確保

### 6.3 本番環境への改善提案

1. **SSH 公開を制限**: 特定 IP アドレスのみ許可
2. **Managed Identity 最小権限化**: Storage アクセスのみに制限
3. **バックアップ暗号化**: Azure Blob Storage の暗号化を有効化、プライベートアクセスのみ許可
4. **OS/MongoDB アップデート**: 最新の安定バージョンに更新
5. **Kubernetes RBAC 厳格化**: Pod に必要最小限の権限のみ付与
6. **セキュリティスキャン有効化**: Trivy/Snyk を本番パイプラインに統合
7. **Private AKS Cluster**: パブリックアクセスを完全に無効化
8. **Azure Defender 有効化**: リアルタイム脅威検知

---

## 📊 要件達成サマリー

### MongoDB VM: 8/8 達成 ✅

| #   | 要件                    | 達成                   |
| --- | ----------------------- | ---------------------- |
| 1   | 1 年以上古い OS         | ✅ Ubuntu 20.04        |
| 2   | SSH 公開                | ✅ 0.0.0.0/0 から許可  |
| 3   | 過剰権限                | ✅ Contributor role    |
| 4   | 古い MongoDB            | ✅ v4.4.29             |
| 5   | AKS Subnet のみアクセス | ✅ NSG で制限          |
| 6   | 認証必須                | ✅ mongoadmin 認証     |
| 7   | デイリーバックアップ    | ✅ Cron + Blob Storage |
| 8   | 公開ストレージ          | ✅ Anonymous access    |

### Kubernetes App: 8/8 達成 ✅

| #   | 要件                   | 達成                 |
| --- | ---------------------- | -------------------- |
| 1   | コンテナ化 + MongoDB   | ✅ Docker + ACR      |
| 2   | プライベートサブネット | ✅ 10.0.1.0/24       |
| 3   | 環境変数で接続情報     | ✅ Kubernetes Secret |
| 4   | wizexercise.txt        | ✅ やまもとたつみ    |
| 5   | cluster-admin 権限     | ✅ RBAC 設定         |
| 6   | Ingress + LB           | ✅ NGINX + Azure LB  |
| 7   | kubectl 操作可能       | ✅ デモ実施          |
| 8   | データ保存証明         | ✅ MongoDB 確認済み  |

### DevSecOps: 3/4 達成 ⚠️

| #   | 要件                 | 達成                      |
| --- | -------------------- | ------------------------- |
| 1   | VCS 管理             | ✅ GitHub                 |
| 2   | IaC Pipeline         | ✅ Bicep + GitHub Actions |
| 3   | App Pipeline         | ✅ Docker + ACR + AKS     |
| 4   | セキュリティスキャン | ⚠️ コメントアウト中       |

### クラウドセキュリティ: 2/3 達成 ⚠️

| #   | 要件               | 達成                      |
| --- | ------------------ | ------------------------- |
| 1   | 監査ログ           | ✅ Azure Activity Log     |
| 2   | 予防的コントロール | ✅ NSG                    |
| 3   | 検知的コントロール | ⚠️ Log Analytics (要設定) |

**総合達成率**: 21/23 = **91.3%** 🎉

---

## 🎯 デモのポイント

1. **スライドとライブデモのバランス**: 理論 → 実演 → 考察のサイクル
2. **脆弱性の明確な説明**: 各設定がなぜ危険か、どう悪用されるかを具体的に
3. **課題解決のストーリー**: 失敗 → 分析 → 修正 → 検証のプロセスを強調
4. **Wiz の価値提案**: これらの脆弱性をどう自動検知・修正できるか
5. **質問への備え**: 技術的詳細、代替案、スケーラビリティについて準備

---

## 📝 補足資料

- **GitHub**: https://github.com/aktsmm/CICD-AKS-technical-exercise
- **アーキテクチャ図**: `docs/architecture-diagram.png`
- **トラブルシューティング**: `Docs_issue_point/Phase20_MongoDB認証スクリプト修正_2025-10-31.md`
- **Azure Portal**: リソースグループ `rg-bbs-cicd-aks`

---

**作成者**: やまもとたつみ  
**作成日**: 2025 年 10 月 31 日  
**環境**: Azure Japan East
