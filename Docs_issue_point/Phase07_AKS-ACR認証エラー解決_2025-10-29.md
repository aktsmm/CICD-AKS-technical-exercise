# Phase 07: AKS-ACR 認証エラー解決

**作成日**: 2025-10-29  
**ステータス**: ✅ 解決済み  
**カテゴリ**: コンテナレジストリ認証

---

## 🔴 問題

### エラー内容

```
Waiting for deployment "guestbook-app" rollout to finish: 0 of 2 updated replicas are available...
error: timed out waiting for the condition
Error: Process completed with exit code 1.
```

### Pod の状態

```bash
$ kubectl get pods -n default
NAME                             READY   STATUS             RESTARTS   AGE
guestbook-app-6867dbf84b-2p8zr   0/1     ImagePullBackOff   0          4m58s
guestbook-app-78996b4f4c-l97vh   0/1     ImagePullBackOff   0          6m44s
guestbook-app-78996b4f4c-wpxpt   0/1     ImagePullBackOff   0          6m44s
```

### 詳細なエラーメッセージ

```
Failed to pull image "acrwizdev.azurecr.io/guestbook:8edd399546e2808cc356e1fd28af9f4fbdaf2d3d":
failed to authorize: failed to fetch anonymous token:
unexpected status from GET request to https://acrwizdev.azurecr.io/oauth2/token?scope=repository%3Aguestbook%3Apull&service=acrwizdev.azurecr.io:
401 Unauthorized
```

---

## 🔍 原因分析

### 根本原因

**AKS の Kubelet Identity に ACR へのアクセス権限が付与されていなかった**

1. **ACR は認証が必要**

   - Azure Container Registry はプライベートレジストリ
   - イメージを pull するには認証が必要

2. **AKS のイメージ pull メカニズム**

   - Kubelet が Managed Identity を使用して ACR に認証
   - デフォルトでは権限なし

3. **ロール割り当てが未実装**
   - Infrastructure デプロイ時に ACR と AKS を作成
   - しかし、AKS → ACR の認証設定が欠落

### なぜ気づかなかったか

- ACR モジュールと AKS モジュールを個別に作成
- ロール割り当てモジュールの実装を忘れた
- App デプロイワークフローで初めてイメージ pull が実行され、エラーが発覚

---

## ✅ 解決策

### 実装: AKS-ACR ロール割り当てモジュール

**`infra/modules/aks-acr-role.bicep`**

```bicep
@description('AKS Kubelet Managed Identity の Principal ID')
param kubeletIdentityPrincipalId string

@description('ACR リソース名')
param acrName string

// ACR リソースの参照
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// AKS に ACR からイメージを pull する権限を付与
resource aksAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, kubeletIdentityPrincipalId, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: kubeletIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = aksAcrPull.id
```

### main.bicep への統合

**`infra/main.bicep`**

```bicep
// AKS に ACR からイメージを pull する権限を付与
module aksAcrRole 'modules/aks-acr-role.bicep' = {
  scope: rg
  name: 'aks-acr-role-${deploymentTimestamp}'
  params: {
    kubeletIdentityPrincipalId: aks.outputs.kubeletIdentity
    acrName: acr.outputs.acrName
  }
}
```

---

## 📊 ロール割り当ての詳細

### AcrPull ロール

| 項目              | 値                                     |
| ----------------- | -------------------------------------- |
| **ロール名**      | AcrPull                                |
| **ロール定義 ID** | `7f951dda-4ed3-4680-a7ca-43fe172d538d` |
| **権限**          | コンテナイメージの読み取り (pull) のみ |
| **スコープ**      | ACR リソース (`acrwizdev`)             |
| **割り当て先**    | AKS Kubelet Managed Identity           |

### 権限の範囲

✅ **許可される操作:**

- `docker pull` (イメージのダウンロード)
- イメージマニフェストの読み取り
- レイヤーのダウンロード

❌ **許可されない操作:**

- `docker push` (イメージのアップロード)
- イメージの削除
- ACR 設定の変更

---

## 🔄 修正後の動作フロー

### Infrastructure デプロイ時

```
1. ACR 作成 (acrwizdev)
2. AKS 作成 (aks-wiz-dev)
   └─ Kubelet Identity 自動作成
3. ロール割り当て作成
   └─ AKS Kubelet Identity → ACR (AcrPull)
```

### Application デプロイ時

```
1. Docker イメージを ACR にプッシュ
   └─ GitHub Actions が admin credentials 使用
2. kubectl apply で Deployment 作成
3. Kubelet がイメージを pull
   └─ Managed Identity で ACR に認証 ✅
4. Pod が正常起動
```

---

## 🎯 検証方法

### 1. ロール割り当ての確認

```bash
# AKS の Kubelet Identity を取得
az aks show --resource-group rg-cicd-aks-bbs --name aks-wiz-dev \
  --query identityProfile.kubeletidentity.objectId -o tsv

# ACR のロール割り当てを確認
az role assignment list --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-cicd-bbs/providers/Microsoft.ContainerRegistry/registries/acrwizdev \
  --query "[?roleDefinitionName=='AcrPull'].{Principal:principalId,Role:roleDefinitionName}"
```

### 2. イメージ Pull テスト

```bash
# 既存の Pod を削除して再作成
kubectl delete pods -n default -l app=guestbook

# Pod の状態を監視
kubectl get pods -n default -w

# イベントログを確認
kubectl describe pod -n default -l app=guestbook
```

**期待される結果:**

```
Normal  Pulling    Successfully pulled image "acrwizdev.azurecr.io/guestbook:xxx"
Normal  Pulled     Container image "acrwizdev.azurecr.io/guestbook:xxx" already present on machine
Normal  Created    Created container guestbook
Normal  Started    Started container guestbook
```

---

## 💡 ベストプラクティス

### 1. **ACR と AKS を統合する標準パターン**

```bicep
// パターン A: attach-acr を使用 (推奨)
az aks update -n aks-wiz-dev -g rg-cicd-aks-bbs --attach-acr acrwizdev

// パターン B: ロール割り当てを明示的に作成 (今回採用)
module aksAcrRole 'modules/aks-acr-role.bicep' = { ... }
```

**今回 Bicep で実装した理由:**

- Infrastructure as Code で完全に管理
- デプロイの再現性を保証
- Azure CLI コマンドの手動実行不要

### 2. **Managed Identity vs Service Principal**

| 方式                    | メリット                                 | デメリット             |
| ----------------------- | ---------------------------------------- | ---------------------- |
| **Managed Identity** ✅ | シークレット管理不要、自動ローテーション | Azure リソースのみ     |
| Service Principal       | Azure 外でも使用可能                     | シークレット管理が必要 |

**今回の選択:** Managed Identity（推奨）

### 3. **最小権限の原則**

- ✅ AcrPull: イメージの読み取りのみ
- ❌ AcrPush: 不要な書き込み権限
- ❌ Contributor: 過剰な権限

---

## 🚨 注意事項

### デプロイ順序の重要性

**誤った順序:**

```
1. App デプロイ開始
2. ACR にイメージプッシュ成功
3. kubectl apply 実行
4. ❌ イメージ pull 失敗（権限なし）
5. Infrastructure デプロイ開始（遅延）
```

**正しい順序:**

```
1. Infrastructure デプロイ（ACR, AKS, ロール割り当て）
2. App デプロイ開始
3. ACR にイメージプッシュ
4. kubectl apply 実行
5. ✅ イメージ pull 成功（権限あり）
```

**対策:** Phase 06 で実装した `workflow_run` トリガーで順序を保証

---

## 🔗 関連する問題

1. **Phase 02**: ACR が存在しない → ACR モジュール作成
2. **Phase 06**: デプロイ順序の問題 → workflow_run 実装
3. **Phase 07** (本件): ACR 認証エラー → ロール割り当て実装

---

## 📚 参考資料

- [Azure AKS と ACR の統合](https://learn.microsoft.com/ja-jp/azure/aks/cluster-container-registry-integration)
- [AcrPull ロールの詳細](https://learn.microsoft.com/ja-jp/azure/container-registry/container-registry-roles)
- [Managed Identity のベストプラクティス](https://learn.microsoft.com/ja-jp/azure/active-directory/managed-identities-azure-resources/overview)

---

## 🔄 変更履歴

| 日時       | 変更内容                                           |
| ---------- | -------------------------------------------------- |
| 2025-10-29 | 初期発見: ImagePullBackOff エラー                  |
| 2025-10-29 | 原因特定: 401 Unauthorized from ACR                |
| 2025-10-29 | 解決: aks-acr-role.bicep 実装                      |
| 2025-10-29 | 統合: main.bicep に追加、Infrastructure 再デプロイ |
