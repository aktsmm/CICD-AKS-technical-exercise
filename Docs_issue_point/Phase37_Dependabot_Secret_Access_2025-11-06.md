# Phase 37: Dependabot PR実行時のシークレットアクセスエラー解消

**日付**: 2025-11-06  
**カテゴリ**: GitHub Actions, Dependabot, セキュリティ

## 🚨 事象

- Dependabot PR #19 (`deps(deps): bump github/codeql-action from 3 to 4`) の実行で GitGuardian ワークフローが失敗
- エラーメッセージ: `{"detail":"Invalid token header. No credentials provided."}`
- `secrets.GITGUARDIAN_API_KEY` の参照が空になっており、APIキー検証とggshield実行がともに失敗

## 🔍 調査結果

### 1. ワークフロー定義の確認
```pwsh
git diff origin/main origin/dependabot/github_actions/github/codeql-action-4 -- .github/workflows/GitGuardian_secret-scan.yml
```

→ Dependabot ブランチでは `github/codeql-action/upload-sarif@v3` が `@v4` にバンプされているのみで、シークレット参照 `${{ secrets.GITGUARDIAN_API_KEY }}` 自体は変更されていない。

### 2. Dependabot のセキュリティ制約

GitHub 公式ドキュメント:  
- [Keeping your supply chain secure with Dependabot - GitHub Docs](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/keeping-your-actions-up-to-date-with-dependabot#accessing-secrets)

> **Dependabot が作成した PR から実行されるワークフローは、デフォルトでリポジトリシークレットにアクセスできません。**  
> これは悪意のある依存関係更新によるシークレット漏洩を防ぐためのセキュリティ機能です。

- Dependabot PRでは `secrets.*` が空文字列として評価される
- `GITHUB_TOKEN` のみ読み取り専用で利用可能
- PRをマージ後、mainブランチからの実行では通常通りシークレットにアクセス可能

## ✅ 解決策

### 方法1: Dependabot PR をマージ（推奨）

1. PR #19 のコード変更を確認（`@v3` → `@v4` のみであることを確認）
2. GitHub UI で PR #19 を **Merge** する
3. マージ後、main ブランチで自動的にワークフローが再実行され、シークレットへのアクセスが成功する

### 方法2: 手動で codeql-action を v4 へ更新

もし Dependabot PR を使わず手動更新する場合:

```pwsh
# mainブランチで作業
cd D:\00_temp\wizwork\CICD-AKS-technical-exercise

# ワークフロー内の @v3 を @v4 に置換
(Get-Content .github/workflows/GitGuardian_secret-scan.yml) -replace 'codeql-action/upload-sarif@v3', 'codeql-action/upload-sarif@v4' | Set-Content .github/workflows/GitGuardian_secret-scan.yml

# コミット・プッシュ
git add .github/workflows/GitGuardian_secret-scan.yml
git commit -m "deps: bump github/codeql-action to v4"
git push origin main
```

### 方法3: Dependabot secrets の明示的許可（非推奨）

リポジトリ設定で Dependabot に特定シークレットへのアクセスを許可できるが、セキュリティリスクが高まるため非推奨:

- Settings > Secrets and variables > Dependabot > Repository secrets で `GITGUARDIAN_API_KEY` を Dependabot secrets として再登録

## 🔁 再発防止と学び

- **Dependabot PR はシークレットアクセス不可**: Dependabot が作成した PR でシークレットを利用するワークフローは必ず失敗する
- **マージ前の動作確認は限定的**: シークレット不要なワークフロー（テスト、ビルド、静的解析など）のみ PR 時点で検証可能
- **セキュリティファースト設計**: この制約は GitHub のベストプラクティスであり、回避よりも運用設計で対応する
- **Dependabot PRレビュー手順**:
  1. 差分を確認しバージョンアップのみか検証
  2. CHANGELOGやリリースノートで破壊的変更がないか確認
  3. マージ後の main 実行でシークレット依存機能を検証

## 📝 メモ

- 今回は `codeql-action` のマイナーバージョンアップ（v3 → v4）なので破壊的変更なし
- PR #19 をマージして main で再実行すれば GitGuardian ワークフローは正常動作する
- 将来的にシークレット依存ワークフローを増やす場合、Dependabot PRでは常に失敗することを前提とした運用フローを確立する

---

**次のアクション**:
1. GitHub UI で PR #19 を確認・マージ
2. マージ後の自動実行で GitGuardian スキャン成功を確認
3. Security > Code scanning alerts に検出結果が表示されるか検証
