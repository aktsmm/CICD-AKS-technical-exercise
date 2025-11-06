# セキュリティスキャン失敗ポリシー - 設計判断と実装ガイド

**作成日**: 2025-11-06  
**カテゴリ**: CI/CD セキュリティポリシー  
**対象**: Checkov, Trivy, CodeQL, GitGuardian

---

## 📋 現在の設定

### 🎯 意図的に Fail させない設計

本プロジェクトでは、**セキュリティスキャンの検出結果をワークフローの失敗条件にしない**設計を採用しています。

#### 現在の設定値

| スキャンツール    | 設定箇所                           | 設定値                                            | 動作                     |
| ----------------- | ---------------------------------- | ------------------------------------------------- | ------------------------ |
| Checkov (IaC)     | `01.infra-deploy.yml`              | `soft_fail: true` + `continue-on-error: true`     | 検出があってもジョブ成功 |
| Trivy (IaC)       | `01.infra-deploy.yml`              | `exit-code: 0` + `continue-on-error: true`        | 検出があってもジョブ成功 |
| Trivy (Container) | `02-1.app-deploy.yml`              | `exit-code: 0` + `continue-on-error: true`        | 検出があってもジョブ成功 |
| CodeQL            | `02-1.app-deploy.yml`              | `continue-on-error: true` (全ステップ)            | 検出があってもジョブ成功 |
| GitGuardian       | `02-3.GitGuardian_secret-scan.yml` | `exit 0` (スクリプト) + `continue-on-error: true` | 検出があってもジョブ成功 |

> **統一ポリシー**: すべてのセキュリティスキャンで `continue-on-error: true` を設定し、検出や失敗があってもワークフローを継続します。

#### 設定例

```yaml
# 01.infra-deploy.yml
- name: Run Checkov Scan
  uses: bridgecrewio/checkov-action@master
  with:
    directory: infra/
    framework: bicep
    soft_fail: true # ✅ 検出があってもジョブは成功
  continue-on-error: true # ✅ 統一: スキャン失敗でもジョブ続行

- name: Run Trivy Config Scan
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: config
    exit-code: 0 # ✅ 検出があっても exit code 0
  continue-on-error: true # ✅ 統一: スキャン失敗でもジョブ続行

- name: Upload Checkov Results
  continue-on-error: true # ✅ アップロード失敗でもワークフロー続行
```

> **ポイント**: `soft_fail: true` や `exit-code: 0` でスキャンツール自体の挙動を制御し、`continue-on-error: true` で GitHub Actions レベルでも失敗を許容しています。

---

## 🤔 なぜ Fail させないのか？

### 1. **実演目的のプロジェクト**

**理由**: 意図的に脆弱性を含む構成を実装し、Wiz 等のツールで検出できることを証明する

**具体例**:

- ✅ MongoDB 4.4 (旧バージョン) → CKV_CUSTOM_MONGODB_VERSION
- ✅ SSH 公開 (0.0.0.0/0) → CKV_AZURE_1
- ✅ Storage Account HTTP 許可 → CKV_AZURE_206
- ✅ VM 過剰権限 (Contributor) → カスタムポリシー違反

**メリット**:

```
脆弱な構成 → スキャン実行 → Security タブで可視化 → 面接で実演
```

もし fail させると、**脆弱な構成がデプロイできず、実演不可能**になる。

---

### 2. **継続的インテグレーション (CI) の維持**

**理由**: セキュリティ改善のための変更がブロックされないようにする

**実務での課題例**:

| シナリオ                | Fail 設定の問題                               | Soft-fail 設定の利点            |
| ----------------------- | --------------------------------------------- | ------------------------------- |
| 新しい Azure 機能の検証 | スキャンツールが未対応で誤検出 → デプロイ不可 | ⚠️ 警告は出るがデプロイ可能     |
| ポリシーの段階的適用    | 全違反を一度に修正しないとデプロイ不可        | ✅ 優先度順に段階的に改善       |
| 緊急のホットフィックス  | セキュリティ違反で本番デプロイ不可            | ⚠️ 警告を記録しつつデプロイ可能 |

**本プロジェクトの場合**:

```
Step 1: 脆弱な構成をデプロイ (実演用)
Step 2: スキャン結果を Security タブで可視化
Step 3: 面接で「このように検出できます」と説明
Step 4: (オプション) 改善版をデプロイして Before/After を比較
```

---

### 3. **可視性とトレーサビリティの重視**

**理由**: Security タブと Artifacts に結果を保存し、後から分析可能にする

**実装**:

```yaml
- name: Upload Checkov Results
  uses: github/codeql-action/upload-sarif@v3
  if: always() # ✅ ジョブが失敗しても必ず実行
  continue-on-error: true
  with:
    sarif_file: checkov-results.sarif
```

**メリット**:

1. ✅ GitHub Security タブで検出結果を一覧表示
2. ✅ SARIF ファイルを Artifact として保存
3. ✅ 履歴として残り、改善傾向を追跡可能
4. ✅ 面接で「このように検出・管理しています」と提示できる

---

### 4. **DevSecOps の段階的導入**

**理由**: いきなり厳格なポリシーを適用すると開発速度が低下する

**段階的アプローチ** (実務のベストプラクティス):

```
Phase 1 (現在): 検出のみ (exit-code: 0)
  ↓ セキュリティ意識の醸成
Phase 2: CRITICAL のみ Fail (exit-code: 1 if severity=CRITICAL)
  ↓ 重大な脆弱性の排除
Phase 3: HIGH 以上 Fail (exit-code: 1 if severity=HIGH,CRITICAL)
  ↓ セキュリティ基準の向上
Phase 4: カスタムポリシー適用 (allowlist管理)
```

**本プロジェクトは Phase 1 を意図的に維持**

---

## 🚨 Fail させる実装方法 (3 パターン)

必要に応じて Fail させる設定に変更できます。以下は実装パターンです。

### パターン 1: Exit Code 制御 (最もシンプル)

#### Checkov

```yaml
- name: Run Checkov Scan
  uses: bridgecrewio/checkov-action@master
  with:
    directory: infra/
    framework: bicep
    soft_fail: false # ✅ 変更: true → false
    # 検出があるとジョブが失敗し、deploy-infraジョブが実行されない
```

#### Trivy

```yaml
- name: Run Trivy Config Scan
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: config
    exit-code: 1 # ✅ 変更: 0 → 1
    severity: CRITICAL,HIGH
    # CRITICAL or HIGH が検出されるとジョブ失敗
```

**メリット**:

- ✅ 1 行変更で即座に有効化
- ✅ シンプルで分かりやすい

**デメリット**:

- ❌ SARIF アップロードが実行されない (ジョブが途中で停止)
- ❌ Security タブに結果が表示されない

---

### パターン 2: SARIF 出力 + 別ジョブで解析 (推奨)

Security タブへの連携を維持しつつ、検出時にデプロイを停止します。

#### 実装例

```yaml
jobs:
  scan-iac:
    name: Scan IaC for Security Issues
    runs-on: ubuntu-latest
    outputs:
      has-critical: ${{ steps.analyze.outputs.has-critical }}
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Run Checkov Scan
        uses: bridgecrewio/checkov-action@master
        with:
          directory: infra/
          framework: bicep
          output_format: sarif
          output_file_path: checkov-results.sarif
          soft_fail: true # ✅ SARIF生成のため true のまま

      - name: Upload Checkov Results
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: checkov-results.sarif

      - name: Analyze SARIF for Critical Issues
        id: analyze
        run: |
          # SARIF から CRITICAL/HIGH の件数を抽出
          CRITICAL_COUNT=$(jq '[.runs[].results[] | select(.level=="error" or .level=="warning")] | length' checkov-results.sarif)

          echo "Critical/High issues found: $CRITICAL_COUNT"

          if [ "$CRITICAL_COUNT" -gt 0 ]; then
            echo "has-critical=true" >> $GITHUB_OUTPUT
            echo "::error::Found $CRITICAL_COUNT critical/high security issues"
          else
            echo "has-critical=false" >> $GITHUB_OUTPUT
          fi

  deploy-infra:
    name: Deploy Azure Infrastructure
    runs-on: ubuntu-latest
    needs: scan-iac
    if: needs.scan-iac.outputs.has-critical != 'true' # ✅ CRITICAL検出時はスキップ
    steps:
      - name: Deploy Infrastructure
        # ... デプロイ処理
```

**メリット**:

- ✅ Security タブに結果が表示される
- ✅ SARIF を Artifact として保存
- ✅ 検出時にデプロイがスキップされる
- ✅ エラーメッセージがワークフロー UI に表示

**デメリット**:

- ⚠️ ワークフロー定義が複雑になる
- ⚠️ SARIF 解析ロジックのメンテナンスが必要

---

### パターン 3: Allowlist 管理 (本番運用向け)

特定のルールを除外しつつ、他は厳格に管理します。

#### Checkov Skip 設定

```yaml
# infra/modules/storage.bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  // checkov:skip=CKV_AZURE_206:実演用に意図的にHTTPを許可
  // checkov:skip=CKV_AZURE_43:実演用に意図的に公開アクセスを許可
  properties: {
    supportsHttpsTrafficOnly: false
    allowBlobPublicAccess: true
  }
}
```

#### Trivy Ignore ファイル

```yaml
# .trivyignore
# 実演目的で意図的に許可する脆弱性

# MongoDB VM: SSH公開 (実演用)
AVD-AZU-0039

# Storage Account: HTTP許可 (実演用)
AVD-AZU-0017

# 注意: 本番環境では削除すること
```

#### Checkov Baseline ファイル

```yaml
# .checkov.baseline.yaml
# 既知の許容される違反を記録

skip_checks:
  - check: CKV_AZURE_1
    comment: "実演用にSSH公開を許可 (本番では禁止)"
    file: infra/modules/vm-mongodb.bicep

  - check: CKV_AZURE_206
    comment: "バックアップ検証のためHTTP許可 (本番では禁止)"
    file: infra/modules/storage.bicep
```

#### ワークフロー設定

```yaml
- name: Run Checkov Scan
  uses: bridgecrewio/checkov-action@master
  with:
    directory: infra/
    framework: bicep
    soft_fail: false # ✅ Fail 有効
    baseline: .checkov.baseline.yaml # ✅ 除外リスト適用
```

**メリット**:

- ✅ 明示的な例外管理
- ✅ コードレビューで例外が可視化される
- ✅ 本番環境への移行がスムーズ
- ✅ 「意図的な脆弱性」が明確

**デメリット**:

- ⚠️ Baseline ファイルのメンテナンスが必要
- ⚠️ 例外が増えすぎるとリスク

---

## 🎯 本プロジェクトの設計判断

### 現状維持の理由 (Fail させない)

| 判断基準         | 評価    | 理由                                     |
| ---------------- | ------- | ---------------------------------------- |
| プロジェクト目的 | ✅ 適合 | 脆弱性の実演が目的                       |
| CI/CD の安定性   | ✅ 適合 | デプロイ失敗のリスクなし                 |
| 可視性           | ✅ 適合 | Security タブで全結果を表示              |
| 面接デモ         | ✅ 適合 | 「検出 → 可視化 → 説明」の流れを実演可能 |
| 学習価値         | ✅ 適合 | DevSecOps の段階的導入を体験             |

### もし本番環境なら

**推奨**: パターン 2 (SARIF 出力 + 別ジョブ解析) + パターン 3 (Allowlist 管理)

```yaml
# 本番環境の理想的な設定
jobs:
  scan:
    steps:
      - name: Checkov
        soft_fail: true # SARIF生成のため
      - name: Upload SARIF
        # Security タブに表示
      - name: Analyze
        # CRITICAL検出時にhas-critical=trueを出力

  deploy-staging:
    needs: scan
    # ステージング環境は警告を無視してデプロイ

  approve-production:
    needs: scan
    # 本番環境は手動承認 + CRITICAL=0 の条件

  deploy-production:
    needs: [scan, approve-production]
    if: needs.scan.outputs.has-critical != 'true'
    # CRITICAL がなければ本番デプロイ
```

---

## 📊 比較表: Fail 設定の影響

| 項目                     | Fail させない (現状)     | Fail させる                         |
| ------------------------ | ------------------------ | ----------------------------------- |
| **脆弱な構成のデプロイ** | ✅ 可能 (実演できる)     | ❌ 不可能                           |
| **Security タブ表示**    | ✅ 全結果表示            | ⚠️ ジョブ失敗で表示されない場合あり |
| **CI/CD 安定性**         | ✅ 高 (常にデプロイ可能) | ⚠️ 低 (検出でブロック)              |
| **セキュリティ強制**     | ❌ なし (任意対応)       | ✅ あり (強制対応)                  |
| **開発速度**             | ✅ 高速                  | ⚠️ 低速 (修正待ち)                  |
| **面接デモ適性**         | ✅ 最適                  | ❌ 不適                             |
| **本番運用適性**         | ❌ 不適                  | ✅ 適合                             |

---

## 🔍 面接での説明ポイント

### 質問: 「なぜセキュリティスキャンで Fail させないのですか?」

**回答例**:

> 「このプロジェクトは、Wiz のようなセキュリティツールが **どのように脆弱性を検出するか** を実演することが目的です。そのため、意図的に脆弱な構成を含めています。
>
> もし Checkov や Trivy で Fail させると、そもそも脆弱な構成がデプロイできず、実演できません。
>
> そこで、`soft_fail: true` と `exit-code: 0` を設定し、検出結果を GitHub Security タブに可視化しつつ、デプロイを継続する設計にしています。
>
> 実務では、このような設定は開発初期や検証環境で使用し、本番環境では段階的に厳格化します。例えば:
>
> 1. **検証環境**: soft_fail=true (全てデプロイ可能)
> 2. **ステージング**: CRITICAL のみ Fail
> 3. **本番**: HIGH 以上 Fail + Allowlist 管理
>
> このプロジェクトでは Phase 1 を採用し、セキュリティ検出の仕組みを実演できる状態にしています。」

### 追加アピールポイント

1. **トレーサビリティ**:

   > 「SARIF ファイルを Artifact として保存し、検出履歴を追跡できます。」

2. **段階的改善**:

   > 「必要に応じて、設定を 1 行変更するだけで Fail させることも可能です。」

3. **実装の柔軟性**:
   > 「Allowlist で特定のルールを除外し、段階的にポリシーを厳格化できます。」

---

## 🛠️ クイックリファレンス

### Fail させたい場合の変更箇所

```yaml
# 01.infra-deploy.yml
- name: Run Checkov Scan
  with:
    soft_fail: false # true → false に変更

- name: Run Trivy Config Scan
  with:
    exit-code: 1 # 0 → 1 に変更

# 02-1.app-deploy.yml
- name: Run Trivy Vulnerability Scanner
  continue-on-error: false # true → false に変更
```

### 現状維持 (Fail させない) の確認

```bash
# 現在の設定を確認
grep -r "soft_fail\|exit-code: 0\|continue-on-error" .github/workflows/

# 期待される出力:
# 01.infra-deploy.yml:38:  soft_fail: true
# 01.infra-deploy.yml:55:  exit-code: 0
# 02-1.app-deploy.yml:102:  continue-on-error: true
```

---

## 📚 参考リンク

- [Checkov soft_fail documentation](https://www.checkov.io/2.Basics/Suppressing%20and%20Skipping%20Policies.html)
- [Trivy exit-code options](https://aquasecurity.github.io/trivy/latest/docs/configuration/reporting/#exit-code)
- [GitHub Actions: Defining prerequisite jobs](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idneeds)
- [SARIF format specification](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)

---

**作成日**: 2025-11-06  
**更新日**: 2025-11-06  
**バージョン**: 1.0  
**レビュー**: Ready for Interview
