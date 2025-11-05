# GitHub Code Scanning の有効化手順

## 現状

- ✅ SARIF ファイルは正しく生成されている（715 bytes）
- ✅ ワークフローサマリーに検出結果が表示されている
- ❌ Security > Code scanning alerts タブに表示されない

## 考えられる原因と対策

### 1. Code Scanning の初回有効化が必要

GitHub リポジトリで初めて Code Scanning を使う場合、明示的に有効化する必要がある場合があります。

**確認手順**:

1. リポジトリの **Settings** タブを開く
2. 左メニューの **Code security and analysis** をクリック
3. **Code scanning** セクションを確認
4. もし "Set up" ボタンがある場合はクリック
5. "Advanced" を選択（既にワークフローがあるため）

### 2. SARIF アップロード権限の確認

ワークフローの `permissions` が正しく設定されているか確認。

現在の設定（GitGuardian_secret-scan.yml）:

```yaml
permissions:
  contents: read
  security-events: write # ✅ これが必要
```

### 3. GitHub Advanced Security の有効化（Private リポジトリの場合）

Private リポジトリの場合、GitHub Advanced Security (GHAS) を有効化する必要があります。

**確認手順**:

1. Settings > Code security and analysis
2. **GitHub Advanced Security** を探す
3. 無効の場合は "Enable" をクリック

Public リポジトリの場合は不要です。

### 4. SARIF フォーマットの検証

生成された SARIF が GitHub の仕様に完全準拠しているか確認。

**確認方法**:

- Actions の Run #25 から `ggshield-sarif` アーティファクトをダウンロード
- 内容を確認して、`results[]` が空でないことを確認
- Microsoft の SARIF Validator で検証: https://sarifweb.azurewebsites.net/Validation

### 5. 処理の遅延

GitHub 側で SARIF の処理に時間がかかっている可能性。

**対応**:

- 5〜10 分待ってから Security タブを再確認
- ブラウザのキャッシュをクリア（Ctrl + Shift + R）

### 6. Code scanning alerts の表示フィルタ

Security タブにアラートがあっても、フィルタで非表示になっている可能性。

**確認手順**:

1. Security > Code scanning alerts を開く
2. 画面上部のフィルタを確認
3. "is:open" や "is:closed" などのフィルタをクリア
4. "Tool: GitGuardian ggshield" でフィルタしてみる

## 推奨される次のアクション

1. **5 分待ってから再確認**

   - GitHub の処理遅延の可能性が高い
   - https://github.com/aktsmm/CICD-AKS-technical-exercise/security/code-scanning

2. **Settings で Code security を確認**

   - Settings > Code security and analysis
   - Code scanning が有効になっているか確認

3. **SARIF アーティファクトをダウンロードして検証**

   - `results[]` が空でないか確認
   - ファイルパスが正しいか確認

4. **ワークフローを再実行**
   - Actions タブで最新の実行を開く
   - "Re-run all jobs" をクリック
   - 再実行後に Security タブを確認

## トラブルシューティングコマンド

```bash
# SARIF の内容を確認（アーティファクトをダウンロード後）
jq '.' ggshield-results.sarif

# results の数を確認
jq '.runs[0].results | length' ggshield-results.sarif

# 検出されたファイルを確認
jq -r '.runs[0].results[].locations[0].physicalLocation.artifactLocation.uri' ggshield-results.sarif
```
