# Phase 38: Security タブへの SARIF 反映が未解決

**日付**: 2025-11-06  
**カテゴリ**: GitHub Code Scanning, SARIF, GitGuardian  
**ステータス**: 🔴 未解決（調査継続中）

## 🚨 事象

GitGuardian の秘匿情報検出結果が、ワークフローの Job Summary には表示されるが、**Security > Code scanning alerts タブには表示されない**。

### 現在の動作状況

✅ **正常に動作している箇所**:
- GitGuardian ggshield がシークレットを正しく検出（exit code 1）
- JSON 出力が正しく生成される
- SARIF 変換が成功（715 bytes → 正常なサイズ）
- ワークフロー Summary に検出ファイル・ルールが表示
- SARIF artifact のダウンロード・確認可能

❌ **問題が発生している箇所**:
- Security > Code scanning alerts タブに何も表示されない
- アラート数が 0 のまま
- フィルタを変更しても検出結果が見つからない

### 検出内容（Summary より）

- **検出ファイル**: `app/wizexercise.txt`
- **検出ルール**: `GGSHIELD_Generic_Password`
- **検出位置**: 22行目、17-33列
- **内容**: Generic Password (`dhs**********GwL`)

## 🔍 実施した対応

### 1. SARIF スキーマの修正（実施済み）

#### 最初の試み
- `originalUriBaseIds` に `SRCROOT` を定義
- `uriBaseId: "SRCROOT"` を artifactLocation に追加
- **結果**: 反映されず

#### 現在の SARIF 形式（簡素化版）
```json
{
  "runs": [{
    "tool": {
      "driver": {
        "name": "GitGuardian ggshield",
        "version": "1.0.0",
        "rules": [...]
      }
    },
    "results": [{
      "ruleId": "GGSHIELD_Generic_Password",
      "level": "error",
      "locations": [{
        "physicalLocation": {
          "artifactLocation": {
            "uri": "app/wizexercise.txt"
          },
          "region": {
            "startLine": 22,
            "startColumn": 17,
            "endColumn": 33
          }
        }
      }]
    }],
    "columnKind": "utf16CodeUnits"
  }]
}
```

**変更履歴**:
- commit `81ef90e`: `SRCROOT` 定義追加、category 固定
- commit `0e63663`: tool version 追加、checkout_path 指定
- commit `146abe5`: ggshield 最新スキーマ対応
- commit `10c8e0b`: SARIF 簡素化（uriBaseId 削除、checkout_path 削除）

### 2. ワークフローの調整（実施済み）

#### upload-sarif ステップ
```yaml
- name: Upload SARIF to GitHub Security tab
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: ggshield-results.sarif
    category: GitGuardian ggshield
  continue-on-error: true
```

**試した設定**:
- ✅ `category` の固定
- ✅ `checkout_path` の明示（→削除）
- ✅ `wait-for-processing: true`（→削除）
- ✅ `continue-on-error: true` でエラーハンドリング

### 3. デバッグステップの追加（実施済み）

- ggshield JSON 出力の確認
- SARIF 内容の表示
- アップロード状態のチェック
- artifact としての保存

### 4. 権限の確認（実施済み）

```yaml
permissions:
  contents: read
  security-events: write  # ✅ 正しく設定済み
```

## 🤔 考えられる原因

### 1. GitHub Advanced Security (GHAS) 未有効化
**可能性**: 🔴 高（Private リポジトリの場合）

- Private リポジトリでは GHAS のライセンスが必要
- Settings > Code security and analysis で確認必要
- Public リポジトリの場合は不要

**確認方法**:
1. リポジトリの Settings タブを開く
2. 左メニュー「Code security and analysis」をクリック
3. 「GitHub Advanced Security」セクションを確認
4. "Disabled" の場合は "Enable" をクリック

### 2. Code Scanning の初回セットアップ未完了
**可能性**: 🟡 中

- リポジトリで Code Scanning を一度も有効化していない
- 明示的なセットアップが必要な場合がある

**確認方法**:
1. Settings > Code security and analysis
2. "Code scanning" セクションを確認
3. "Set up" ボタンがある場合はクリック → "Advanced" を選択

### 3. SARIF フォーマットの互換性問題
**可能性**: 🟡 中

- GitHub が認識できない SARIF 要素が含まれている
- `columnKind: "utf16CodeUnits"` が問題の可能性
- ルール定義の形式が不適切

**検証方法**:
- Microsoft SARIF Validator で検証: https://sarifweb.azurewebsites.net/Validation
- 他のツール（Checkov, Trivy）の SARIF と比較

### 4. GitHub 側の処理遅延
**可能性**: 🟢 低（時間経過で解消するはず）

- SARIF アップロード後、処理に数分〜数十分かかる場合がある
- 初回は特に時間がかかる可能性

**対応**:
- 5〜10分待機
- ブラウザキャッシュをクリア（Ctrl + Shift + R）

### 5. リポジトリのデフォルトブランチ設定
**可能性**: 🟢 低（確認済み: main が default）

- Code Scanning はデフォルトブランチのアラートのみ表示
- 現在の設定: `main` ← ✅ 正常

### 6. codeql-action のバージョン問題
**可能性**: 🟡 中

- 現在使用: `github/codeql-action/upload-sarif@v3`
- v4 へのアップデートで改善する可能性
- Dependabot PR #19 がマージ待ち

## 📋 今後の調査項目

### 優先度 高

1. **GitHub Advanced Security の状態確認**
   ```bash
   # Settings > Code security and analysis
   # → GitHub Advanced Security の Enabled/Disabled を確認
   ```

2. **Code Scanning の初回セットアップ**
   ```bash
   # Settings > Code security and analysis > Code scanning
   # → "Set up" ボタンの有無を確認
   ```

3. **他のツールとの比較**
   - Checkov の SARIF が Security タブに表示されているか確認
   - 表示されている場合、SARIF の差分を調査

### 優先度 中

4. **SARIF Validator での検証**
   - artifact をダウンロード
   - https://sarifweb.azurewebsites.net/Validation で検証
   - エラー・警告の確認

5. **codeql-action v4 へのアップデート**
   ```bash
   # Dependabot PR #19 をマージ
   # または手動で @v3 → @v4 に変更
   ```

6. **columnKind の削除テスト**
   ```python
   # ggshield_to_sarif.py から以下を削除して再テスト
   # "columnKind": "utf16CodeUnits",
   ```

### 優先度 低

7. **GitHub Support への問い合わせ**
   - SARIF が正しくアップロードされているか確認
   - GitHub 側のログを確認してもらう

8. **代替ツールの検討**
   - GitLeaks など他のシークレットスキャンツールとの比較
   - ggshield の代わりに TruffleHog を試す

## 🔗 参考リソース

### GitHub 公式ドキュメント
- [Code scanning について](https://docs.github.com/ja/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning)
- [SARIF ファイルのアップロード](https://docs.github.com/ja/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github)
- [SARIF サポート](https://docs.github.com/ja/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning)

### SARIF 仕様
- [SARIF v2.1.0 Schema](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)
- [SARIF Validator](https://sarifweb.azurewebsites.net/Validation)

### GitGuardian ドキュメント
- [ggshield 公式ドキュメント](https://docs.gitguardian.com/ggshield/reference/commands/secret_scan)
- [CI/CD 統合ガイド](https://docs.gitguardian.com/ggshield-docs/integrations/ci-cd-integrations)

## 💡 一時的な回避策

Security タブへの反映ができない間の代替手段：

1. **Job Summary の活用**
   - ワークフロー実行後、Summary タブで検出結果を確認
   - 検出ファイルとルールが一覧表示される

2. **Artifact のダウンロード**
   - `ggshield-sarif` と `ggshield-json` を手動でダウンロード
   - ローカルで内容を確認

3. **GitGuardian Dashboard**
   - https://dashboard.gitguardian.com/ で検出履歴を確認
   - API 経由での統合管理

4. **手動レビュー**
   - 検出された `app/wizexercise.txt` の 22行目を直接確認
   - 該当シークレットの妥当性を判断

## 📝 メモ

- 2025-11-06 時点で 10回以上の SARIF アップロードを実施
- すべて Summary には反映、Security タブには 0 件
- SARIF の内容自体は正しい（rules, results, locations すべて適切）
- 他のセキュリティスキャンツール（Checkov, Trivy）の状況も併せて確認が必要

---

**次のアクション**:
1. Settings > Code security and analysis を開いて GHAS の状態を確認
2. 確認結果をこのドキュメントに追記
3. 必要に応じて GitHub Support へ問い合わせ
