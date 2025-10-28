FROM node:18-alpine

WORKDIR /app

# wizexercise.txt をコピー(デモ用)
COPY wizexercise.txt /app/wizexercise.txt

# アプリファイルコピー
COPY package*.json ./
RUN npm install --omit=dev

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
