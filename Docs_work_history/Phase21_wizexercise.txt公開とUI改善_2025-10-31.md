# Phase 21: wizexercise.txt 公開機能とサンセット UI リフレッシュ

**日時**: 2025 年 10 月 31 日  
**目的**: wizexercise.txt のブラウザアクセス実装、トップページリンク追加、サンセット調の UI リフレッシュ

---

## 📋 実装内容

### 1. wizexercise.txt ブラウザアクセス機能追加

#### 背景

当初、`wizexercise.txt`の確認方法は**2 つ**想定されていました:

1. **🔧 kubectl exec コマンド** - コンテナ内部を直接確認

   ```bash
   kubectl exec -it <POD_NAME> -- cat /app/wizexercise.txt
   ```

2. **🌐 Web ブラウザからアクセス** - ❌ 未実装
   - 理由: Node.js Express アプリで公開ルートが未設定
   - 既存ルート: `/`（トップページ）と`/api/messages`のみ

#### 実装内容

**app/app.js に 2 つのエンドポイント追加**:

```javascript
// HTMLプレビュー: wizexercise.txt の内容をシンプルに描画
app.get("/wizfile", (req, res) => {
  const filePath = path.join(__dirname, "wizexercise.txt");
  const content = fs.readFileSync(filePath, "utf-8");
  res.send(`<pre>${content}</pre>`);
});

// プレーンテキスト: ブラウザや curl から直接取得
app.get("/wizexercise.txt", (req, res) => {
  const filePath = path.join(__dirname, "wizexercise.txt");
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.sendFile(filePath);
});
```

**特徴**:

- `/wizexercise.txt` でプレーンテキストとして直接参照・ダウンロードが可能
- `/wizfile` で HTML ラップしたプレビューを提供
- Content-Type ヘッダーを明示し文字化けを防止
- デモ優先のためファイル存在チェックは未実装（404 ハンドリングは今後検討）

#### wizexercise.txt にアクセス方法を追記

```plaintext
===================================
このファイルへのアクセス方法:
===================================

【方法1】kubectl exec コマンド（コンテナ内部確認）
$ kubectl exec -it $(kubectl get pod -l app=guestbook -o jsonpath='{.items[0].metadata.name}') -- cat /app/wizexercise.txt

【方法2】ブラウザから直接アクセス
URL: http://<INGRESS_IP>/wizexercise.txt

【方法3】curl コマンド
$ curl http://<INGRESS_IP>/wizexercise.txt
```

※ HTML プレビュー版 `/wizfile` はアプリで提供しつつ、ファイル内では 3 パターンに絞って案内。

---

### 2. トップページにシークレットファイルリンク追加

#### 背景

デモ中に wizexercise.txt へ素早くアクセスするため、トップページから直接リンクを配置。

#### 実装内容

**app/views/index.ejs のヘッダー部にリンクを常設**:

```html
<div class="header-info">
  <span>Azure Kubernetes Service Demo</span>
  <span class="badge vulnerable">⚠️ VULNERABLE</span>
  <!-- Secret file shortcut for the demo walkthrough -->
  <a href="/wizexercise.txt" class="secret-link">🔒 Secret File</a>
  <span class="server-info">� <%= serverHost %></span>
</div>
```

**特徴**:

- ✅ ヘッダー右側に常時表示され、デモ中に迷わずアクセス可能
- ✅ `secret-link` クラスでホバー時の背景トーンを制御
- ✅ アイコンを英語ラベルに変更し、海外メンバーにも意図が伝わるよう調整

---

### 3. サンセット BBS 風 UI デザイン刷新

#### 背景

当初のデザインは「AI 臭さ」が強く、過度にモダンで装飾的だった:

- ❌ グラデーション背景（紫系）
- ❌ 影・丸み・アニメーション過剰
- ❌ ホバーで浮き上がる演出
- ❌ 絵文字多用

**ユーザー要望**: 「派手すぎないが記憶に残る“サンセット”テイストに刷新してほしい」

#### 実装内容

**主なスタイル調整**:

```css
/* Warm gradient and softer card edges introduced in Phase21 */
body {
  background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
  min-height: 100vh;
  padding: 20px;
}

/* Header now adopts a sunset palette with readable contrast */
.header {
  background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
  color: #78350f;
}
```

- フォントはサンセリフ系を維持しつつ、ヘッダーとボタンの配色を琥珀系に統一
- `.message-card` の影と角丸を調整してカードリストの可読性を向上
- `.stats` セクションを追加し、投稿数やステータスをワンビューで把握できるようにした

**微調整ポイント**:

- `secret-link` クラスでリンクのホバー挙動をコントロール（背景を 30% 透明に）
- `.form-section` と `.messages-section` に余白と落ち着いた背景色を付け、長文投稿でも読みやすいレイアウトへ
- フッター背景を #78350f に揃え、全体のトーンをサンセット調で統一

---

### 4. DEMO 手順書の IP アドレスプレースホルダー化

#### 背景

リソース再作成時に IP アドレスが変わるため、ハードコードされた IP は保守性が低い。

#### 実装内容

**docs/DEMO_PROCEDURE.md に環境変数セクション追加**:

```powershell
## ⚙️ 環境変数（デモ前に確認・設定）

# MongoDB VM Public IP（事前確認）
$MONGO_PUBLIC_IP = az network public-ip show -g rg-bbs-cicd-aks0000 -n vm-mongo-dev-pip --query "ipAddress" -o tsv
Write-Host "MongoDB VM IP: $MONGO_PUBLIC_IP" -ForegroundColor Cyan

# Ingress External IP（事前確認）
$INGRESS_IP = kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "Ingress IP: $INGRESS_IP" -ForegroundColor Cyan

# アプリURL
$APP_URL = "http://$INGRESS_IP"
Write-Host "App URL: $APP_URL" -ForegroundColor Green
```

**置き換えた IP アドレス**:

- ❌ `135.149.87.151` → ✅ `<INGRESS_IP>`
- ❌ `172.192.56.57` → ✅ `<MONGO_PUBLIC_IP>`

**メリット**:

- ✅ デプロイ環境が変わっても手順書を修正不要
- ✅ デモ前にコマンド実行で最新 IP を取得
- ✅ ハードコードされた値がないため保守性向上

---

## 🚀 デプロイ履歴

### コミット履歴

```bash
# 1. wizexercise.txt エンドポイント追加
0fd9452 feat: Add /wizexercise.txt endpoint for direct browser access

# 2. DEMO手順書にブラウザアクセス方法追記
a814d6c docs: Update demo procedure with browser access method for wizexercise.txt

# 3. トップページリンク + IPプレースホルダー化
52dd365 feat: Add secret file link to homepage and use IP placeholders in demo docs

# 4. サンセット UI 仕上げ（commit msg: retro BBS style）
972f85a style: Redesign UI to retro BBS style with modern touch
```

> 💡 `972f85a` のコミットメッセージは「retro BBS style」だが、最終リファインでサンセット調に寄せたことを本ドキュメントで補足。

---

## 🎯 達成事項

### wizexercise.txt アクセス

| 方法               | 実装状況 | URL/コマンド                                         |
| ------------------ | -------- | ---------------------------------------------------- |
| kubectl exec       | ✅ 完了  | `kubectl exec -it <POD> -- cat /app/wizexercise.txt` |
| ブラウザ直接       | ✅ 完了  | `http://<INGRESS_IP>/wizexercise.txt`                |
| HTML プレビュー    | ✅ 完了  | `http://<INGRESS_IP>/wizfile`                        |
| curl コマンド      | ✅ 完了  | `curl http://<INGRESS_IP>/wizexercise.txt`           |
| トップページリンク | ✅ 完了  | ヘッダーに「� Secret File」リンクを常設              |

### UI デザイン

| 要素           | Before                      | After                                               |
| -------------- | --------------------------- | --------------------------------------------------- |
| 背景           | 紫グラデーション            | 琥珀グラデーション `#fef3c7 → #fde68a`              |
| ヘッダー       | 紫グラデーション + 影       | サンセット調グラデーション + `⚠️ VULNERABLE` バッジ |
| ボタン         | グラデーション + 浮き上がり | 琥珀グラデーション + ソフトシャドウ                 |
| メッセージ表示 | カード型 + 影               | カード型 + 影（角丸と余白を最適化）                 |
| フォント       | Segoe UI                    | Segoe UI（温かみのあるカラーパレットと組み合わせ）  |
| 全体の雰囲気   | モダン・AI 臭い             | サンセット BBS テイストで落ち着いた印象             |

### ドキュメント

| ファイル          | 改善内容                                                  |
| ----------------- | --------------------------------------------------------- |
| wizexercise.txt   | 3 つのアクセス方法を明記（HTML プレビューはルートで案内） |
| DEMO_PROCEDURE.md | IP アドレスをプレースホルダー化、環境変数取得コマンド追加 |
| Docs_work_history | Phase21 として本ドキュメント作成                          |

---

## 📝 学んだこと

### 1. Express.js での静的ファイル公開

- `res.sendFile()` を使ったファイル直接提供
- Content-Type ヘッダーの重要性（文字化け防止）
- セキュリティ考慮: ファイル存在確認 + 404 エラーハンドリング

### 2. デモ資料の保守性

- ハードコードされた値（IP、URL）は避けるべき
- プレースホルダー + 取得コマンドで柔軟性確保
- デモ前のチェックリストとして機能

### 3. UI デザインのバランス

- 「AI 臭さ」の正体は紫系の配色と過剰なシャドウ → 琥珀グラデーションで解消
- サンセット系のカラーパレットとカード余白を整えることで視認性を確保
- ホバー演出は控えめにしつつ、レスポンシブ挙動は維持してデモの体験価値を損なわない

---

## 🔄 次のステップ候補

### 短期

- [ ] GitHub Actions の自動デプロイ完了確認
- [ ] 実際のブラウザで新 UI を確認
- [ ] シークレットファイルリンクの動作検証

### 中期

- [ ] デモリハーサル実施（45 分タイムボックス）
- [ ] プレゼンテーションスライド作成
- [ ] 脆弱性検知デモのシナリオ確認

### 長期（本番環境への改善）

- [ ] wizexercise.txt の認証保護（本番では公開すべきでない）
- [ ] UI のアクセシビリティ改善
- [ ] レスポンシブデザインのモバイル最適化

---

## 🎨 UI Before/After 比較

### Before (AI 寄りのモダン UI)

```
■ 紫のグラデーション背景
■ カード型のメッセージ（影付き、丸み）
■ ホバーで浮き上がる、移動する
■ 絵文字多用（🚀💬📤📋など）
■ モダンすぎて"作られた感"
```

### After (サンセット BBS テイスト)

```
■ 琥珀系グラデーション背景とホワイトカード
■ 投稿数を示す stats バーを追加
■ Secret File リンクをヘッダーに常時表示
■ カード型メッセージの影と角丸を微調整
■ 暖色系で統一しつつ、デモ向けのアイコンは維持
```

---

## 📊 検証方法

### デプロイ完了後の確認手順

```powershell
# 1. IPアドレス取得
$INGRESS_IP = kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "App URL: http://$INGRESS_IP" -ForegroundColor Green

# 2. ブラウザで開く
Start-Process "http://$INGRESS_IP"

# 3. 確認項目
# ✅ サンセット BBS 風のデザインになっているか
# ✅ ヘッダーに「Secret File」リンクが常時表示されているか
# ✅ リンクをクリックして wizexercise.txt が表示されるか
# ✅ メッセージ投稿が正常に動作するか
# ✅ カードレイアウトでメッセージが表示されるか

# 4. curl でも確認
curl "http://$INGRESS_IP/wizexercise.txt"
```

---

**作成者**: やまもとたつみ  
**作成日**: 2025 年 10 月 31 日  
**関連 Phase**: Phase20（MongoDB 認証修正）の次のフェーズ
