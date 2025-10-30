# wizexercise.txt のコンテナ転送メカニズム

**作成日**: 2025 年 10 月 31 日  
**プロジェクト**: CICD-AKS-Technical Exercise

---

## 🎯 概要

このドキュメントでは、`wizexercise.txt` がどのようにしてローカル環境から Kubernetes Pod のコンテナ内部に届くのか、その全プロセスを詳細に解説します。

**重要な発見**: これは「転送」ではなく「焼き込み」です。

---

## 📊 全体フロー図

```
┌─────────────────────────────────────────────────────────────────┐
│  1. ローカル開発環境 (開発者のPC)                                 │
│                                                                   │
│  📁 wiz-technical-exercise/app/                                  │
│     ├── app.js                                                   │
│     ├── package.json                                             │
│     ├── Dockerfile                 ← 📝 ビルド手順書            │
│     └── wizexercise.txt            ← 📄 このファイル            │
│                                                                   │
│  $ git add .                                                     │
│  $ git commit -m "Update wizexercise.txt"                       │
│  $ git push origin main           ← ⬆️ GitHubにプッシュ         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ GitHub Actions トリガー
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. GitHub Actions (CI/CD Runner)                                │
│                                                                   │
│  🤖 Workflow: app-deploy.yml                                     │
│                                                                   │
│  Step 1: Checkout Code                                           │
│  ├─> actions/checkout@v4                                         │
│  ├─> git clone リポジトリ全体をダウンロード                      │
│  └─> app/wizexercise.txt も含まれる                             │
│                                                                   │
│  Step 2: Build Docker Image                                      │
│  ├─> cd app/                                                     │
│  ├─> docker build -t guestbook:${GITHUB_SHA} .                  │
│  │                                                                │
│  │   🐳 Dockerビルドプロセス開始                                 │
│  │   ┌──────────────────────────────────────────────┐          │
│  │   │ Dockerfile の実行 (レイヤーごとに処理)        │          │
│  │   │                                                │          │
│  │   │ Step 1/7: FROM node:18-alpine                 │          │
│  │   │   └─> ベースイメージをPull                    │          │
│  │   │                                                │          │
│  │   │ Step 2/7: WORKDIR /app                        │          │
│  │   │   └─> /app ディレクトリ作成                   │          │
│  │   │                                                │          │
│  │   │ Step 3/7: COPY wizexercise.txt /app/       ⭐ │          │
│  │   │   └─> ローカル → イメージレイヤーに焼き込み   │          │
│  │   │       ファイル内容がイメージに永続化          │          │
│  │   │                                                │          │
│  │   │ Step 4/7: COPY package*.json ./               │          │
│  │   │ Step 5/7: RUN npm install                     │          │
│  │   │ Step 6/7: COPY . .                            │          │
│  │   │ Step 7/7: CMD ["npm", "start"]                │          │
│  │   └──────────────────────────────────────────────┘          │
│  │                                                                │
│  └─> 🎁 Dockerイメージ完成                                       │
│      └─> wizexercise.txt がイメージに焼き込まれた               │
│          (イメージレイヤーの一部として永続化)                    │
│                                                                   │
│  Step 3: Trivy Security Scan                                     │
│  └─> イメージの脆弱性スキャン                                    │
│                                                                   │
│  Step 4: Push to ACR                                             │
│  └─> docker push <ACR_NAME>.azurecr.io/guestbook:${SHA}         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ イメージをAzure Container Registryに保存
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. Azure Container Registry (ACR)                               │
│                                                                   │
│  📦 コンテナイメージ保管庫                                       │
│     Registry: <ACR_NAME>.azurecr.io                             │
│     Repository: guestbook                                        │
│     Tag: ${GITHUB_SHA}                                           │
│                                                                   │
│  イメージレイヤー構造:                                           │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Layer 1: node:18-alpine (200MB)                        │    │
│  │   └─> Node.js 18 ランタイム                            │    │
│  ├────────────────────────────────────────────────────────┤    │
│  │ Layer 2: WORKDIR /app (0.1KB)                          │    │
│  │   └─> ディレクトリ作成                                 │    │
│  ├────────────────────────────────────────────────────────┤    │
│  │ Layer 3: wizexercise.txt (0.8KB)                    ⭐ │    │
│  │   └─> ファイル内容が焼き込まれている                   │    │
│  ├────────────────────────────────────────────────────────┤    │
│  │ Layer 4: package.json (0.5KB)                          │    │
│  ├────────────────────────────────────────────────────────┤    │
│  │ Layer 5: npm dependencies (50MB)                       │    │
│  ├────────────────────────────────────────────────────────┤    │
│  │ Layer 6: Application code (2MB)                        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                   │
│  🔒 特徴:                                                        │
│  - イメージは不変 (Immutable)                                   │
│  - レイヤーキャッシュで効率的                                    │
│  - SHA256ハッシュで整合性保証                                   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ Kubernetes が Pull
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. AKS Cluster (Kubernetes)                                     │
│                                                                   │
│  📋 Deployment 適用                                              │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ apiVersion: apps/v1                                     │    │
│  │ kind: Deployment                                        │    │
│  │ metadata:                                               │    │
│  │   name: guestbook-app                                   │    │
│  │ spec:                                                   │    │
│  │   replicas: 2                                           │    │
│  │   containers:                                           │    │
│  │   - name: guestbook                                     │    │
│  │     image: <ACR>.azurecr.io/guestbook:${SHA}  ← ⭐    │    │
│  │     ports:                                              │    │
│  │     - containerPort: 3000                               │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                   │
│  🐳 コンテナ起動プロセス                                         │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Worker Node 1: aks-nodepool1-xxx-vmss000000            │    │
│  │                                                         │    │
│  │  1. kubelet がイメージを検知                           │    │
│  │  2. ACRに認証 (Managed Identity使用)                   │    │
│  │  3. イメージをPull (全レイヤーをダウンロード)          │    │
│  │     └─> docker pull <ACR>/guestbook:${SHA}            │    │
│  │  4. コンテナを起動                                      │    │
│  │     └─> イメージの全レイヤーをマージして展開           │    │
│  │                                                         │    │
│  │  📦 Pod: guestbook-app-xxx-6j7s4                       │    │
│  │     Container: guestbook                               │    │
│  │     ├─ /                                               │    │
│  │     │  ├─ bin/                                         │    │
│  │     │  ├─ usr/                                         │    │
│  │     │  └─ app/                ← WORKDIR               │    │
│  │     │      ├── app.js                                  │    │
│  │     │      ├── package.json                            │    │
│  │     │      ├── wizexercise.txt  ← ✅ ここに存在！     │    │
│  │     │      ├── views/                                  │    │
│  │     │      └── node_modules/                          │    │
│  │     └─ プロセス: node /app/app.js (PID 1)            │    │
│  │                                                         │    │
│  │  🔍 ファイル属性:                                      │    │
│  │     -rw-r--r-- 1 root root 866 Oct 30 18:22 wizexercise.txt│
│  └────────────────────────────────────────────────────────┘    │
│                                                                   │
│  📊 Pod 2も同じ構成:                                            │
│  └─> guestbook-app-xxx-vdvjr (Worker Node 2)                   │
│      └─> 同じイメージから起動 = 同じファイルを含む             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔑 核心メカニズム: Dockerfile の COPY 命令

### Dockerfile の該当部分

```dockerfile
FROM node:18-alpine

WORKDIR /app

# ⭐ wizexercise.txt をコピー(デモ用)
COPY wizexercise.txt /app/wizexercise.txt

# アプリファイルコピー
COPY package*.json ./
RUN npm install --omit=dev

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
```

### COPY 命令の動作詳細

```dockerfile
COPY wizexercise.txt /app/wizexercise.txt
│    │                │
│    │                └─ コピー先 (イメージ内のパス)
│    └─────────────────── コピー元 (ビルドコンテキスト内)
└──────────────────────── Docker命令
```

**処理の流れ:**

1. **ビルドコンテキスト準備**

   ```bash
   # app/ ディレクトリがビルドコンテキストになる
   docker build -t guestbook:abc123 /path/to/app/
   ```

2. **COPY 命令実行**

   - ビルドコンテキスト内の `wizexercise.txt` を検索
   - ファイル内容を読み込み
   - 新しいイメージレイヤーを作成
   - レイヤー内に `/app/wizexercise.txt` としてファイルを保存

3. **レイヤー作成**

   ```
   Layer SHA256: a3f4b5c6d7e8f9...
   ├─ 変更タイプ: ADD
   ├─ ファイルパス: /app/wizexercise.txt
   ├─ サイズ: 866 bytes
   └─ 内容: (ファイルの実データ)
   ```

4. **イメージに焼き込み**
   - レイヤーはイメージメタデータに含まれる
   - イメージが Pull されると、このレイヤーも展開される
   - **ファイルは永続的にイメージの一部となる**

---

## 🏗️ Docker イメージのレイヤー構造

### レイヤーの仕組み

```
Dockerイメージ = 複数のレイヤーの積み重ね

┌─────────────────────────────────────┐
│ Layer 6: Application Code           │ ← COPY . .
├─────────────────────────────────────┤
│ Layer 5: npm dependencies           │ ← RUN npm install
├─────────────────────────────────────┤
│ Layer 4: package.json               │ ← COPY package*.json
├─────────────────────────────────────┤
│ Layer 3: wizexercise.txt         ⭐ │ ← COPY wizexercise.txt
├─────────────────────────────────────┤
│ Layer 2: WORKDIR /app               │ ← WORKDIR
├─────────────────────────────────────┤
│ Layer 1: node:18-alpine             │ ← FROM
└─────────────────────────────────────┘

コンテナ起動時:
→ 全レイヤーをマージして単一のファイルシステムとして見せる
```

### レイヤーの特徴

| 特徴                  | 説明                           |
| --------------------- | ------------------------------ |
| **Read-Only**         | レイヤーは読み取り専用 (不変)  |
| **キャッシュ可能**    | 同じレイヤーは再利用される     |
| **SHA256 識別**       | 内容ハッシュで一意に識別       |
| **増分保存**          | 変更部分だけを新レイヤーに保存 |
| **Union File System** | 複数レイヤーを透過的に重ねる   |

---

## 🔄 完全なライフサイクル

### Phase 1: 開発 (ローカル環境)

```bash
# ファイルの場所
D:\00_temp\wizwork\wiz-technical-exercise\app\wizexercise.txt

# 内容編集
notepad wizexercise.txt

# Git にコミット
git add app/wizexercise.txt
git commit -m "Update wizexercise.txt"
git push origin main
```

**状態:** ファイルシステム上の通常のテキストファイル

---

### Phase 2: ビルド (GitHub Actions)

#### 2-1. コードチェックアウト

```yaml
- name: Checkout Code
  uses: actions/checkout@v4
```

**動作:**

- リポジトリ全体をクローン
- `app/wizexercise.txt` も含まれる
- GitHub Actions Runner の VM にファイル配置

#### 2-2. Docker ビルド

```yaml
- name: Build Docker Image
  run: |
    cd app
    docker build -t guestbook:${{ github.sha }} .
```

**詳細プロセス:**

```bash
# 実際に実行されるコマンド
docker build -t guestbook:abc123def456 .

# Dockerデーモンの処理:

[Step 1/7] FROM node:18-alpine
 ---> Pulling image from Docker Hub
 ---> Using cached image (if available)
 ---> Image ID: 1a2b3c4d5e6f

[Step 2/7] WORKDIR /app
 ---> Creating directory /app
 ---> Layer ID: 7g8h9i0j1k2l

[Step 3/7] COPY wizexercise.txt /app/wizexercise.txt
 ---> Reading file: ./wizexercise.txt (866 bytes)
 ---> Creating new layer
 ---> Adding file to layer: /app/wizexercise.txt
 ---> Layer ID: 3m4n5o6p7q8r  ⭐ このレイヤーにファイルが含まれる

[Step 4/7] COPY package*.json ./
 ---> Layer ID: 9s0t1u2v3w4x

[Step 5/7] RUN npm install --omit=dev
 ---> Running command in temporary container
 ---> Committing changes to new layer
 ---> Layer ID: 5y6z7a8b9c0d

[Step 6/7] COPY . .
 ---> Layer ID: 1e2f3g4h5i6j

[Step 7/7] CMD ["npm", "start"]
 ---> Layer ID: 7k8l9m0n1o2p

Successfully built abc123def456
Successfully tagged guestbook:abc123def456
```

**イメージメタデータ:**

```json
{
  "Id": "sha256:abc123def456...",
  "RepoTags": ["guestbook:abc123def456"],
  "Layers": [
    "sha256:1a2b3c4d5e6f...", // node:18-alpine
    "sha256:7g8h9i0j1k2l...", // WORKDIR
    "sha256:3m4n5o6p7q8r...", // wizexercise.txt ⭐
    "sha256:9s0t1u2v3w4x...", // package.json
    "sha256:5y6z7a8b9c0d...", // npm install
    "sha256:1e2f3g4h5i6j...", // app code
    "sha256:7k8l9m0n1o2p..." // CMD
  ]
}
```

**状態:** Docker イメージレイヤーとして永続化

---

### Phase 3: プッシュ (ACR)

```yaml
- name: Push to ACR
  run: |
    docker push <ACR_NAME>.azurecr.io/guestbook:${{ github.sha }}
```

**動作:**

```bash
# レイヤーごとにプッシュ
The push refers to repository [<ACR>.azurecr.io/guestbook]
7k8l9m0n1o2p: Preparing
1e2f3g4h5i6j: Preparing
5y6z7a8b9c0d: Preparing
9s0t1u2v3w4x: Preparing
3m4n5o6p7q8r: Preparing  ⭐ wizexercise.txt レイヤー
7g8h9i0j1k2l: Preparing
1a2b3c4d5e6f: Preparing

# アップロード
3m4n5o6p7q8r: Pushed  ⭐ 866 bytes
# ... (他のレイヤーもプッシュ)

abc123def456: digest: sha256:xxx... size: 2456
```

**ACR での保存:**

- ストレージ: Azure Blob Storage
- 暗号化: 保存時暗号化 (Encryption at Rest)
- アクセス制御: Azure RBAC
- レプリケーション: Geo-redundant storage (GRS)

**状態:** Azure Container Registry に永続保存

---

### Phase 4: デプロイ (Kubernetes)

#### 4-1. Deployment 更新

```yaml
- name: Update Deployment
  run: |
    kubectl set image deployment/guestbook-app \
      guestbook=<ACR>.azurecr.io/guestbook:${{ github.sha }}
```

**Kubernetes の動作:**

```yaml
# Deployment が更新される
spec:
  template:
    spec:
      containers:
        - name: guestbook
          image: <ACR>.azurecr.io/guestbook:abc123def456 # 新しいSHA
```

#### 4-2. Pod のローリングアップデート

```
1. 新しいReplicaSet作成
   └─> guestbook-app-abc123def456

2. Worker Node 1で新しいPod起動
   ├─> kubelet がイメージ仕様を読み取る
   ├─> ACRから認証 (Managed Identity)
   ├─> イメージをPull
   │   └─> すべてのレイヤーをダウンロード
   │       ├─ Layer 1: node:18-alpine (キャッシュ済み)
   │       ├─ Layer 2: WORKDIR (キャッシュ済み)
   │       ├─ Layer 3: wizexercise.txt (新規ダウンロード) ⭐
   │       ├─ Layer 4: package.json
   │       ├─ Layer 5: npm dependencies
   │       ├─ Layer 6: app code
   │       └─ Layer 7: CMD
   └─> コンテナ起動

3. ヘルスチェック
   └─> HTTP GET /health → 200 OK

4. Service に追加
   └─> Endpoint リストに追加

5. 古いPodを削除
   └─> グレースフルシャットダウン
```

#### 4-3. コンテナ内のファイルシステム

```bash
# Pod内で確認
kubectl exec -it guestbook-app-xxx-6j7s4 -- sh

# ファイルシステム構造
/ # ls -la /app/
total 48
drwxr-xr-x    1 root     root          4096 Oct 30 18:22 .
drwxr-xr-x    1 root     root          4096 Oct 31 03:00 ..
-rw-r--r--    1 root     root          1234 Oct 30 18:22 app.js
-rw-r--r--    1 root     root           456 Oct 30 18:22 package.json
-rw-r--r--    1 root     root           866 Oct 30 18:22 wizexercise.txt  ⭐
drwxr-xr-x    2 root     root          4096 Oct 30 18:22 views
drwxr-xr-x  100 root     root          4096 Oct 30 18:22 node_modules

# ファイル内容確認
/ # cat /app/wizexercise.txt
氏名: yamapan
日付: 2025-10-28
CICD-AKS-Technical Exercise
...
```

**状態:** コンテナ内のファイルシステムとして展開済み

---

## 🔍 検証方法

### ビルド時の確認

```bash
# ローカルでビルド
cd app/
docker build -t test-guestbook .

# レイヤー履歴確認
docker history test-guestbook

# 出力例:
# IMAGE          CREATED         CREATED BY                                      SIZE
# abc123def     2 minutes ago   /bin/sh -c #(nop) CMD ["npm" "start"]           0B
# 1e2f3g4h5     2 minutes ago   /bin/sh -c #(nop) COPY dir:... in /app/         2MB
# 5y6z7a8b9     3 minutes ago   /bin/sh -c npm install --omit=dev               50MB
# 9s0t1u2v3     3 minutes ago   /bin/sh -c #(nop) COPY file:... in /app/        0.5KB
# 3m4n5o6p7     3 minutes ago   /bin/sh -c #(nop) COPY file:... in /app/wiz...  866B ⭐
# 7g8h9i0j1     3 minutes ago   /bin/sh -c #(nop) WORKDIR /app                  0B
# 1a2b3c4d5     1 day ago       /bin/sh -c #(nop) ...                           200MB

# イメージ詳細確認
docker inspect test-guestbook

# レイヤー一覧
"Layers": [
    "sha256:1a2b3c4d5e6f...",
    "sha256:7g8h9i0j1k2l...",
    "sha256:3m4n5o6p7q8r...",  ⭐ wizexercise.txt
    ...
]
```

### イメージ内のファイル確認

```bash
# イメージからコンテナを起動（一時的）
docker run --rm test-guestbook ls -la /app/

# 出力:
# -rw-r--r-- 1 root root  1234 Oct 30 18:22 app.js
# -rw-r--r-- 1 root root   866 Oct 30 18:22 wizexercise.txt ⭐
# -rw-r--r-- 1 root root   456 Oct 30 18:22 package.json
# drwxr-xr-x 2 root root  4096 Oct 30 18:22 views

# ファイル内容確認
docker run --rm test-guestbook cat /app/wizexercise.txt
```

### デプロイ後の確認

```bash
# Pod一覧
kubectl get pods -l app=guestbook

# 出力:
# NAME                             READY   STATUS    RESTARTS   AGE
# guestbook-app-xxx-6j7s4          1/1     Running   0          5m
# guestbook-app-xxx-vdvjr          1/1     Running   0          5m

# Pod内でファイル確認
kubectl exec -it guestbook-app-xxx-6j7s4 -- ls -la /app/wizexercise.txt

# 出力:
# -rw-r--r-- 1 root root 866 Oct 30 18:22 /app/wizexercise.txt

# ファイル内容確認
kubectl exec -it guestbook-app-xxx-6j7s4 -- cat /app/wizexercise.txt

# 両方のPodで同じ内容を確認
kubectl exec guestbook-app-xxx-6j7s4 -- md5sum /app/wizexercise.txt
kubectl exec guestbook-app-xxx-vdvjr -- md5sum /app/wizexercise.txt
# 同じMD5ハッシュ = 同じファイル ✅
```

---

## 💡 重要な概念

### 転送 vs 焼き込み

| 方式         | 説明                       | タイミング       | 永続性              |
| ------------ | -------------------------- | ---------------- | ------------------- |
| **転送**     | 実行時にファイルをコピー   | コンテナ起動時   | コンテナに依存      |
| **焼き込み** | ビルド時にイメージに含める | イメージビルド時 | イメージに永続化 ✅ |

**このプロジェクトでは「焼き込み」を使用:**

- `Dockerfile` の `COPY` 命令でイメージに焼き込み
- すべての Pod が同じファイルを持つ
- イメージが存在する限り永続的

### Immutable Infrastructure (不変インフラ)

```
従来の方式:
サーバー起動 → ファイルをSCP転送 → 設定を変更
問題: サーバーごとに状態が異なる可能性

Docker方式 (Immutable):
イメージビルド → すべてを焼き込み → コンテナ起動
利点: すべてのコンテナが同一の状態から起動
```

**メリット:**

- ✅ 再現性: どの環境でも同じ結果
- ✅ 一貫性: すべての Pod が同じファイルを持つ
- ✅ デバッグ容易: イメージは変更されない
- ✅ ロールバック簡単: 古いイメージに戻すだけ

---

## 🎯 Wiz 課題要件との対応

### 要件: コンテナ内に wizexercise.txt (氏名を記載) を含める

**実装方法:**

1. **ファイル作成**

   ```bash
   echo "氏名: yamapan" > app/wizexercise.txt
   ```

2. **Dockerfile に記述**

   ```dockerfile
   COPY wizexercise.txt /app/wizexercise.txt
   ```

3. **ビルド・デプロイ**

   ```bash
   docker build -t guestbook .
   docker push <ACR>/guestbook
   kubectl set image ...
   ```

4. **検証**
   ```bash
   kubectl exec -it pod-name -- cat /app/wizexercise.txt
   ```

**要件達成: ✅**

- ファイルはコンテナ内に存在
- 氏名 (yamapan) が記載されている
- 稼働中のコンテナで存在を証明可能

### プレゼンでの説明ポイント

1. **どのように挿入したか**

   - Dockerfile の `COPY` 命令を使用
   - イメージビルド時に焼き込み

2. **存在を証明**

   ```bash
   # ライブデモ
   kubectl exec -it $(kubectl get pod -l app=guestbook -o jsonpath='{.items[0].metadata.name}') \
     -- cat /app/wizexercise.txt
   ```

3. **なぜこの方式か**
   - 不変インフラの実践
   - すべての Pod で一貫性保証
   - デプロイの自動化

---

## 🔄 更新プロセス

### ファイル内容を変更する場合

```bash
# 1. ローカルでファイル編集
vim app/wizexercise.txt

# 2. Git コミット
git add app/wizexercise.txt
git commit -m "Update wizexercise.txt content"
git push origin main

# 3. GitHub Actions が自動実行
# - 新しいイメージをビルド (新しいSHA)
# - 新しいレイヤーに更新されたファイルを含める
# - ACRにプッシュ
# - Kubernetes Deployment を更新

# 4. Podがローリングアップデート
# - 新しいイメージから新しいPodが起動
# - 更新されたwizexercise.txtを含む
```

**重要:** ファイルを変更するには、イメージを再ビルドする必要がある

---

## 📚 技術詳細

### Docker Build Context

```bash
docker build -t guestbook:latest .
                                 └─ ビルドコンテキスト (current directory)
```

**ビルドコンテキストの役割:**

- `COPY` や `ADD` 命令でアクセスできるファイル範囲
- `.dockerignore` で除外ファイルを指定可能
- GitHub Actions では `app/` ディレクトリがコンテキスト

### Union File System

```
コンテナのファイルシステム = Union FS

┌─────────────────────────┐
│ Container Layer (RW)    │ ← 書き込み可能レイヤー
├─────────────────────────┤
│ Layer 6: App Code (RO)  │ ↑
├─────────────────────────┤ │ 読み取り専用レイヤー
│ Layer 5: Dependencies   │ │ (イメージレイヤー)
├─────────────────────────┤ │
│ Layer 4: package.json   │ │
├─────────────────────────┤ │
│ Layer 3: wizexercise.txt│ │ ⭐
├─────────────────────────┤ │
│ Layer 2: WORKDIR        │ │
├─────────────────────────┤ │
│ Layer 1: Base Image     │ ↓
└─────────────────────────┘

ファイルアクセス時:
- 上位レイヤーから順に検索
- 最初に見つかったファイルを使用
- コンテナレイヤーで変更可能（揮発性）
- イメージレイヤーは不変
```

### レイヤーキャッシュ

```
初回ビルド:
Step 1: FROM node:18-alpine      (Pull from registry)
Step 2: WORKDIR /app             (New layer)
Step 3: COPY wizexercise.txt     (New layer) ⭐
Step 4: COPY package.json        (New layer)
Step 5: RUN npm install          (New layer)

2回目のビルド (wizexercise.txtを変更):
Step 1: FROM node:18-alpine      (Using cache ✅)
Step 2: WORKDIR /app             (Using cache ✅)
Step 3: COPY wizexercise.txt     (Changed, new layer) ⭐
Step 4: COPY package.json        (Cache invalidated, rebuild)
Step 5: RUN npm install          (Cache invalidated, rebuild)

結果: Step 3以降が再実行される
```

---

## 🛡️ セキュリティ考慮事項

### 機密情報の取り扱い

⚠️ **wizexercise.txt はデモ用なので問題ないが、一般論として:**

```dockerfile
# ❌ 悪い例: 機密情報をイメージに焼き込む
COPY secrets.txt /app/secrets.txt  # イメージに永続化される！

# ✅ 良い例: 実行時に注入
# Kubernetes Secret を使用
```

**理由:**

- Docker イメージは配布される可能性がある
- レイヤーは削除しても履歴に残る
- イメージを Pull した誰でもファイルを抽出可能

### 最小権限の原則

```dockerfile
# wizexercise.txt の権限
-rw-r--r-- 1 root root 866 Oct 30 18:22 /app/wizexercise.txt
└─┬──┘ │    │    │    └─ サイズ
  │    │    │    └─ グループ
  │    │    └─ 所有者
  │    └─ グループ: 読み取りのみ
  └─ 他: 読み取りのみ
```

---

## 📊 まとめ

### 仕組みの本質

**wizexercise.txt の旅:**

```
1. ローカルファイル (app/wizexercise.txt)
   ↓ git push
2. GitHub リポジトリ
   ↓ GitHub Actions checkout
3. GitHub Actions Runner VM
   ↓ docker build (COPY命令)
4. Docker イメージレイヤー (焼き込み完了)
   ↓ docker push
5. Azure Container Registry (永続保存)
   ↓ docker pull
6. Worker Node のイメージキャッシュ
   ↓ container start (レイヤー展開)
7. Pod コンテナ内 (/app/wizexercise.txt として存在)
```

### キーポイント

| 項目           | 説明                                      |
| -------------- | ----------------------------------------- |
| **メカニズム** | `Dockerfile` の `COPY` 命令による焼き込み |
| **タイミング** | イメージビルド時 (1 回のみ)               |
| **保存場所**   | Docker イメージのレイヤー内               |
| **永続性**     | イメージが存在する限り永続的              |
| **一貫性**     | すべての Pod が同じファイルを持つ         |
| **更新方法**   | ファイル変更 → 再ビルド → 再デプロイ      |
| **利点**       | 不変インフラ、再現性、一貫性              |

### Wiz 課題要件達成

✅ **要件:** コンテナ内に wizexercise.txt (氏名を記載) を含める  
✅ **実装:** Dockerfile COPY 命令でイメージに焼き込み  
✅ **証明:** kubectl exec でファイル存在を確認可能  
✅ **説明:** ビルドプロセスとレイヤー構造を明確に説明可能

---

## 🔗 関連ドキュメント

- [Dockerfile リファレンス](https://docs.docker.com/engine/reference/builder/)
- [Docker レイヤーキャッシュ](https://docs.docker.com/develop/dev-best-practices/)
- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Azure Container Registry](https://learn.microsoft.com/azure/container-registry/)

---

**このメカニズムにより、Wiz 技術課題の「コンテナ内に wizexercise.txt を含める」という要件を完璧に満たしています！**
