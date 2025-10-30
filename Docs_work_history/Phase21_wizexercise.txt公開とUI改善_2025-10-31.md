# Phase 21: wizexercise.txt 公開機能とレトロBBS風UI実装

**日時**: 2025年10月31日  
**目的**: wizexercise.txtのブラウザアクセス実装、トップページリンク追加、レトロBBS風デザイン変更

---

## 📋 実装内容

### 1. wizexercise.txt ブラウザアクセス機能追加

#### 背景
当初、`wizexercise.txt`の確認方法は**2つ**想定されていました:

1. **🔧 kubectl exec コマンド** - コンテナ内部を直接確認
   ```bash
   kubectl exec -it <POD_NAME> -- cat /app/wizexercise.txt
   ```

2. **🌐 Web ブラウザからアクセス** - ❌ 未実装
   - 理由: Node.js Expressアプリで公開ルートが未設定
   - 既存ルート: `/`（トップページ）と`/api/messages`のみ

#### 実装内容

**app/app.js に2つのエンドポイント追加**:

```javascript
// ルート1: HTMLプレビュー版（既存）
app.get("/wizfile", (req, res) => {
  const filePath = path.join(__dirname, "wizexercise.txt");
  if (fs.existsSync(filePath)) {
    const content = fs.readFileSync(filePath, "utf-8");
    res.send(`<pre>${content}</pre>`);
  } else {
    res.status(404).send("wizexercise.txt が見つかりません");
  }
});

// ルート2: 直接ファイル提供（新規追加）
app.get("/wizexercise.txt", (req, res) => {
  const filePath = path.join(__dirname, "wizexercise.txt");
  if (fs.existsSync(filePath)) {
    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.sendFile(filePath);
  } else {
    res.status(404).send("wizexercise.txt が見つかりません");
  }
});
```

**特徴**:
- `/wizexercise.txt` - ファイル名そのままでアクセス可能（プレーンテキスト）
- `/wizfile` - HTMLでラップして表示
- Content-Type ヘッダー設定で文字化け防止

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

【方法4】HTMLプレビュー版
URL: http://<INGRESS_IP>/wizfile
```

---

### 2. トップページにシークレットファイルリンク追加

#### 背景
デモ中にwizexercise.txtへ素早くアクセスするため、トップページから直接リンクを配置。

#### 実装内容

**app/views/index.ejs のヘッダー部分に追加**:

```html
<p style="margin-top: 15px;">
  <a href="/wizexercise.txt" 
     style="color: #fff; text-decoration: none; background: rgba(255,255,255,0.2); 
            padding: 8px 16px; border-radius: 5px; font-size: 0.9em; 
            display: inline-block; transition: all 0.3s;"
     onmouseover="this.style.background='rgba(255,255,255,0.3)'" 
     onmouseout="this.style.background='rgba(255,255,255,0.2)'">
    🔐 シークレットファイル
  </a>
</p>
```

**特徴**:
- ✅ ヘッダー部分に配置（タイトルの下）
- ✅ ホバーエフェクト付き
- ✅ アイコン（🔐）で視認性向上

---

### 3. レトロBBS風UIデザイン変更

#### 背景
当初のデザインは「AI臭さ」が強く、過度にモダンで装飾的だった:
- ❌ グラデーション背景（紫系）
- ❌ 影・丸み・アニメーション過剰
- ❌ ホバーで浮き上がる演出
- ❌ 絵文字多用

**ユーザー要望**: 「レトロBBS風 × ちょっとだけモダン」

#### 実装内容

**削除した要素**:
```css
/* Before */
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
border-radius: 10px;
transform: translateY(-2px);
```

**追加したレトロ要素**:

1. **90年代BBS風レイアウト**
   - テーブルベースのフォーム・メッセージ表示
   - ダブルボーダー (`border: 3px double #666`)
   - グレー背景 (`#e0e0e0`)

2. **クラシックなヘッダー**
   ```css
   .header {
     background: #336699;  /* 懐かしい青 */
     color: #fff;
     border-bottom: 3px solid #224466;
   }
   ```

3. **outsetボタン（3D効果）**
   ```css
   .btn-submit {
     border: 2px outset #336699;
   }
   .btn-submit:active {
     border-style: inset;  /* クリック時に凹む */
   }
   ```

4. **レトロフォント**
   ```css
   font-family: "MS PGothic", "Osaka-Mono", monospace, sans-serif;
   ```

5. **テーブル型メッセージ表示**
   ```html
   <table class="message-table">
     <thead>
       <tr>
         <th>投稿者</th>
         <th>メッセージ</th>
       </tr>
     </thead>
     <tbody>
       <!-- 偶数行は薄いグレー背景 -->
     </tbody>
   </table>
   ```

**ちょっとだけモダンな要素**:
- ✅ ホバーで行がハイライト（黄色 `#ffffcc`）
- ✅ レスポンシブ対応
- ✅ シンプルなフッター
- ✅ 最低限のCSS transition

---

### 4. DEMO手順書のIPアドレスプレースホルダー化

#### 背景
リソース再作成時にIPアドレスが変わるため、ハードコードされたIPは保守性が低い。

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

**置き換えたIPアドレス**:
- ❌ `135.149.87.151` → ✅ `<INGRESS_IP>`
- ❌ `172.192.56.57` → ✅ `<MONGO_PUBLIC_IP>`

**メリット**:
- ✅ デプロイ環境が変わっても手順書を修正不要
- ✅ デモ前にコマンド実行で最新IPを取得
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

# 4. レトロBBS風UIデザイン変更
972f85a style: Redesign UI to retro BBS style with modern touch
```

---

## 🎯 達成事項

### wizexercise.txt アクセス

| 方法 | 実装状況 | URL/コマンド |
|------|---------|-------------|
| kubectl exec | ✅ 完了 | `kubectl exec -it <POD> -- cat /app/wizexercise.txt` |
| ブラウザ直接 | ✅ 完了 | `http://<INGRESS_IP>/wizexercise.txt` |
| HTMLプレビュー | ✅ 完了 | `http://<INGRESS_IP>/wizfile` |
| curl コマンド | ✅ 完了 | `curl http://<INGRESS_IP>/wizexercise.txt` |
| トップページリンク | ✅ 完了 | ヘッダーに「🔐 シークレットファイル」リンク配置 |

### UIデザイン

| 要素 | Before | After |
|------|--------|-------|
| 背景 | 紫グラデーション | グレー単色 `#e0e0e0` |
| ヘッダー | 紫グラデーション + 影 | 青単色 `#336699` + ダブルボーダー |
| ボタン | グラデーション + 浮き上がり | outset 3D効果 |
| メッセージ表示 | カード型 + 影 | テーブル型 + ストライプ |
| フォント | Segoe UI | MS PGothic |
| 全体の雰囲気 | モダン・AI臭い | レトロBBS風 |

### ドキュメント

| ファイル | 改善内容 |
|---------|---------|
| wizexercise.txt | 4つのアクセス方法を明記 |
| DEMO_PROCEDURE.md | IPアドレスをプレースホルダー化、環境変数取得コマンド追加 |
| Docs_work_history | Phase21 として本ドキュメント作成 |

---

## 📝 学んだこと

### 1. Express.js での静的ファイル公開
- `res.sendFile()` を使ったファイル直接提供
- Content-Type ヘッダーの重要性（文字化け防止）
- セキュリティ考慮: ファイル存在確認 + 404エラーハンドリング

### 2. デモ資料の保守性
- ハードコードされた値（IP、URL）は避けるべき
- プレースホルダー + 取得コマンドで柔軟性確保
- デモ前のチェックリストとして機能

### 3. UIデザインのバランス
- 「AI臭さ」の正体: 過度なグラデーション・影・アニメーション
- レトロ感の演出: テーブルレイアウト、ダブルボーダー、outsetボタン
- 完全にレトロにしすぎない: ホバーエフェクト、レスポンシブは維持

---

## 🔄 次のステップ候補

### 短期
- [ ] GitHub Actions の自動デプロイ完了確認
- [ ] 実際のブラウザで新UIを確認
- [ ] シークレットファイルリンクの動作検証

### 中期
- [ ] デモリハーサル実施（45分タイムボックス）
- [ ] プレゼンテーションスライド作成
- [ ] 脆弱性検知デモのシナリオ確認

### 長期（本番環境への改善）
- [ ] wizexercise.txt の認証保護（本番では公開すべきでない）
- [ ] UIのアクセシビリティ改善
- [ ] レスポンシブデザインのモバイル最適化

---

## 🎨 UI Before/After 比較

### Before (AI臭い)
```
■ 紫のグラデーション背景
■ カード型のメッセージ（影付き、丸み）
■ ホバーで浮き上がる、移動する
■ 絵文字多用（🚀💬📤📋など）
■ モダンすぎて"作られた感"
```

### After (レトロBBS風)
```
■ グレー単色背景
■ テーブル型のメッセージ（1px枠線、ストライプ）
■ ホバーで黄色ハイライトのみ
■ 絵文字は最小限（■記号で代用）
■ 90年代BBSの懐かしい雰囲気
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
# ✅ レトロBBS風のデザインになっているか
# ✅ ヘッダーに「[Secret File]」リンクがあるか
# ✅ リンクをクリックして wizexercise.txt が表示されるか
# ✅ メッセージ投稿が正常に動作するか
# ✅ テーブルレイアウトでメッセージが表示されるか

# 4. curl でも確認
curl "http://$INGRESS_IP/wizexercise.txt"
```

---

**作成者**: やまもとたつみ  
**作成日**: 2025年10月31日  
**関連Phase**: Phase20（MongoDB認証修正）の次のフェーズ
