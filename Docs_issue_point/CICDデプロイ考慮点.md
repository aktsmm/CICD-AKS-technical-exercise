# CI/CD デプロイ考慮点

## 作成日

2025 年 10 月 29 日

## 概要

Wiz Technical Exercise プロジェクトの GitHub Actions CI/CD パイプライン構築時に発生した問題と解決策をまとめたドキュメント。

---

## 問題 1: GitHub Push Protection による機密情報検出

### 発生状況

```
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote: - GITHUB PUSH PROTECTION
remote:   - Push cannot contain secrets
remote:   —— Azure Active Directory Application Secret —————————
```

### 原因

- `docs/AZURE_SETUP_INFO.md` に Azure Service Principal の `clientSecret` が含まれていた
- GitHub の Secret Scanning が機密情報を検出して push をブロック

### 解決策

#### 1. `.gitignore` に機密情報ファイルを追加

```gitignore
# Secrets and credentials (DO NOT COMMIT)
docs/AZURE_SETUP_INFO.md
mongo_password.txt
*.secret
*.credentials
```

#### 2. Git 履歴から機密情報を削除

```powershell
# 問題のコミットより前にリセット
git reset --soft deda077

# 機密情報を除外してクリーンな履歴で再コミット
git commit -m "Initial commit: Complete Wiz Technical Exercise..."

# 強制プッシュで履歴を上書き
git push origin main --force
```

### 教訓

- ✅ 機密情報は必ず `.gitignore` で除外
- ✅ Azure 認証情報は GitHub Secrets で管理
- ✅ ローカル参照用ファイルはリポジトリに含めない
- ✅ Git 履歴に機密情報が残らないよう初期設定を徹底

---

## 問題 2: CodeQL Action の非推奨バージョン使用

### 発生状況

```
Scan IaC for Security Issues
CodeQL Action major versions v1 and v2 have been deprecated.
Please update all occurrences of the CodeQL Action in your workflow files to v3.
```

### 原因

- GitHub Actions ワークフローで `github/codeql-action/upload-sarif@v2` を使用
- v1/v2 は 2025 年 1 月 10 日に非推奨化された

### 解決策

#### infra-deploy.yml の修正

```yaml
# 修正前
- name: Upload Checkov Results
  uses: github/codeql-action/upload-sarif@v2
  if: always()
  with:
    sarif_file: checkov-results.sarif

# 修正後
- name: Upload Checkov Results
  uses: github/codeql-action/upload-sarif@v3
  if: always()
  continue-on-error: true
  with:
    sarif_file: checkov-results.sarif
```

#### app-deploy.yml の修正

```yaml
# 修正前
- name: Upload Trivy Results
  uses: github/codeql-action/upload-sarif@v2
  if: always()
  with:
    sarif_file: trivy-results.sarif

# 修正後
- name: Upload Trivy Results
  uses: github/codeql-action/upload-sarif@v3
  if: always()
  continue-on-error: true
  with:
    sarif_file: trivy-results.sarif
```

### 教訓

- ✅ GitHub Actions は定期的にバージョンアップデートを確認
- ✅ 非推奨化スケジュールを把握（Major version の変更に注意）
- ✅ Dependabot を有効化してアクション更新を自動化

---

## 問題 3: SARIF Upload 権限エラー

### 発生状況

```
Scan IaC for Security Issues
Resource not accessible by integration
```

### 原因

- GitHub Actions が Code Scanning に SARIF ファイルをアップロードする権限がない
- リポジトリ設定で Code Scanning / Security が有効化されていない可能性

### 解決策

#### ワークフローに `continue-on-error: true` を追加

```yaml
- name: Upload Checkov Results
  uses: github/codeql-action/upload-sarif@v3
  if: always()
  continue-on-error: true # ⭐ この行を追加
  with:
    sarif_file: checkov-results.sarif
```

#### リポジトリ設定の確認（オプション）

1. **Settings > Code security and analysis**
2. **Code scanning** セクションで設定を有効化
3. **SARIF uploads** を許可

### 教訓

- ✅ セキュリティスキャンの失敗でデプロイを止めない設計
- ✅ SARIF アップロードはオプショナルな機能として扱う
- ✅ `continue-on-error: true` でレジリエントなパイプラインを構築

---

## 問題 4: Checkov セキュリティスキャンの失敗（意図的な脆弱性）

### 発生状況

```
12 errors detected:
- CKV_AZURE_171: Ensure AKS cluster upgrade channel is chosen
- CKV_AZURE_226: Ensure ephemeral disks are used for OS disks
- CKV_AZURE_141: Ensure AKS local admin account is disabled
- CKV_AZURE_7: Ensure AKS cluster has Network Policy configured
- CKV_AZURE_227: Ensure AKS cluster encrypts temp disks
- CKV_AZURE_97: Ensure VMSS has encryption at host enabled
- CKV_AZURE_178: Ensure linux VM enables SSH with keys
- CKV_AZURE_1: Ensure Azure Instance does not use basic authentication
- CKV_AZURE_151: Ensure Windows VM enables encryption
- CKV_AZURE_50: Ensure Virtual Machine Extensions are not Installed
```

### 原因

- このプロジェクトは **意図的に脆弱な構成** を含んでいる
- Checkov がセキュリティベストプラクティス違反を正しく検出
- デフォルト設定では失敗でパイプラインが停止

### 解決策

#### `soft_fail: true` の設定（すでに実装済み）

```yaml
- name: Run Checkov Scan
  uses: bridgecrewio/checkov-action@master
  with:
    directory: infra/
    framework: bicep
    output_format: sarif
    output_file_path: checkov-results.sarif
    soft_fail: true # ⭐ 検出してもワークフローは継続
```

### 検出された脆弱性の説明

#### AKS 関連の脆弱性（意図的）

| チェック      | 説明                         | 推奨対策                                   |
| ------------- | ---------------------------- | ------------------------------------------ |
| CKV_AZURE_171 | アップグレードチャネル未設定 | `upgradeChannel: 'stable'` を追加          |
| CKV_AZURE_141 | ローカル管理者アカウント有効 | `disableLocalAccounts: true` を設定        |
| CKV_AZURE_7   | ネットワークポリシー未設定   | `networkPolicy: 'azure'` または `'calico'` |
| CKV_AZURE_227 | 一時ディスク暗号化なし       | `enableEncryptionAtHost: true`             |

#### VM 関連の脆弱性（意図的）

| チェック      | 説明                        | 推奨対策                                 |
| ------------- | --------------------------- | ---------------------------------------- |
| CKV_AZURE_178 | SSH キー認証未使用          | パスワード認証を削除、SSH 公開鍵のみ許可 |
| CKV_AZURE_1   | Basic 認証使用              | SSH キーベース認証に変更                 |
| CKV_AZURE_97  | ホスト暗号化なし            | `securityProfile.encryptionAtHost: true` |
| CKV_AZURE_50  | VM 拡張機能インストール済み | 不要な拡張機能を削除                     |

### 教訓

- ✅ `soft_fail: true` で検出はするがデプロイは継続
- ✅ 意図的な脆弱性はドキュメント化して説明可能にする
- ✅ セキュリティスキャン結果を技術面接で活用
- ✅ 本番環境では `soft_fail: false` にして厳格に運用

---

## ベストプラクティス まとめ

### 1. 機密情報管理

```yaml
✅ GitHub Secrets を使用
✅ .gitignore で機密ファイルを除外
✅ 環境変数として注入
❌ コード内にハードコーディング禁止
❌ ログ出力で機密情報を表示しない
```

### 2. セキュリティスキャン

```yaml
✅ IaC: Checkov でインフラスキャン
✅ Container: Trivy でイメージスキャン
✅ soft_fail を適切に使用
✅ SARIF 形式でレポート保存
✅ continue-on-error でレジリエンス確保
```

### 3. ワークフロー設計

```yaml
✅ scan → build → deploy の段階的実行
✅ needs: でジョブ依存関係を明示
✅ outputs: で前ジョブの結果を引き継ぎ
✅ if: always() で確実にアップロード
✅ continue-on-error でオプショナル処理
```

### 4. GitHub Actions バージョン管理

```yaml
✅ @v3 など明示的なバージョン指定
✅ Dependabot で自動更新
✅ 非推奨化スケジュールの監視
✅ breaking changes のテスト
```

### 5. エラーハンドリング

```yaml
✅ continue-on-error: true （失敗許容）
✅ if: always() （常に実行）
✅ if: failure() （失敗時のみ）
✅ timeout-minutes: 30 （タイムアウト設定）
```

---

## 参考リンク

### GitHub Actions

- [GitHub Actions Documentation](https://docs.github.com/actions)
- [CodeQL Action v3 Migration Guide](https://github.blog/changelog/2025-01-10-code-scanning-codeql-action-v2-is-now-deprecated/)
- [GitHub Secret Scanning](https://docs.github.com/code-security/secret-scanning)

### セキュリティスキャン

- [Checkov Documentation](https://www.checkov.io/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [SARIF Format Specification](https://sarifweb.azurewebsites.net/)

### Azure セキュリティ

- [AKS Security Best Practices](https://learn.microsoft.com/azure/aks/best-practices)
- [Azure Security Baseline for AKS](https://learn.microsoft.com/security/benchmark/azure/baselines/aks-security-baseline)
- [VM Security Best Practices](https://learn.microsoft.com/azure/virtual-machines/security-recommendations)

---

## トラブルシューティング チェックリスト

### デプロイが短時間で失敗する場合

#### ✅ 確認項目

- [ ] GitHub Secrets が正しく設定されているか
  - `AZURE_CREDENTIALS` (JSON 形式)
  - `AZURE_SUBSCRIPTION_ID`
  - `MONGO_ADMIN_PASSWORD`
- [ ] Service Principal の権限が十分か（Contributor）
- [ ] Azure Provider が登録されているか
  - `Microsoft.ContainerService`
  - `Microsoft.ContainerRegistry`
  - `Microsoft.Compute`
  - `Microsoft.Network`
  - `Microsoft.Storage`
- [ ] `.gitignore` に機密情報ファイルが含まれているか
- [ ] Git 履歴に機密情報が残っていないか

#### ✅ デバッグコマンド

```powershell
# Azure ログイン確認
az account show

# Provider 登録確認
az provider list --query "[?registrationState=='Registered'].namespace" -o table

# Service Principal 権限確認
az role assignment list --assignee <CLIENT_ID> --query "[].{Role:roleDefinitionName, Scope:scope}" -o table

# ACR 確認
az acr show --name acrwizexercise --resource-group rg-wiz-exercise

# GitHub Secrets 確認（マスクされていることを確認）
# Settings > Secrets and variables > Actions
```

---

## 変更履歴

| 日付       | 変更内容                               | 理由                 |
| ---------- | -------------------------------------- | -------------------- |
| 2025-10-29 | CodeQL Action v2 → v3                  | 非推奨化対応         |
| 2025-10-29 | SARIF upload に continue-on-error 追加 | 権限エラー回避       |
| 2025-10-29 | .gitignore に機密ファイル追加          | Push Protection 対応 |
| 2025-10-29 | Git 履歴から機密情報削除               | セキュリティ強化     |

---

**最終更新**: 2025 年 10 月 29 日  
**作成者**: GitHub Copilot  
**プロジェクト**: Wiz Technical Exercise
