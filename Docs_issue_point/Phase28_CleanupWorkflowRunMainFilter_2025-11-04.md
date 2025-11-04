# Phase28: Cleanup ワークフローが workflow_run でスキップされる問題対応 (2025-11-04)

## 事象概要

- GitHub Actions ワークフロー `🧹 Cleanup Workflow Runs (Keep latest 7 human + 3 dependabot runs)` が `workflow_run` トリガーで起動した際、ジョブ条件が偽となり実行されなかった。
- 対象トリガーは `Deploy Infrastructure`, `Build and Deploy Application`, `Deploy Policy Guardrails` が `failure` / `success` で完了したときのクリーンアップ実行を想定していた。

## 原因

- 条件式が `github.ref == 'refs/heads/main'` のみを main 判定に使用していたため、`workflow_run` イベントで `github.ref` が空文字になり常に偽となっていた。
- `workflow_run` のコンテキストでは、実行元ワークフローのブランチ情報は `github.event.workflow_run.head_branch` に格納される (#microsoft.docs.mcp [GitHub Actions コンテキスト](https://docs.github.com/ja/actions/learn-github-actions/contexts#github-context) に記載)。

## 対応内容

1. `.github/workflows/cleanup.yml` の `jobs.cleanup.if` を更新し、`workflow_run` イベント時は `github.event.workflow_run.head_branch == 'main'` を評価するよう条件式を拡張。
2. 条件式全体を整理し、`workflow_run` の結論が `failure` もしくは `success` のときのみ実行する既存ロジックを維持しつつブランチ判定を共存させた。
3. 変更後に GitHub Actions ログで条件式が `workflow_run` 起動時でも真になることを確認し、クリーンアップが予定どおり実行されることを検証。

## 再発防止・実務ヒント

- `workflow_run` を利用する際は、`github.ref` ではなく `github.event.workflow_run.*` 系のプロパティを参照する。特にブランチ名は `head_branch` を用いると、手動実行やフォークからのトリガーにも安全に対応できる。
- 条件式をテストするには、ワークフロー `workflow_dispatch` を main ブランチで手動実行し、同じ条件が期待どおり評価されるか比較すると安心。
- 条件が複雑化した場合は、`steps` 内で `echo "if condition: ${{ condition }}"` のように中間値を出力し、デバッグを容易にするのが実務的。

## 参考リンク

- GitHub Actions コンテキスト一覧 (#microsoft.docs.mcp): <https://docs.github.com/ja/actions/learn-github-actions/contexts#github-context>
