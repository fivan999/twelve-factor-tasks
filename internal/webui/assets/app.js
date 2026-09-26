const form = document.querySelector('#task-form');
const list = document.querySelector('#tasks');
const message = document.querySelector('#message');
const counter = document.querySelector('#counter');
const template = document.querySelector('#task-template');
let tasks = [];

async function request(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: options.body ? { 'Content-Type': 'application/json' } : undefined,
  });
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    throw new Error(body.error || 'Ошибка запроса');
  }
  return response.status === 204 ? null : response.json();
}

function showError(error) {
  message.textContent = error.message;
  setTimeout(() => { message.textContent = ''; }, 3500);
}

function render() {
  list.replaceChildren();
  counter.textContent = tasks.length;
  if (!tasks.length) {
    const empty = document.createElement('li');
    empty.className = 'empty';
    empty.textContent = 'Пока пусто. Самое время добавить первую задачу.';
    list.append(empty);
    return;
  }
  for (const task of tasks) {
    const node = template.content.cloneNode(true);
    const item = node.querySelector('.task');
    const checkbox = node.querySelector('input');
    item.classList.toggle('done', task.completed);
    checkbox.checked = task.completed;
    node.querySelector('strong').textContent = task.title;
    node.querySelector('.task-copy p').textContent = task.description;
    checkbox.addEventListener('change', () => update(task, { ...task, completed: checkbox.checked }));
    node.querySelector('.edit').addEventListener('click', () => edit(task));
    node.querySelector('.delete').addEventListener('click', () => remove(task.id));
    list.append(node);
  }
}

async function load() {
  try { tasks = await request('/api/tasks'); render(); } catch (error) { showError(error); }
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  const data = new FormData(form);
  try {
    const task = await request('/api/tasks', { method: 'POST', body: JSON.stringify({ title: data.get('title'), description: data.get('description'), completed: false }) });
    tasks.unshift(task);
    form.reset();
    render();
  } catch (error) { showError(error); }
});

async function update(original, changed) {
  try {
    const payload = {
      title: changed.title,
      description: changed.description,
      completed: changed.completed,
    };
    const saved = await request(`/api/tasks/${original.id}`, { method: 'PUT', body: JSON.stringify(payload) });
    tasks = tasks.map(task => task.id === saved.id ? saved : task);
    render();
  } catch (error) { showError(error); render(); }
}

function edit(task) {
  const title = prompt('Название задачи', task.title);
  if (title === null) return;
  const description = prompt('Описание', task.description);
  if (description === null) return;
  update(task, { title, description, completed: task.completed });
}

async function remove(id) {
  try {
    await request(`/api/tasks/${id}`, { method: 'DELETE' });
    tasks = tasks.filter(task => task.id !== id);
    render();
  } catch (error) { showError(error); }
}

load();
