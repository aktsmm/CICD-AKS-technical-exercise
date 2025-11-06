# Issue: MongoDB バックアップの GitHub Actions 不安定性と解決策

## 📋 概要

**作成日**: 2025年11月5日  
**ステータス**: ✅ 解決済み  
**影響範囲**: MongoDB バックアップシステム

---

## 🔴 問題の詳細

### 発生した問題

GitHub Actions の `.github/workflows/backup-schedule.yml` を使用した MongoDB バックアップが以下の理由で**不安定**かつ**実装困難**であった:

1. **Azure Run Command の仕様変更**
   - `RunCommandLinux` 拡張が Compute Resource Provider (CRP) 管理に移行
   - ユーザーによる `az vm extension delete` が禁止される
   - エラー: `OperationNotAllowed - Operation 'Delete VM Extension' is not allowed`

2. **キャッシュ問題**
   - `/var/lib/waagent/run-command/download/` にスクリプトがキャッシュされる
   - 古い "This is a sample script" が何度も実行される
   - walinuxagent 再起動でも解消しない

3. **`--parameters` オプションの非対応**
   - `az vm run-command invoke --parameters` が位置引数として機能しない
   - スクリプト内に直接変数を埋め込む必要がある

4. **複雑性の増大**
   - キャッシュクリア、拡張再インストール、診断ログなど肥大化
   - YAML が 400行以上になり保守困難

### 試行錯誤の履歴

| Run | 対応 | 結果 |
|-----|------|------|
| #51-56 | Python heredoc 修正、診断ログ追加、キャッシュクリア | ❌ "This is a sample script" 継続 |
| #57 | 拡張削除を同期化、待機時間延長 | ❌ `OperationNotAllowed` エラー |
| #58 | VM 内でキャッシュ削除、walinuxagent 再起動 | ❌ キャッシュ残存 |
| #59 | スクリプト存在確認 + 初回デプロイ | ❌ スクリプト未配置 |
| #60 | `--parameters` を削除、変数を直接埋め込み | ❌ "This is a sample script" 再発 |

---

## ✅ 解決策: VM 内 cron による自動バックアップ

### 採用した方針

GitHub Actions を**完全に廃止**し、**VM 内の cron** で直接バックアップを実行する方式に切り替え。

### 実装内容

#### 1. 新規スクリプト作成

| ファイル | 説明 |
|---------|------|
| `setup-cron-backup.sh` | cron ジョブを設定（1日3回: 02:00, 10:00, 18:00 JST） |
| `run-backup-now.sh` | オンデマンドバックアップ実行用 |
| `README-BACKUP.md` | PowerShell/Bash 対応の詳細ドキュメント |

#### 2. バックアップスケジュール

| 時刻 (JST) | 時刻 (UTC) | 説明 |
|-----------|-----------|------|
| 02:00 | 17:00 (前日) | 深夜バックアップ |
| 10:00 | 01:00 | 午前バックアップ |
| 18:00 | 09:00 | 夕方バックアップ |

#### 3. GitHub Actions の無効化

```yaml
name: 3. Mongo Backup (DISABLED - Using VM cron instead)

on:
    # push: ... (コメントアウト)
    # schedule: ... (コメントアウト)
    workflow_dispatch:  # Manual trigger only for testing
```

---

## 💡 利点

### 技術的利点

| 項目 | GitHub Actions | VM cron |
|------|---------------|---------|
| **信頼性** | ❌ キャッシュ問題頻発 | ✅ 安定動作 |
| **複雑性** | ❌ 400行以上の YAML | ✅ シンプルな cron |
| **保守性** | ❌ Azure CLI 仕様変更の影響大 | ✅ 標準的な cron |
| **デバッグ** | ❌ GitHub Actions ログ確認必須 | ✅ VM 内でログ直接確認 |
| **実行速度** | ❌ ~3分（拡張処理含む） | ✅ ~30秒（直接実行） |

### 運用上の利点

- ✅ **ネットワーク依存なし**: VM 内で完結
- ✅ **GitHub Actions の課金影響なし**: cron はローカル実行
- ✅ **スケジュール柔軟性**: cron で自由に変更可能
- ✅ **オンデマンド実行**: SSH 経由または Azure CLI で即座に実行

---

## 🚀 セットアップ手順

### 初回セットアップ

```powershell
# 1. バックアップスクリプトのインストール
$RG = "rg-bbs-cicd-aks200"
$VM_NAME = "vm-mongo-dev"
$STORAGE_ACCOUNT = "stwizdevrwocrqcivjsx4"
$MONGO_ADMIN_USER = "mongoadmin"
$MONGO_ADMIN_PASSWORD = "your-password"

az vm run-command invoke `
  --resource-group $RG `
  --name $VM_NAME `
  --command-id RunShellScript `
  --scripts @"
export MONGO_ADMIN_USER='$MONGO_ADMIN_USER'
export MONGO_ADMIN_PASSWORD='$MONGO_ADMIN_PASSWORD'
curl -fsSL https://raw.githubusercontent.com/aktsmm/CICD-AKS-technical-exercise/main/infra/scripts/setup-backup.sh | bash -s -- '$STORAGE_ACCOUNT' 'backups'
"@

# 2. cron ジョブの設定
$cronScript = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aktsmm/CICD-AKS-technical-exercise/main/infra/scripts/setup-cron-backup.sh" -UseBasicParsing | Select-Object -ExpandProperty Content

az vm run-command invoke `
  --resource-group $RG `
  --name $VM_NAME `
  --command-id RunShellScript `
  --scripts $cronScript
```

### オンデマンドバックアップ

```powershell
az vm run-command invoke `
  --resource-group "rg-bbs-cicd-aks200" `
  --name "vm-mongo-dev" `
  --command-id RunShellScript `
  --scripts '/usr/local/bin/mongodb-backup.sh'
```

---

## 📚 関連ドキュメント

- **詳細ガイド**: `infra/scripts/README-BACKUP.md`
- **セットアップスクリプト**: `infra/scripts/setup-cron-backup.sh`
- **オンデマンド実行**: `infra/scripts/run-backup-now.sh`

---

## 🔮 今後の改善案

### 短期的改善

- [ ] バックアップファイルの自動削除（30日以上経過）
- [ ] バックアップ失敗時のアラート通知（Azure Monitor）
- [ ] ログローテーション設定（`logrotate`）

### 長期的改善

- [ ] Azure Backup Service への移行検討
- [ ] バックアップの差分化（増分バックアップ）
- [ ] 複数リージョンへのバックアップレプリケーション

---

## 📊 教訓

### 学んだこと

1. **Azure Run Command の制限**
   - システム拡張（CRP 管理）はユーザー制御不可
   - キャッシュ問題は根本的に解決困難
   - VM 内完結型のアプローチが最も安定

2. **GitHub Actions の適用範囲**
   - CI/CD には最適
   - VM 内の運用タスク（cron 相当）には不向き
   - Azure Run Command は一時的な操作に限定すべき

3. **シンプル設計の重要性**
   - 複雑な回避策は保守コスト大
   - 標準的な手法（cron）が最も信頼性高い

### 他プロジェクトへの適用

このアプローチは以下の場合に有効:

- ✅ VM 上の定期実行タスク（バックアップ、メンテナンス）
- ✅ Azure Run Command のキャッシュ問題が発生
- ✅ GitHub Actions の実行時間・課金が懸念

---

## 🎯 結論

**VM 内 cron による自動バックアップ**は、GitHub Actions の不安定性を完全に回避し、**シンプル・安定・高速**なバックアップシステムを実現した。

本番運用では、Azure のマネージドサービス（cron ベース）を活用することが、GitHub Actions のような外部 CI/CD ツールよりも適切であることが実証された。

---

**関連コミット:**
- `e13eeb8` - 切り替え: GitHub Actions から VM 内 cron による1日3回自動バックアップへ移行
- `03addba` - 更新: README に PowerShell 対応のコマンド例を追加
- `7a8f144` - 修正: パラメータをスクリプト内に直接埋め込み (--parameters 非対応回避)
- `82a2ecf` - Fix: Deploy backup script on first run if missing (hybrid approach)
- `823f2af` - Fix: Clear RunCommand cache internally (CRP-managed extension cannot be deleted)
