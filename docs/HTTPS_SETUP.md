# HTTPS Setup Guide

## 概要

このガイドでは、GitHub Actionsを使用してAKSアプリケーションにHTTPS（SSL/TLS）を設定する方法を説明します。

## 🔒 HTTPS化の方法

### 自動セットアップ（推奨）

GitHub Actionsワークフローを使用して自動的にHTTPSをセットアップします。

#### 手順

1. **GitHubリポジトリのActionsタブに移動**
   ```
   https://github.com/aktsmm/CICD-AKS-technical-exercise/actions
   ```

2. **"Setup HTTPS with Self-Signed Certificate" ワークフローを選択**

3. **"Run workflow" をクリック**
   - `domain` フィールドは空のままでOK（自動的に `<INGRESS_IP>.nip.io` を使用）
   - または、カスタムドメインを指定可能

4. **ワークフローの完了を待つ（約3-5分）**

5. **アクセス確認**
   ```bash
   # Ingress IP確認
   kubectl get svc -n ingress-nginx ingress-nginx-controller
   
   # 証明書確認
   kubectl get certificate guestbook-tls
   
   # ブラウザでアクセス
   # https://<INGRESS_IP>.nip.io
   ```

## 📋 実装内容

### インストールされるコンポーネント

| コンポーネント | バージョン | 用途 |
|---------------|-----------|------|
| **cert-manager** | v1.13.2 | Kubernetes証明書管理 |
| **Self-Signed ClusterIssuer** | - | 自己署名証明書の発行 |
| **TLS Secret** | - | SSL/TLS証明書の保存 |

### 設定される内容

1. **cert-manager のインストール**
   - Namespace: `cert-manager`
   - CRDs: Certificate, ClusterIssuer, Issuer

2. **Self-Signed ClusterIssuer の作成**
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: selfsigned-issuer
   spec:
     selfSigned: {}
   ```

3. **Ingress の更新**
   - TLS設定追加
   - 自動HTTPSリダイレクト
   - ドメイン名設定（nip.ioまたはカスタム）

4. **証明書の自動発行**
   - Secret名: `guestbook-tls`
   - 有効期限: 90日（自動更新）

## 🌐 アクセス方法

### HTTPS アクセス

```bash
# nip.ioを使用する場合（自動）
https://4.190.29.229.nip.io

# カスタムドメインを使用する場合
https://your-custom-domain.com
```

### ブラウザ警告について

⚠️ **自己署名証明書を使用しているため、ブラウザに警告が表示されます。**

これはデモ環境では正常な動作です。本番環境では Let's Encrypt などの信頼された認証局を使用してください。

#### 警告の対処方法

**Chrome / Edge:**
1. 「詳細設定」をクリック
2. 「<ドメイン>にアクセスする（安全ではありません）」をクリック

**Firefox:**
1. 「詳細情報」をクリック
2. 「危険性を承知で続行」をクリック

**Safari:**
1. 「詳細を表示」をクリック
2. 「このWebサイトを閲覧」をクリック

## 🔧 手動セットアップ

ワークフローを使わず手動でセットアップする場合:

### 1. cert-manager のインストール

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# インストール確認
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
```

### 2. ClusterIssuer の作成

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF
```

### 3. Ingress IP の取得

```bash
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"
```

### 4. Ingress の更新

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: guestbook-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: selfsigned-issuer
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - ${INGRESS_IP}.nip.io
    secretName: guestbook-tls
  rules:
  - host: ${INGRESS_IP}.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: guestbook-service
            port:
              number: 80
EOF
```

### 5. 証明書の確認

```bash
# 証明書のステータス確認
kubectl get certificate guestbook-tls

# 詳細情報
kubectl describe certificate guestbook-tls

# Secretの確認
kubectl get secret guestbook-tls
```

## 🔍 トラブルシューティング

### 証明書が発行されない

```bash
# cert-manager のログ確認
kubectl logs -n cert-manager deployment/cert-manager

# Certificate の詳細確認
kubectl describe certificate guestbook-tls

# CertificateRequest の確認
kubectl get certificaterequest
kubectl describe certificaterequest <request-name>
```

### Ingress が HTTPS で応答しない

```bash
# Ingress の確認
kubectl describe ingress guestbook-ingress

# NGINX Ingress Controller のログ確認
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# TLS Secret の確認
kubectl get secret guestbook-tls -o yaml
```

### nip.io が解決できない

```bash
# DNS解決テスト
nslookup 4.190.29.229.nip.io

# または dig コマンド
dig 4.190.29.229.nip.io

# 代替: /etc/hosts に手動追加（ローカルテスト用）
echo "4.190.29.229 test.local" | sudo tee -a /etc/hosts
```

## 📊 本番環境への移行

デモ環境では自己署名証明書を使用していますが、本番環境では以下を推奨:

### Let's Encrypt を使用する場合

1. **ドメイン名の準備**
   - Azure DNS または他のDNSプロバイダーでドメイン取得
   - A レコードで Ingress IP を指定

2. **ClusterIssuer の変更**
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: your-email@example.com
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
       - http01:
           ingress:
             class: nginx
   ```

3. **Ingress の更新**
   ```yaml
   metadata:
     annotations:
       cert-manager.io/cluster-issuer: letsencrypt-prod  # 変更
   ```

### Azure Application Gateway を使用する場合

- Application Gateway Ingress Controller (AGIC) を使用
- Azure Key Vault で証明書管理
- WAF機能でセキュリティ強化

## ✅ 検証コマンド

```bash
# HTTPS接続テスト
curl -k https://4.190.29.229.nip.io

# 証明書情報の確認
openssl s_client -connect 4.190.29.229.nip.io:443 -showcerts

# HTTP → HTTPS リダイレクトの確認
curl -I http://4.190.29.229.nip.io

# 証明書の有効期限確認
kubectl get certificate guestbook-tls -o jsonpath='{.status.notAfter}'
```

## 🎯 まとめ

- ✅ GitHub Actionsで完全自動化
- ✅ nip.io でドメイン不要
- ✅ 自己署名証明書で即座にHTTPS化
- ✅ 本番環境への移行パスも提供

**デモ環境に最適な、ナウい😎 HTTPS設定が完成しました！**
