# Dockerfile
# Node.js 18 Alpine ベースイメージを使用
FROM node:18-alpine

# 作業ディレクトリを設定
WORKDIR /app

# wizexercise.txt をコピー(デモ用の脆弱性検証ファイル)
COPY wizexercise.txt /app/wizexercise.txt

# package.json と package-lock.json をコピー
COPY package*.json ./

# 本番用依存関係のみインストール
RUN npm install --production

# アプリケーションファイルをコピー
COPY . .

# ポート 3000 を公開
EXPOSE 3000

# アプリケーションを起動
CMD ["npm", "start"]