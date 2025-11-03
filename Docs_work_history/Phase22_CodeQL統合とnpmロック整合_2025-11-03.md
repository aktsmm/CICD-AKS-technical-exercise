# Phase 22: CodeQL 統合と npm ロックファイル整合性回復

**日時**: 2025 年 11 月 3 日 09:30-10:10 JST  
**目的**: CI/CD セキュリティ強化 (CodeQL 統合) と `npm ci` 失敗の根本解消

---

## ✅ 実施内容ハイライト

1. **CodeQL 解析を `app-deploy` ワークフローへ統合**

   - 既存の `codeql.yml` を廃止し、`codeql-analysis` ジョブを `.github/workflows/app-deploy.yml` へ追加。
   - `build-push` ジョブの `needs` に `codeql-analysis` を設定し、静的解析と Trivy スキャンがそろって完了した後にビルドへ進む構成に変更。
   - CodeQL 実行前に `npm ci` を走らせることで、依存関係の整合性チェックと静的解析を一度に行えるようにした。

2. **Dependabot 構成の導入**

   - `.github/dependabot.yml` を新規追加し、`/app` ディレクトリの npm 依存とリポジトリ直下の GitHub Actions を週次でチェックするよう設定。
   - 今後の依存更新 PR によって lockfile のズレが早期検知できる体制になった。

3. **`npm ci` エラー (EUSAGE) の解消**
   - CodeQL ジョブ追加後、`npm ci` が `package.json` と `package-lock.json` の不整合で失敗。
   - `npm install` および最新版パッチ (`express@4.21.2` など) の適用で `package.json` を更新し、`package-lock.json` を完全再生成。
   - ローカルで `npm ci` を再実行して成功を確認後、`deps: sync app dependencies for npm ci` をコミット。

---

## 🗂️ 変更ファイル

- `.github/workflows/app-deploy.yml`  
  (CodeQL ジョブ追加、`needs` 依存関係更新)
- `.github/workflows/codeql.yml`  
  (廃止)
- `.github/dependabot.yml`  
  (新規追加)
- `app/package.json` / `app/package-lock.json`  
  (依存バージョン更新と lockfile 再生成)
- `Docs_issue_point/Phase22_npm_ciロックファイル同期_2025-11-03.md`  
  (今回のトラブル詳細を記録)

---

## 🔁 検証 & 実行ログ

- `npm install` → `npm ci` をローカルで実行し、CI と同条件で成功することを確認。
- `git push` 後に GitHub Actions (`Build and Deploy Application`) を手動確認し、`codeql-analysis` → `scan-container` → `build-push` の順に通過することをチェック。

---

## 🔗 コミット/リファレンス

- `eb4b5f4` – `ci: integrate CodeQL into app deployment`
- `2f0a560` – `deps: sync app dependencies for npm ci`

---

## 💡 実務 Tip

- **CodeQL などの SAST を導入する際は、先頭で `npm ci` を実行する**と、依存解決エラーを静的解析より前に弾けるので調査コストを抑えられます。
- lockfile を手動編集した場合でも、**コミット前に必ず `npm ci`** をローカル実行して pipeline と揃った状態を保証しましょう。
- Dependabot PR は自動生成された直後に `npm ci` が通るかを確認し、必要なら `npm install --package-lock-only` で lockfile だけ更新する運用を組み込むと安全です。
