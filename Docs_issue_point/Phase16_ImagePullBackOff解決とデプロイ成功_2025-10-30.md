# Phase 16: ImagePullBackOff 解決とデプロイ成功 (2025-10-30)

## 📋 問題の概要

### 発生したエラー

**GitHub Actions Run #91 での失敗**:

```
Failed to pull image "acrdev.azurecr.io/guestbook:v4":
failed to authorize: failed to fetch anonymous token:
unexpected status from GET request to https://acrdev.azurecr.io/oauth2/token:
401 Unauthorized

Error: ImagePullBackOff
```

### エラーの詳細

- **Pod 状態**: `ImagePullBackOff`
- **影響**: 両方の Pod が起動できず、デプロイが 5 分でタイムアウト
- **根本原因**: deployment.yaml にハードコードされた ACR 名が実際の ACR 名と一致しない

```yaml
# deployment.yaml (誤り)
image: acrdev.azurecr.io/guestbook:v4

# 実際のACR名
acrwizdevc3zjwc.azurecr.io
```

## 🔍 根本原因分析

### 1. ハードコードされた ACR 名

**問題箇所**: `app/k8s/deployment.yaml` Line 18

```yaml
spec:
  containers:
    - name: guestbook
      image: acrdev.azurecr.io/guestbook:v4 # ❌ ハードコード
```

- ACR は`acr${environment}${uniqueString}`パターンで動的に生成される
- 実際の名前: `acrwizdevc3zjwc.azurecr.io`
- deployment.yaml の値: `acrdev.azurecr.io` (存在しない)

### 2. sed 置換パターンの失敗

**問題箇所**: `.github/workflows/app-deploy.yml` Line 242

```bash
# 誤ったパターン
sed -i "s|image: acrwiz.*\.azurecr\.io/guestbook:.*|image: ${ACR_NAME}...|g"
```

**マッチしない理由**:

- sed パターン: `acrwiz.*` を探す
- deployment.yaml: `acrdev` と書かれている
- 結果: パターンマッチせず、置換されない

### 3. ACR 認証自体は正常

**確認結果**:

```powershell
# AKS Kubelet Identity
az aks show -g rg-bbs-icd-aks001 -n aks-dev --query "identityProfile.kubeletidentity.objectId"
# → edd03eba-a280-4ea8-858a-8794467b7832

# AcrPullロール確認
az role assignment list --assignee edd03eba-a280-4ea8-858a-8794467b7832
# → AcrPull権限が正しく付与されている
```

**結論**:

- ✅ AKS → ACR の認証設定は正常
- ❌ 間違った ACR 名を参照していた

## 🛠️ 実施した修正

### 修正 1: deployment.yaml のプレースホルダー化

**ファイル**: `app/k8s/deployment.yaml`

```yaml
# Before (ハードコード)
spec:
  containers:
    - name: guestbook
      image: acrdev.azurecr.io/guestbook:v4

# After (プレースホルダー)
spec:
  containers:
    - name: guestbook
      image: <ACR_NAME>.azurecr.io/guestbook:<IMAGE_TAG>
```

**変更理由**:

- 環境非依存なマニフェストに変更
- GitHub Actions で動的に置換可能

### 修正 2: sed 置換ロジックの簡素化

**ファイル**: `.github/workflows/app-deploy.yml`

```yaml
# Before (複雑な正規表現)
- name: Replace Placeholders in K8s Manifests
  run: |
    ACR_NAME="${{ needs.build-push.outputs.acr_name }}"
    sed -i "s|image: acrwiz.*\.azurecr\.io/guestbook:.*|image: ${ACR_NAME}.azurecr.io/${{ env.IMAGE_NAME }}:${{ needs.build-push.outputs.image_tag }}|g" app/k8s/deployment.yaml

# After (シンプルなプレースホルダー置換)
- name: Replace Placeholders in K8s Manifests
  run: |
    ACR_NAME="${{ needs.build-push.outputs.acr_name }}"
    sed -i "s|<ACR_NAME>|${ACR_NAME}|g" app/k8s/deployment.yaml
    sed -i "s|<IMAGE_TAG>|${{ needs.build-push.outputs.image_tag }}|g" app/k8s/deployment.yaml
    sed -i "s|<MONGO_VM_IP>|${{ steps.infra.outputs.mongo_ip }}|g" app/k8s/deployment.yaml
```

**変更理由**:

- 正規表現の複雑さを排除
- 確実にマッチする文字列置換
- 可読性とメンテナンス性の向上

### 修正 3: ACR 待機ロジックの追加

**ファイル**: `.github/workflows/app-deploy.yml`

```yaml
# ACRの取得（最大20回リトライ、30秒間隔 = 最大10分待機）
max_acr_attempts=20
acr_attempt=1
ACR_NAME=""

while [ $acr_attempt -le $max_acr_attempts ]; do
    echo "🔍 Attempt $acr_attempt/$max_acr_attempts: Checking ACR..."

    ACR_NAME=$(az acr list --resource-group ${{ env.RESOURCE_GROUP }} --query "[0].name" -o tsv)

    if [ -n "$ACR_NAME" ]; then
        echo "✅ ACR found: ${ACR_NAME}"
        break
    fi

    if [ $acr_attempt -eq $max_acr_attempts ]; then
        echo "❌ No ACR found after $max_acr_attempts attempts!"
        exit 1
    fi

    echo "⏳ ACR not found yet. Waiting 30 seconds..."
    sleep 30
    acr_attempt=$((acr_attempt + 1))
done
```

**変更理由**:

- ACR 作成には 5-10 分かかる
- リソースグループ存在 ≠ ACR 作成完了
- インフラデプロイとアプリデプロイの競合を回避

## ✅ 修正結果の検証

### GitHub Actions 実行結果

| Run | ワークフロー                 | 状態       | 時間         | 結果             |
| --- | ---------------------------- | ---------- | ------------ | ---------------- |
| #91 | Build and Deploy Application | ❌ Failed  | 5m (timeout) | ImagePullBackOff |
| #95 | Build and Deploy Application | ✅ Success | 2m 44s       | デプロイ成功     |

**改善**: 5 分タイムアウト → **2 分 44 秒で完了**

### Pod 状態確認

```bash
$ az aks command invoke --resource-group rg-bbs-icd-aks001 --name aks-dev \
  --command "kubectl get pods -l app=guestbook -o wide"

NAME                             READY   STATUS    RESTARTS   AGE
guestbook-app-7df97bc5f8-7gp94   1/1     Running   0          13m
guestbook-app-7df97bc5f8-svbc6   1/1     Running   0          13m
```

✅ **両方の Pod が正常に起動**

### イメージ名確認

```bash
$ az aks command invoke --resource-group rg-bbs-icd-aks001 --name aks-dev \
  --command "kubectl get deployment guestbook-app -o jsonpath='{.spec.template.spec.containers[0].image}'"

acrwizdevc3zjwc.azurecr.io/guestbook:182da1e52889e297c176c2696dbdd1f20a79c08a
```

✅ **正しい ACR 名とコミット SHA が設定されている**

### Service 確認

```bash
$ az aks command invoke --resource-group rg-bbs-icd-aks001 --name aks-dev \
  --command "kubectl get svc guestbook-service"

NAME                TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)        AGE
guestbook-service   LoadBalancer   10.1.90.233   4.189.83.247   80:31478/TCP   13m
```

✅ **LoadBalancer IP が正常に割り当て**

### アプリケーションアクセス

**URL**: `http://4.189.83.247`

✅ **ブラウザからアクセス可能**

## 📊 技術的な学び

### 1. Kubernetes マニフェストのベストプラクティス

**問題**: 環境依存の値をハードコード

**解決策**:

- プレースホルダーを使用
- CI/CD パイプラインで動的置換
- Kustomize / Helm も検討可能

### 2. sed コマンドの落とし穴

**複雑な正規表現のリスク**:

```bash
# 脆弱: 想定外の文字列にマッチしない
sed -i "s|image: acrwiz.*\.azurecr\.io/guestbook:.*|...|g"
```

**推奨: シンプルな文字列置換**:

```bash
# 堅牢: 確実にマッチする
sed -i "s|<ACR_NAME>|${ACR_NAME}|g"
```

### 3. CI/CD パイプラインの依存関係管理

**問題**: インフラデプロイとアプリデプロイの競合

**解決策**:

- `workflow_run` トリガーで依存関係を明示
- リソース待機ロジックの実装 (リトライ + sleep)
- タイムアウト設定の適切化

### 4. Azure Managed Identity の利点

**今回の教訓**:

- AKS Kubelet Identity + AcrPull ロールは正常に動作
- イメージプルシークレット不要
- 認証情報のローテーション不要

**確認コマンド**:

```powershell
# Kubelet IdentityのAcrPull権限確認
$KUBELET_ID = az aks show -g <RG_NAME> -n <AKS_NAME> --query "identityProfile.kubeletidentity.objectId" -o tsv
az role assignment list --assignee $KUBELET_ID --scope <ACR_RESOURCE_ID>
```

## 🎯 今後の改善提案

### 1. Kustomize / Helm の導入

**現状**: sed での文字列置換

**改善案**: Kubernetes 標準ツールを使用

```yaml
# kustomization.yaml
images:
  - name: <ACR_NAME>.azurecr.io/guestbook
    newName: acrwizdevc3zjwc.azurecr.io/guestbook
    newTag: 182da1e...
```

### 2. 環境変数の Secret 化

**現状**: MONGO_URI が平文

**改善案**:

```yaml
env:
  - name: MONGO_URI
    valueFrom:
      secretKeyRef:
        name: mongodb-secret
        key: connection-string
```

### 3. デプロイ前の検証ステップ

**追加すべきチェック**:

- ACR 存在確認
- イメージが正常に push 済みか
- Kubernetes manifest の構文検証

```yaml
- name: Validate Manifests
  run: |
    kubectl apply --dry-run=client -f app/k8s/
```

### 4. ロールバック機能

**現状**: デプロイ失敗時は手動対応

**改善案**:

```yaml
- name: Deploy with Rollback
  run: |
    kubectl apply -f app/k8s/deployment.yaml
    kubectl rollout status deployment/guestbook-app --timeout=5m || {
      echo "Deployment failed, rolling back..."
      kubectl rollout undo deployment/guestbook-app
      exit 1
    }
```

## 📝 関連ドキュメント

- [Phase 15: ACR 待機ロジック追加](Phase15_ACR待機ロジック追加_2025-10-30.md)
- [Phase 07: AKS-ACR 認証エラー解決](Phase07_AKS-ACR認証エラー解決_2025-10-29.md)

## 🎉 まとめ

### 解決した問題

1. ✅ ImagePullBackOff (401 Unauthorized)
2. ✅ sed パターンマッチ失敗
3. ✅ ACR 待機ロジック不足

### デプロイ成功の証拠

- ✅ Pods: 2/2 Running
- ✅ Image: 正しい ACR 名 + コミット SHA
- ✅ Service: LoadBalancer IP 割り当て済み
- ✅ 時間: 2 分 44 秒で完了

### コミット情報

- **コミットハッシュ**: `182da1e52889e297c176c2696dbdd1f20a79c08a`
- **コミットメッセージ**: "fix: Replace hardcoded ACR name with placeholder in deployment.yaml"
- **GitHub Actions Run**: #95 (Success)

**プロジェクトは完全にデプロイ可能な状態になりました！** 🚀
