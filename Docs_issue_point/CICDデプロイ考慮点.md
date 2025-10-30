# Phase 0: GitHub Push Protection エラー

**発生日時**: 2025 年 1 月 29 日  
**フェーズ**: Phase 0 - プロジェクトセットアップ  
**重要度**: 🔴 Critical  
**ステータス**: ✅ 解決済み

---

## 📋 概要

CICD-AKS-Technical Exercise プロジェクトの初回コミット時に GitHub Push Protection が機密情報を検出し、push がブロックされた問題と解決策をまとめたドキュメント。

---

## 🔥 エラーメッセージ (全文)

```
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote: - GITHUB PUSH PROTECTION
remote:   - Push cannot contain secrets
remote:   —— Azure Active Directory Application Secret —————————
remote:   Secret scanning found 1 Azure Active Directory Application Secret secret(s) in your push.
remote:
remote:   The following secrets were found:
remote:   - docs/AZURE_SETUP_INFO.md (line 12): clientSecret: "xxxx..."
remote:
remote:   To push this commit, remove the secret or allow the secret to be pushed.
```

**発生箇所**:

- ファイル: `docs/AZURE_SETUP_INFO.md`
- 行番号: 12 行目
- Git コマンド: `git push origin main`

---

## 🔍 原因分析

### 根本原因

- `docs/AZURE_SETUP_INFO.md` に Azure Service Principal の `clientSecret` が平文で記載されていた
- GitHub の Secret Scanning (Push Protection) が機密情報を自動検出
- セキュリティポリシーにより push が自動的にブロック

### なぜ発生したか

1. プロジェクトセットアップ時に Azure 認証情報をドキュメント化
2. `.gitignore` に `docs/AZURE_SETUP_INFO.md` を追加し忘れた
3. Git commit / push 前に機密情報の確認を怠った

---

## 🛠️ 試行錯誤の記録

### 試行 1: 該当行の削除のみ

**実行内容**:

- `docs/AZURE_SETUP_INFO.md` から `clientSecret` の行を削除
- 再度 `git push` を試行

**結果**: ❌ 失敗

**分析**:

- Git 履歴に機密情報が残っているため、GitHub が過去のコミットもスキャン
- 履歴を書き換えない限り push できない

### 試行 2: Git 履歴のリセットと再構築

**実行内容**:

1. 問題のコミットより前にリセット

   ```powershell
   git reset --soft deda077
   ```

2. `.gitignore` に機密情報ファイルを追加

   ```gitignore
   # Secrets and credentials (DO NOT COMMIT)
   docs/AZURE_SETUP_INFO.md
   mongo_password.txt
   *.secret
   *.credentials
   ```

3. クリーンな履歴で再コミット

   ```powershell
   git commit -m "Initial commit: Complete CICD-AKS-Technical Exercise..."
   ```

4. 強制プッシュで履歴を上書き
   ```powershell
   git push --force origin main
   ```

**結果**: ✅ 成功

**分析**:

- Git 履歴を完全にクリーンアップしたことで、GitHub の Secret Scanning をパス
- 機密情報ファイルが `.gitignore` で除外されているため、今後も安全

---

## ✅ 最終的な解決方法

### 対応内容

**ステップ 1: `.gitignore` に機密情報ファイルを追加**

```gitignore
# Secrets and credentials (DO NOT COMMIT)
docs/AZURE_SETUP_INFO.md
mongo_password.txt
*.secret
*.credentials
```

**ステップ 2: Git 履歴から機密情報を削除**

```powershell
# 問題のコミットより前にリセット
git reset --soft deda077

# 機密情報を除外してクリーンな履歴で再コミット
git commit -m "Initial commit: Complete CICD-AKS-Technical Exercise..."

# 強制プッシュで履歴を上書き (⚠️ 注意: 共同作業者がいる場合は事前連絡)
git push origin main --force
```

**変更したファイル**:

- `.gitignore` (機密情報ファイルを追加)
- Git 履歴 (強制プッシュで上書き)

**実施日時**: 2025 年 1 月 29 日

---

## 🔄 再発防止策

### 1. プロジェクト開始時の `.gitignore` 整備

**対応内容**:

- プロジェクト開始直後に機密情報ファイルを `.gitignore` に追加
- テンプレートを用意して標準化

**確認コマンド**:

```powershell
# .gitignore に機密情報パターンが含まれるか確認
cat .gitignore | Select-String "secret|credential|password"
```

### 2. プリコミットフックの導入

**対応内容**:

- Git hooks で機密情報を自動検出
- コミット前に警告を表示

**実装例** (`.git/hooks/pre-commit`):

```bash
#!/bin/sh
# 機密情報パターンを検出
if git diff --cached | grep -i "clientSecret\|password\|apiKey"; then
    echo "警告: 機密情報が含まれている可能性があります"
    exit 1
fi
```

### 3. Azure 認証情報の管理方法の統一

**対応内容**:

- GitHub Secrets で一元管理
- ローカル参照用は `Docs_Secrets/` に記録 (`.gitignore` で除外済み)
- ドキュメントには認証情報を記載しない

### 4. チーム内での周知徹底

**対応内容**:

- 機密情報の扱い方をドキュメント化
- `.github/copilot-instructions.md` に記載
- 定期的な確認とレビュー

---

## 📚 参考情報

### GitHub 関連

- [GitHub Secret Scanning](https://docs.github.com/ja/code-security/secret-scanning/about-secret-scanning)
- [GitHub Push Protection](https://docs.github.com/ja/code-security/secret-scanning/push-protection-for-repositories-and-organizations)
- [Git 履歴から機密情報を削除する方法](https://docs.github.com/ja/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)

---

## ✅ 解決確認チェックリスト

- [x] `.gitignore` に機密情報ファイルを追加
- [x] Git 履歴から機密情報を削除
- [x] 強制プッシュで履歴を上書き
- [x] GitHub への push が成功
- [x] `Docs_Secrets/` ディレクトリを作成し、機密情報を移動
- [x] ドキュメントに再発防止策を記載

---

**作成者**: aktsmm  
**最終更新**: 2025 年 1 月 29 日  
**関連ドキュメント**:

- `Docs_Secrets/README.md` - 機密情報管理ガイドライン
- `.github/copilot-instructions.md` - プロジェクトガイドライン
- `Phase00-01_GitHubActions修正_2025-01-29.md` - GitHub Actions の修正履歴

---

---

# その他のトラブル (参考記録)

以下は、Phase 0 以降で発生した他のトラブルの簡易記録です。
詳細は各フェーズの専用ドキュメントを参照してください。

---

## トラブル: CodeQL Action v2 非推奨

**発生日時**: 2025 年 1 月 29 日  
**重要度**: 🟡 Warning  
**ステータス**: ✅ 解決済み

**概要**:
GitHub Actions ワークフローで `github/codeql-action/upload-sarif@v2` を使用していたが、v2 が非推奨化された。

**解決方法**:

- `@v2` → `@v3` に更新
- `continue-on-error: true` を追加

**詳細**: `Phase00-01_GitHubActions修正_2025-01-29.md` 参照

---

## トラブル: Artifact Actions v3 非推奨

**発生日時**: 2025 年 1 月 29 日  
**重要度**: 🔴 Critical  
**ステータス**: ✅ 解決済み

**概要**:
`actions/upload-artifact@v3` と `actions/download-artifact@v3` が非推奨化され、ワークフローが失敗。

**解決方法**:

- `@v3` → `@v4` に更新
- ダウンロードパスを `outputs/` に変更

**詳細**: `Phase00-01_GitHubActions修正_2025-01-29.md` 参照

---

## トラブル: SARIF Upload 権限エラー

**発生日時**: 2025 年 1 月 29 日  
**重要度**: 🟡 Warning  
**ステータス**: ✅ 解決済み

**概要**:
GitHub Actions が Code Scanning に SARIF ファイルをアップロードする権限がない。

**解決方法**:

- `continue-on-error: true` を追加
- セキュリティスキャン失敗でもデプロイ継続

**詳細**: セキュリティスキャンはオプショナルな機能として扱う

---

## トラブル: Checkov セキュリティスキャンの失敗

**発生日時**: 2025 年 1 月 29 日  
**重要度**: 🔵 Info (意図的な脆弱性)  
**ステータス**: ✅ 解決済み

**概要**:
Checkov が 12 個のセキュリティ違反を検出。このプロジェクトは Wiz のデモ用に意図的に脆弱な構成を含む。

**解決方法**:

- `soft_fail: true` を設定済み
- 検出はするがデプロイは継続

**検出された主な脆弱性**:

- AKS: ローカル管理者有効、ネットワークポリシー未設定
- VM: パスワード認証使用、暗号化なし

---

**このファイルの管理**:

- 上記のトラブルは参考記録として保持
- 詳細なトラブル対応は各フェーズの専用ドキュメント参照
- 新しいトラブルは Phase 別に新規ファイルを作成

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
az acr show --name acrwizexercise --resource-group rg-cicd-aks

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
**プロジェクト**: CICD-AKS-Technical Exercise
