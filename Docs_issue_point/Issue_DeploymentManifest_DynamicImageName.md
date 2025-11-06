# Issue: Deploymentマニフェストのイメージ名動的化

## 📋 概要

**問題**: Kubernetesの`deployment.yaml`でコンテナイメージ名が`guestbook`とハードコードされていたため、イメージ名を変更する際にマニフェストファイルの修正が必要だった。

**解決**: GitHub Variables `IMAGE_NAME`を使用して、ワークフロー実行時に動的にイメージ名を置換するように改善。

---

## 🔍 問題の詳細

### 変更前の状態

**ファイル**: `app/k8s/deployment.yaml`

```yaml
containers:
  - name: guestbook
    image: <ACR_NAME>.azurecr.io/guestbook:<IMAGE_TAG>
```

**問題点**:

- イメージ名`guestbook`がハードコード
- イメージ名変更時にマニフェストファイルの修正が必要
- GitHub Variablesで`IMAGE_NAME`を定義しているのに活用されていない
- 環境ごとに異なるイメージ名を使う場合の柔軟性が低い

### ワークフローの処理

**ファイル**: `.github/workflows/02-1.app-deploy.yml`

```yaml
- name: Prepare Kubernetes Manifests
  env:
    ACR_NAME: ${{ needs.build-push.outputs.acr_name }}
    IMAGE_TAG: ${{ needs.build-push.outputs.image_tag }}
  run: |
    sed -i "s|<ACR_NAME>|${ACR_NAME}|g" rendered/deployment.yaml
    sed -i "s|<IMAGE_TAG>|${IMAGE_TAG}|g" rendered/deployment.yaml
    # ⚠️ IMAGE_NAME の置換処理がない
```

---

## ✅ 解決策

### 1. Deploymentマニフェストの修正

**ファイル**: `app/k8s/deployment.yaml`

```yaml
containers:
  - name: guestbook
    image: <ACR_NAME>.azurecr.io/<IMAGE_NAME>:<IMAGE_TAG>
    # ↑ guestbook → <IMAGE_NAME> プレースホルダー化
```

### 2. ワークフローの修正

**ファイル**: `.github/workflows/02-1.app-deploy.yml`

```yaml
- name: Prepare Kubernetes Manifests
  env:
    ACR_NAME: ${{ needs.build-push.outputs.acr_name }}
    IMAGE_TAG: ${{ needs.build-push.outputs.image_tag }}
  run: |
    mkdir -p rendered
    cp app/k8s/deployment.yaml rendered/deployment.yaml
    # ... 他のファイルコピー ...

    sed -i "s|<ACR_NAME>|${ACR_NAME}|g" rendered/deployment.yaml
    sed -i "s|<IMAGE_NAME>|${{ env.IMAGE_NAME }}|g" rendered/deployment.yaml  # ✅ 追加
    sed -i "s|<IMAGE_TAG>|${IMAGE_TAG}|g" rendered/deployment.yaml
```

### 3. GitHub Variables設定

既に設定済み:

```bash
IMAGE_NAME='bbs-app'
```

確認コマンド:

```bash
gh variable list
```

---

## 🎯 改善効果

### メリット

1. **保守性向上**
   - イメージ名変更時はGitHub Variablesの`IMAGE_NAME`のみ更新
   - マニフェストファイルの修正不要

2. **柔軟性向上**
   - 環境ごとに異なるイメージ名を簡単に設定可能
   - 複数の環境(dev/staging/prod)への展開が容易

3. **設定の一元管理**
   - イメージ名はGitHub Variablesで一元管理
   - コードとインフラ設定の分離

4. **一貫性**
   - ACR名、イメージ名、イメージタグすべてが動的置換
   - プレースホルダーパターンの統一

### 動作フロー

```text
[ワークフロー実行]
    ↓
[GitHub Variables取得]
    env.IMAGE_NAME = 'bbs-app'
    ↓
[マニフェストファイルコピー]
    deployment.yaml → rendered/deployment.yaml
    ↓
[sed コマンドで置換]
    <ACR_NAME> → acr000xxxxx
    <IMAGE_NAME> → bbs-app  ← ✅ 追加された処理
    <IMAGE_TAG> → a1b2c3d4
    ↓
[最終的なイメージ指定]
    acr000xxxxx.azurecr.io/bbs-app:a1b2c3d4
    ↓
[AKSへデプロイ]
```

---

## 📦 関連ファイル

- `app/k8s/deployment.yaml` - Kubernetesデプロイメントマニフェスト
- `.github/workflows/02-1.app-deploy.yml` - アプリケーションデプロイワークフロー
- GitHub Variables: `IMAGE_NAME` (値: `bbs-app`)

---

## 🔄 デプロイ方法

### イメージ名の変更手順

1. GitHub Variablesの更新:

   ```bash
   gh variable set IMAGE_NAME --body "新しいイメージ名"
   ```

2. ワークフローを実行:

   - 自動: `app/` ディレクトリ配下を変更してpush
   - 手動: GitHub Actions画面から「2-1. Build and Deploy Application」を実行

3. 確認:

   ```bash
   kubectl get deployment guestbook-app -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```

### ロールバック手順

イメージ名を元に戻す場合:

```bash
gh variable set IMAGE_NAME --body "bbs-app"
```

---

## 📝 コミット情報

- **コミットハッシュ**: `f64c353`
- **コミット日時**: 2025年11月6日
- **ブランチ**: `main`
- **コミットメッセージ**:

  ```text
  feat: Deploymentマニフェストのイメージ名をGitHub変数から動的取得
  
  変更内容:
  - app/k8s/deployment.yaml: イメージ名を <IMAGE_NAME> プレースホルダー化
  - .github/workflows/02-1.app-deploy.yml: sed コマンドで IMAGE_NAME 変数を置換
  
  メリット:
  - イメージ名の変更時に GitHub Variables の IMAGE_NAME のみ更新すればよい
  - マニフェストファイルの修正が不要
  - 環境ごとの柔軟な設定が可能
  ```

---

## ✅ 検証方法

### 1. ワークフロー実行確認

```bash
# 最新のワークフロー実行を確認
gh run list --workflow="02-1.app-deploy.yml" --limit 1
```

### 2. デプロイされたイメージ確認

```bash
# AKSクラスターに接続
az aks get-credentials --resource-group rg-bbs-cicd-aks-demo --name <AKS_NAME>

# Deploymentのイメージ確認
kubectl get deployment guestbook-app -o yaml | grep image:

# 期待される出力:
# image: acr000xxxxx.azurecr.io/bbs-app:コミットSHA
```

### 3. GitHub Variables確認

```bash
gh variable list
# 出力に IMAGE_NAME=bbs-app が含まれることを確認
```

---

## 🚀 今後の拡張案

### 1. 環境別イメージ名

Environment機能を使用して環境ごとに異なるイメージ名を設定:

```yaml
environment:
  name: production
# production環境のvariablesで IMAGE_NAME を上書き
```

### 2. イメージタグ戦略の柔軟化

セマンティックバージョニングへの対応:

```yaml
IMAGE_TAG: v1.2.3  # GitHubリリースタグから取得
```

### 3. マルチリージョン展開

リージョンごとに異なるACR + イメージ名の組み合わせ:

```yaml
IMAGE_NAME: ${REGION}-bbs-app  # asia-bbs-app, europe-bbs-app
```

---

## 📚 参考資料

- [GitHub Actions - Variables](https://docs.github.com/en/actions/learn-github-actions/variables)
- [Kubernetes - Container Images](https://kubernetes.io/docs/concepts/containers/images/)
- [Azure Container Registry - Best Practices](https://learn.microsoft.com/ja-jp/azure/container-registry/container-registry-best-practices)

---

**ステータス**: ✅ 解決済み  
**対応日**: 2025年11月6日  
**影響範囲**: CI/CD パイプライン、Kubernetes デプロイメント  
**優先度**: 中（保守性改善）
