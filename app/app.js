const express = require("express");
const mongoose = require("mongoose");
const bodyParser = require("body-parser");
const fs = require("fs");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;
const MONGO_URI =
  process.env.MONGO_URI || "mongodb://localhost:27017/guestbook";

// Middleware
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.set("view engine", "ejs");

// MongoDB接続
mongoose
  .connect(MONGO_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => {
    console.log("✅ MongoDB接続成功");
  })
  .catch((err) => {
    console.error("❌ MongoDB接続失敗:", err);
  });

// Messageスキーマ
const messageSchema = new mongoose.Schema({
  name: String,
  message: String,
  createdAt: { type: Date, default: Date.now },
});

const Message = mongoose.model("Message", messageSchema);

// ルート: 掲示板表示
app.get("/", async (req, res) => {
  try {
    const messages = await Message.find().sort({ createdAt: -1 });
    res.render("index", { messages });
  } catch (err) {
    res.status(500).send("エラーが発生しました");
  }
});

// ルート: メッセージ投稿
app.post("/post", async (req, res) => {
  const { name, message } = req.body;
  const newMessage = new Message({ name, message });
  await newMessage.save();
  res.redirect("/");
});

// ルート: wizexercise.txt表示（デモ用）
app.get("/wizfile", (req, res) => {
  // 動的にコンテンツを生成
  const publicUrl =
    process.env.PUBLIC_URL || req.get("host") || "localhost:3000";
  const protocol = publicUrl.includes("localhost") ? "http" : "http";
  const baseUrl = `${protocol}://${publicUrl}`;

  const content = `氏名: yamapan
日付: 2025-10-28
CICD-AKS-Technical Exercise

===================================
このファイルへのアクセス方法:
===================================

【方法1】kubectl exec コマンド（コンテナ内部確認）
$ kubectl exec -it $(kubectl get pod -l app=guestbook -o jsonpath='{.items[0].metadata.name}') -- cat /app/wizexercise.txt

【方法2】ブラウザから直接アクセス
URL: ${baseUrl}/wizexercise.txt

【方法3】curl コマンド
$ curl ${baseUrl}/wizexercise.txt

【方法4】HTMLプレビュー版
URL: ${baseUrl}/wizfile

---
Generated at: ${new Date().toLocaleString("ja-JP", {
    timeZone: "Asia/Tokyo",
  })} JST
Current Host: ${req.get("host")}`;

  res.send(`<pre>${content}</pre>`);
});

// ルート: wizexercise.txtを直接提供（動的生成）
app.get("/wizexercise.txt", (req, res) => {
  // 動的にコンテンツを生成
  const publicUrl =
    process.env.PUBLIC_URL || req.get("host") || "localhost:3000";
  const protocol = publicUrl.includes("localhost") ? "http" : "http";
  const baseUrl = `${protocol}://${publicUrl}`;

  const content = `氏名: yamapan
日付: 2025-10-28
CICD-AKS-Technical Exercise

===================================
このファイルへのアクセス方法:
===================================

【方法1】kubectl exec コマンド（コンテナ内部確認）
$ kubectl exec -it $(kubectl get pod -l app=guestbook -o jsonpath='{.items[0].metadata.name}') -- cat /app/wizexercise.txt

【方法2】ブラウザから直接アクセス
URL: ${baseUrl}/wizexercise.txt

【方法3】curl コマンド
$ curl ${baseUrl}/wizexercise.txt

【方法4】HTMLプレビュー版
URL: ${baseUrl}/wizfile

---
Generated at: ${new Date().toLocaleString("ja-JP", {
    timeZone: "Asia/Tokyo",
  })} JST
Current Host: ${req.get("host")}`;

  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.send(content);
});

// ヘルスチェック
app.get("/health", (req, res) => {
  res.status(200).send("OK");
});

app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
