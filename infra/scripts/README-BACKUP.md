# MongoDB バックアップ設定ガイド

## 📋 概要

MongoDB VM 上で **1日3回自動バックアップ** を実行する cron ベースのバックアップシステムです。

### バックアップスケジュール

| 時刻 (JST) | 時刻 (UTC) | 説明 |
|-----------|-----------|------|
| 02:00 | 17:00 (前日) | 深夜バックアップ |
| 10:00 | 01:00 | 午前バックアップ |
| 18:00 | 09:00 | 夕方バックアップ |

---

## 🚀 初回セットアップ

### 1. バックアップスクリプトのインストール

```bash
# Azure にログイン
az login

# 環境変数設定
export RG="rg-bbs-cicd-aks200"
export VM_NAME="vm-mongo-dev"
export STORAGE_ACCOUNT="stwizdevrwocrqcivjsx4"  # 実際の値に置き換え
export MONGO_ADMIN_USER="mongoadmin"
export MONGO_ADMIN_PASSWORD="your-password"

# setup-backup.sh を実行
curl -fsSL https://raw.githubusercontent.com/aktsmm/CICD-AKS-technical-exercise/main/infra/scripts/setup-backup.sh | \
  bash -s -- "$STORAGE_ACCOUNT" "backups"
```

### 2. cron ジョブの設定

```bash
# VM に SSH 接続
az vm run-command invoke \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --command-id RunShellScript \
  --scripts "$(curl -fsSL https://raw.githubusercontent.com/aktsmm/CICD-AKS-technical-exercise/main/infra/scripts/setup-cron-backup.sh)"
```

または VM 内で直接実行:

```bash
sudo curl -fsSL https://raw.githubusercontent.com/aktsmm/CICD-AKS-technical-exercise/main/infra/scripts/setup-cron-backup.sh -o /tmp/setup-cron.sh
sudo chmod +x /tmp/setup-cron.sh
sudo /tmp/setup-cron.sh
```

---

## 🔧 オンデマンドバックアップ

### VM 内で実行

```bash
# 方法1: オンデマンドスクリプト使用
sudo /usr/local/bin/run-backup-now.sh

# 方法2: バックアップスクリプト直接実行
sudo /usr/local/bin/mongodb-backup.sh
```

### Azure CLI 経由で実行 (ローカルから)

```bash
az vm run-command invoke \
  --resource-group "rg-bbs-cicd-aks200" \
  --name "vm-mongo-dev" \
  --command-id RunShellScript \
  --scripts '/usr/local/bin/mongodb-backup.sh'
```

---

## 📊 監視・確認

### cron ジョブ確認

```bash
sudo crontab -l | grep mongodb-backup
```

### ログ確認

```bash
# リアルタイムログ
sudo tail -f /var/log/mongodb-backup.log

# 最新20行
sudo tail -n 20 /var/log/mongodb-backup.log
```

### バックアップファイル確認

```bash
# ローカルバックアップ一覧
ls -lh /var/backups/mongodb/

# Azure Storage 内のバックアップ確認
az storage blob list \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "backups" \
  --output table
```

---

## 🛠️ トラブルシューティング

### cron が実行されない場合

```bash
# cron サービス状態確認
sudo systemctl status cron

# cron を再起動
sudo systemctl restart cron

# cron ログ確認
sudo grep CRON /var/log/syslog | tail -n 20
```

### バックアップが失敗する場合

```bash
# 手動実行でエラー確認
sudo /usr/local/bin/mongodb-backup.sh

# MongoDB 接続確認
mongosh -u "$MONGO_ADMIN_USER" -p "$MONGO_ADMIN_PASSWORD" --eval "db.adminCommand('ping')"

# Azure CLI 認証確認
az account show
```

---

## 📦 バックアップファイル構造

```
/var/backups/mongodb/
└── mongodb_backup_20250105_020000.tar.gz  # YYYYMMDD_HHMMSS 形式

Azure Storage:
└── backups/
    └── mongodb_backup_20250105_020000.tar.gz
```

---

## 🔒 セキュリティ考慮事項

- ✅ バックアップストレージは **公開リスト・公開読み取り可能** (Wiz 課題要件)
- ✅ MongoDB 認証必須
- ✅ Kubernetes ネットワーク内からのみ MongoDB アクセス可能
- ⚠️ SSH ポートはパブリックに公開 (Wiz 課題要件)

---

## 📚 関連ファイル

| ファイル | 説明 |
|---------|------|
| `setup-backup.sh` | バックアップスクリプトインストール |
| `setup-cron-backup.sh` | cron ジョブ設定 |
| `run-backup-now.sh` | オンデマンドバックアップ実行 |
| `/usr/local/bin/mongodb-backup.sh` | 実際のバックアップスクリプト |
| `/var/log/mongodb-backup.log` | バックアップログ |

---

## ❓ よくある質問

**Q: バックアップは自動削除される？**  
A: いいえ。手動削除が必要です。将来的にログローテーション機能を追加予定。

**Q: バックアップ時刻を変更したい**  
A: `setup-cron-backup.sh` の `CRON_JOBS` 配列を編集して再実行してください。

**Q: GitHub Actions は使わないの？**  
A: Azure Run Command の不安定性により、VM 内 cron に変更しました。より信頼性が高く、シンプルです。
