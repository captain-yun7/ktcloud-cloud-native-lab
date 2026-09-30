const list = document.getElementById('list');
const status = document.getElementById('status');

async function load() {
  try {
    const res = await fetch('/api/todos');
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const todos = await res.json();
    list.innerHTML = '';
    for (const t of todos) {
      const li = document.createElement('li');
      li.textContent = t.title;
      const del = document.createElement('button');
      del.textContent = '삭제';
      del.onclick = async () => { await fetch(`/api/todos/${t.id}`, { method: 'DELETE' }); load(); };
      li.appendChild(del);
      list.appendChild(li);
    }
    status.textContent = `${todos.length}개`;
  } catch (err) {
    status.textContent = `api 연결 실패: ${err.message}`;
  }
}

document.getElementById('add').onsubmit = async (e) => {
  e.preventDefault();
  const input = document.getElementById('title');
  await fetch('/api/todos', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: input.value }),
  });
  input.value = '';
  load();
};

load();
