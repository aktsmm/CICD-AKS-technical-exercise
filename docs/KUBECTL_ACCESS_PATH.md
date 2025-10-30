# kubectl アクセス経路の詳細

**作成日**: 2025 年 10 月 31 日  
**プロジェクト**: CICD-AKS-Technical Exercise

---

## 🔍 重要な発見

**kubectl はインターネット経由でアクセス可能だが、Pod 自体は外部からアクセスできない！**

これは Kubernetes のセキュリティモデルの核心です：

- ✅ **kubectl → AKS API Server**: パブリックエンドポイント（インターネット経由）
- ❌ **外部 → Pod 直接**: 不可能（プライベートネットワーク内）
- ✅ **Ingress → Pod**: 許可された経路のみ（HTTP/HTTPS）

---

## 📊 全体アーキテクチャ図

```
┌──────────────────────────────────────────────────────────────────┐
│                    あなたのPC (Windows)                            │
│                                                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  kubectl コマンド                                        │    │
│  │  (PowerShell / CMD)                                      │    │
│  └─────────────────────────────────────────────────────────┘    │
│                            │                                      │
│                            │ 1. 認証情報読み込み                  │
│                            ▼                                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  ~/.kube/config                                          │    │
│  │  - Cluster: aks-dev                                      │    │
│  │  - Server: https://aks-dev-ax196xm1.hcp.japaneast...    │    │
│  │  - User: clusterUser_rg-bbs-cicd-aks_aks-dev            │    │
│  │  - Certificate: クライアント証明書                        │    │
│  │  - Token: Azure AD Token                                 │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
                            │
                            │ 2. HTTPS通信 (Port 443)
                            │    TLS暗号化
                            │    🌐 インターネット経由
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Internet                                        │
│                   (パブリックネットワーク)                         │
└──────────────────────────────────────────────────────────────────┘
                            │
                            │ 3. Azure境界通過
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│               Azure Japan East Region                              │
│                                                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  🎯 AKS API Server (Control Plane)                      │    │
│  │  URL: https://aks-dev-ax196xm1.hcp.japaneast.azmk8s.io │    │
│  │  Port: 443 (HTTPS)                                       │    │
│  │  🌐 パブリックエンドポイント                             │    │
│  │                                                           │    │
│  │  機能:                                                    │    │
│  │  - 認証・認可 (Azure AD + Kubernetes RBAC)               │    │
│  │  - API リクエスト処理                                     │    │
│  │  - etcd への永続化                                        │    │
│  │  - Worker Node への指示                                  │    │
│  │                                                           │    │
│  │  ⚠️ セキュリティ:                                        │    │
│  │  - Azure AD認証必須                                      │    │
│  │  - クライアント証明書検証                                 │    │
│  │  - IP制限可能（現在は無制限）                            │    │
│  └─────────────────────────────────────────────────────────┘    │
│                            │                                      │
│                            │ 4. 内部通信 (プライベートネットワーク)│
│                            ▼                                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  🔒 VNet: vnetdev (10.0.0.0/16)                         │    │
│  │     プライベートネットワーク - 外部から直接アクセス不可   │    │
│  │                                                           │    │
│  │  ┌───────────────────────────────────────────────────┐  │    │
│  │  │ Subnet: aks-subnet (10.0.1.0/24)                 │  │    │
│  │  │                                                   │  │    │
│  │  │  ┌─────────────────────────────────────────┐    │  │    │
│  │  │  │ Worker Node 1                           │    │  │    │
│  │  │  │ (aks-nodepool1-96593604-vmss000000)     │    │  │    │
│  │  │  │                                          │    │  │    │
│  │  │  │  ┌──────────────────────────────────┐  │    │  │    │
│  │  │  │  │ kubelet (Node Agent)             │  │    │  │    │
│  │  │  │  │ - API Serverから指示受信         │  │    │  │    │
│  │  │  │  │ - Pod管理                        │  │    │  │    │
│  │  │  │  └──────────────────────────────────┘  │    │  │    │
│  │  │  │  ┌──────────────────────────────────┐  │    │  │    │
│  │  │  │  │ 🔒 Pod: guestbook-app-xxx       │  │    │  │    │
│  │  │  │  │ Private IP: 10.0.1.55           │  │    │  │    │
│  │  │  │  │                                   │  │    │  │    │
│  │  │  │  │  /app/wizexercise.txt            │  │    │  │    │
│  │  │  │  │                                   │  │    │  │    │
│  │  │  │  │  ❌ 外部から直接アクセス不可      │  │    │  │    │
│  │  │  │  └──────────────────────────────────┘  │    │  │    │
│  │  │  └─────────────────────────────────────────┘    │  │    │
│  │  │                                                   │  │    │
│  │  │  ┌─────────────────────────────────────────┐    │  │    │
│  │  │  │ Worker Node 2                           │    │  │    │
│  │  │  │ (aks-nodepool1-96593604-vmss000001)     │    │  │    │
│  │  │  │                                          │    │  │    │
│  │  │  │  ┌──────────────────────────────────┐  │    │  │    │
│  │  │  │  │ 🔒 Pod: guestbook-app-xxx       │  │    │  │    │
│  │  │  │  │ Private IP: 10.0.1.25           │  │    │  │    │
│  │  │  │  └──────────────────────────────────┘  │    │  │    │
│  │  │  └─────────────────────────────────────────┘    │  │    │
│  │  └───────────────────────────────────────────────────┘  │    │
│  │                                                           │    │
│  │  ┌───────────────────────────────────────────────────┐  │    │
│  │  │ 🌐 NGINX Ingress Controller (Public Access)      │  │    │
│  │  │ External IP: 4.190.29.229                         │  │    │
│  │  │ Azure Load Balancer経由                           │  │    │
│  │  │                                                   │  │    │
│  │  │  ✅ 許可された経路でPodにアクセス                 │  │    │
│  │  └───────────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🔐 認証フロー詳細

### kubectl exec コマンド実行時の流れ

```bash
kubectl exec -it guestbook-app-xxx -- cat /app/wizexercise.txt
```

#### ステップバイステップ

```
1. kubectl コマンド実行 (あなたのPC)
   └─> kubectl exec -it guestbook-app-xxx -- cat /app/wizexercise.txt

2. ~/.kube/config 読み込み
   ├─> Cluster: aks-dev
   ├─> Server: https://aks-dev-ax196xm1.hcp.japaneast.azmk8s.io:443
   ├─> User: clusterUser_rg-bbs-cicd-aks_aks-dev
   └─> Credentials:
       ├─> Client Certificate (X.509)
       └─> Azure AD Token

3. HTTPS リクエスト送信
   └─> TLS 1.2/1.3 暗号化通信
       └─> 🌐 Internet 経由で Azure へ
           └─> Port 443 (HTTPS)

4. AKS API Server で認証・認可
   ├─> ✅ クライアント証明書検証
   ├─> ✅ Azure AD トークン検証
   └─> ✅ Kubernetes RBAC チェック
       └─> ClusterRoleBinding: developer-cluster-admin
           └─> Role: cluster-admin (すべての権限)
               ⚠️ 脆弱性: 過剰な権限付与

5. API Server → kubelet 通信 (内部ネットワーク)
   └─> 🔒 VNet内部通信 (10.0.1.0/24)
       └─> Worker Node の kubelet にコマンド転送

6. kubelet → Pod 実行
   └─> Pod内でコマンド実行
       └─> cat /app/wizexercise.txt

7. レスポンス返却
   └─> kubelet → API Server → kubectl
       └─> ファイル内容が画面に表示
```

---

## 🌐 ネットワーク層の詳細

### 通信プロトコルスタック

| レイヤー               | プロトコル | ポート | 暗号化       | 詳細                |
| ---------------------- | ---------- | ------ | ------------ | ------------------- |
| **アプリケーション層** | HTTPS      | 443    | TLS 1.2/1.3  | Kubernetes REST API |
| **トランスポート層**   | TCP        | 443    | -            | 信頼性のある通信    |
| **ネットワーク層**     | IP         | -      | -            | ルーティング        |
| **認証層**             | mTLS       | -      | X.509 証明書 | 双方向認証          |

### 暗号化の詳細

```
TLS Handshake:
1. Client Hello (kubectl)
   └─> 対応暗号スイート提示

2. Server Hello (API Server)
   └─> 暗号スイート選択
   └─> サーバー証明書送信

3. Client Certificate (kubectl)
   └─> クライアント証明書送信

4. Finished
   └─> 暗号化通信開始
```

---

## 🔑 認証情報の管理

### kubectl 設定ファイル

**場所**: `C:\Users\<username>\.kube\config`

```yaml
apiVersion: v1
clusters:
  - cluster:
      certificate-authority-data: DATA+OMITTED
      server: https://aks-dev-ax196xm1.hcp.japaneast.azmk8s.io:443
    name: aks-dev
contexts:
  - context:
      cluster: aks-dev
      user: clusterUser_rg-bbs-cicd-aks_aks-dev
    name: aks-dev
current-context: aks-dev
kind: Config
preferences: {}
users:
  - name: clusterUser_rg-bbs-cicd-aks_aks-dev
    user:
      client-certificate-data: DATA+OMITTED
      client-key-data: DATA+OMITTED
      token: REDACTED
```

### 認証要素

| 要素                   | 説明                                           | 用途                        |
| ---------------------- | ---------------------------------------------- | --------------------------- |
| **Server URL**         | `aks-dev-ax196xm1.hcp.japaneast.azmk8s.io:443` | API Server のエンドポイント |
| **Client Certificate** | X.509 証明書                                   | クライアント認証            |
| **Client Key**         | 秘密鍵                                         | 証明書の署名検証            |
| **Azure AD Token**     | JWT 形式                                       | Azure AD 認証               |
| **CA Certificate**     | 認証局証明書                                   | サーバー証明書検証          |

---

## 🎯 API Server の詳細

### URL 構造

```
https://aks-dev-ax196xm1.hcp.japaneast.azmk8s.io:443
        │       │       │    │          │           │
        │       │       │    │          │           └─ ポート (HTTPS)
        │       │       │    │          └─────────────── Azure Kubernetesドメイン
        │       │       │    └────────────────────────── リージョン (Japan East)
        │       │       └─────────────────────────────── Hosted Control Plane
        │       └─────────────────────────────────────── 一意識別子 (ランダムハッシュ)
        └─────────────────────────────────────────────── クラスタ名
```

### 特徴

| 項目             | 詳細                     |
| ---------------- | ------------------------ |
| **管理主体**     | Azure (マネージド)       |
| **アクセス方法** | パブリックエンドポイント |
| **可用性**       | 99.95% SLA               |
| **スケーリング** | Azure 自動管理           |
| **アップデート** | Azure 自動適用           |
| **バックアップ** | etcd 自動バックアップ    |

### セキュリティ機能

- ✅ **Azure AD 統合**: エンタープライズ認証
- ✅ **RBAC**: きめ細かいアクセス制御
- ✅ **Network Policy**: Pod 間通信制御
- ✅ **Private Cluster**: API Server をプライベート化可能（現在は無効）
- ✅ **IP 制限**: 特定 IP からのみアクセス許可可能（現在は無制限）
- ✅ **監査ログ**: すべての API 呼び出しを記録

---

## 🚦 アクセス制御の比較

### kubectl vs Web ブラウザ

| アクセス方法      | 経路                                          | 認証              | ターゲット          | アクセス可否 |
| ----------------- | --------------------------------------------- | ----------------- | ------------------- | ------------ |
| **kubectl exec**  | Internet → API Server → kubelet → Pod         | Azure AD + 証明書 | Pod 内部            | ✅ 可能      |
| **Web Browser**   | Internet → Azure LB → Ingress → Service → Pod | なし              | HTTP/HTTPS endpoint | ✅ 可能      |
| **直接 Pod IP**   | Internet → ???                                | ???               | Pod (10.0.1.x)      | ❌ 不可能    |
| **直接 Node SSH** | Internet → ???                                | ???               | Worker Node         | ❌ 不可能    |

### なぜ kubectl は外部からアクセスできるのか？

**答え: API Server がパブリックエンドポイントだから**

```
kubectl → 🌐 Internet → 🎯 API Server (Public) → 🔒 kubelet (Private) → 🔒 Pod (Private)
           ↑                    ↑                       ↑                    ↑
         外部から             Azure管理の             VNet内部のみ          VNet内部のみ
         アクセス可能         パブリックIP            アクセス可能          アクセス可能
```

**重要:**

- API Server は**意図的にパブリック**にされている
- これにより、どこからでもクラスタ管理が可能
- ただし、**強固な認証・認可**で保護されている

### なぜ Pod には直接アクセスできないのか？

**答え: Pod はプライベート IP しか持たないから**

```
外部 → ❌ Pod (10.0.1.55) → 到達不可
       └─ VNet内部のプライベートIP
          └─ Internet routing不可

外部 → ✅ Ingress (4.190.29.229) → Pod
       └─ Azure Load BalancerのパブリックIP
          └─ 許可された経路でPodにアクセス
```

---

## 🛡️ セキュリティ上の考慮点

### パブリック API Server のリスク

| リスク                   | 説明                | 対策                                |
| ------------------------ | ------------------- | ----------------------------------- |
| **ブルートフォース攻撃** | 認証情報の総当たり  | ✅ Azure AD MFA 強制                |
| **認証情報漏洩**         | ~/.kube/config 流出 | ✅ 定期的な証明書ローテーション     |
| **DDoS 攻撃**            | API Server 過負荷   | ✅ Azure DDoS Protection            |
| **不正アクセス**         | 未承認ユーザー      | ✅ RBAC + Azure AD 条件付きアクセス |
| **内部脅威**             | 過剰な権限          | ⚠️ cluster-admin 権限（脆弱性）     |

### 本番環境での推奨設定

```bash
# 1. Private Cluster有効化
az aks create --enable-private-cluster

# 2. API Server IP制限
az aks update \
  --api-server-authorized-ip-ranges "203.0.113.0/24,198.51.100.0/24"

# 3. Azure AD統合強化
az aks update --enable-azure-rbac

# 4. ネットワークポリシー有効化
az aks create --network-policy azure
```

---

## 📊 kubectl vs Ingress 比較表

| 項目             | kubectl                                    | Ingress (Web)                                                 |
| ---------------- | ------------------------------------------ | ------------------------------------------------------------- |
| **経路**         | PC → Internet → API Server → kubelet → Pod | PC → Internet → Azure LB → Ingress Controller → Service → Pod |
| **認証**         | Azure AD + クライアント証明書              | なし（パブリックアクセス）                                    |
| **プロトコル**   | HTTPS (Port 443)                           | HTTP/HTTPS (Port 80/443)                                      |
| **ターゲット**   | Kubernetes API                             | アプリケーションエンドポイント                                |
| **アクセス範囲** | すべてのリソース（RBAC 次第）              | 公開された HTTP/HTTPS のみ                                    |
| **用途**         | 管理・運用・デバッグ                       | エンドユーザーアクセス                                        |
| **セキュリティ** | 強固（多要素認証）                         | 弱い（認証なし） ⚠️                                           |
| **外部公開**     | API Server のみ公開                        | Ingress Controller を公開                                     |

---

## 🔍 検証コマンド

### API Server 情報の確認

```bash
# クラスタ情報
kubectl cluster-info

# 出力例:
# Kubernetes control plane is running at https://aks-dev-ax196xm1.hcp.japaneast.azmk8s.io:443

# 現在の設定表示
kubectl config view --minify

# 接続テスト
kubectl get nodes
```

### ネットワーク確認

```bash
# API Serverへの接続確認
curl -k https://aks-dev-ax196xm1.hcp.japaneast.azmk8s.io:443

# Pod IP確認（プライベートIP）
kubectl get pods -o wide

# Ingress IP確認（パブリックIP）
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

---

## 💡 まとめ

### 重要なポイント

1. **kubectl はパブリックアクセス**

   - API Server がパブリックエンドポイントとして Internet 公開
   - Azure AD + 証明書による強固な認証

2. **Pod はプライベート**

   - VNet 内部のプライベート IP のみ
   - 直接外部アクセス不可

3. **2 つのアクセス経路**

   - 管理用: kubectl → API Server → Pod
   - エンドユーザー用: Browser → Ingress → Service → Pod

4. **セキュリティの多層防御**
   - API Server: 認証・認可・監査
   - Network: VNet 分離、NSG、Network Policy
   - RBAC: きめ細かい権限制御

### デモ環境での脆弱性

⚠️ **意図的に設定した脆弱性**:

- API Server が IP 制限なしでパブリック公開
- cluster-admin 権限の過剰付与
- Ingress が認証なしでパブリック公開

本番環境では**必ず対策すること**！

---

## 📚 参考資料

- [Azure Kubernetes Service (AKS) documentation](https://learn.microsoft.com/azure/aks/)
- [Kubernetes API Server](https://kubernetes.io/docs/concepts/overview/kubernetes-api/)
- [Azure AD integration for AKS](https://learn.microsoft.com/azure/aks/azure-ad-integration-cli)
- [Private AKS clusters](https://learn.microsoft.com/azure/aks/private-clusters)
