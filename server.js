const express = require('express');
const cors = require('cors');
const Database = require('better-sqlite3');
const path = require('path');

const app = express();
const PORT = 3000;
const DB_PATH = path.join(__dirname, 'data', 'payroll.db');

app.use(cors());
app.use(express.json());

// Get database connection
function getDb() {
  return new Database(DB_PATH);
}

// API: Get all tables
app.get('/api/tables', (req, res) => {
  const db = getDb();
  const tables = db.prepare(`
    SELECT name FROM sqlite_master
    WHERE type='table' AND name NOT LIKE 'sqlite_%'
    ORDER BY name
  `).all();
  db.close();
  res.json(tables.map(t => t.name));
});

// API: Get table schema
app.get('/api/tables/:name/schema', (req, res) => {
  const db = getDb();
  const schema = db.prepare(`PRAGMA table_info(${req.params.name})`).all();
  db.close();
  res.json(schema);
});

// API: Get table data
app.get('/api/tables/:name', (req, res) => {
  const db = getDb();
  const limit = parseInt(req.query.limit) || 100;
  const offset = parseInt(req.query.offset) || 0;

  const count = db.prepare(`SELECT COUNT(*) as cnt FROM ${req.params.name}`).get().cnt;
  const rows = db.prepare(`SELECT * FROM ${req.params.name} LIMIT ? OFFSET ?`).all(limit, offset);
  db.close();

  res.json({ count, rows, limit, offset });
});

// API: Insert row
app.post('/api/tables/:name', (req, res) => {
  const db = getDb();
  const data = req.body;
  const columns = Object.keys(data).join(', ');
  const placeholders = Object.keys(data).map(() => '?').join(', ');
  const values = Object.values(data);

  try {
    const result = db.prepare(`INSERT INTO ${req.params.name} (${columns}) VALUES (${placeholders})`).run(...values);
    db.close();
    res.json({ success: true, id: result.lastInsertRowid });
  } catch (err) {
    db.close();
    res.status(400).json({ error: err.message });
  }
});

// API: Update row
app.put('/api/tables/:name/:id', (req, res) => {
  const db = getDb();
  const data = req.body;
  const sets = Object.keys(data).map(k => `${k} = ?`).join(', ');
  const values = [...Object.values(data), req.params.id];

  try {
    db.prepare(`UPDATE ${req.params.name} SET ${sets} WHERE id = ?`).run(...values);
    db.close();
    res.json({ success: true });
  } catch (err) {
    db.close();
    res.status(400).json({ error: err.message });
  }
});

// API: Delete row
app.delete('/api/tables/:name/:id', (req, res) => {
  const db = getDb();
  try {
    db.prepare(`DELETE FROM ${req.params.name} WHERE id = ?`).run(req.params.id);
    db.close();
    res.json({ success: true });
  } catch (err) {
    db.close();
    res.status(400).json({ error: err.message });
  }
});

// Serve the UI
app.get('/', (req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="uk">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Zarplata DB</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #1a1a2e; color: #eee; }
    .container { display: flex; height: 100vh; }
    .sidebar { width: 220px; background: #16213e; padding: 20px; overflow-y: auto; }
    .sidebar h2 { color: #0f3460; font-size: 14px; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px; color: #888; }
    .sidebar ul { list-style: none; }
    .sidebar li { padding: 8px 12px; cursor: pointer; border-radius: 6px; margin: 2px 0; font-size: 13px; transition: all 0.2s; }
    .sidebar li:hover { background: #0f3460; }
    .sidebar li.active { background: #e94560; color: white; }
    .main { flex: 1; padding: 20px; overflow: auto; }
    .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
    .header h1 { font-size: 24px; }
    .btn { padding: 8px 16px; border: none; border-radius: 6px; cursor: pointer; font-size: 13px; transition: all 0.2s; }
    .btn-primary { background: #e94560; color: white; }
    .btn-primary:hover { background: #ff6b6b; }
    .btn-secondary { background: #333; color: #eee; }
    .btn-danger { background: #c0392b; color: white; }
    table { width: 100%; border-collapse: collapse; background: #16213e; border-radius: 8px; overflow: hidden; font-size: 13px; }
    th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid #0f3460; }
    th { background: #0f3460; font-weight: 600; position: sticky; top: 0; }
    tr:hover { background: #1a1a3e; }
    .editable { cursor: text; }
    .editable:focus { outline: 2px solid #e94560; background: #1a1a3e; }
    .actions { display: flex; gap: 5px; }
    .modal { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.7); display: none; align-items: center; justify-content: center; }
    .modal.active { display: flex; }
    .modal-content { background: #16213e; padding: 24px; border-radius: 12px; min-width: 400px; max-height: 80vh; overflow-y: auto; }
    .modal h3 { margin-bottom: 20px; }
    .form-group { margin-bottom: 15px; }
    .form-group label { display: block; margin-bottom: 5px; font-size: 12px; color: #888; }
    .form-group input { width: 100%; padding: 10px; border: 1px solid #333; border-radius: 6px; background: #1a1a2e; color: #eee; }
    .form-actions { display: flex; gap: 10px; justify-content: flex-end; margin-top: 20px; }
    .count { color: #888; font-size: 13px; }
    .toast { position: fixed; bottom: 20px; right: 20px; padding: 12px 20px; border-radius: 6px; background: #27ae60; color: white; display: none; }
    .toast.error { background: #c0392b; }
    .toast.active { display: block; }
  </style>
</head>
<body>
  <div class="container">
    <div class="sidebar">
      <h2>Tables</h2>
      <ul id="tableList"></ul>
    </div>
    <div class="main">
      <div class="header">
        <h1 id="tableName">Select a table</h1>
        <div>
          <span class="count" id="rowCount"></span>
          <button class="btn btn-primary" id="addBtn" style="display:none" onclick="showAddModal()">+ Add</button>
        </div>
      </div>
      <div id="tableContainer"></div>
    </div>
  </div>

  <div class="modal" id="addModal">
    <div class="modal-content">
      <h3>Add New Row</h3>
      <form id="addForm"></form>
      <div class="form-actions">
        <button class="btn btn-secondary" onclick="closeModal()">Cancel</button>
        <button class="btn btn-primary" onclick="saveRow()">Save</button>
      </div>
    </div>
  </div>

  <div class="toast" id="toast"></div>

  <script>
    let currentTable = null;
    let currentSchema = [];

    async function loadTables() {
      const res = await fetch('/api/tables');
      const tables = await res.json();
      const list = document.getElementById('tableList');
      list.innerHTML = tables.map(t => '<li onclick="selectTable(\\'' + t + '\\')">' + t + '</li>').join('');
    }

    async function selectTable(name) {
      currentTable = name;
      document.querySelectorAll('.sidebar li').forEach(li => li.classList.remove('active'));
      event.target.classList.add('active');
      document.getElementById('tableName').textContent = name;
      document.getElementById('addBtn').style.display = 'inline-block';

      const [schemaRes, dataRes] = await Promise.all([
        fetch('/api/tables/' + name + '/schema'),
        fetch('/api/tables/' + name)
      ]);
      currentSchema = await schemaRes.json();
      const data = await dataRes.json();

      document.getElementById('rowCount').textContent = data.count + ' rows';
      renderTable(data.rows);
    }

    function renderTable(rows) {
      if (!currentSchema.length) return;
      const cols = currentSchema.map(c => c.name);
      let html = '<table><thead><tr>';
      html += cols.map(c => '<th>' + c + '</th>').join('');
      html += '<th>Actions</th></tr></thead><tbody>';

      rows.forEach(row => {
        html += '<tr data-id="' + row.id + '">';
        cols.forEach(col => {
          const val = row[col] !== null ? row[col] : '';
          if (col === 'id') {
            html += '<td>' + val + '</td>';
          } else {
            html += '<td class="editable" contenteditable="true" data-col="' + col + '" data-orig="' + val + '" onblur="updateCell(this)">' + val + '</td>';
          }
        });
        html += '<td class="actions"><button class="btn btn-danger" onclick="deleteRow(' + row.id + ')">Delete</button></td>';
        html += '</tr>';
      });
      html += '</tbody></table>';
      document.getElementById('tableContainer').innerHTML = html;
    }

    async function updateCell(cell) {
      const newVal = cell.textContent;
      const origVal = cell.dataset.orig;
      if (newVal === origVal) return;

      const row = cell.closest('tr');
      const id = row.dataset.id;
      const col = cell.dataset.col;

      const res = await fetch('/api/tables/' + currentTable + '/' + id, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ [col]: newVal })
      });

      if (res.ok) {
        cell.dataset.orig = newVal;
        showToast('Updated!');
      } else {
        cell.textContent = origVal;
        showToast('Error!', true);
      }
    }

    async function deleteRow(id) {
      if (!confirm('Delete this row?')) return;
      const res = await fetch('/api/tables/' + currentTable + '/' + id, { method: 'DELETE' });
      if (res.ok) {
        showToast('Deleted!');
        selectTable(currentTable);
      } else {
        showToast('Error!', true);
      }
    }

    function showAddModal() {
      const form = document.getElementById('addForm');
      form.innerHTML = currentSchema
        .filter(c => c.name !== 'id')
        .map(c => '<div class="form-group"><label>' + c.name + ' (' + c.type + ')</label><input name="' + c.name + '" ' + (c.notnull && !c.dflt_value ? 'required' : '') + '></div>')
        .join('');
      document.getElementById('addModal').classList.add('active');
    }

    function closeModal() {
      document.getElementById('addModal').classList.remove('active');
    }

    async function saveRow() {
      const form = document.getElementById('addForm');
      const data = {};
      new FormData(form).forEach((v, k) => { if (v) data[k] = v; });

      const res = await fetch('/api/tables/' + currentTable, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
      });

      if (res.ok) {
        closeModal();
        showToast('Added!');
        selectTable(currentTable);
      } else {
        const err = await res.json();
        showToast(err.error, true);
      }
    }

    function showToast(msg, isError = false) {
      const toast = document.getElementById('toast');
      toast.textContent = msg;
      toast.className = 'toast active' + (isError ? ' error' : '');
      setTimeout(() => toast.classList.remove('active'), 2000);
    }

    loadTables();
  </script>
</body>
</html>`);
});

app.listen(PORT, () => {
  console.log('\\n🚀 Zarplata DB Interface running at http://localhost:' + PORT);
  console.log('\\n📊 Database: ' + DB_PATH + '\\n');
});
