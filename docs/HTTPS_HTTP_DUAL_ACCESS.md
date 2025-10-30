# HTTP/HTTPS 両対応の実装

**作成日**: 2025年10月31日  
**プロジェクト**: CICD-AKS-Technical Exercise

---

## 🎯 概要

このドキュメントでは、Kubernetes Ingressを使用してHTTPとHTTPSの両方でアクセスできるように実装した方法を説明します。

**実現した機能:**
- ✅ HTTP直IPアクセス: `http://4.190.29.229`
- ✅ HTTPSドメインアクセス: `https://4.190.29.229.nip.io`
- ✅ 自動HTTPS証明書管理（cert-manager）
- ✅ 単一のIngressリソースで両対応

---

## 🔐 なぜHTTPSには直IPが使えないのか？

### TLS証明書の仕組み

HTTPS（TLS/SSL）の証明書は**ドメイン名に対して発行**されます。

```
証明書の構造:
┌─────────────────────────────────────────────┐
│ X.509 Certificate                           │
├─────────────────────────────────────────────┤
│ Subject:                                    │
│   Common Name (CN): example.com             │
│                                             │
│ Subject Alternative Names (SAN):            │
│   DNS: example.com                          │
│   DNS: www.example.com                      │
│   DNS: *.example.com                        │
└─────────────────────────────────────────────┘
```

### ブラウザの検証プロセス

```
1. ユーザーがアクセス: https://example.com
   ↓
2. サーバーが証明書を送信
   ↓
3. ブラウザが検証:
   - アクセス先URL: "example.com"
   - 証明書のCN/SAN: "example.com"
   - ✅ 一致 → 接続許可
   - ❌ 不一致 → "安全ではありません"エラー
```

### 直IPの問題

```
❌ 直IPでHTTPSアクセスした場合:

アクセス: https://4.190.29.229
証明書: CN=4.190.29.229.nip.io
          ↑
          不一致！

ブラウザのエラー:
"NET::ERR_CERT_COMMON_NAME_INVALID"
証明書のドメイン名とアクセス先が一致しません
```

### なぜIPアドレス証明書は使われないのか？

| 理由 | 説明 |
|-----|------|
| **IPの変動性** | IPアドレスは変更される可能性が高い（DHCP、クラウド再配置） |
| **証明書の更新** | IPが変わるたびに証明書を再発行する必要がある |
| **コスト** | 公式CAはIPアドレス証明書を高額で発行（または発行しない） |
| **セキュリティ** | IPは所有権の証明が難しい |
| **ベストプラクティス** | HTTPSはドメイン名で使用するのが標準 |

---

## 💡 解決策: nip.io

### nip.ioとは？

**nip.io**は、IPアドレスをドメイン名に変換してくれる無料のDNSサービスです。

```
公式サイト: https://nip.io/

仕組み:
  IPアドレス.nip.io → IPアドレス に自動解決

例:
  4.190.29.229.nip.io → 4.190.29.229
  10.0.1.100.nip.io   → 10.0.1.100
  192.168.1.1.nip.io  → 192.168.1.1
```

### DNSクエリの流れ

```
┌──────────────┐
│   ブラウザ    │
└──────┬───────┘
       │ 1. "4.190.29.229.nip.io のIPは？"
       ▼
┌──────────────┐
│  nip.io DNS  │
│   サーバー    │
└──────┬───────┘
       │ 2. ドメイン名を解析
       │    "4.190.29.229" を抽出
       │
       │ 3. "それは 4.190.29.229 です"
       ▼
┌──────────────┐
│   ブラウザ    │
│              │
│ 4.190.29.229 │ ← 4. このIPにアクセス
│ に接続       │
└──────────────┘
```

### なぜnip.ioが便利か？

| メリット | 説明 |
|---------|------|
| **DNS設定不要** | 独自ドメインやDNSレコード設定が不要 |
| **即座に使える** | IPが決まればすぐにドメイン名として使用可能 |
| **無料** | 完全無料で利用可能 |
| **証明書発行可能** | Let's EncryptやSelf-Signedで証明書を発行できる |
| **開発/デモ向け** | 開発環境やデモに最適 |

### nip.ioの動作確認

```bash
# DNS解決テスト
nslookup 4.190.29.229.nip.io

# 出力例:
# Server:  UnKnown
# Address:  8.8.8.8
#
# Non-authoritative answer:
# Name:    4.190.29.229.nip.io
# Address:  4.190.29.229  ← IPアドレスに解決される
```

---

## 🏗️ 実装アーキテクチャ

### 全体構成図

```
┌─────────────────────────────────────────────────────────────────┐
│                         インターネット                            │
└─────────────────┬───────────────────────┬───────────────────────┘
                  │                       │
        HTTP (80) │                       │ HTTPS (443)
                  │                       │
    ┌─────────────▼───────────┐ ┌────────▼──────────────┐
    │  http://4.190.29.229   │ │ https://4.190.29.229  │
    │   (直IPアクセス)        │ │      .nip.io          │
    │                         │ │  (ドメイン名アクセス)  │
    └─────────────┬───────────┘ └────────┬──────────────┘
                  │                       │
                  └───────────┬───────────┘
                              │
                    ┌─────────▼─────────┐
                    │ Azure Load        │
                    │ Balancer          │
                    │ (External IP)     │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │ NGINX Ingress     │
                    │ Controller        │
                    │ (Port 80/443)     │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │ Kubernetes        │
                    │ Ingress Resource  │
                    │                   │
                    │ Rules:            │
                    │ 1. host指定       │
                    │ 2. host無し       │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │ guestbook-service │
                    │ (ClusterIP)       │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │ guestbook-app Pod │
                    │ (Node.js App)     │
                    └───────────────────┘
```

### Ingressルールの構成

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: guestbook-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: selfsigned-issuer
spec:
  ingressClassName: nginx
  
  # TLS設定（HTTPS用）
  tls:
    - hosts:
        - 4.190.29.229.nip.io
      secretName: guestbook-tls-cert
  
  rules:
    # ルール1: ホスト名指定（HTTPS/HTTPドメインアクセス用）
    - host: 4.190.29.229.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: guestbook-service
                port:
                  number: 80
    
    # ルール2: ホスト名無し（HTTP直IPアクセス用）
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: guestbook-service
                port:
                  number: 80
```

---

## 🔄 トラフィックフロー

### HTTPアクセス（直IP）

```
1. ユーザー
   └─> http://4.190.29.229

2. DNS解決
   └─> IPアドレスそのもの（DNS不要）

3. Azure Load Balancer
   └─> Port 80 でリクエスト受信

4. Ingress Controller
   └─> HTTP リクエストを受信
   └─> Host ヘッダー: 空 または "4.190.29.229"

5. Ingress ルールマッチング
   ├─> ルール1 (host: 4.190.29.229.nip.io) → 不一致
   └─> ルール2 (host無し) → ✅ 一致！

6. Service → Pod
   └─> guestbook-service (ClusterIP) → Pod

7. レスポンス
   └─> HTTP 200 OK
```

### HTTPSアクセス（ドメイン名）

```
1. ユーザー
   └─> https://4.190.29.229.nip.io

2. DNS解決
   ├─> nip.io DNSサーバーに問い合わせ
   └─> 4.190.29.229 を返答

3. Azure Load Balancer
   └─> Port 443 でリクエスト受信

4. Ingress Controller
   ├─> TLS ハンドシェイク
   │   └─> Secret "guestbook-tls-cert" から証明書を取得
   │   └─> 証明書提示: CN=4.190.29.229.nip.io
   │   └─> ブラウザ検証: ✅ 一致
   │
   └─> HTTPS リクエストを復号化
   └─> Host ヘッダー: "4.190.29.229.nip.io"

5. Ingress ルールマッチング
   ├─> ルール1 (host: 4.190.29.229.nip.io) → ✅ 一致！
   └─> ルール2 には到達しない

6. Service → Pod
   └─> guestbook-service (ClusterIP) → Pod

7. レスポンス
   └─> HTTPS 200 OK (暗号化)
```

---

## 🛠️ 実装の詳細

### 1. cert-managerのインストール

cert-managerは、Kubernetes用の証明書管理ツールです。

```bash
# cert-manager v1.13.2 をインストール
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# cert-managerのPodを確認
kubectl get pods -n cert-manager

# 出力例:
# NAME                                      READY   STATUS    RESTARTS   AGE
# cert-manager-7d4b5d7c9f-abcde            1/1     Running   0          2m
# cert-manager-cainjector-6d8f9b8c7-fghij  1/1     Running   0          2m
# cert-manager-webhook-5b7c8d9e6f-klmno    1/1     Running   0          2m
```

**cert-managerの役割:**
- 証明書の自動発行
- 証明書の自動更新
- 証明書のライフサイクル管理
- Kubernetes Secretとして証明書を保存

### 2. Self-Signed ClusterIssuerの作成

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
```

**ClusterIssuerとは:**
- 証明書を発行する"発行者"を定義
- `ClusterIssuer`はクラスター全体で使用可能
- `Issuer`は特定のNamespaceのみ

**Self-Signed（自己署名）とは:**
- 自分で署名した証明書
- CA（認証局）による署名なし
- ブラウザは警告を表示
- 開発/デモ環境で使用

**本番環境では:**
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

### 3. Ingress TLS設定

```yaml
spec:
  tls:
    - hosts:
        - 4.190.29.229.nip.io
      secretName: guestbook-tls-cert
```

**動作:**
1. cert-managerがIngressを監視
2. `cert-manager.io/cluster-issuer`アノテーションを検知
3. `selfsigned-issuer`を使用して証明書を発行
4. 証明書をSecret `guestbook-tls-cert`に保存
5. Ingress Controllerが自動的にSecretから証明書を読み込み

### 4. 証明書の確認

```bash
# Certificate リソース確認
kubectl get certificate

# 出力例:
# NAME                  READY   SECRET                AGE
# guestbook-tls-cert    True    guestbook-tls-cert    5m

# Certificate詳細
kubectl describe certificate guestbook-tls-cert

# Secret確認
kubectl get secret guestbook-tls-cert -o yaml

# Secret内のデータ:
# data:
#   tls.crt: <base64 encoded certificate>
#   tls.key: <base64 encoded private key>
```

### 5. 証明書の内容確認

```bash
# Secretから証明書を抽出
kubectl get secret guestbook-tls-cert -o jsonpath='{.data.tls\.crt}' | base64 -d > cert.pem

# 証明書の詳細表示
openssl x509 -in cert.pem -text -noout

# 出力例:
# Certificate:
#     Data:
#         Version: 3 (0x2)
#         Serial Number: xxxxx
#         Signature Algorithm: sha256WithRSAEncryption
#         Issuer: O = cert-manager, CN = guestbook-tls-cert
#         Validity
#             Not Before: Oct 31 10:00:00 2024 GMT
#             Not After : Jan 29 10:00:00 2025 GMT  ← 90日間有効
#         Subject: CN = 4.190.29.229.nip.io  ← ドメイン名
#         Subject Public Key Info:
#             Public Key Algorithm: rsaEncryption
#                 RSA Public-Key: (2048 bit)
```

---

## 📊 アクセスパターンの比較

### 各アクセス方法の詳細

| 項目 | HTTP 直IP | HTTP ドメイン | HTTPS ドメイン |
|-----|----------|-------------|--------------|
| **URL** | http://4.190.29.229 | http://4.190.29.229.nip.io | https://4.190.29.229.nip.io |
| **DNS解決** | 不要 | nip.io | nip.io |
| **ポート** | 80 | 80 | 443 |
| **暗号化** | ❌ なし | ❌ なし | ✅ TLS 1.2/1.3 |
| **証明書** | - | - | Self-Signed |
| **Ingressルール** | ルール2 (host無し) | ルール1 (host指定) | ルール1 (host指定) + TLS |
| **ブラウザ警告** | なし | なし | ⚠️ あり（自己署名） |
| **使用場面** | 開発/テスト | 開発/テスト | デモ/本番前検証 |

### 通信内容の違い

#### HTTP（暗号化なし）

```
GET / HTTP/1.1
Host: 4.190.29.229
User-Agent: Mozilla/5.0
Accept: text/html
Connection: keep-alive

↓ 平文で送信（盗聴可能） ↓

HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 1234

<!DOCTYPE html>
<html>
...
```

#### HTTPS（暗号化あり）

```
Client Hello (TLS Handshake)
  ↓
Server Hello + Certificate
  ↓
Key Exchange
  ↓
【暗号化された通信】

暗号化前（アプリケーション層）:
GET / HTTP/1.1
Host: 4.190.29.229.nip.io
...

暗号化後（ネットワーク層）:
17 03 03 00 8f a3 7f 2b 9c 1e ...  ← 判読不可能
```

---

## 🔍 トラブルシューティング

### 問題1: HTTP直IPで404エラー

**症状:**
```
$ curl http://4.190.29.229
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx</center>
</body>
</html>
```

**原因:**
Ingressに`host`指定のルールしかない場合、ホスト名なしのリクエストがマッチしない。

```yaml
# ❌ これだけだとNG
rules:
  - host: 4.190.29.229.nip.io
    http:
      paths:
        - path: /
          backend:
            service:
              name: guestbook-service
```

**解決策:**
ホスト名なしのルールを追加

```yaml
# ✅ 正しい設定
rules:
  - host: 4.190.29.229.nip.io  # ドメインアクセス用
    http:
      paths:
        - path: /
          backend:
            service:
              name: guestbook-service
  - http:  # 直IPアクセス用（host無し）
      paths:
        - path: /
          backend:
            service:
              name: guestbook-service
```

### 問題2: HTTPS証明書エラー

**症状:**
```
NET::ERR_CERT_AUTHORITY_INVALID
この接続ではプライバシーが保護されません
```

**原因:**
自己署名証明書を使用しているため、ブラウザが信頼できないと判断。

**これは正常な動作です！**

**対応方法:**

1. **ブラウザで例外を許可**
   ```
   Chrome/Edge:
   - "詳細設定" をクリック
   - "4.190.29.229.nip.io にアクセスする（安全ではありません）" をクリック
   
   Firefox:
   - "詳細情報..." をクリック
   - "危険性を承知で続行" をクリック
   ```

2. **curl で検証を無効化**
   ```bash
   curl -k https://4.190.29.229.nip.io
   # -k = --insecure (証明書検証をスキップ)
   ```

3. **本番環境ではLet's Encryptを使用**

### 問題3: 証明書が発行されない

**確認コマンド:**
```bash
# Certificate リソース確認
kubectl get certificate

# NAME                  READY   SECRET                AGE
# guestbook-tls-cert    False   guestbook-tls-cert    2m  ← READYがFalse

# 詳細確認
kubectl describe certificate guestbook-tls-cert

# Events:
#   Type     Reason        Age   From          Message
#   ----     ------        ----  ----          -------
#   Warning  Failed        1m    cert-manager  Failed to create Order: ...
```

**原因と対策:**

| 原因 | 対策 |
|-----|------|
| cert-managerがインストールされていない | `kubectl apply -f cert-manager.yaml` |
| ClusterIssuerが存在しない | `kubectl get clusterissuer` で確認 |
| アノテーションが間違っている | `cert-manager.io/cluster-issuer: selfsigned-issuer` を確認 |
| cert-manager Podがクラッシュ | `kubectl get pods -n cert-manager` で確認 |

### 問題4: nip.ioが解決しない

**確認:**
```bash
# DNS解決テスト
nslookup 4.190.29.229.nip.io

# タイムアウトする場合:
# Server:  UnKnown
# Address:  x.x.x.x
# 
# DNS request timed out.
```

**原因:**
- nip.ioサービスが一時的にダウン
- ファイアウォールがDNSをブロック
- プロキシ環境

**対策:**
```bash
# 代替サービスを使用
# sslip.io (nip.ioの代替)
4.190.29.229.sslip.io

# または hosts ファイルを編集
# Windows: C:\Windows\System32\drivers\etc\hosts
# Linux/Mac: /etc/hosts
4.190.29.229 my-aks-app.local
```

---

## 🔒 セキュリティ考慮事項

### 自己署名証明書のリスク

| リスク | 説明 | 対策 |
|-------|------|------|
| **中間者攻撃** | 偽の証明書でも検証されない | 本番環境では使用しない |
| **ユーザーの誤解** | ユーザーが警告を無視する習慣がつく | デモであることを明示 |
| **信頼チェーン無し** | CAによる検証なし | 内部ネットワークのみで使用 |

### 本番環境への移行

#### Let's Encryptの使用

```yaml
# 本番用 ClusterIssuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # Let's Encrypt本番サーバー
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
```

```yaml
# Ingressのアノテーション変更
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod  # ← 変更
```

**Let's Encryptの利点:**
- ✅ 無料
- ✅ ブラウザに信頼される
- ✅ 自動更新（90日ごと）
- ✅ ワイルドカード証明書対応（DNS-01チャレンジ）

**制限:**
- 独自ドメインが必要（nip.ioでは使用不可）
- レート制限あり（週50証明書/ドメイン）
- 証明書の有効期限が90日

### HTTPSの重要性

| なぜHTTPSが必要か | 説明 |
|-----------------|------|
| **暗号化** | 通信内容が盗聴されない |
| **改ざん防止** | データが途中で変更されない |
| **認証** | 接続先サーバーの正当性を確認 |
| **SEO** | Googleは HTTPS サイトを優遇 |
| **HTTP/2** | HTTP/2 はHTTPSが必須 |
| **PWA** | Progressive Web Apps には必須 |
| **Cookie Secure** | Secure属性のCookieを使用可能 |

---

## 📈 パフォーマンス比較

### レイテンシの違い

```bash
# HTTP（平文）
$ time curl -s http://4.190.29.229 > /dev/null
real    0m0.052s

# HTTPS（TLS）
$ time curl -s https://4.190.29.229.nip.io > /dev/null
real    0m0.125s  ← TLSハンドシェイクのオーバーヘッド
```

### TLSハンドシェイクのコスト

```
HTTP:
  TCP 3-way handshake: 1 RTT
  Total: 1 RTT

HTTPS (TLS 1.2):
  TCP 3-way handshake: 1 RTT
  TLS handshake: 2 RTT
  Total: 3 RTT

HTTPS (TLS 1.3):
  TCP 3-way handshake: 1 RTT
  TLS handshake: 1 RTT
  Total: 2 RTT  ← TLS 1.3 で改善！
```

### 最適化手法

| 手法 | 効果 |
|-----|------|
| **TLS Session Resumption** | 再接続時のハンドシェイクを省略 |
| **HTTP/2** | 多重化で複数リクエストを効率化 |
| **Certificate Caching** | 証明書検証結果をキャッシュ |
| **OCSP Stapling** | 証明書失効確認を高速化 |

---

## 🎯 まとめ

### 実装のポイント

1. **HTTPSには必ずドメイン名が必要**
   - TLS証明書はドメイン名に対して発行される
   - 直IPではHTTPSは実質使用不可

2. **nip.io は開発/デモに最適**
   - DNS設定不要
   - 即座に使用可能
   - 証明書発行可能

3. **Ingressで両対応を実現**
   - `host`指定ルール: HTTPS/HTTPドメインアクセス
   - `host`無しルール: HTTP直IPアクセス

4. **cert-manager で証明書を自動管理**
   - 自己署名証明書の自動発行
   - 証明書の自動更新
   - Kubernetes Secretとして管理

### アクセス方法

| 方法 | URL | 用途 |
|-----|-----|------|
| **HTTP直IP** | http://4.190.29.229 | シンプルな動作確認 |
| **HTTPS** | https://4.190.29.229.nip.io | セキュアなデモ |

### 本番環境への移行

```yaml
# 1. 独自ドメインの準備
#    例: myapp.example.com

# 2. Let's Encrypt ClusterIssuer作成
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx

# 3. Ingress更新
spec:
  tls:
    - hosts:
        - myapp.example.com
      secretName: myapp-tls-cert
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            backend:
              service:
                name: guestbook-service

# 4. DNSレコード設定
# A Record: myapp.example.com → 4.190.29.229
```

---

## 🔗 関連ドキュメント

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Let's Encrypt](https://letsencrypt.org/)
- [nip.io](https://nip.io/)
- [TLS 1.3 Specification (RFC 8446)](https://tools.ietf.org/html/rfc8446)

---

**このアーキテクチャにより、開発からデモまでシームレスにHTTP/HTTPS両対応を実現しています！** 🚀
