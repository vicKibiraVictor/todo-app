const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({
  host: process.env.DB_HOST || "localhost",
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || "postgres",
  password: process.env.DB_PASSWORD || "postgres",
  database: process.env.DB_NAME || "tododb",
});

// Initialize DB table
const initDB = async () => {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS todos (
      id SERIAL PRIMARY KEY,
      title VARCHAR(255) NOT NULL,
      description TEXT,
      completed BOOLEAN DEFAULT false,
      priority VARCHAR(20) DEFAULT 'medium',
      created_at TIMESTAMP DEFAULT NOW()
    )
  `);
  console.log("✅ Database table ready");
};

// Health check
app.get("/health", (req, res) => res.json({ status: "ok" }));

// GET all todos
app.get("/api/todos", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM todos ORDER BY created_at DESC");
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET single todo
app.get("/api/todos/:id", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM todos WHERE id = $1", [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: "Todo not found" });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST create todo
app.post("/api/todos", async (req, res) => {
  const { title, description, priority } = req.body;
  if (!title) return res.status(400).json({ error: "Title is required" });
  try {
    const result = await pool.query(
      "INSERT INTO todos (title, description, priority) VALUES ($1, $2, $3) RETURNING *",
      [title, description || "", priority || "medium"]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT update todo
app.put("/api/todos/:id", async (req, res) => {
  const { title, description, completed, priority } = req.body;
  try {
    const result = await pool.query(
      `UPDATE todos SET
        title = COALESCE($1, title),
        description = COALESCE($2, description),
        completed = COALESCE($3, completed),
        priority = COALESCE($4, priority)
       WHERE id = $5 RETURNING *`,
      [title, description, completed, priority, req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: "Todo not found" });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE todo
app.delete("/api/todos/:id", async (req, res) => {
  try {
    const result = await pool.query("DELETE FROM todos WHERE id = $1 RETURNING *", [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: "Todo not found" });
    res.json({ message: "Todo deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 5000;
initDB().then(() => {
  app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
});
