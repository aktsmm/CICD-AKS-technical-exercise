# Issue: Docker イメージ名の大文字エラー

## 📋 概要

**問題**: GitHub Actions ワークフロー「Scan Container Image」ジョブが、Docker イメージのビルド時に失敗。

**エラーメッセージ**:

```
ERROR: failed to build: invalid tag "SuperBBS:3378faea2ae51a4bcbec8a747c1c814bc1ee3439":
repository name must be lowercase
```

**原因**: GitHub Variables の `IMAGE_NAME` に大文字が含まれていたため、Docker のタグ命名規則に違反。

**影響範囲**: CI/CD パイプライン（アプリケーションデプロイワークフロー）

---

## 🔍 問題の詳細

### エラー発生箇所

**ワークフロー**: `.github/workflows/02-1.app-deploy.yml`  
**ジョブ**: `scan-container`  
**ステップ**: `Build Docker Image (for scanning)`

```yaml
- name: Build Docker Image (for scanning)
  run: |
    cd app
    docker build -t ${{ env.IMAGE_NAME }}:${{ github.sha }} .
```

### エラーログ

```text
Run cd app
ERROR: failed to build: invalid tag "SuperBBS:3378faea2ae51a4bcbec8a747c1c814bc1ee3439":
repository name must be lowercase
Error: Process completed with exit code 1.
```

### 根本原因

1. **GitHub Variables 設定**:
   - `IMAGE_NAME` の値が `SuperBBS` と大文字を含んでいた
2. **Docker 命名規則違反**:

   - Docker イメージのリポジトリ名（タグ）は**小文字のみ**許可
   - 大文字、特殊文字（一部除く）は使用不可

3. **検証不足**:
   - GitHub Variables 設定時に命名規則のバリデーションなし
   - ワークフロー実行時に初めてエラーが検出される

---

## ✅ 解決策

### 1. GitHub Variables の修正

**修正前**:

```bash
IMAGE_NAME=SuperBBS
```

**修正後**:

```bash
IMAGE_NAME=bbs-app
```

#### 修正コマンド

```bash
# 現在の値を確認
gh variable list

# IMAGE_NAME を小文字に変更
gh variable set IMAGE_NAME --body "bbs-app"

# 変更を確認
gh variable get IMAGE_NAME
```

### 2. Docker タグ命名規則の確認

#### 許可される文字

- 小文字の英字 (`a-z`)
- 数字 (`0-9`)
- ハイフン (`-`)
- アンダースコア (`_`)
- ドット (`.`)

#### 禁止される文字

- 大文字の英字 (`A-Z`) ← **今回のエラー原因**
- スペース
- 特殊文字（`@`, `#`, `$`, etc.）

#### 命名のベストプラクティス

```bash
# ✅ 良い例
bbs-app
my-application
webapp-v2
nginx-1.21

# ❌ 悪い例
SuperBBS      # 大文字
My_App        # 大文字
web@app       # 特殊文字
app name      # スペース
```

---

## 🔄 修正手順

### Step 1: GitHub Variables を確認

```bash
cd d:\00_temp\wizwork\CICD-AKS-technical-exercise
gh variable list
```

### Step 2: IMAGE_NAME を小文字に変更

```bash
gh variable set IMAGE_NAME --body "bbs-app"
```

### Step 3: ワークフローを再実行

1. GitHub Actions 画面に移動
2. 失敗した「2-1. Build and Deploy Application」ワークフローを選択
3. 「Re-run failed jobs」をクリック

または、コミット&プッシュで自動トリガー:

```bash
# 軽微な変更でワークフローをトリガー
git commit --allow-empty -m "chore: trigger workflow after IMAGE_NAME fix"
git push origin main
```

---

## 🎯 検証方法

### 1. ローカルで Docker ビルド確認

```bash
cd app

# 修正後のイメージ名でビルド
docker build -t bbs-app:test .

# ビルド成功を確認
docker images | grep bbs-app
```

### 2. GitHub Actions ログ確認

```bash
# 最新のワークフロー実行を確認
gh run list --workflow="02-1.app-deploy.yml" --limit 3

# 特定の実行の詳細を確認
gh run view <RUN_ID>
```

### 3. ACR へのプッシュ確認

ワークフロー成功後、ACR に正しくイメージがプッシュされたか確認:

```bash
# ACR名を取得
ACR_NAME=$(az acr list --resource-group rg-bbs-cicd-aks-demo --query "[0].name" -o tsv)

# イメージリストを確認
az acr repository list --name $ACR_NAME --output table

# 特定のイメージタグを確認
az acr repository show-tags --name $ACR_NAME --repository bbs-app --output table
```

---

## 📚 関連知識

### Docker タグの完全な命名規則

Docker 公式ドキュメントより:

```text
tag := [registry-url/]name[:tag]
name := [component/]component
component := [a-z0-9]+ ([-._] [a-z0-9]+)*

制約:
- 小文字のみ
- 最大128文字
- 連続する区切り文字(-._ )は不可
- 先頭・末尾は英数字のみ
```

### Azure Container Registry (ACR) の追加制約

ACR は基本的に Docker の命名規則に従いますが、追加の推奨事項があります:

- リポジトリ名: 1-256 文字
- タグ名: 1-128 文字
- 階層構造のサポート: `myapp/backend`, `myapp/frontend`

---

## 🔧 予防策

### 1. GitHub Variables 設定時のチェックリスト

```markdown
□ 小文字のみ使用
□ 英数字とハイフン・アンダースコア・ドットのみ
□ 128 文字以内
□ 意味のある名前（例: アプリ名-役割）
□ 環境別の命名規則統一
```

### 2. ワークフローにバリデーション追加（オプション）

`.github/workflows/02-1.app-deploy.yml` にバリデーションステップを追加:

```yaml
- name: Validate IMAGE_NAME
  run: |
    IMAGE_NAME="${{ env.IMAGE_NAME }}"

    # 小文字チェック
    if [[ "$IMAGE_NAME" =~ [A-Z] ]]; then
      echo "❌ ERROR: IMAGE_NAME contains uppercase letters: $IMAGE_NAME"
      echo "Docker image names must be lowercase only."
      exit 1
    fi

    # 不正文字チェック
    if [[ ! "$IMAGE_NAME" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
      echo "❌ ERROR: IMAGE_NAME contains invalid characters: $IMAGE_NAME"
      echo "Allowed: lowercase letters, numbers, dots, hyphens, underscores"
      exit 1
    fi

    echo "✅ IMAGE_NAME validation passed: $IMAGE_NAME"
```

### 3. 初回セットアップガイドに追記

`初回セットアップガイド.md` に命名規則の注意事項を追加:

```markdown
### GitHub Variables 設定時の注意事項

**IMAGE_NAME の命名規則**:

- ✅ 小文字のみ使用（例: bbs-app, myapp-web）
- ❌ 大文字は使用不可（例: SuperBBS, MyApp）
- 推奨形式: `{アプリ名}-{役割}` または `{プロジェクト名}-app`
```

---

## 📝 修正履歴

| 日付       | 担当者 | 内容                                        |
| ---------- | ------ | ------------------------------------------- |
| 2025-11-06 | -      | IMAGE_NAME を `SuperBBS` → `bbs-app` に修正 |
| 2025-11-06 | -      | Issue ドキュメント作成                      |

---

## 🔗 関連リソース

- [Docker Official Documentation - Image Naming](https://docs.docker.com/engine/reference/commandline/tag/)
- [Azure Container Registry - Repositories and images](https://learn.microsoft.com/ja-jp/azure/container-registry/container-registry-concepts)
- [GitHub Actions - Variables](https://docs.github.com/en/actions/learn-github-actions/variables)

---

**ステータス**: ✅ 解決済み  
**対応日**: 2025 年 11 月 6 日  
**影響範囲**: CI/CD パイプライン（Scan Container Image ジョブ）  
**優先度**: 高（パイプライン停止）  
**再発防止**: バリデーション追加、ドキュメント更新
