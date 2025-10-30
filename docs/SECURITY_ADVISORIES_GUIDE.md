# GitHub Security Advisories 設定ガイド

**プロジェクト**: CICD-AKS-technical-exercise  
**目的**: セキュリティ脆弱性の管理とレポート体制の構築  
**日付**: 2025 年 10 月 31 日

---

## 📋 目次

1. [Security Advisories とは](#1-security-advisories-とは)
2. [このプロジェクトで報告すべき脆弱性](#2-このプロジェクトで報告すべき脆弱性)
3. [Security Advisory の作成手順](#3-security-advisory-の作成手順)
4. [実際の脆弱性レポート例](#4-実際の脆弱性レポート例)
5. [Dependabot Alerts の有効化](#5-dependabot-alerts-の有効化)
6. [Code Scanning (CodeQL) の設定](#6-code-scanning-codeql-の設定)
7. [Secret Scanning の有効化](#7-secret-scanning-の有効化)

---

## 1. Security Advisories とは

### 概要

GitHub Security Advisories は、リポジトリ内で発見されたセキュリティ脆弱性を：

- **非公開で議論**
- **修正パッチを開発**
- **CVE 番号を取得**
- **公開時期をコントロール**

するための機能です。

### このプロジェクトでの活用方法

**Wiz Technical Exercise** では、**意図的な脆弱性**を含んでいるため、Security Advisories を使って：

1. 脆弱性を文書化
2. Wiz 製品でどう検知されるかを示す
3. 修正方法を提案
4. プレゼンテーションの材料とする

---

## 2. このプロジェクトで報告すべき脆弱性

### 2.1 インフラストラクチャレベルの脆弱性

| ID       | 脆弱性                      | 深刻度   | CVSS | 説明                                               |
| -------- | --------------------------- | -------- | ---- | -------------------------------------------------- |
| GHSA-001 | Internet-facing SSH Port    | Critical | 9.8  | MongoDB VM の SSH ポートがインターネット全体に公開 |
| GHSA-002 | Excessive Cloud Permissions | High     | 8.1  | Managed Identity に Contributor 権限が付与         |
| GHSA-003 | Public Backup Storage       | Critical | 9.1  | 認証なしで MongoDB バックアップにアクセス可能      |
| GHSA-004 | Outdated MongoDB Version    | Medium   | 6.5  | MongoDB 4.4.29 (既知の脆弱性あり)                  |
| GHSA-005 | Outdated OS (Ubuntu 20.04)  | Medium   | 5.9  | 1 年以上古い OS バージョン使用                     |

### 2.2 アプリケーションレベルの脆弱性

| ID       | 脆弱性                        | 深刻度   | CVSS | 説明                                                 |
| -------- | ----------------------------- | -------- | ---- | ---------------------------------------------------- |
| GHSA-101 | Overprivileged Kubernetes Pod | High     | 8.8  | cluster-admin 権限がデフォルト ServiceAccount に付与 |
| GHSA-102 | Hardcoded MongoDB Credentials | Critical | 9.8  | 環境変数でパスワード露出                             |
| GHSA-103 | No Rate Limiting              | Medium   | 6.1  | API エンドポイントにレート制限なし                   |
| GHSA-104 | Missing Input Validation      | High     | 7.5  | XSS/SQL インジェクションのリスク                     |

### 2.3 CI/CD パイプラインの脆弱性

| ID       | 脆弱性                     | 深刻度 | CVSS | 説明                                   |
| -------- | -------------------------- | ------ | ---- | -------------------------------------- |
| GHSA-201 | Disabled Security Scanning | High   | 7.3  | Trivy スキャンがコメントアウト         |
| GHSA-202 | Secrets in GitHub Actions  | High   | 8.2  | MONGO_ADMIN_PASSWORD が Secrets に保存 |

---

## 3. Security Advisory の作成手順

### Step 1: Security タブにアクセス

1. GitHub リポジトリページで **Security** タブをクリック
2. **Advisories** → **New draft security advisory** をクリック

### Step 2: 基本情報を入力

```
Title: Internet-facing SSH Port on MongoDB VM

Severity: Critical

CVE ID: Request CVE ID from GitHub (オプション)

Affected Product:
- Package: Infrastructure/MongoDB VM
- Ecosystem: Azure
- Affected versions: All versions

Description:
The MongoDB virtual machine has SSH port (22) exposed to the internet
(0.0.0.0/0) through Network Security Group rules. This allows potential
attackers to attempt brute-force attacks against the SSH service.

Impact:
- Unauthorized access to MongoDB VM
- Potential lateral movement to AKS cluster
- Data exfiltration from MongoDB database
- Cryptojacking or ransomware deployment

Attack Vector: Network
Attack Complexity: Low
Privileges Required: None
User Interaction: None

References:
- https://github.com/aktsmm/CICD-AKS-technical-exercise/blob/main/infra/modules/vm-mongodb.bicep#L123
- CWE-284: Improper Access Control
```

### Step 3: 脆弱性の詳細を記述

**Vulnerability Details**:

````markdown
## Technical Details

The MongoDB VM is deployed with the following NSG rule:

```bicep
{
  name: 'allow-ssh'
  properties: {
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '22'
    sourceAddressPrefix: '*'  // ⚠️ Should be restricted
    destinationAddressPrefix: '*'
  }
}
```
````

This configuration allows SSH access from any IP address globally.

## Proof of Concept

1. Identify public IP of MongoDB VM:

```powershell
az network public-ip show -g rg-bbs-cicd-aks0000 -n vm-mongo-dev-pip --query ipAddress -o tsv
# Output: 172.192.56.57
```

2. Attempt SSH connection:

```bash
ssh azureuser@172.192.56.57
# Connection succeeds, password prompt appears
```

3. Automated scanning tools (e.g., Shodan, Masscan) can discover this exposed service.

## CVSS Score Calculation

**CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H**

- Attack Vector (AV): Network (N)
- Attack Complexity (AC): Low (L)
- Privileges Required (PR): None (N)
- User Interaction (UI): None (N)
- Scope (S): Unchanged (U)
- Confidentiality Impact (C): High (H)
- Integrity Impact (I): High (H)
- Availability Impact (A): High (H)

**Base Score**: 9.8 (Critical)

````

### Step 4: 修正方法を提案

**Patched Versions / Mitigation**:
```markdown
## Recommended Fix

### Option 1: Restrict SSH to Specific IP (Recommended)

Modify the NSG rule to allow SSH only from trusted IP addresses:

```bicep
sourceAddressPrefix: '203.0.113.0/24'  // Your office IP range
````

### Option 2: Use Azure Bastion

Remove direct SSH access and use Azure Bastion:

```bicep
resource bastion 'Microsoft.Network/bastionHosts@2021-05-01' = {
  name: 'bastion-${environment}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: bastionSubnet.id
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}
```

### Option 3: Use Just-In-Time (JIT) Access

Enable Azure Defender JIT VM Access:

```powershell
az security jit-policy create \
  --resource-group rg-bbs-cicd-aks0000 \
  --name mongodb-vm-jit \
  --vm-resource-id /subscriptions/.../vm-mongo-dev \
  --ports '[{"number":22,"protocol":"*","allowedSourceAddressPrefix":"*","maxRequestAccessDuration":"PT3H"}]'
```

## Verification

After applying the fix, verify:

```powershell
# Check NSG rule
az network nsg rule show -g rg-bbs-cicd-aks0000 --nsg-name nsg-mongo-dev -n allow-ssh

# Attempt connection from unauthorized IP (should fail)
ssh azureuser@172.192.56.57
# Connection refused or timeout
```

## Detection with Wiz

Wiz Security Platform would detect this vulnerability as:

- **Issue**: Internet-facing VM with SSH enabled
- **Severity**: Critical
- **Recommendation**: Restrict SSH access to specific IPs or use Bastion
- **Affected Resource**: vm-mongo-dev (172.192.56.57)

````

### Step 5: 関係者を追加 (オプション)

**Collaborators**:
- プロジェクトメンバー
- セキュリティチーム
- Wizパネリスト (プレゼン時)

### Step 6: 公開設定

**Publish Advisory**:
- **Draft**: 非公開で作業中
- **Published**: 一般公開 (CVE番号取得後)
- **Closed**: 修正完了

---

## 4. 実際の脆弱性レポート例

### 例1: GHSA-001 - Internet-facing SSH Port

**ファイル**: `.github/SECURITY.md` に記載

```markdown
# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it by:

1. **Creating a Security Advisory**:
   - Go to https://github.com/aktsmm/CICD-AKS-technical-exercise/security/advisories
   - Click "New draft security advisory"
   - Follow the template

2. **Email**: security@example.com (プライベートな報告用)

3. **Expected Response Time**: 48 hours

## Known Vulnerabilities (Intentional)

⚠️ **This project intentionally contains security vulnerabilities for educational purposes (Wiz Technical Exercise).**

### Critical Issues

#### GHSA-001: Internet-facing SSH Port
- **Severity**: Critical (CVSS 9.8)
- **Status**: Known, intentional for demo
- **Location**: `infra/modules/vm-mongodb.bicep:123`
- **Mitigation**: Restrict sourceAddressPrefix to specific IPs

#### GHSA-003: Public Backup Storage
- **Severity**: Critical (CVSS 9.1)
- **Status**: Known, intentional for demo
- **Location**: `infra/modules/storage.bicep:45`
- **Mitigation**: Set publicAccess to 'None'

### High Issues

#### GHSA-101: Overprivileged Kubernetes Pod
- **Severity**: High (CVSS 8.8)
- **Status**: Known, intentional for demo
- **Location**: `app/k8s/rbac.yaml:10`
- **Mitigation**: Create specific ServiceAccount with limited RBAC

#### GHSA-102: Hardcoded MongoDB Credentials
- **Severity**: High (CVSS 8.2)
- **Status**: Mitigated with Kubernetes Secrets
- **Location**: `app/k8s/deployment.yaml:30`
- **Best Practice**: Use Azure Key Vault + CSI Driver

### Medium Issues

#### GHSA-004: Outdated MongoDB Version
- **Severity**: Medium (CVSS 6.5)
- **Status**: Known, intentional (requirement)
- **Location**: `infra/scripts/install-mongodb.sh:15`
- **Mitigation**: Upgrade to MongoDB 7.0+

## Security Scanning

### Enabled
- ✅ Dependabot Alerts
- ✅ Secret Scanning
- ✅ Code Scanning (CodeQL)

### Disabled (intentionally)
- ⚠️ Trivy Container Scanning (commented out in `.github/workflows/app-deploy.yml`)

## Responsible Disclosure

For non-intentional vulnerabilities:

1. **Do not** create public GitHub issues
2. **Do** use Security Advisories or email
3. Allow 90 days for remediation before public disclosure
4. Receive credit in our security acknowledgments

## Security Updates

We will publish security advisories for:
- Unintentional vulnerabilities discovered
- Patches and fixes
- End-of-support announcements
````

### 例 2: GHSA-003 - Public Backup Storage

**Advisory Draft**:

````markdown
# GHSA-003: Publicly Accessible MongoDB Backup Storage

## Summary

MongoDB backup files are stored in Azure Blob Storage with anonymous public read access enabled, allowing anyone to download sensitive database backups without authentication.

## Severity

**Critical** - CVSS Score: 9.1

## Affected Versions

All versions of this repository

## Vulnerability Details

### Configuration Issue

The storage container is configured with public blob access:

```bicep
resource storageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  parent: blobService
  name: 'backups'
  properties: {
    publicAccess: 'Blob'  // ⚠️ Allows anonymous read access
  }
}
```
````

### Impact Assessment

**Data at Risk**:

- MongoDB user credentials (`admin.system.users`)
- Application data (`guestbook.messages`)
- System metadata (`admin.system.version`)

**Attack Scenario**:

1. Attacker discovers storage account URL through:
   - DNS enumeration
   - Public GitHub repository
   - Azure Resource Manager API
2. Downloads backup file:
   ```bash
   curl https://stwizdevj2axc7dgverlk.blob.core.windows.net/backups/mongodb_backup_20251030_165815.tar.gz -o backup.tar.gz
   ```
3. Extracts MongoDB dump:
   ```bash
   tar -xzf backup.tar.gz
   ```
4. Restores locally and accesses sensitive data:
   ```bash
   mongorestore dump_20251030_165815/
   mongo guestbook --eval 'db.messages.find()'
   ```

### Proof of Concept

**Public URL** (working example):

```
https://stwizdevj2axc7dgverlk.blob.core.windows.net/backups/mongodb_backup_20251030_165815.tar.gz
```

**Verification**:

```powershell
# Check public access setting
az storage container show --name backups --account-name stwizdevj2axc7dgverlk --auth-mode login --query "properties.publicAccess"
# Output: "blob"

# Test anonymous download
Invoke-WebRequest -Uri "https://stwizdevj2axc7dgverlk.blob.core.windows.net/backups/mongodb_backup_20251030_165815.tar.gz" -OutFile "test_download.tar.gz"
# Success (no authentication required)
```

## CVSS Score

**CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N**

- Attack Vector: Network
- Attack Complexity: Low
- Privileges Required: None
- User Interaction: None
- Confidentiality Impact: High
- Integrity Impact: None
- Availability Impact: None

**Base Score**: 9.1 (Critical)

## Remediation

### Immediate Actions

1. **Disable Public Access**:

```bicep
properties: {
  publicAccess: 'None'  // No anonymous access
}
```

2. **Apply via Azure CLI**:

```powershell
az storage container set-permission \
  --name backups \
  --account-name stwizdevj2axc7dgverlk \
  --public-access off
```

3. **Verify Fix**:

```powershell
Invoke-WebRequest -Uri "https://stwizdevj2axc7dgverlk.blob.core.windows.net/backups/mongodb_backup_20251030_165815.tar.gz"
# Expected: 404 or 401 error
```

### Long-term Solutions

1. **Use Private Endpoints**:

```bicep
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pe-storage-${environment}'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']
        }
      }
    ]
  }
}
```

2. **Enable Encryption at Rest**:

```bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageAccountName
  properties: {
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}
```

3. **Use Managed Identity for Access**:

```bash
# In mongodb-backup.sh
az storage blob upload \
  --account-name ${STORAGE_ACCOUNT} \
  --container-name backups \
  --name ${BACKUP_FILE} \
  --file ${BACKUP_DIR}/${BACKUP_FILE} \
  --auth-mode login  # Uses VM's Managed Identity
```

4. **Implement SAS Token with Expiration**:

```powershell
# Generate time-limited SAS token
$end = (Get-Date).AddHours(1).ToString("yyyy-MM-ddTHH:mmZ")
az storage container generate-sas \
  --account-name stwizdevj2axc7dgverlk \
  --name backups \
  --permissions r \
  --expiry $end
```

## Detection

### Azure Defender

```powershell
# Enable Azure Defender for Storage
az security pricing create \
  --name StorageAccounts \
  --tier Standard
```

### Wiz Detection

Wiz would flag this as:

- **Issue Type**: "Public Storage Container with Sensitive Data"
- **Severity**: Critical
- **Detection Method**: Storage account enumeration + content analysis
- **Recommendation**: "Disable public access and use Private Endpoints"

### Azure Policy

```json
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "equals": "Microsoft.Storage/storageAccounts/blobServices/containers"
      },
      {
        "field": "Microsoft.Storage/storageAccounts/blobServices/containers/publicAccess",
        "notEquals": "None"
      }
    ]
  },
  "then": {
    "effect": "deny"
  }
}
```

## References

- [CWE-284: Improper Access Control](https://cwe.mitre.org/data/definitions/284.html)
- [Azure Storage Security Guide](https://docs.microsoft.com/en-us/azure/storage/common/storage-security-guide)
- [OWASP: Sensitive Data Exposure](https://owasp.org/www-project-top-ten/2017/A3_2017-Sensitive_Data_Exposure)

## Credits

Reported by: Tatsumi Yamamoto (Wiz Technical Exercise)  
Discovered: 2025-10-30  
Published: 2025-10-31

```

---

## 5. Dependabot Alerts の有効化

### 設定手順

1. **Settings** → **Code security and analysis**
2. 以下を有効化:
   - ✅ Dependency graph
   - ✅ Dependabot alerts
   - ✅ Dependabot security updates

### 期待されるアラート例

**Node.js Dependencies**:
```

⚠️ express 4.17.1 has known vulnerabilities
Upgrade to express 4.18.2+
Severity: High
GHSA-qvmq-4xmf-w8j7

```

**GitHub Actions**:
```

⚠️ actions/checkout@v2 is outdated
Upgrade to actions/checkout@v4
Severity: Low

````

---

## 6. Code Scanning (CodeQL) の設定

### GitHub Actions Workflow作成

**ファイル**: `.github/workflows/codeql-analysis.yml`

```yaml
name: "CodeQL Analysis"

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 6 * * 1'  # 毎週月曜日午前6時

jobs:
  analyze:
    name: Analyze
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write

    strategy:
      fail-fast: false
      matrix:
        language: [ 'javascript', 'python' ]

    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Initialize CodeQL
      uses: github/codeql-action/init@v3
      with:
        languages: ${{ matrix.language }}
        queries: security-and-quality

    - name: Autobuild
      uses: github/codeql-action/autobuild@v3

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v3
      with:
        category: "/language:${{matrix.language}}"
````

### 期待される検出例

```
⚠️ SQL Injection vulnerability
   Location: app/app.js:45
   Severity: High

⚠️ Cross-Site Scripting (XSS)
   Location: app/views/index.ejs:12
   Severity: Medium

⚠️ Hardcoded credentials
   Location: infra/scripts/setup-mongodb-auth.sh:8
   Severity: Critical
```

---

## 7. Secret Scanning の有効化

### 設定手順

1. **Settings** → **Code security and analysis**
2. **Secret scanning** を有効化
3. **Push protection** を有効化 (推奨)

### 検出される可能性のある Secrets

```
⚠️ Azure Connection String detected
   File: pipelines/infra-deploy.yml:15
   Pattern: AccountKey=...

⚠️ MongoDB Password detected
   File: mongo_password.txt
   Pattern: Plain text password

⚠️ GitHub Personal Access Token
   File: .github/workflows/app-deploy.yml:25
   Pattern: ghp_...
```

### Push Protection 設定

```bash
# .gitignore に追加
mongo_password.txt
*.key
*.pem
.env
secrets/
```

---

## 8. プレゼンテーションでの活用方法

### デモシナリオ

1. **Security タブを開く**:

   ```
   "このプロジェクトには意図的に8つの重大な脆弱性を実装しました。
    GitHub Security Advisoriesで管理しています。"
   ```

2. **GHSA-001 を開いて説明**:

   ```
   "Internet-facing SSH ポートの脆弱性。
    CVSS 9.8 Criticalです。
    Wizならこれを自動検知し、修正案を提示します。"
   ```

3. **Code Scanning 結果を表示**:

   ```
   "CodeQLで XSS, SQL Injection, Hardcoded Secrets を検出。
    これらも本番環境では修正必須です。"
   ```

4. **Dependabot Alerts を表示**:
   ```
   "依存関係の脆弱性も自動検知。
    express 4.17.1 に既知の脆弱性があります。"
   ```

### スライド構成案

**Slide: "Security Posture Overview"**

```
📊 Vulnerability Summary

Critical:   3 issues (GHSA-001, 003, 102)
High:       4 issues (GHSA-002, 101, 201, 202)
Medium:     3 issues (GHSA-004, 005, 103)
Low:        0 issues

Total:      10 intentional vulnerabilities

✅ All documented in Security Advisories
✅ Detection methods identified
✅ Remediation plans prepared
```

---

## 9. 実装チェックリスト

### 必須項目

- [ ] `.github/SECURITY.md` ファイル作成
- [ ] Security Advisory Draft 作成 (GHSA-001, 003, 101)
- [ ] Dependabot Alerts 有効化
- [ ] Secret Scanning 有効化
- [ ] CodeQL Workflow 追加 (`.github/workflows/codeql-analysis.yml`)
- [ ] `.gitignore` に秘密情報パターン追加

### オプション項目

- [ ] CVE 番号リクエスト (本番環境のみ)
- [ ] Security Policy テンプレート作成
- [ ] Vulnerability Disclosure Timeline 設定
- [ ] Bug Bounty Program 検討 (エンタープライズ向け)

---

## 10. まとめ

### GitHub セキュリティ機能の活用

| 機能                | 目的         | Wiz Technical Exercise での使い方        |
| ------------------- | ------------ | ---------------------------------------- |
| Security Advisories | 脆弱性管理   | 意図的な脆弱性を文書化、Wiz との比較デモ |
| Dependabot          | 依存関係監視 | 古いライブラリの検出、更新推奨           |
| CodeQL              | コード解析   | XSS/SQLi 等の検出、セキュアコーディング  |
| Secret Scanning     | 認証情報保護 | パスワード/キーの誤コミット防止          |

### プレゼンでの訴求ポイント

1. **体系的な脆弱性管理**: GitHub 標準機能で基本的な管理は可能
2. **Wiz の優位性**: クラウドインフラ特有の設定ミスは GitHub では検知不可
3. **統合的アプローチ**: GitOps + IaC + Wiz で包括的なセキュリティ

---

**作成者**: やまもとたつみ  
**作成日**: 2025 年 10 月 31 日  
**更新日**: 2025 年 10 月 31 日
