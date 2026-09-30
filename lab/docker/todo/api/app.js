const express = require('express');
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'todo',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'todo',
});

const app = express();
app.use(express.json());

app.get('/api/health', (req, res) => res.json({ ok: true }));

app.get('/api/todos', async (req, res) => {
  const { rows } = await pool.query('SELECT id, title FROM todos ORDER BY id');
  res.json(rows);
});

app.post('/api/todos', async (req, res) => {
  const title = String(req.body.title || '').trim().slice(0, 200);
  if (!title) return res.status(400).json({ error: 'title is required' });
  const { rows } = await pool.query('INSERT INTO todos (title) VALUES ($1) RETURNING id, title', [title]);
  res.status(201).json(rows[0]);
});

app.delete('/api/todos/:id', async (req, res) => {
  await pool.query('DELETE FROM todos WHERE id = $1', [Number(req.params.id)]);
  res.status(204).end();
});

// DB가 아직 준비 안 됐을 수 있어 몇 번 다시 시도한다
async function start() {
  for (let i = 1; i <= 15; i++) {
    try {
      await pool.query('CREATE TABLE IF NOT EXISTS todos (id SERIAL PRIMARY KEY, title TEXT NOT NULL)');
      console.log(`connected to database at ${pool.options.host}`);
      app.listen(3000, () => console.log('todo api listening on port 3000'));
      return;
    } catch (err) {
      console.log(`waiting for database at ${pool.options.host} (${i}/15): ${err.message}`);
      await new Promise((r) => setTimeout(r, 2000));
    }
  }
  console.log('could not connect to database');
  process.exit(1);
}

start();
