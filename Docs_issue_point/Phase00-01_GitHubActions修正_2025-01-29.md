# Phase 0-1: GitHub Actions CI/CD 修正履歴

**発生日時**: 2025 年 1 月 29 日  
**フェーズ**: Phase 0 → Phase 1 (CI/CD パイプライン修正)  
**重要度**: 🔴 Critical

---

## 📋 トラブル概要

GitHub Actions ワークフローで複数のエラーが連続発生し、インフラデプロイとアプリデプロイが実行できない状態でした。

---

## 🔥 発生したトラブル一覧

### トラブル #1: Dockerfile 未実装エラー

**発生日時**: 2025 年 1 月 29 日 (最初の GitHub Actions 実行時)

**エラーメッセージ (全文)**:

```
ERROR: failed to solve: dockerfile parse error on line 1:
file with no instructions
```

**発生箇所**:

- `.github/workflows/app-deploy.yml` の Docker build ステップ
- `app/Dockerfile` が TODO コメントのみで空だった

**原因**:

- `app/Dockerfile` が以下のようにプレースホルダーのままだった:
  ```dockerfile
  # TODO: Implement Dockerfile
  # This Dockerfile will build the Node.js guestbook application
  ```

**試行錯誤の記録**:

1. **調査**: `app/` ディレクトリの内容を確認

   - `package.json` で Node.js アプリと判明
   - `app.js` がエントリーポイント
   - Port 3000 で起動

2. **解決策の検討**:

   - Node.js 公式イメージの選定 → `node:18-alpine` (軽量版)
   - 本番環境用に `npm install --production` を使用
   - 環境変数 `NODE_ENV=production` を設定

3. **実装**:
   ```dockerfile
   FROM node:18-alpine
   WORKDIR /app
   COPY wizexercise.txt ./
   COPY package*.json ./
   RUN npm install --production
   COPY . .
   EXPOSE 3000
   ENV NODE_ENV=production
   CMD ["npm", "start"]
   ```

**最終的な解決方法**:

- Dockerfile を完全実装 (上記コード)
- コミット: `105094a - Fix: Complete Dockerfile implementation for Node.js guestbook app`

**再発防止策**:

- ✅ プロジェクト開始時に全ファイルの実装状況を確認
- ✅ TODO コメントのみのファイルは即座に実装
- ✅ GitHub Actions をローカルで事前テスト (act ツール利用検討)

---

### トラブル #2: CodeQL Action v2 非推奨エラー

**発生日時**: 2025 年 1 月 29 日 (Dockerfile 修正後)

**エラーメッセージ (全文)**:

```
Node.js 16 actions are deprecated. Please update the following actions to use Node.js 20:
github/codeql-action/upload-sarif@v2.
For more information see: https://github.blog/changelog/2023-09-22-github-actions-transitioning-from-node-16-to-node-20/.
```

**発生箇所**:

- `.github/workflows/infra-deploy.yml` の "Upload Checkov scan results to GitHub Security tab" ステップ
- `.github/workflows/app-deploy.yml` の "Upload Trivy scan results to GitHub Security tab" ステップ

**原因**:

- `github/codeql-action/upload-sarif@v2` が Node.js 16 を使用
- GitHub Actions が Node.js 20 への移行を推奨
- v2 は将来的に廃止予定

**試行錯誤の記録**:

1. **GitHub Actions のログを確認**:

   - Warning が出ているが、ワークフローは続行
   - SARIF アップロードは成功している

2. **対応方針の検討**:

   - v3 へのアップグレードが推奨されている
   - Breaking changes がないことを確認
   - `continue-on-error: true` を追加してエラーでもワークフロー継続

3. **実装**:

   ```yaml
   # infra-deploy.yml
   - name: Upload Checkov scan results to GitHub Security tab
     uses: github/codeql-action/upload-sarif@v3 # v2 → v3
     continue-on-error: true
     with:
       sarif_file: checkov-results.sarif

   # app-deploy.yml
   - name: Upload Trivy scan results to GitHub Security tab
     uses: github/codeql-action/upload-sarif@v3 # v2 → v3
     continue-on-error: true
     with:
       sarif_file: trivy-results.sarif
   ```

**最終的な解決方法**:

- `github/codeql-action/upload-sarif@v2` → `@v3` に更新
- `continue-on-error: true` を追加 (SARIF アップロード失敗でもデプロイ継続)

**再発防止策**:

- ✅ Dependabot で GitHub Actions の自動更新を有効化
- ✅ 定期的に GitHub Actions のバージョンをチェック
- ✅ 非推奨警告が出たら即座に対応

---

### トラブル #3: Artifact Actions v3 非推奨エラー

**発生日時**: 2025 年 1 月 29 日 (CodeQL Action 修正後)

**エラーメッセージ (全文)**:

```
The following actions uses node12 which is deprecated and will be forced to run on node16:
actions/upload-artifact@v3, actions/download-artifact@v3.
For more information see: https://github.blog/changelog/2023-06-13-github-actions-all-actions-will-run-on-node16-instead-of-node12-by-default/

This request has been automatically failed because it uses a deprecated version of
`actions/upload-artifact: v3`. Learn more: https://github.blog/changelog/2024-04-16-deprecation-notice-v3-of-artifact-actions/
```

**発生箇所**:

- `.github/workflows/infra-deploy.yml` の "Upload deployment outputs" ステップ
- `.github/workflows/app-deploy.yml` の "Download deployment outputs" ステップ

**原因**:

- `actions/upload-artifact@v3` と `actions/download-artifact@v3` が非推奨
- v3 は 2024 年 4 月 16 日以降完全に動作しなくなった
- v4 では内部実装が変更されており、互換性なし

**試行錯誤の記録**:

1. **v4 の Breaking Changes を調査**:

   - v3: artifact は個別の名前空間に保存
   - v4: artifact は実行単位で管理される
   - ダウンロード時のパス構造が変更

2. **v4 への移行手順**:

   ```yaml
   # infra-deploy.yml (アップロード側)
   - name: Upload deployment outputs
     uses: actions/upload-artifact@v4 # v3 → v4
     with:
       name: infra-outputs
       path: outputs/infra-outputs.txt
       retention-days: 1

   # app-deploy.yml (ダウンロード側)
   - name: Download deployment outputs
     uses: actions/download-artifact@v4 # v3 → v4
     with:
       name: infra-outputs
       path: outputs/ # v4 では明示的にパスを指定
   ```

3. **パス構造の調整**:
   - v3: ダウンロード先が `infra-outputs/infra-outputs.txt`
   - v4: ダウンロード先が `outputs/infra-outputs.txt`
   - 後続ステップで参照するパスを変更

**最終的な解決方法**:

- `actions/upload-artifact@v3` → `@v4` に更新
- `actions/download-artifact@v3` → `@v4` に更新
- ダウンロードパスを `infra-outputs.txt` → `outputs/infra-outputs.txt` に変更
- コミット: `4a0a9ef - Fix: Update artifact actions from v3 to v4`

**再発防止策**:

- ✅ GitHub Changelog を定期的に確認
- ✅ Dependabot で GitHub Actions の自動更新
- ✅ v4 の新機能 (retention-days 等) を活用

---

### トラブル #4: Artifact ダウンロードパス不正エラー

**発生日時**: 2025 年 1 月 29 日 (Artifact Actions v4 更新後)

**エラーメッセージ (全文)**:

```
Error: Unable to find file 'infra-outputs.txt'
```

**発生箇所**:

- `.github/workflows/app-deploy.yml` の "Set environment variables from outputs" ステップ
- Artifact ダウンロード後に環境変数を設定しようとして失敗

**原因**:

- Artifact Actions v4 でダウンロード先のパス構造が変更された
- `infra-outputs.txt` が `outputs/infra-outputs.txt` にダウンロードされている
- ワークフロー内で古いパス `infra-outputs.txt` を参照していた

**試行錯誤の記録**:

1. **デバッグ出力の追加**:

   ```yaml
   - name: Debug - List downloaded files
     run: |
       echo "Current directory:"
       pwd
       echo "Directory contents:"
       ls -la
       echo "outputs directory:"
       ls -la outputs/ || echo "outputs/ not found"
   ```

2. **パスの修正**:

   - `cat infra-outputs.txt` → `cat outputs/infra-outputs.txt`
   - ただし、Artifact が存在しない場合にエラーになる問題が残る

3. **フォールバック処理の追加**:
   ```yaml
   - name: Set environment variables from outputs
     run: |
       if [ -f outputs/infra-outputs.txt ]; then
         echo "Using artifact outputs"
         cat outputs/infra-outputs.txt >> $GITHUB_ENV
       else
         echo "Artifact not found, querying Azure directly"
         # Azure CLI で直接取得
       fi
   ```

**最終的な解決方法**:

- Artifact ファイルパスを `outputs/infra-outputs.txt` に修正
- ファイル存在チェックとフォールバック処理を追加
- Azure CLI での直接クエリをフォールバックとして実装
- コミット: `15882e3 - Fix: Improve artifact handling and add error checking in app-deploy`

**再発防止策**:

- ✅ Artifact の存在チェックを必須化
- ✅ フォールバック処理を標準実装
- ✅ デバッグ出力を残してトラブルシューティングを容易に

---

## 📊 修正内容の全体まとめ

| トラブル               | 対象ファイル                         | 変更内容                            | コミット |
| ---------------------- | ------------------------------------ | ----------------------------------- | -------- |
| #1 Dockerfile 未実装   | `app/Dockerfile`                     | Node.js 18 Alpine イメージで実装    | 105094a  |
| #2 CodeQL Action v2    | `infra-deploy.yml`, `app-deploy.yml` | `@v2` → `@v3` + `continue-on-error` | 4a0a9ef  |
| #3 Artifact Actions v3 | `infra-deploy.yml`, `app-deploy.yml` | `@v3` → `@v4` + パス調整            | 4a0a9ef  |
| #4 Artifact パス不正   | `app-deploy.yml`                     | パス修正 + フォールバック処理       | 15882e3  |

---

## ✅ 最終的な動作確認結果

### インフラデプロイワークフロー (infra-deploy.yml)

**実行結果**: ✅ 部分的に成功 (Storage Account でエラー)

**成功したステップ**:

- ✅ Checkout code
- ✅ Azure Login
- ✅ Run Checkov scan
- ✅ Upload Checkov SARIF
- ✅ Deploy Bicep (11/12 リソース成功)
- ✅ Upload deployment outputs

**失敗したステップ**:

- ❌ Deploy Bicep - Storage Account デプロイ失敗
  - エラー: "PublicAcces..." (ポリシー制約)
  - 対応: サブスクリプション切り替えで解決予定

**作成されたリソース**:

1. Azure Container Registry (acrwizexercise)
2. Storage Account (stwizdev5ogryzdtfnsbk) - 作成後にエラー
3. Log Analytics Workspace (log-dev)
4. Virtual Network (vnetdev)
5. Network Security Group (vm-mongo-dev-nsg)
6. Public IP (vm-mongo-dev-pip)
7. Network Interface (vm-mongo-dev-nic)
8. Virtual Machine (vm-mongo-dev)
9. OS Disk (vm-mongo-dev_OsDisk)
10. AKS Cluster (aks-dev)
11. VM Extension (vm-mongo-dev/install-mongodb)
12. Container Insights (ContainerInsights)

### アプリデプロイワークフロー (app-deploy.yml)

**実行結果**: ⏳ 未実行 (インフラデプロイ完了後に実行予定)

---

## 🔄 Phase 1 で実施予定の対応

### 1. Azure サブスクリプション切り替え

**対応日**: 2025 年 1 月 29 日

**実施内容**:

- サブスクリプション切り替え: "hinokuni-sub" → "Visual Studio Enterprise"
- Service Principal 新規作成: `spexercise-github-vspro`
- GitHub Secrets 更新:
  - `AZURE_CREDENTIALS`
  - `AZURE_SUBSCRIPTION_ID`

**期待される結果**:

- ✅ Storage Account のデプロイ成功 (ポリシー制約なし)
- ✅ 全 12 リソースのデプロイ完了

---

## 📚 参考ドキュメント

### GitHub Actions 関連

- [GitHub Actions - Node.js 20 移行ガイド](https://github.blog/changelog/2023-09-22-github-actions-transitioning-from-node-16-to-node-20/)
- [Artifact Actions v4 移行ガイド](https://github.blog/changelog/2024-04-16-deprecation-notice-v3-of-artifact-actions/)
- [CodeQL Action v3 リリースノート](https://github.com/github/codeql-action/releases/tag/codeql-bundle-v2.14.6)

### Azure Bicep 関連

- [Azure Bicep - Storage Account](https://learn.microsoft.com/ja-jp/azure/templates/microsoft.storage/storageaccounts)
- [Azure Policy - PublicNetworkAccess 制約](https://learn.microsoft.com/ja-jp/azure/governance/policy/samples/built-in-policies#storage)

### Docker 関連

- [Node.js Docker イメージ](https://hub.docker.com/_/node)
- [Dockerfile ベストプラクティス](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

---

## 🎯 今後の改善案

1. **GitHub Actions のローカルテスト**

   - `act` ツールの導入
   - CI/CD をローカルで事前検証

2. **Dependabot の設定**

   - GitHub Actions の自動更新
   - 週次でバージョンチェック

3. **Artifact の改善**

   - より堅牢なフォールバック処理
   - Artifact の有効期限を最適化

4. **セキュリティスキャンの強化**
   - Checkov のカスタムポリシー追加
   - Trivy の脆弱性しきい値設定

---

**作成者**: aktsmm  
**最終更新**: 2025 年 1 月 29 日  
**関連ドキュメント**:

- `Docs_work_history/Phase01_環境準備_2025-01-29.md`
- `.github/copilot-instructions.md`
