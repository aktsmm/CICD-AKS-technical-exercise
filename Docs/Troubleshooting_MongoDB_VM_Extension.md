# MongoDB VM カスタムスクリプト トラブルシューティング

最終更新日: 2025-11-11  
対象リソース: `vm-mongo-dev`  
関連ワークフロー: `.github/workflows/01.infra-deploy.yml`

---

## 1. 症状の把握

- GitHub Actions の `Deploy Infrastructure` ジョブが `VMExtensionProvisioningError` で失敗する。
- Azure Portal では MongoDB VM の拡張機能が `Provisioning failed` になっている。
- `/var/log/azure/.../CustomScript/extension.log` に `apt-get` 関連エラーが記録されている。

## 2. 速攻チェックリスト

1. `az deployment group show` で失敗した拡張名を特定。
2. `az vm extension list` で状態が `Failed` のものを確認。
3. `az vm run-command invoke --command-id RunShellScript --scripts "sudo tail -n 50 /var/log/azure/Microsoft.Azure.Extensions.CustomScript/extension.log"` で直近ログを取得。
4. `sudo systemctl status mongod` でサービスが起動しているか確認。
5. `mongo --version` でバージョンが 4.4 系に固定されているか確認。

> 実運用 Tips: 失敗ログを GitHub Actions のアーティファクトとして保存しておくと、Portal へアクセスできない状況でも後追い調査が可能です。

## 3. 代表的なエラーと対処

| 症状                                           | 原因                                            | 対処                                                                                              | 備考                                                |
| ---------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| `Could not resolve host: repo.mongodb.org`     | DNS/FW がブロック                               | NSG/Firewall のポート 80,443 を解放。再実行前に `nslookup repo.mongodb.org` を実施                | GitHub Actions ランナーからのアウトバウンドも要確認 |
| `apt-get install mongodb-org=4.4.*` で 404     | リポジトリの GPG キー登録ミス or バージョン削除 | キーを Keyring 保存 (`/usr/share/keyrings`)、バージョン固定 (`4.4.29`) で再実行                   | 今回の修正で防止済み                                |
| `systemctl status mongod` が `inactive (dead)` | 設定ファイルに `bindIp` が存在せず起動失敗      | `sed` で追加した `net.bindIp` 設定を確認。`/etc/mongod.conf` に `net:` セクションがあるかチェック | `mongod --config` で読み込みパスを再確認            |
| `mongo` コマンドが `command not found`         | PATH 未設定 or インストール失敗                 | `which mongo`、`ls /usr/bin/mongo` でバイナリ位置を確認                                           | `/var/log/mongodb/version.log` の証跡を活用         |

## 4. ワークフローからの再実行手順

1. `main` ブランチを最新に更新 (`git pull`)。
2. `infra/scripts/install-mongodb.sh` の修正を取り込んでコミット。
3. GitHub Actions の `01.infra-deploy` を手動再実行 (`Run workflow` → `main`)。
4. 成功後、`deploy-success-<date>` のタグを作成しロールバックポイントを確保。

> 実運用 Tips: 再実行前に `az vm extension delete` で失敗したカスタムスクリプト拡張を削除すると、再適用がスムーズです。

## 5. 調査ログの保全

- `/var/log/azure/Microsoft.Azure.Extensions.CustomScript/extension.log`
- `/var/log/cloud-init-output.log`
- `/var/log/apt/history.log`
- GitHub Actions の `Az CLI Deploy` ステップログ

### 推奨保存場所

`Docs_issue_point/Phase02_アプリデプロイ問題と解決_2025-10-29.md` に調査メモを追記し、関連スクリーンショットは `Docs/demo-captures/` に保管。

## 6. 参考資料

- #microsoft.docs.mcp: [Linux 用カスタムスクリプト拡張のトラブルシューティング](https://learn.microsoft.com/azure/virtual-machines/extensions/custom-script-linux-troubleshoot) — カスタムスクリプト拡張のログ確認手順と一般的な失敗要因がまとまっています。
- MongoDB: [Install MongoDB Community Edition on Ubuntu (v4.4)](https://www.mongodb.com/docs/v4.4/tutorial/install-mongodb-on-ubuntu/) — 旧バージョンのパッケージ取得手順を参照できます。

> 実運用 Tips: `az vm extension set --name customScript` を使えば GitHub Actions を待たずに再実行できるため、緊急時の現場調査に役立ちます。

## 7. 再発防止策

- GitHub Actions のデプロイ前に `infra/scripts/install-mongodb.sh` へ `shellcheck` を走らせ、構文エラーや未定義変数を検出する。
- カスタムスクリプト拡張の結果を `az deployment group show --query properties.outputs` で JSON 保存し、失敗時の差分を Pull Request にコメントする仕組みを追加する。
- MongoDB リポジトリの廃止予定を把握できるよう、[MongoDB リリースノート](https://www.mongodb.com/docs/manual/release-notes/) をウォッチし、バージョンが撤去される前にアーカイブを確保する。

> 実運用 Tips: `shellcheck infra/scripts/install-mongodb.sh` を PR パイプラインに組み込むと、レビュー前にリグレッションを自動検出できます。
