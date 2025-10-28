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
  const filePath = path.join(__dirname, "wizexercise.txt");
  if (fs.existsSync(filePath)) {
    const content = fs.readFileSync(filePath, "utf-8");
    res.send(`<pre>${content}</pre>`);
  } else {
    res.status(404).send("wizexercise.txt が見つかりません");
  }
});

// ヘルスチェック
app.get("/health", (req, res) => {
  res.status(200).send("OK");
});

app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
