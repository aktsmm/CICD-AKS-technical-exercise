# Phase22: Dependabot 概要と手動実行メモ

## 目的

- `Dependabot` の役割と既存設定（`.github/dependabot.yml`）の把握に役立つ補助資料を残す。
- 手元のリポジトリで手動トリガーする手順を明文化し、運用時の即応性を高める。
- Pull Request 化を想定できる改善点・検討事項を列挙し、次のアクション候補を明確化する。

## Dependabot の概要

- Dependabot は GitHub が提供する依存パッケージ自動更新サービスで、`npm` や GitHub Actions など複数エコシステムに対応する。
- `.github/dependabot.yml` に複数の update-config を定義でき、対象パッケージのディレクトリ、スケジュール、ラベル、再試行ポリシーなどを制御できる。
- 既存設定（週次）では以下をカバー：
  - `npm` (`/app`) のデフォルトブランチに向けた更新チェック。
  - ルート (`/`) の GitHub Actions ワークフロー更新チェック。
- 参考: GitHub Docs "About Dependabot" では、サポート対象・構成要素・通知方法が説明されている [[GitHub Docs](https://docs.github.com/en/code-security/dependabot/dependabot-alerts/about-dependabot-alerts)].

## 手動実行手順

### GitHub UI からのトリガー

1. リポジトリの `Security` タブ → `Dependabot` ("Dependency graph") を開く。
2. 左ペインの `Dependabot` セクションで `Open Dependabot` ボタンを押すと、現在設定されているアップデート jobs が一覧表示される。
3. 対象エコシステム（例: `npm`）を選び、`Check for updates` をクリックすると即時チェックが実行される。
4. 処理完了後、変更があれば自動的に Pull Request が生成される。生成された PR の `Checks` で CI 通過状況を確認し、内容精査のうえマージする。
   - 上記 UI 操作は GitHub Docs "Triggering a Dependabot update" の "Check for updates" に記載のフロー [[GitHub Docs](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/triggering-a-dependabot-update)].

### `gh` CLI から API 経由でトリガー例

```powershell
# gh CLI の REST 呼び出しで npm 用の Dependabot check を手動起動
# owner/repo は対象リポジトリに置き換え
# package-ecosystem には dependabot.yml と同じ識別子を指定
$owner = "aktsmm"
$repo  = "CICD-AKS-technical-exercise"
$body  = '{"package-ecosystem":"npm","directory":"/app"}'
# POST /repos/{owner}/{repo}/dependabot/updates は GitHub Docs 参照
# 成功すると 202 Accepted が返り、バックグラウンドで更新チェックが走る
gh api -X POST `/repos/$owner/$repo/dependabot/updates` --input - --content-type application/json <<< $body
```

- CLI 操作用 API エンドポイントは GitHub Docs "Triggering a Dependabot update via API" の例を参考 [[GitHub Docs](https://docs.github.com/en/rest/dependabot/updates?apiVersion=2022-11-28#create-a-dependabot-update)].

## PR 化につながる検討事項

- **アラートラベル統一**: `target-branch` や `labels` を dependabot.yml に追加し、レビュー担当のフィルタリングを容易化。
- **バージョン戦略の明確化**: `versioning-strategy` (`increase`, `lockfile-only` など) を設定し、PR の頻度・粒度をコントロール。
- **広範囲のエコシステム追加**: パイプラインや IaC (`terraform`, `github-actions`, `docker`) にも範囲拡大するか検討。
- **失敗時リトライ戦略**: `open-pull-requests-limit` や `rebase-strategy` のチューニングで、CI 失敗後のリカバリを改善。
- **セキュリティアップデート通知**: `security-updates` (デフォルト有効) の確認と、必要に応じて Slack / Teams 通知連携。
- **PR テンプレート整備**: Dependabot 用 PR テンプレートを `.github/PULL_REQUEST_TEMPLATE` で分岐させ、レビューポイントを標準化。

## 参考資料

- GitHub Docs: About Dependabot Alerts — Dependabot の概要、サポート範囲、通知メカニズム [[GitHub Docs](https://docs.github.com/en/code-security/dependabot/dependabot-alerts/about-dependabot-alerts)]
- GitHub Docs: Triggering a Dependabot update — UI 操作や API 経由の手動実行手順 [[GitHub Docs](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/triggering-a-dependabot-update)]
- GitHub Docs: Create a Dependabot update (REST API) — gh CLI で叩けるエンドポイント仕様 [[GitHub Docs](https://docs.github.com/en/rest/dependabot/updates?apiVersion=2022-11-28#create-a-dependabot-update)]
