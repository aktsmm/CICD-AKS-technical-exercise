# Phase31: Deployment Summary Bash Syntax Error (2025-11-04)

## 🔴 トラブル発生

### 問題タイトル
Deploy to AKS ステップでの bash 構文エラー

### 関連Issue
- Issue #202: Deploy MISS

### 現象

**エラーメッセージ:**
```bash
/home/runner/work/_temp/9f6e536d-7665-46f5-a119-211353822d4d.sh: line 17: -: command not found
Error: Process completed with exit code 127.
```

**発生箇所:**
- ワークフロー: `2-1. Build and Deploy Application`
- ステップ: `Publish Deployment Summary`
- ファイル: `.github/workflows/app-deploy.yml` (Line 451)

**状況:**
デプロイメントサマリーを生成しようとした際に、bash スクリプトの構文エラーが発生してワークフローが失敗。

---

## 🔍 原因

### 問題のコード (Line 451)

```yaml
echo "- Domain: ${{ steps.tls.outputs.domain != '' && steps.tls.outputs.domain || 'Pending IP allocation' }}"
```

### 技術的な原因

1. **GitHub Actions 式構文を bash 内で使用**
   - `!=`, `&&`, `||` は GitHub Actions の式構文であり、bash の構文ではない
   - GitHub Actions がこの式を展開した結果、無効な bash コードが生成される

2. **展開後の bash コード例**
   ```bash
   # GitHub Actions が展開すると以下のようになる（想定）
   echo "- Domain: value != '' && value || 'Pending IP allocation'"
   ```
   - これは bash として解釈できず、`-` が単独のコマンドとして扱われる
   - 結果: `-: command not found` エラー

3. **GitHub Actions 式の正しい使用場所**
   - `if:` 条件式内
   - `with:` パラメータ内
   - **run: スクリプト内では使用不可**

---

## ✅ 解決方法

### 修正内容

**修正前:**
```yaml
- name: Publish Deployment Summary
  run: |
    RG='${{ env.RESOURCE_GROUP }}'
    CLUSTER='${{ steps.infra.outputs.aks_name }}'

    PODS=$(az aks command invoke --resource-group "$RG" --name "$CLUSTER" --command "kubectl get pods -n default -l app=guestbook -o wide" --query "logs" -o tsv)

    {
      echo "### Deployment Summary"
      echo "- Cluster: ${CLUSTER}"
      echo "- Mongo VM IP: ${{ steps.infra.outputs.mongo_ip }}"
      echo "- Domain: ${{ steps.tls.outputs.domain != '' && steps.tls.outputs.domain || 'Pending IP allocation' }}"
      echo "- Image: ${{ needs.build-push.outputs.acr_name }}.azurecr.io/${{ env.IMAGE_NAME }}:${{ needs.build-push.outputs.image_tag }}"
      echo "- Pods:" 
      echo '```'
      echo "$PODS"
      echo '```'
    } >> $GITHUB_STEP_SUMMARY
```

**修正後:**
```yaml
- name: Publish Deployment Summary
  run: |
    RG='${{ env.RESOURCE_GROUP }}'
    CLUSTER='${{ steps.infra.outputs.aks_name }}'
    DOMAIN='${{ steps.tls.outputs.domain }}'

    PODS=$(az aks command invoke --resource-group "$RG" --name "$CLUSTER" --command "kubectl get pods -n default -l app=guestbook -o wide" --query "logs" -o tsv)

    {
      echo "### Deployment Summary"
      echo "- Cluster: ${CLUSTER}"
      echo "- Mongo VM IP: ${{ steps.infra.outputs.mongo_ip }}"
      if [ -n "$DOMAIN" ]; then
        echo "- Domain: ${DOMAIN}"
      else
        echo "- Domain: Pending IP allocation"
      fi
      echo "- Image: ${{ needs.build-push.outputs.acr_name }}.azurecr.io/${{ env.IMAGE_NAME }}:${{ needs.build-push.outputs.image_tag }}"
      echo "- Pods:" 
      echo '```'
      echo "$PODS"
      echo '```'
    } >> $GITHUB_STEP_SUMMARY
```

### 変更点

1. **DOMAIN 変数の追加**
   ```yaml
   DOMAIN='${{ steps.tls.outputs.domain }}'
   ```
   - GitHub Actions の出力を bash 変数に格納

2. **bash 条件式への置き換え**
   ```bash
   if [ -n "$DOMAIN" ]; then
     echo "- Domain: ${DOMAIN}"
   else
     echo "- Domain: Pending IP allocation"
   fi
   ```
   - `[ -n "$DOMAIN" ]`: 文字列が空でないかチェック
   - 標準的な bash if-then-else 構文を使用

---

## 🧪 検証

### テストスクリプト

```bash
#!/bin/bash

# Test 1: ドメインに値がある場合
DOMAIN="48.218.193.10.nip.io"
if [ -n "$DOMAIN" ]; then
  echo "- Domain: ${DOMAIN}"
else
  echo "- Domain: Pending IP allocation"
fi
# 出力: - Domain: 48.218.193.10.nip.io

# Test 2: ドメインが空文字列の場合
DOMAIN=""
if [ -n "$DOMAIN" ]; then
  echo "- Domain: ${DOMAIN}"
else
  echo "- Domain: Pending IP allocation"
fi
# 出力: - Domain: Pending IP allocation

# Test 3: ドメインが未設定の場合
unset DOMAIN
if [ -n "$DOMAIN" ]; then
  echo "- Domain: ${DOMAIN}"
else
  echo "- Domain: Pending IP allocation"
fi
# 出力: - Domain: Pending IP allocation
```

### 検証結果
✅ すべてのケースで正しく動作

---

## 📝 学習ポイント

### GitHub Actions での条件分岐の使い分け

#### 1. GitHub Actions 式構文（YAML レベル）
```yaml
# ✅ 正しい使用例
- name: Conditional Step
  if: ${{ steps.tls.outputs.domain != '' }}
  run: echo "Domain exists"

# ✅ with パラメータ内
- name: Set Variable
  with:
    value: ${{ steps.tls.outputs.domain != '' && steps.tls.outputs.domain || 'default' }}
```

#### 2. bash スクリプト内の条件分岐
```yaml
# ✅ 正しい使用例
- name: Bash Conditional
  run: |
    DOMAIN='${{ steps.tls.outputs.domain }}'
    if [ -n "$DOMAIN" ]; then
      echo "Domain: $DOMAIN"
    else
      echo "No domain"
    fi

# ❌ 間違った使用例
- name: Wrong Usage
  run: |
    echo "Domain: ${{ steps.tls.outputs.domain != '' && steps.tls.outputs.domain || 'N/A' }}"
```

### bash 条件式のオプション

| 式 | 意味 |
|---|---|
| `[ -n "$VAR" ]` | 変数が空でない |
| `[ -z "$VAR" ]` | 変数が空 |
| `[ "$VAR" = "value" ]` | 変数が特定の値と等しい |
| `[ "$VAR" != "value" ]` | 変数が特定の値と異なる |

---

## 🚀 再発防止策

### レビューチェックリスト

1. **run: スクリプト内での GitHub Actions 式の使用をチェック**
   ```bash
   # コードレビュー時に以下をチェック
   grep -r "run:.*\${{.*&&\|\|\|!=" .github/workflows/
   ```

2. **bash 変数への事前代入**
   - GitHub Actions の出力は bash 変数に代入してから使用
   - スクリプト内での条件分岐は bash 構文を使用

3. **テスト環境での検証**
   - 複雑な bash スクリプトはローカルで先にテストする
   - shellcheck などの静的解析ツールを活用

---

## 📚 参考リンク

### 公式ドキュメント
- [GitHub Actions - Expressions](https://docs.github.com/en/actions/learn-github-actions/expressions)
- [GitHub Actions - Contexts](https://docs.github.com/en/actions/learn-github-actions/contexts)
- [Bash Conditional Expressions](https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html)

### 関連Issue
- Issue #202: Deploy MISS

---

## ✅ 解決確認

- [x] bash 構文エラーを修正
- [x] DOMAIN 変数を事前に代入
- [x] if-then-else 条件式に置き換え
- [x] ローカルでテストスクリプトを実行
- [x] YAML 構文検証 (yamllint)
- [x] ドキュメント作成

**修正コミット:** `ce61352`  
**日時:** 2025-11-04
