const express = require('express');
const cors = require('cors');
const Database = require('better-sqlite3');
const path = require('path');

const app = express();
const PORT = 3000;
const DB_PATH = path.join(__dirname, 'data', 'payroll.db');

app.use(cors());
app.use(express.json());

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

// API: Get all rules
app.get('/api/rules', (req, res) => {
  const db = getDb();
  const rules = db.prepare(`SELECT * FROM calculation_rules ORDER BY code`).all();
  db.close();
  res.json(rules);
});

// API: Get all templates with their rules
app.get('/api/templates', (req, res) => {
  const db = getDb();
  const templates = db.prepare(`SELECT * FROM calculation_templates ORDER BY code`).all();
  for (const t of templates) {
    t.rules = db.prepare(`
      SELECT tr.id as link_id, tr.execution_order, r.*
      FROM template_rules tr
      JOIN calculation_rules r ON r.id = tr.rule_id
      WHERE tr.template_id = ?
      ORDER BY tr.execution_order
    `).all(t.id);
  }
  db.close();
  res.json(templates);
});

// API: Add rule to template
app.post('/api/templates/:templateId/rules', (req, res) => {
  const db = getDb();
  const { rule_id } = req.body;
  try {
    const maxOrder = db.prepare(`SELECT MAX(execution_order) as m FROM template_rules WHERE template_id = ?`).get(req.params.templateId).m || 0;
    db.prepare(`INSERT INTO template_rules (template_id, rule_id, execution_order) VALUES (?, ?, ?)`).run(req.params.templateId, rule_id, maxOrder + 1);
    db.close();
    res.json({ success: true });
  } catch (err) {
    db.close();
    res.status(400).json({ error: err.message });
  }
});

// API: Remove rule from template
app.delete('/api/templates/:templateId/rules/:linkId', (req, res) => {
  const db = getDb();
  try {
    db.prepare(`DELETE FROM template_rules WHERE id = ?`).run(req.params.linkId);
    db.close();
    res.json({ success: true });
  } catch (err) {
    db.close();
    res.status(400).json({ error: err.message });
  }
});

// API: Reorder rule in template
app.put('/api/templates/:templateId/rules/:linkId/order', (req, res) => {
  const db = getDb();
  const { direction } = req.body; // 'up' or 'down'
  try {
    const current = db.prepare(`SELECT * FROM template_rules WHERE id = ?`).get(req.params.linkId);
    const newOrder = direction === 'up' ? current.execution_order - 1 : current.execution_order + 1;
    const swap = db.prepare(`SELECT * FROM template_rules WHERE template_id = ? AND execution_order = ?`).get(req.params.templateId, newOrder);
    if (swap) {
      db.prepare(`UPDATE template_rules SET execution_order = ? WHERE id = ?`).run(current.execution_order, swap.id);
      db.prepare(`UPDATE template_rules SET execution_order = ? WHERE id = ?`).run(newOrder, current.id);
    }
    db.close();
    res.json({ success: true });
  } catch (err) {
    db.close();
    res.status(400).json({ error: err.message });
  }
});

// API: Get periods
app.get('/api/periods', (req, res) => {
  const db = getDb();
  const periods = db.prepare(`SELECT * FROM calculation_periods ORDER BY start_date DESC`).all();
  db.close();
  res.json(periods);
});

// API: Get employees for selection
app.get('/api/employees', (req, res) => {
  const db = getDb();
  const employees = db.prepare(`SELECT id, employee_code, first_name || ' ' || last_name as name FROM employees WHERE status = 'active'`).all();
  db.close();
  res.json(employees);
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
    .container { display: flex; height: 100vh; flex-direction: column; }
    .top-area { display: flex; flex: 1; overflow: hidden; }
    .sidebar { width: 220px; background: #16213e; padding: 15px; overflow-y: auto; flex-shrink: 0; }
    .sidebar h2 { font-size: 11px; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 1px; color: #666; margin-top: 15px; }
    .sidebar h2:first-child { margin-top: 0; }
    .sidebar ul { list-style: none; }
    .sidebar li { padding: 8px 12px; cursor: pointer; border-radius: 6px; margin: 2px 0; font-size: 13px; transition: all 0.2s; }
    .sidebar li:hover { background: #0f3460; }
    .sidebar li.active { background: #e94560; color: white; }
    .sidebar li.special { background: #0f3460; border-left: 3px solid #e94560; }
    .main { flex: 1; padding: 20px; overflow: auto; display: flex; flex-direction: column; }
    .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; flex-shrink: 0; }
    .header h1 { font-size: 22px; }
    .btn { padding: 8px 16px; border: none; border-radius: 6px; cursor: pointer; font-size: 13px; transition: all 0.2s; }
    .btn-sm { padding: 4px 10px; font-size: 11px; }
    .btn-primary { background: #e94560; color: white; }
    .btn-primary:hover { background: #ff6b6b; }
    .btn-secondary { background: #333; color: #eee; }
    .btn-danger { background: #c0392b; color: white; }
    .btn-success { background: #27ae60; color: white; }
    .table-wrapper { flex: 1; overflow: auto; }
    table { width: 100%; border-collapse: collapse; background: #16213e; border-radius: 8px; overflow: hidden; font-size: 13px; }
    th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid #0f3460; }
    th { background: #0f3460; font-weight: 600; position: sticky; top: 0; z-index: 10; }
    tr:hover { background: #1a1a3e; }
    .editable { cursor: text; }
    .editable:focus { outline: 2px solid #e94560; background: #1a1a3e; }
    .actions { display: flex; gap: 5px; }

    /* Command bar */
    .command-bar { background: #16213e; border-top: 1px solid #0f3460; padding: 15px 20px; flex-shrink: 0; }
    .command-input { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; background: #1a1a2e; border-radius: 8px; padding: 10px 15px; min-height: 50px; }
    .chip { display: inline-flex; align-items: center; gap: 6px; background: #0f3460; padding: 6px 12px; border-radius: 20px; font-size: 13px; cursor: pointer; position: relative; }
    .chip:hover { background: #e94560; }
    .chip .arrow { font-size: 10px; }
    .dropdown { position: absolute; bottom: 100%; left: 0; background: #16213e; border-radius: 8px; box-shadow: 0 -4px 20px rgba(0,0,0,0.3); min-width: 180px; display: none; margin-bottom: 5px; overflow: hidden; z-index: 100; }
    .dropdown.active { display: block; }
    .dropdown-item { padding: 10px 15px; cursor: pointer; font-size: 13px; border-bottom: 1px solid #0f3460; }
    .dropdown-item:hover { background: #0f3460; }
    .dropdown-item:last-child { border-bottom: none; }
    .dropdown-header { padding: 8px 15px; font-size: 11px; color: #888; text-transform: uppercase; background: #0f3460; }

    /* Modal */
    .modal { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.7); display: none; align-items: center; justify-content: center; z-index: 1000; }
    .modal.active { display: flex; }
    .modal-content { background: #16213e; padding: 24px; border-radius: 12px; min-width: 400px; max-width: 600px; max-height: 80vh; overflow-y: auto; }
    .modal h3 { margin-bottom: 20px; }
    .form-group { margin-bottom: 15px; }
    .form-group label { display: block; margin-bottom: 5px; font-size: 12px; color: #888; }
    .form-group input, .form-group select { width: 100%; padding: 10px; border: 1px solid #333; border-radius: 6px; background: #1a1a2e; color: #eee; }
    .form-actions { display: flex; gap: 10px; justify-content: flex-end; margin-top: 20px; }
    .count { color: #888; font-size: 13px; margin-right: 10px; }
    .toast { position: fixed; bottom: 80px; right: 20px; padding: 12px 20px; border-radius: 6px; background: #27ae60; color: white; display: none; z-index: 1001; }
    .toast.error { background: #c0392b; }
    .toast.active { display: block; }

    /* Rules & Templates view */
    .rules-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
    .panel { background: #16213e; border-radius: 8px; padding: 15px; }
    .panel h3 { margin-bottom: 15px; font-size: 16px; display: flex; justify-content: space-between; align-items: center; }
    .rule-item { display: flex; justify-content: space-between; align-items: center; padding: 10px; background: #1a1a2e; border-radius: 6px; margin-bottom: 8px; }
    .rule-item .info { flex: 1; }
    .rule-item .code { font-weight: 600; color: #e94560; }
    .rule-item .name { font-size: 12px; color: #888; }
    .rule-item .type { font-size: 11px; padding: 2px 8px; border-radius: 10px; background: #0f3460; }
    .template-rules { margin-top: 10px; }
    .template-rule { display: flex; align-items: center; gap: 10px; padding: 8px 10px; background: #1a1a2e; border-radius: 6px; margin-bottom: 5px; }
    .template-rule .order { width: 24px; height: 24px; background: #e94560; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 600; }
    .template-rule .arrows { display: flex; flex-direction: column; gap: 2px; }
    .template-rule .arrows button { padding: 2px 6px; font-size: 10px; }
    .add-rule-select { margin-top: 10px; display: flex; gap: 10px; }
    .add-rule-select select { flex: 1; }
  </style>
</head>
<body>
  <div class="container">
    <div class="top-area">
      <div class="sidebar">
        <h2>Views</h2>
        <ul>
          <li class="special" onclick="showRulesView()">Правила & Шаблони</li>
        </ul>
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
        <div class="table-wrapper" id="tableContainer"></div>
      </div>
    </div>

    <div class="command-bar">
      <div class="command-input">
        <div class="chip" onclick="toggleDropdown('createDropdown')">
          + Створити <span class="arrow">▼</span>
          <div class="dropdown" id="createDropdown">
            <div class="dropdown-header">Документи</div>
            <div class="dropdown-item" onclick="createPeriod(event)">📅 Період</div>
            <div class="dropdown-item" onclick="createAccrualDoc(event)">📄 Документ нарахування</div>
            <div class="dropdown-item" onclick="createPaymentDoc(event)">💳 Документ оплати</div>
            <div class="dropdown-header">Налаштування</div>
            <div class="dropdown-item" onclick="createRule(event)">📐 Правило розрахунку</div>
            <div class="dropdown-item" onclick="createTemplate(event)">📋 Шаблон</div>
          </div>
        </div>
        <div class="chip" onclick="toggleDropdown('calcDropdown')">
          ⚡ Розрахувати <span class="arrow">▼</span>
          <div class="dropdown" id="calcDropdown">
            <div class="dropdown-item" onclick="runCalculation(event)">Запустити розрахунок періоду</div>
          </div>
        </div>
        <div class="chip" onclick="toggleDropdown('viewDropdown')">
          👁 Перегляд <span class="arrow">▼</span>
          <div class="dropdown" id="viewDropdown">
            <div class="dropdown-item" onclick="showRulesView(); closeDropdowns();">Правила & Шаблони</div>
            <div class="dropdown-item" onclick="selectTable('employees'); closeDropdowns();">Працівники</div>
            <div class="dropdown-item" onclick="selectTable('calculation_periods'); closeDropdowns();">Періоди</div>
            <div class="dropdown-item" onclick="selectTable('accrual_documents'); closeDropdowns();">Документи нарахувань</div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <div class="modal" id="addModal">
    <div class="modal-content">
      <h3 id="modalTitle">Add New Row</h3>
      <form id="addForm"></form>
      <div class="form-actions">
        <button class="btn btn-secondary" type="button" onclick="closeModal()">Cancel</button>
        <button class="btn btn-primary" type="button" onclick="saveRow()">Save</button>
      </div>
    </div>
  </div>

  <div class="toast" id="toast"></div>

  <script>
    let currentTable = null;
    let currentSchema = [];
    let currentView = 'table';

    async function loadTables() {
      const res = await fetch('/api/tables');
      const tables = await res.json();
      const list = document.getElementById('tableList');
      list.innerHTML = tables.map(t => '<li onclick="selectTable(\\'' + t + '\\')">' + t + '</li>').join('');
    }

    async function selectTable(name) {
      currentTable = name;
      currentView = 'table';
      document.querySelectorAll('.sidebar li').forEach(li => li.classList.remove('active'));
      const items = document.querySelectorAll('.sidebar li');
      items.forEach(li => { if (li.textContent === name) li.classList.add('active'); });
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
          const displayVal = String(val).length > 50 ? String(val).substring(0, 50) + '...' : val;
          if (col === 'id') {
            html += '<td>' + val + '</td>';
          } else {
            html += '<td class="editable" contenteditable="true" data-col="' + col + '" data-orig="' + encodeURIComponent(val) + '" onblur="updateCell(this)">' + displayVal + '</td>';
          }
        });
        html += '<td class="actions"><button class="btn btn-danger btn-sm" onclick="deleteRow(' + row.id + ')">Del</button></td>';
        html += '</tr>';
      });
      html += '</tbody></table>';
      document.getElementById('tableContainer').innerHTML = html;
    }

    async function updateCell(cell) {
      const newVal = cell.textContent;
      const origVal = decodeURIComponent(cell.dataset.orig);
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
        cell.dataset.orig = encodeURIComponent(newVal);
        showToast('Оновлено!');
      } else {
        cell.textContent = origVal;
        showToast('Помилка!', true);
      }
    }

    async function deleteRow(id) {
      if (!confirm('Видалити цей запис?')) return;
      const res = await fetch('/api/tables/' + currentTable + '/' + id, { method: 'DELETE' });
      if (res.ok) {
        showToast('Видалено!');
        selectTable(currentTable);
      } else {
        showToast('Помилка!', true);
      }
    }

    function showAddModal() {
      document.getElementById('modalTitle').textContent = 'Додати запис';
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
        showToast('Додано!');
        if (currentView === 'rules') {
          showRulesView();
        } else {
          selectTable(currentTable);
        }
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

    // Dropdown handling
    function toggleDropdown(id) {
      event.stopPropagation();
      closeDropdowns();
      document.getElementById(id).classList.toggle('active');
    }

    function closeDropdowns() {
      document.querySelectorAll('.dropdown').forEach(d => d.classList.remove('active'));
    }

    document.addEventListener('click', closeDropdowns);

    // Rules & Templates View
    async function showRulesView() {
      currentView = 'rules';
      document.querySelectorAll('.sidebar li').forEach(li => li.classList.remove('active'));
      document.querySelector('.sidebar li.special').classList.add('active');
      document.getElementById('tableName').textContent = 'Правила & Шаблони';
      document.getElementById('addBtn').style.display = 'none';
      document.getElementById('rowCount').textContent = '';

      const [rulesRes, templatesRes] = await Promise.all([
        fetch('/api/rules'),
        fetch('/api/templates')
      ]);
      const rules = await rulesRes.json();
      const templates = await templatesRes.json();

      let html = '<div class="rules-grid">';

      // Rules panel
      html += '<div class="panel"><h3>Правила розрахунку <button class="btn btn-primary btn-sm" onclick="createRule(event)">+ Додати</button></h3>';
      rules.forEach(r => {
        const typeLabel = r.rule_type === 'accrual' ? '💰 нарах.' : r.rule_type === 'tax' ? '📉 податок' : '📊 ' + r.rule_type;
        html += '<div class="rule-item"><div class="info"><div class="code">' + r.code + '</div><div class="name">' + r.name + '</div></div><span class="type">' + typeLabel + '</span></div>';
      });
      html += '</div>';

      // Templates panel
      html += '<div class="panel"><h3>Шаблони <button class="btn btn-primary btn-sm" onclick="createTemplate(event)">+ Додати</button></h3>';
      templates.forEach(t => {
        html += '<div style="background:#1a1a2e;border-radius:8px;padding:12px;margin-bottom:15px;">';
        html += '<div style="font-weight:600;color:#e94560;margin-bottom:5px;">' + t.code + '</div>';
        html += '<div style="font-size:12px;color:#888;margin-bottom:10px;">' + t.name + '</div>';
        html += '<div class="template-rules">';
        t.rules.forEach((r, i) => {
          html += '<div class="template-rule">';
          html += '<span class="order">' + r.execution_order + '</span>';
          html += '<div style="flex:1"><div style="font-weight:500;">' + r.code + '</div><div style="font-size:11px;color:#888;">' + r.name + '</div></div>';
          html += '<div class="arrows">';
          html += '<button class="btn btn-secondary btn-sm" onclick="moveRule(' + t.id + ',' + r.link_id + ',\\'up\\')">▲</button>';
          html += '<button class="btn btn-secondary btn-sm" onclick="moveRule(' + t.id + ',' + r.link_id + ',\\'down\\')">▼</button>';
          html += '</div>';
          html += '<button class="btn btn-danger btn-sm" onclick="removeRuleFromTemplate(' + t.id + ',' + r.link_id + ')">✕</button>';
          html += '</div>';
        });
        html += '</div>';
        html += '<div class="add-rule-select"><select id="addRule_' + t.id + '">';
        html += '<option value="">Додати правило...</option>';
        rules.forEach(r => {
          if (!t.rules.find(tr => tr.id === r.id)) {
            html += '<option value="' + r.id + '">' + r.code + ' - ' + r.name + '</option>';
          }
        });
        html += '</select><button class="btn btn-success btn-sm" onclick="addRuleToTemplate(' + t.id + ')">+</button></div>';
        html += '</div>';
      });
      html += '</div></div>';

      document.getElementById('tableContainer').innerHTML = html;
    }

    async function addRuleToTemplate(templateId) {
      const select = document.getElementById('addRule_' + templateId);
      const ruleId = select.value;
      if (!ruleId) return;

      const res = await fetch('/api/templates/' + templateId + '/rules', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ rule_id: ruleId })
      });

      if (res.ok) {
        showToast('Правило додано!');
        showRulesView();
      } else {
        showToast('Помилка!', true);
      }
    }

    async function removeRuleFromTemplate(templateId, linkId) {
      if (!confirm('Видалити правило з шаблону?')) return;
      const res = await fetch('/api/templates/' + templateId + '/rules/' + linkId, { method: 'DELETE' });
      if (res.ok) {
        showToast('Видалено!');
        showRulesView();
      } else {
        showToast('Помилка!', true);
      }
    }

    async function moveRule(templateId, linkId, direction) {
      const res = await fetch('/api/templates/' + templateId + '/rules/' + linkId + '/order', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ direction })
      });
      if (res.ok) showRulesView();
    }

    // Create actions
    function createPeriod(e) {
      e.stopPropagation();
      closeDropdowns();
      currentTable = 'calculation_periods';
      currentSchema = [
        {name: 'id'}, {name: 'period_code', notnull: 1}, {name: 'period_name', notnull: 1},
        {name: 'start_date', notnull: 1}, {name: 'end_date', notnull: 1},
        {name: 'period_type', notnull: 1}, {name: 'status'}, {name: 'working_days'}, {name: 'working_hours'}
      ];
      document.getElementById('modalTitle').textContent = 'Створити період';
      document.getElementById('addForm').innerHTML =
        '<div class="form-group"><label>Код періоду</label><input name="period_code" placeholder="2024-01" required></div>' +
        '<div class="form-group"><label>Назва</label><input name="period_name" placeholder="Січень 2024" required></div>' +
        '<div class="form-group"><label>Дата початку</label><input name="start_date" type="date" required></div>' +
        '<div class="form-group"><label>Дата кінця</label><input name="end_date" type="date" required></div>' +
        '<div class="form-group"><label>Тип</label><select name="period_type"><option value="monthly">monthly</option><option value="bi-weekly">bi-weekly</option><option value="weekly">weekly</option></select></div>' +
        '<div class="form-group"><label>Робочих днів</label><input name="working_days" type="number" value="22"></div>';
      document.getElementById('addModal').classList.add('active');
    }

    function createAccrualDoc(e) {
      e.stopPropagation();
      closeDropdowns();
      currentTable = 'accrual_documents';
      document.getElementById('modalTitle').textContent = 'Створити документ нарахування';
      loadAccrualDocForm();
    }

    async function loadAccrualDocForm() {
      const [periodsRes, templatesRes] = await Promise.all([
        fetch('/api/periods'),
        fetch('/api/templates')
      ]);
      const periods = await periodsRes.json();
      const templates = await templatesRes.json();

      let html = '<div class="form-group"><label>Номер документа</label><input name="document_number" placeholder="ACC-2024-01-001" required></div>';
      html += '<div class="form-group"><label>Період</label><select name="period_id" required>';
      periods.forEach(p => html += '<option value="' + p.id + '">' + p.period_code + ' - ' + p.period_name + '</option>');
      html += '</select></div>';
      html += '<div class="form-group"><label>Шаблон</label><select name="template_id" required>';
      templates.forEach(t => html += '<option value="' + t.id + '">' + t.code + ' - ' + t.name + '</option>');
      html += '</select></div>';
      html += '<div class="form-group"><label>Опис</label><input name="description"></div>';

      currentSchema = [{name:'id'},{name:'document_number',notnull:1},{name:'period_id',notnull:1},{name:'template_id',notnull:1},{name:'description'}];
      document.getElementById('addForm').innerHTML = html;
      document.getElementById('addModal').classList.add('active');
    }

    function createPaymentDoc(e) {
      e.stopPropagation();
      closeDropdowns();
      currentTable = 'payment_documents';
      document.getElementById('modalTitle').textContent = 'Створити документ оплати';
      loadPaymentDocForm();
    }

    async function loadPaymentDocForm() {
      const periodsRes = await fetch('/api/periods');
      const periods = await periodsRes.json();

      let html = '<div class="form-group"><label>Номер документа</label><input name="document_number" placeholder="PAY-2024-01-001" required></div>';
      html += '<div class="form-group"><label>Період</label><select name="period_id" required>';
      periods.forEach(p => html += '<option value="' + p.id + '">' + p.period_code + ' - ' + p.period_name + '</option>');
      html += '</select></div>';
      html += '<div class="form-group"><label>Дата оплати</label><input name="payment_date" type="date" required></div>';
      html += '<div class="form-group"><label>Тип</label><select name="payment_type"><option value="salary">salary</option><option value="advance">advance</option><option value="bonus">bonus</option></select></div>';

      currentSchema = [{name:'id'},{name:'document_number',notnull:1},{name:'period_id',notnull:1},{name:'payment_date',notnull:1},{name:'payment_type',notnull:1}];
      document.getElementById('addForm').innerHTML = html;
      document.getElementById('addModal').classList.add('active');
    }

    function createRule(e) {
      e.stopPropagation();
      closeDropdowns();
      currentTable = 'calculation_rules';
      document.getElementById('modalTitle').textContent = 'Створити правило';
      document.getElementById('addForm').innerHTML =
        '<div class="form-group"><label>Код</label><input name="code" placeholder="NEW_RULE" required></div>' +
        '<div class="form-group"><label>Назва</label><input name="name" required></div>' +
        '<div class="form-group"><label>Тип</label><select name="rule_type"><option value="accrual">accrual (нарахування)</option><option value="deduction">deduction (утримання)</option><option value="tax">tax (податок)</option></select></div>' +
        '<div class="form-group"><label>SQL формула</label><input name="sql_formula" placeholder="SELECT..." required></div>' +
        '<div class="form-group"><label>Опис</label><input name="description"></div>';
      currentSchema = [{name:'id'},{name:'code',notnull:1},{name:'name',notnull:1},{name:'rule_type',notnull:1},{name:'sql_formula',notnull:1},{name:'description'}];
      document.getElementById('addModal').classList.add('active');
    }

    function createTemplate(e) {
      e.stopPropagation();
      closeDropdowns();
      currentTable = 'calculation_templates';
      document.getElementById('modalTitle').textContent = 'Створити шаблон';
      document.getElementById('addForm').innerHTML =
        '<div class="form-group"><label>Код</label><input name="code" placeholder="NEW_TEMPLATE" required></div>' +
        '<div class="form-group"><label>Назва</label><input name="name" required></div>' +
        '<div class="form-group"><label>Опис</label><input name="description"></div>';
      currentSchema = [{name:'id'},{name:'code',notnull:1},{name:'name',notnull:1},{name:'description'}];
      document.getElementById('addModal').classList.add('active');
    }

    function runCalculation(e) {
      e.stopPropagation();
      closeDropdowns();
      showToast('Функція в розробці');
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
