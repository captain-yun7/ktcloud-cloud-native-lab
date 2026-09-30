const express = require('express');
const fs = require('fs');
const path = require('path');

const DIR = path.join(__dirname, 'files');
fs.mkdirSync(DIR, { recursive: true });

const app = express();
app.use(express.urlencoded({ extended: false }));

const escape = (s) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
// 파일 이름은 영문·숫자·-·_ 만 허용 (경로 조작 방지)
const safeName = (s) => /^[A-Za-z0-9_-]{1,40}$/.test(s || '') ? s : null;

app.get('/', (req, res) => {
  const names = fs.readdirSync(DIR).filter((f) => f.endsWith('.txt')).sort();
  const items = names.map((f) => `<li><a href="/files/${escape(f)}">${escape(f)}</a></li>`).join('');
  res.send(`<!doctype html><meta charset="utf-8"><title>files</title>
<h1>파일 저장</h1>
<form method="post" action="/save">
  <p>이름 (영문·숫자) <input name="name" required></p>
  <p>내용 <textarea name="text" required></textarea></p>
  <button>저장</button>
</form>
<h2>저장된 파일 (${names.length}개)</h2>
<ul>${items}</ul>
`);
});

app.post('/save', (req, res) => {
  const name = safeName(req.body.name);
  if (!name) return res.status(400).send('name: 영문·숫자·-·_ 만 쓸 수 있습니다\n');
  fs.writeFileSync(path.join(DIR, `${name}.txt`), String(req.body.text || ''));
  res.redirect('/');
});

app.get('/files/:file', (req, res) => {
  const name = safeName(req.params.file.replace(/\.txt$/, ''));
  const file = name && path.join(DIR, `${name}.txt`);
  if (!file || !fs.existsSync(file)) return res.status(404).send('Where is your file?\n');
  res.type('text/plain').send(fs.readFileSync(file, 'utf8'));
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`files app listening on port ${port}`);
});
