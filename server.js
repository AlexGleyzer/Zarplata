const http = require("http");
const path = require("path");
const fs = require("fs");
const sqlite3 = require("sqlite3").verbose();

const ROOT_DIR = __dirname;
const DB_PATH = path.join(ROOT_DIR, "data", "payroll.db");
const PORT = process.env.PORT || 3000;
const PUBLIC_DIR = path.join(ROOT_DIR, "public");

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;")
    .replaceAll("'", "&#39;");
}

function renderPage(title, body, activeMenu, extraHtml = "", extraScript = "", extraHead = "") {
  return `<!doctype html>
<html lang="uk">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${escapeHtml(title)}</title>
    ${extraHead}
    <style>
      :root { color-scheme: light dark; }
      * { box-sizing: border-box; }
      body { font-family: Arial, sans-serif; margin: 0; }
      header { margin-bottom: 16px; }
      table { border-collapse: collapse; width: 100%; }
      th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
      th { background: #f5f5f5; }
      .muted { color: #666; }
      .card { border: 1px solid #ddd; padding: 12px; border-radius: 8px; }
      .layout { display: grid; grid-template-columns: 240px 1fr; min-height: 100vh; }
      .sidebar { border-right: 1px solid #ddd; padding: 20px; background: #fafafa; }
      .sidebar h2 { margin: 0 0 12px; font-size: 18px; }
      .menu { list-style: none; padding: 0; margin: 0; }
      .menu a { display: block; padding: 8px 10px; color: inherit; text-decoration: none; border-radius: 6px; }
      .menu a.active { background: #e9e9e9; font-weight: bold; }
      .content { padding: 24px; }
      .actions { display: flex; gap: 8px; align-items: center; }
      .button { padding: 6px 10px; border: 1px solid #aaa; border-radius: 6px; background: #fff; cursor: pointer; }
      .button:hover { background: #f5f5f5; }
      .modal-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.4); display: none; align-items: center; justify-content: center; }
      .modal { background: #fff; color: #111; border-radius: 10px; width: min(520px, 92vw); padding: 16px; border: 1px solid #ccc; }
      .modal header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
      .modal h3 { margin: 0; font-size: 18px; }
      .modal table { width: 100%; border: none; }
      .modal td { border: none; padding: 6px 4px; }
      .modal .label { color: #666; width: 160px; }
      .modal-open { display: flex; }
      .toggle-button { width: 32px; height: 32px; padding: 0; font-weight: bold; }
      .details-row { display: none; background: #fafafa; }
      .details-cell { padding: 0; }
      .details { padding: 12px; }
      .details table { margin-top: 8px; }
      .filters { display: flex; gap: 12px; align-items: center; margin-bottom: 12px; flex-wrap: wrap; }
      .filters label { font-size: 12px; color: #666; display: block; }
      .filters input[type="text"] { padding: 6px 8px; min-width: 240px; }
      .filters select { padding: 6px 8px; }
      .filters .control { display: flex; flex-direction: column; gap: 4px; }
      .form-grid { display: grid; grid-template-columns: 160px 1fr; gap: 8px 12px; align-items: center; }
      .form-row { display: contents; }
      .form-row.hidden { display: none; }
      .form-grid label { color: #666; font-size: 12px; }
      .form-grid input, .form-grid select { padding: 6px 8px; }
      .modal-backdrop { z-index: 1000; }
      .chip-line { border: 1px solid #ccc; padding: 10px; border-radius: 8px; background: #fafafa; }
      .chip-line label { font-size: 12px; color: #666; display: block; margin-bottom: 6px; }
      .chip-input { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; min-height: 36px; cursor: text; }
      .chip { display: inline-flex; align-items: center; gap: 6px; background: #e9e9e9; border-radius: 999px; padding: 6px 10px; font-size: 12px; }
      .chip button { border: none; background: transparent; cursor: pointer; font-size: 14px; line-height: 1; }
      .chip-placeholder { color: #999; font-size: 12px; }
      .chip-dropdown { position: relative; }
      .chip-menu { position: absolute; left: 0; bottom: calc(100% + 6px); min-width: 240px; border: 1px solid #ccc; border-radius: 8px; background: #fff; padding: 8px; display: none; box-shadow: 0 8px 20px rgba(0,0,0,0.12); z-index: 1200; }
      .chip-menu.open { display: block; }
      .chip-menu ul { list-style: none; padding: 0; margin: 0; }
      .chip-menu li { padding: 6px 8px; border-radius: 6px; cursor: pointer; }
      .chip-menu li:hover { background: #f3f3f3; }
      .chip-menu .level-1 { padding-left: 16px; }
      .chip-menu .section-title { font-size: 11px; text-transform: uppercase; letter-spacing: 0.6px; color: #666; padding: 8px 6px 4px; }
      .chip-menu .divider { border-top: 1px solid #e0e0e0; margin: 6px 0; }
      .hidden { display: none; }
      .employee-table { table-layout: fixed; }
      .resizable th { position: relative; }
      .resizer {
        position: absolute;
        right: 0;
        top: 0;
        height: 100%;
        width: 6px;
        cursor: col-resize;
        user-select: none;
      }
      .resizing {
        cursor: col-resize;
      }
      .tree-row { background: #f9f9f9; }
      .tree-label { display: inline-flex; align-items: center; gap: 6px; }
      .tree-indent { display: inline-block; width: 16px; }
      @media (prefers-color-scheme: dark) {
        .sidebar { background: #1e1e1e; border-color: #333; }
        .menu a.active { background: #333; }
        .card { border-color: #333; }
        th, td { border-color: #333; }
        th { background: #2a2a2a; }
        .button { background: #1f1f1f; border-color: #444; color: #f0f0f0; }
        .modal { background: #1f1f1f; color: #f0f0f0; border-color: #444; }
        .modal .label { color: #aaa; }
        .details-row { background: #1a1a1a; }
        .filters label { color: #aaa; }
        .tree-row { background: #1b1b1b; }
        .form-grid label { color: #aaa; }
        .chip-line { background: #1a1a1a; border-color: #333; }
        .chip { background: #333; color: #f0f0f0; }
        .chip-menu { background: #1f1f1f; border-color: #333; }
        .chip-menu li:hover { background: #2a2a2a; }
        .chip-menu .section-title { color: #aaa; }
        .chip-menu .divider { border-top-color: #333; }
      }
    </style>
  </head>
  <body>
    <div class="layout">
      <aside class="sidebar">
        <h2>Зарплата</h2>
        <ul class="menu">
          <li><a href="/org-structure" class="${activeMenu === "org-structure" ? "active" : ""}">Структура</a></li>
          <li><a href="/employees" class="${activeMenu === "employees" ? "active" : ""}">Працівники</a></li>
          <li><a href="/rule-templates" class="${activeMenu === "rule-templates" ? "active" : ""}">Шаблони правил</a></li>
          <li><a href="/bases" class="${activeMenu === "bases" ? "active" : ""}">Бази (загальні)</a></li>
          <li><a href="/employee-bases" class="${activeMenu === "employee-bases" ? "active" : ""}">Бази працівників</a></li>
        </ul>
      </aside>
      <main class="content">
        <header>
          <h1>${escapeHtml(title)}</h1>
        </header>
        ${body}
      </main>
    </div>
    ${extraHtml}
    ${extraScript ? `<script>${extraScript}</script>` : ""}
  </body>
</html>`;
}

function renderMissingDb() {
  const body = `
    <div class="card">
      <p>База даних не знайдена за шляхом:</p>
      <p><code>${escapeHtml(DB_PATH)}</code></p>
      <p class="muted">Створіть файл БД та застосуйте міграції:</p>
      <pre><code>mkdir data
npm run migrate</code></pre>
    </div>
  `;

  return renderPage("Бази розрахунку", body, "bases");
}

function renderBaseValues(rows) {
  if (rows.length === 0) {
    const body = `
      <div class="card">
        <p>Записів у <code>base_values</code> ще немає.</p>
      </div>
    `;
    return renderPage("Бази (загальні)", body, "bases");
  }

  const rowsHtml = rows
    .map(
      (row) => `
        <tr data-base-code="${escapeHtml(row.base_code)}"
            data-value="${escapeHtml(row.value)}"
            data-valid-from="${escapeHtml(row.valid_from)}"
            data-valid-to="${escapeHtml(row.valid_to ?? "")}"
            data-comment="${escapeHtml(row.comment ?? "")}">
          <td>${escapeHtml(row.base_code)}</td>
          <td>${escapeHtml(row.value)}</td>
          <td>${escapeHtml(row.valid_from)}</td>
          <td>${escapeHtml(row.valid_to ?? "")}</td>
          <td>${escapeHtml(row.comment ?? "")}</td>
          <td class="actions"><button class="button" data-open-modal type="button">Деталі</button></td>
        </tr>
      `
    )
    .join("");

  const body = `
    <table>
      <thead>
        <tr>
          <th>Код бази</th>
          <th>Значення</th>
          <th>Діє з</th>
          <th>Діє до</th>
          <th>Коментар</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        ${rowsHtml}
      </tbody>
    </table>
  `;

  const modal = `
    <div class="modal-backdrop" id="modalBackdrop" role="dialog" aria-modal="true" aria-hidden="true">
      <div class="modal">
        <header>
          <h3>Деталі бази</h3>
          <button class="button" id="modalClose" type="button">Закрити</button>
        </header>
        <table>
          <tbody>
            <tr><td class="label">Код бази</td><td id="modalBaseCode"></td></tr>
            <tr><td class="label">Значення</td><td id="modalValue"></td></tr>
            <tr><td class="label">Діє з</td><td id="modalValidFrom"></td></tr>
            <tr><td class="label">Діє до</td><td id="modalValidTo"></td></tr>
            <tr><td class="label">Коментар</td><td id="modalComment"></td></tr>
          </tbody>
        </table>
      </div>
    </div>
  `;

  const script = `
    const backdrop = document.getElementById("modalBackdrop");
    const closeBtn = document.getElementById("modalClose");
    const fields = {
      baseCode: document.getElementById("modalBaseCode"),
      value: document.getElementById("modalValue"),
      validFrom: document.getElementById("modalValidFrom"),
      validTo: document.getElementById("modalValidTo"),
      comment: document.getElementById("modalComment")
    };

    function openModal(data) {
      fields.baseCode.textContent = data.baseCode || "";
      fields.value.textContent = data.value || "";
      fields.validFrom.textContent = data.validFrom || "";
      fields.validTo.textContent = data.validTo || "";
      fields.comment.textContent = data.comment || "";
      backdrop.classList.add("modal-open");
      backdrop.setAttribute("aria-hidden", "false");
    }

    function closeModal() {
      backdrop.classList.remove("modal-open");
      backdrop.setAttribute("aria-hidden", "true");
    }

    document.querySelectorAll("[data-open-modal]").forEach((button) => {
      button.addEventListener("click", (event) => {
        const row = event.currentTarget.closest("tr");
        if (!row) return;
        openModal(row.dataset);
      });
    });

    closeBtn.addEventListener("click", closeModal);
    backdrop.addEventListener("click", (event) => {
      if (event.target === backdrop) closeModal();
    });
  `;

  return renderPage("Бази (загальні)", body, "bases", modal, script);
}

function renderEmployeeBases(rows) {
  if (rows.length === 0) {
    const body = `
      <div class="card">
        <p>Записів у <code>employee_bases</code> ще немає.</p>
      </div>
    `;
    return renderPage("Бази працівників", body, "employee-bases");
  }

  const rowsHtml = rows
    .map((row) => {
      const employeeLabel = [row.employee_code, row.employee_name]
        .filter(Boolean)
        .join(" — ");
      return `
        <tr data-employee-id="${escapeHtml(row.employee_id)}"
            data-employee-code="${escapeHtml(row.employee_code ?? "")}"
            data-employee-name="${escapeHtml(row.employee_name ?? "")}"
            data-base-code="${escapeHtml(row.base_code)}"
            data-value="${escapeHtml(row.value)}"
            data-valid-from="${escapeHtml(row.valid_from)}"
            data-valid-to="${escapeHtml(row.valid_to ?? "")}">
          <td>${escapeHtml(employeeLabel || row.employee_id)}</td>
          <td>${escapeHtml(row.base_code)}</td>
          <td>${escapeHtml(row.value)}</td>
          <td>${escapeHtml(row.valid_from)}</td>
          <td>${escapeHtml(row.valid_to ?? "")}</td>
          <td class="actions"><button class="button" data-open-modal type="button">Деталі</button></td>
        </tr>
      `;
    })
    .join("");

  const body = `
    <table>
      <thead>
        <tr>
          <th>Працівник</th>
          <th>Код бази</th>
          <th>Значення</th>
          <th>Діє з</th>
          <th>Діє до</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        ${rowsHtml}
      </tbody>
    </table>
  `;

  const modal = `
    <div class="modal-backdrop" id="modalBackdrop" role="dialog" aria-modal="true" aria-hidden="true">
      <div class="modal">
        <header>
          <h3>Деталі бази працівника</h3>
          <button class="button" id="modalClose" type="button">Закрити</button>
        </header>
        <table>
          <tbody>
            <tr><td class="label">Працівник</td><td id="modalEmployee"></td></tr>
            <tr><td class="label">Код бази</td><td id="modalBaseCode"></td></tr>
            <tr><td class="label">Значення</td><td id="modalValue"></td></tr>
            <tr><td class="label">Діє з</td><td id="modalValidFrom"></td></tr>
            <tr><td class="label">Діє до</td><td id="modalValidTo"></td></tr>
          </tbody>
        </table>
      </div>
    </div>
  `;

  const script = `
    const backdrop = document.getElementById("modalBackdrop");
    const closeBtn = document.getElementById("modalClose");
    const fields = {
      employee: document.getElementById("modalEmployee"),
      baseCode: document.getElementById("modalBaseCode"),
      value: document.getElementById("modalValue"),
      validFrom: document.getElementById("modalValidFrom"),
      validTo: document.getElementById("modalValidTo")
    };

    function openModal(data) {
      const labelParts = [data.employeeCode, data.employeeName].filter(Boolean);
      fields.employee.textContent = labelParts.length ? labelParts.join(" — ") : (data.employeeId || "");
      fields.baseCode.textContent = data.baseCode || "";
      fields.value.textContent = data.value || "";
      fields.validFrom.textContent = data.validFrom || "";
      fields.validTo.textContent = data.validTo || "";
      backdrop.classList.add("modal-open");
      backdrop.setAttribute("aria-hidden", "false");
    }

    function closeModal() {
      backdrop.classList.remove("modal-open");
      backdrop.setAttribute("aria-hidden", "true");
    }

    document.querySelectorAll("[data-open-modal]").forEach((button) => {
      button.addEventListener("click", (event) => {
        const row = event.currentTarget.closest("tr");
        if (!row) return;
        openModal(row.dataset);
      });
    });

    closeBtn.addEventListener("click", closeModal);
    backdrop.addEventListener("click", (event) => {
      if (event.target === backdrop) closeModal();
    });
  `;

  return renderPage("Бази працівників", body, "employee-bases", modal, script);
}

function renderRuleTemplates(templates, templateRules) {
  const rulesByTemplate = new Map();
  templateRules.forEach((rule) => {
    if (!rulesByTemplate.has(rule.template_id)) {
      rulesByTemplate.set(rule.template_id, []);
    }
    rulesByTemplate.get(rule.template_id).push(rule);
  });

  const rowsHtml = templates
    .map((template) => {
      const rules = rulesByTemplate.get(template.id) || [];
      const rulesList = rules.length
        ? `<ol>${rules
            .map(
              (rule) => `
                <li>${escapeHtml(rule.rule_code ?? "")} ${escapeHtml(rule.rule_name ?? "")} (${escapeHtml(rule.execution_order ?? "")})</li>
              `
            )
            .join("")}</ol>`
        : `<span class="muted">Правил немає</span>`;
      return `
        <tr>
          <td>${escapeHtml(template.code ?? "")}</td>
          <td>${escapeHtml(template.name ?? "")}</td>
          <td>${escapeHtml(template.description ?? "")}</td>
          <td>${template.is_active ? "Так" : "Ні"}</td>
          <td>${rulesList}</td>
        </tr>
      `;
    })
    .join("");

  const body = templates.length
    ? `
      <table>
        <thead>
          <tr>
            <th>Код</th>
            <th>Назва</th>
            <th>Опис</th>
            <th>Активний</th>
            <th>Правила (порядок)</th>
          </tr>
        </thead>
        <tbody>
          ${rowsHtml}
        </tbody>
      </table>
    `
    : `
      <div class="card">
        <p>Шаблонів правил ще немає.</p>
      </div>
    `;

  const chipLine = `
    <div class="chip-line" style="margin-top: 16px;">
      <label>Команди</label>
      <div class="chip-dropdown">
        <div id="chipInput" class="chip-input" tabindex="0">
          <span id="chipPlaceholder" class="chip-placeholder">Оберіть команду</span>
        </div>
        <div id="chipMenu" class="chip-menu">
          <div class="section-title">Що зробити</div>
          <ul id="chipActionList">
            <li data-group="action" data-token="створити" data-label="створити">створити</li>
          </ul>
          <div class="divider"></div>
          <div class="section-title">В якому періоді</div>
          <ul id="chipPeriodList">
            <li class="muted">Періодів немає</li>
          </ul>
          <div class="divider"></div>
          <div class="section-title">З яким підрозділом</div>
          <ul id="chipUnitList">
            <li class="muted">Підрозділів немає</li>
          </ul>
        </div>
      </div>
    </div>
  `;

  const script = `
    const chipInput = document.getElementById("chipInput");
    const chipMenu = document.getElementById("chipMenu");
    const chipPlaceholder = document.getElementById("chipPlaceholder");
    const chipActionList = document.getElementById("chipActionList");
    const chipPeriodList = document.getElementById("chipPeriodList");
    const chipUnitList = document.getElementById("chipUnitList");
    const selected = {};

    function updatePlaceholder() {
      const hasChips = chipInput.querySelectorAll(".chip").length > 0;
      chipPlaceholder.style.display = hasChips ? "none" : "inline";
    }

    function addChip(group, token, label) {
      if (selected[group]) {
        selected[group].remove();
      }
      const chip = document.createElement("span");
      chip.className = "chip";
      chip.dataset.group = group;
      chip.textContent = label || token;
      const remove = document.createElement("button");
      remove.type = "button";
      remove.textContent = "×";
      remove.addEventListener("click", (event) => {
        event.stopPropagation();
        delete selected[group];
        chip.remove();
        updatePlaceholder();
      });
      chip.appendChild(remove);
      chipInput.appendChild(chip);
      selected[group] = chip;
      updatePlaceholder();
    }

    chipInput.addEventListener("click", () => {
      chipMenu.classList.toggle("open");
    });

    document.addEventListener("click", (event) => {
      if (!chipMenu.contains(event.target) && !chipInput.contains(event.target)) {
        chipMenu.classList.remove("open");
      }
    });

    chipMenu.addEventListener("click", (event) => {
      const item = event.target.closest("[data-group]");
      if (!item) return;
      event.stopPropagation();
      addChip(item.dataset.group, item.dataset.token, item.dataset.label || item.dataset.token);
      chipMenu.classList.remove("open");
    });

    function setPeriodOptions(periods) {
      chipPeriodList.innerHTML = "";
      if (!periods.length) {
        chipPeriodList.innerHTML = '<li class="muted">Періодів немає</li>';
        return;
      }
      periods.forEach((period) => {
        const item = document.createElement("li");
        item.dataset.group = "period";
        item.dataset.token = period.period_code;
        item.dataset.label = period.period_name
          ? period.period_code + " — " + period.period_name
          : period.period_code;
        item.textContent = item.dataset.label;
        chipPeriodList.appendChild(item);
      });
    }

    function setUnitOptions(units) {
      chipUnitList.innerHTML = "";
      if (!units.length) {
        chipUnitList.innerHTML = '<li class="muted">Підрозділів немає</li>';
        return;
      }
      units.forEach((unit) => {
        const item = document.createElement("li");
        item.dataset.group = "unit";
        item.dataset.token = unit.code;
        item.dataset.label = unit.code + " — " + unit.name;
        item.textContent = item.dataset.label;
        chipUnitList.appendChild(item);
      });
    }

    fetch("/api/periods")
      .then((response) => response.json())
      .then((data) => setPeriodOptions(data.periods || []))
      .catch(() => setPeriodOptions([]));

    fetch("/api/org-units/active")
      .then((response) => response.json())
      .then((data) => setUnitOptions(data.units || []))
      .catch(() => setUnitOptions([]));

    updatePlaceholder();
  `;

  return renderPage("Шаблони правил", body + chipLine, "rule-templates", "", script);
}

function renderEmployees(employees, bases) {
  if (employees.length === 0) {
    const body = `
      <div class="card">
        <p>Працівників ще немає.</p>
      </div>
    `;
    return renderPage("Працівники", body, "employees");
  }

  const basesByEmployee = new Map();
  bases.forEach((base) => {
    if (!basesByEmployee.has(base.employee_id)) {
      basesByEmployee.set(base.employee_id, []);
    }
    basesByEmployee.get(base.employee_id).push(base);
  });

  const rowsHtml = employees
    .map((employee) => {
      const basesList = basesByEmployee.get(employee.id) || [];
      const detailsTable = basesList.length
        ? `
          <table>
            <thead>
              <tr>
                <th>Код бази</th>
                <th>Значення</th>
                <th>Діє з</th>
                <th>Діє до</th>
              </tr>
            </thead>
            <tbody>
              ${basesList
                .map(
                  (base) => `
                    <tr>
                      <td>${escapeHtml(base.base_code)}</td>
                      <td>${escapeHtml(base.value)}</td>
                      <td>${escapeHtml(base.valid_from)}</td>
                      <td>${escapeHtml(base.valid_to ?? "")}</td>
                    </tr>
                  `
                )
                .join("")}
            </tbody>
          </table>
        `
        : `<p class="muted">Оклади, надбавки та інші бази ще не задані.</p>`;

      const isActive = employee.fired_at ? "0" : "1";
      const unitLabel = [employee.org_unit_code, employee.org_unit_name]
        .filter(Boolean)
        .join(" — ");

      return `
        <tr data-employee-row="1"
            data-detail-id="details-${employee.id}"
            data-code="${escapeHtml(employee.code ?? "")}"
            data-name="${escapeHtml(employee.full_name)}"
            data-unit="${escapeHtml(unitLabel)}"
            data-active="${isActive}">
          <td class="actions">
            <button class="button toggle-button" data-toggle="details-${employee.id}" type="button">+</button>
          </td>
          <td>${escapeHtml(employee.code ?? "")}</td>
          <td>${escapeHtml(employee.full_name)}</td>
          <td>${escapeHtml(unitLabel)}</td>
          <td>${escapeHtml(employee.hired_at ?? "")}</td>
          <td>${escapeHtml(employee.fired_at ?? "")}</td>
        </tr>
        <tr class="details-row" id="details-${employee.id}">
          <td colspan="6" class="details-cell">
            <div class="details">
              <p class="muted">Підрозділ: ${escapeHtml(unitLabel || "—")}</p>
              ${detailsTable}
            </div>
          </td>
        </tr>
      `;
    })
    .join("");

  const body = `
    <div class="filters">
      <div class="control">
        <label for="employeeSearch">Пошук</label>
        <input id="employeeSearch" type="text" placeholder="Код або ПІБ" />
      </div>
      <div class="control">
        <label for="employeeStatus">Статус</label>
        <select id="employeeStatus">
          <option value="all">Усі</option>
          <option value="active">Активні</option>
          <option value="fired">Звільнені</option>
        </select>
      </div>
    </div>
    <table class="employee-table resizable" style="--col-toggle: 48px; --col-code: 120px; --col-name: 240px; --col-unit: 220px; --col-hired: 140px; --col-fired: 140px;">
      <colgroup>
        <col style="width: var(--col-toggle);" />
        <col style="width: var(--col-code);" />
        <col style="width: var(--col-name);" />
        <col style="width: var(--col-unit);" />
        <col style="width: var(--col-hired);" />
        <col style="width: var(--col-fired);" />
      </colgroup>
      <thead>
        <tr>
          <th></th>
          <th>Код<span class="resizer" data-col="code"></span></th>
          <th>ПІБ<span class="resizer" data-col="name"></span></th>
          <th>Підрозділ<span class="resizer" data-col="unit"></span></th>
          <th>Прийнятий<span class="resizer" data-col="hired"></span></th>
          <th>Звільнений<span class="resizer" data-col="fired"></span></th>
        </tr>
      </thead>
      <tbody>
        ${rowsHtml}
      </tbody>
    </table>
  `;

  const script = `
    const searchInput = document.getElementById("employeeSearch");
    const statusSelect = document.getElementById("employeeStatus");
    const table = document.querySelector(".employee-table");

    function applyFilters() {
      const query = (searchInput.value || "").trim().toLowerCase();
      const status = statusSelect.value;

      document.querySelectorAll("[data-employee-row]").forEach((row) => {
        const code = (row.dataset.code || "").toLowerCase();
        const name = (row.dataset.name || "").toLowerCase();
        const unit = (row.dataset.unit || "").toLowerCase();
        const active = row.dataset.active === "1";
        const matchesQuery =
          !query ||
          code.includes(query) ||
          name.includes(query) ||
          unit.includes(query);
        const matchesStatus =
          status === "all" ||
          (status === "active" && active) ||
          (status === "fired" && !active);

        const isVisible = matchesQuery && matchesStatus;
        row.style.display = isVisible ? "table-row" : "none";

        const detailId = row.dataset.detailId;
        if (detailId) {
          const detailRow = document.getElementById(detailId);
          if (detailRow) {
            detailRow.style.display = isVisible ? detailRow.style.display : "none";
          }
        }
      });
    }

    searchInput.addEventListener("input", applyFilters);
    statusSelect.addEventListener("change", applyFilters);

    function initResize() {
      let currentResizer = null;
      let startX = 0;
      let startWidth = 0;

      function onMouseMove(event) {
        if (!currentResizer) return;
        const delta = event.clientX - startX;
        const newWidth = Math.max(60, startWidth + delta);
        const colKey = currentResizer.dataset.col;
        table.style.setProperty("--col-" + colKey, newWidth + "px");
      }

      function onMouseUp() {
        if (!currentResizer) return;
        document.body.classList.remove("resizing");
        currentResizer = null;
        document.removeEventListener("mousemove", onMouseMove);
        document.removeEventListener("mouseup", onMouseUp);
      }

      document.querySelectorAll(".resizer").forEach((resizer) => {
        resizer.addEventListener("mousedown", (event) => {
          currentResizer = event.currentTarget;
          startX = event.clientX;
          const colKey = currentResizer.dataset.col;
          const currentWidth = getComputedStyle(table).getPropertyValue("--col-" + colKey);
          startWidth = parseFloat(currentWidth) || 120;
          document.body.classList.add("resizing");
          document.addEventListener("mousemove", onMouseMove);
          document.addEventListener("mouseup", onMouseUp);
        });
      });
    }

    initResize();

    document.querySelectorAll("[data-toggle]").forEach((button) => {
      button.addEventListener("click", (event) => {
        const targetId = event.currentTarget.getAttribute("data-toggle");
        const row = document.getElementById(targetId);
        if (!row) return;
        const isOpen = row.style.display === "table-row";
        row.style.display = isOpen ? "none" : "table-row";
        event.currentTarget.textContent = isOpen ? "+" : "–";
      });
    });
  `;

  return renderPage("Працівники", body, "employees", "", script);
}

function renderOrgStructure() {
  const body = `
    <div class="actions" style="margin-bottom: 12px;">
      <button class="button" id="addRootUnit" type="button">Додати підрозділ</button>
      <span id="orgActionStatus" class="muted"></span>
    </div>
    <div class="modal-backdrop" id="orgUnitModal" role="dialog" aria-modal="true" aria-hidden="true">
      <div class="modal">
        <header>
          <h3 id="orgUnitModalTitle">Підрозділ</h3>
          <button class="button" id="orgUnitModalClose" type="button">Закрити</button>
        </header>
        <form id="orgUnitForm">
          <input type="hidden" id="orgUnitMode" />
          <input type="hidden" id="orgUnitOriginalCode" />
          <div class="form-grid">
            <div class="form-row" data-field="code">
              <label for="orgUnitCode">Код</label>
              <input id="orgUnitCode" type="text" />
            </div>
            <div class="form-row" data-field="name">
              <label for="orgUnitName">Назва</label>
              <input id="orgUnitName" type="text" />
            </div>
            <div class="form-row" data-field="type">
              <label for="orgUnitType">Тип</label>
              <input id="orgUnitType" type="text" list="orgUnitTypes" />
            </div>
            <div class="form-row" data-field="parent">
              <label for="orgUnitParent">Батьківський</label>
              <input id="orgUnitParent" type="text" list="orgUnitOptions" placeholder="порожнє = корінь" />
            </div>
            <div class="form-row hidden" data-field="close">
              <label></label>
              <div class="muted" id="orgUnitCloseInfo"></div>
            </div>
          </div>
          <div class="actions" style="margin-top: 12px;">
            <button class="button" type="submit">Застосувати</button>
          </div>
        </form>
      </div>
    </div>
    <div class="filters">
      <div class="control">
        <label for="orgSearch">Пошук</label>
        <input id="orgSearch" type="text" placeholder="Підрозділ, код або ПІБ" />
      </div>
    </div>
    <div id="orgStructureTable"></div>
    <datalist id="orgUnitOptions"></datalist>
    <datalist id="orgUnitTypes">
      <option value="COMPANY"></option>
      <option value="DEPARTMENT"></option>
      <option value="DIVISION"></option>
      <option value="SECTION"></option>
      <option value="TEAM"></option>
    </datalist>
  `;

  const script = `
    const table = new Tabulator("#orgStructureTable", {
      layout: "fitDataFill",
      columnResizable: true,
      dataTree: true,
      dataTreeChildField: "children",
      dataTreeStartExpanded: false,
      placeholder: "Підрозділів ще немає.",
      columns: [
        { title: "Підрозділ / Працівник", field: "label", minWidth: 220,
          formatter: (cell) => {
            const data = cell.getData();
            const value = cell.getValue() || "";
            return data.node_type === "unit" ? "<strong>" + value + "</strong>" : value;
          }
        },
        { title: "Код", field: "code", width: 140 },
        { title: "Тип", field: "unit_type", width: 160 },
        { title: "К-сть працівників", field: "employee_count", width: 160 },
        { title: "Прийнятий", field: "hired_at", width: 140 },
        { title: "Звільнений", field: "fired_at", width: 140 },
        { title: "Дії", field: "actions", width: 220, headerSort: false,
          formatter: (cell) => {
            const data = cell.getData();
            const wrap = document.createElement("div");
            wrap.className = "actions";
            if (data.node_type !== "unit") return "";
            wrap.innerHTML = [
              '<button class="button" data-action="add-child">+</button>',
              '<button class="button" data-action="edit">Редагувати</button>',
              '<button class="button" data-action="move">Перемістити</button>',
              '<button class="button" data-action="close">Закрити</button>'
            ].join("");
            return wrap;
          },
          cellClick: (event, cell) => {
            const target = event.target.closest("[data-action]");
            if (!target) return;
            const action = target.dataset.action;
            const data = cell.getData();
            if (action === "add-child") {
              openUnitModal("add", { parent_code: data.code });
            } else if (action === "edit") {
              openUnitModal("edit", data);
            } else if (action === "move") {
              openUnitModal("move", data);
            } else if (action === "close") {
              openUnitModal("close", data);
            }
          }
        }
      ]
    });

    function refreshTree() {
      return fetch("/api/org-structure")
        .then((response) => response.json())
        .then((data) => table.setData(data));
    }
    function refreshUnitOptions() {
      return fetch("/api/org-units/active")
        .then((response) => response.json())
        .then((data) => {
          const list = data.units || [];
          const datalist = document.getElementById("orgUnitOptions");
          datalist.innerHTML = "";
          list.forEach((unit) => {
            const option = document.createElement("option");
            option.value = unit.code;
            option.textContent = unit.code + " — " + unit.name;
            datalist.appendChild(option);
          });
        });
    }

    refreshTree();
    refreshUnitOptions();

    const searchInput = document.getElementById("orgSearch");
    searchInput.addEventListener("input", () => {
      const query = (searchInput.value || "").trim().toLowerCase();
      if (!query) {
        table.clearFilter();
        return;
      }
      table.setFilter((data) => {
        const label = String(data.label || "").toLowerCase();
        const code = String(data.code || "").toLowerCase();
        const type = String(data.unit_type || "").toLowerCase();
        return label.includes(query) || code.includes(query) || type.includes(query);
      });
    });

    const actionStatus = document.getElementById("orgActionStatus");
    const addRootUnit = document.getElementById("addRootUnit");

    function setStatus(message, isError = false) {
      actionStatus.textContent = message || "";
      actionStatus.style.color = isError ? "#b00020" : "";
    }

    const orgUnitModal = document.getElementById("orgUnitModal");
    const orgUnitModalClose = document.getElementById("orgUnitModalClose");
    const orgUnitModalTitle = document.getElementById("orgUnitModalTitle");
    const orgUnitForm = document.getElementById("orgUnitForm");
    const orgUnitMode = document.getElementById("orgUnitMode");
    const orgUnitOriginalCode = document.getElementById("orgUnitOriginalCode");
    const orgUnitCode = document.getElementById("orgUnitCode");
    const orgUnitName = document.getElementById("orgUnitName");
    const orgUnitType = document.getElementById("orgUnitType");
    const orgUnitParent = document.getElementById("orgUnitParent");
    const orgUnitCloseInfo = document.getElementById("orgUnitCloseInfo");
    const unitRowCode = orgUnitForm.querySelector('[data-field="code"]');
    const unitRowName = orgUnitForm.querySelector('[data-field="name"]');
    const unitRowType = orgUnitForm.querySelector('[data-field="type"]');
    const unitRowParent = orgUnitForm.querySelector('[data-field="parent"]');
    const unitRowClose = orgUnitForm.querySelector('[data-field="close"]');

    function toggleModal(open) {
      orgUnitModal.classList.toggle("modal-open", open);
      orgUnitModal.setAttribute("aria-hidden", open ? "false" : "true");
    }

    function openUnitModal(mode, data = {}) {
      orgUnitMode.value = mode;
      orgUnitOriginalCode.value = data.code || "";
      orgUnitCode.value = data.code || "";
      orgUnitName.value = data.label || data.name || "";
      orgUnitType.value = data.unit_type || "";
      orgUnitParent.value = data.parent_code || data.parent_code === "" ? data.parent_code : "";
      orgUnitCloseInfo.textContent = mode === "close" ? "Підрозділ буде закрито (valid_to)." : "";
      unitRowClose.classList.toggle("hidden", mode !== "close");

      unitRowCode.classList.toggle("hidden", mode === "move" || mode === "close");
      unitRowName.classList.toggle("hidden", mode === "move" || mode === "close");
      unitRowType.classList.toggle("hidden", mode === "move" || mode === "close");
      unitRowParent.classList.toggle("hidden", mode === "edit" || mode === "close");

      orgUnitModalTitle.textContent =
        mode === "add" ? "Додати підрозділ" :
        mode === "edit" ? "Редагувати підрозділ" :
        mode === "move" ? "Перемістити підрозділ" :
        "Закрити підрозділ";
      toggleModal(true);
    }

    function closeUnitModal() {
      toggleModal(false);
      orgUnitForm.reset();
    }

    orgUnitModalClose.addEventListener("click", closeUnitModal);
    orgUnitModal.addEventListener("click", (event) => {
      if (event.target === orgUnitModal) closeUnitModal();
    });
    addRootUnit.addEventListener("click", () => openUnitModal("add"));

    orgUnitForm.addEventListener("submit", (event) => {
      event.preventDefault();
      const mode = orgUnitMode.value;
      const payload = {
        unit_code: orgUnitOriginalCode.value,
        code: orgUnitCode.value.trim(),
        name: orgUnitName.value.trim(),
        unit_type: orgUnitType.value.trim(),
        parent_code: orgUnitParent.value.trim()
      };
      let url = "";
      if (mode === "add") url = "/api/org-unit/create";
      if (mode === "edit") url = "/api/org-unit/update";
      if (mode === "move") url = "/api/org-unit/move";
      if (mode === "close") url = "/api/org-unit/close";
      fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      })
        .then((response) => response.json())
        .then((data) => {
          if (!data.ok) {
            setStatus(data.message || "Помилка виконання.", true);
            return;
          }
          setStatus(data.message || "Готово.");
          if (data.tree) {
            table.setData(data.tree);
          } else {
            refreshTree();
          }
          refreshUnitOptions();
          closeUnitModal();
        })
        .catch(() => setStatus("Помилка виконання.", true));
    });
  `;

  const extraHead = `
    <link rel="stylesheet" href="/vendor/tabulator/tabulator.min.css" />
  `;
  const extraHtml = `
    <script src="/vendor/tabulator/tabulator.min.js"></script>
  `;

  return renderPage("Структура", body, "org-structure", extraHtml, script, extraHead);
}

function buildOrgTree(units, employees) {
  const unitById = new Map(units.map((unit) => [unit.id, unit]));
  const childrenByParent = new Map();
  units.forEach((unit) => {
    const parentId = unit.parent_id ?? null;
    if (!childrenByParent.has(parentId)) {
      childrenByParent.set(parentId, []);
    }
    childrenByParent.get(parentId).push(unit);
  });
  childrenByParent.forEach((list) =>
    list.sort((a, b) => a.name.localeCompare(b.name))
  );

  const employeesByUnit = new Map();
  employees.forEach((employee) => {
    if (!employeesByUnit.has(employee.org_unit_id)) {
      employeesByUnit.set(employee.org_unit_id, []);
    }
    employeesByUnit.get(employee.org_unit_id).push(employee);
  });

  function buildNode(unit) {
    const childUnits = childrenByParent.get(unit.id) || [];
    const unitEmployees = employeesByUnit.get(unit.id) || [];

    const children = childUnits.map(buildNode);
    const employeeNodes = unitEmployees.map((employee) => ({
      id: `emp-${employee.id}`,
      node_type: "employee",
      label: employee.full_name,
      code: employee.code,
      unit_type: "EMPLOYEE",
      employee_count: "",
      hired_at: employee.hired_at,
      fired_at: employee.fired_at,
      children: []
    }));

    const totalEmployees =
      unitEmployees.length +
      children.reduce((sum, child) => sum + (child.employee_count || 0), 0);

    return {
      id: `unit-${unit.id}`,
      node_type: "unit",
      unit_id: unit.id,
      label: unit.name,
      code: unit.code,
      unit_type: unit.unit_type,
      parent_code: unit.parent_id ? unitById.get(unit.parent_id)?.code || "" : "",
      employee_count: totalEmployees,
      hired_at: "",
      fired_at: "",
      children: [...children, ...employeeNodes]
    };
  }

  const roots = childrenByParent.get(null) || [];
  return roots.map(buildNode);
}

function formatDate(value) {
  const pad = (n) => String(n).padStart(2, "0");
  const date = value instanceof Date ? value : new Date();
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function formatDateTime(value) {
  const pad = (n) => String(n).padStart(2, "0");
  const date = value instanceof Date ? value : new Date();
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

function fetchActiveOrgData(db, callback) {
  db.all(
    `
      SELECT id, parent_id, code, name, unit_type
      FROM org_units
      WHERE valid_to IS NULL
      ORDER BY name
    `,
    (unitErr, units) => {
      if (unitErr) return callback(unitErr);
      db.all(
        `
          SELECT e.id,
                 e.code,
                 e.full_name,
                 e.hired_at,
                 e.fired_at,
                 h.org_unit_id
          FROM employees e
          JOIN employee_org_unit_history h
            ON h.employee_id = e.id AND h.valid_to IS NULL
          ORDER BY e.full_name
        `,
        (empErr, employees) => {
          if (empErr) return callback(empErr);
          callback(null, { units, employees });
        }
      );
    }
  );
}

function respondWithTree(db, res, message) {
  fetchActiveOrgData(db, (err, data) => {
    if (err) {
      res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ ok: false, message: err.message }));
      db.close();
      return;
    }
    res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
    res.end(JSON.stringify({
      ok: true,
      message,
      tree: buildOrgTree(data.units, data.employees)
    }));
    db.close();
  });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  if (url.pathname.startsWith("/vendor/")) {
    const safePath = path
      .normalize(url.pathname)
      .replace(/^(\.\.(\/|\\|$))+/, "")
      .replace(/^[/\\]+/, "");
    const filePath = path.join(PUBLIC_DIR, safePath);
    if (!filePath.startsWith(PUBLIC_DIR) || !fs.existsSync(filePath)) {
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Not found");
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType =
      ext === ".css"
        ? "text/css; charset=utf-8"
        : ext === ".js"
        ? "application/javascript; charset=utf-8"
        : "application/octet-stream";
    res.writeHead(200, { "Content-Type": contentType });
    res.end(fs.readFileSync(filePath));
    return;
  }

  if (url.pathname === "/") {
    res.writeHead(302, { Location: "/org-structure" });
    res.end();
    return;
  }

  if (url.pathname === "/api/org-units/active") {
    if (!fs.existsSync(DB_PATH)) {
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ units: [] }));
      return;
    }
    const db = new sqlite3.Database(DB_PATH);
    db.all(
      `
        SELECT id, code, name, unit_type
        FROM org_units
        WHERE valid_to IS NULL
        ORDER BY name
      `,
      (err, units) => {
        if (err) {
          res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
          res.end(JSON.stringify({ units: [] }));
          db.close();
          return;
        }
        res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ units }));
        db.close();
      }
    );
    return;
  }

  if (url.pathname === "/api/periods") {
    if (!fs.existsSync(DB_PATH)) {
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ periods: [] }));
      return;
    }
    const db = new sqlite3.Database(DB_PATH);
    db.all(
      `
        SELECT id, period_code, period_name, start_date, end_date, status
        FROM calculation_periods
        ORDER BY start_date DESC
      `,
      (err, periods) => {
        if (err) {
          res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
          res.end(JSON.stringify({ periods: [] }));
          db.close();
          return;
        }
        res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ periods }));
        db.close();
      }
    );
    return;
  }

  if (url.pathname.startsWith("/api/org-unit/") && req.method === "POST") {
    if (!fs.existsSync(DB_PATH)) {
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ ok: false, message: "База даних не знайдена." }));
      return;
    }
    let body = "";
    req.on("data", (chunk) => {
      body += chunk.toString();
    });
    req.on("end", () => {
      let payload = {};
      try {
        payload = JSON.parse(body || "{}");
      } catch (error) {
        res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, message: "Некоректний JSON." }));
        return;
      }

      const db = new sqlite3.Database(DB_PATH);
      const today = formatDate();
      const now = formatDateTime();

      if (url.pathname === "/api/org-unit/create") {
        const code = (payload.code || "").trim();
        const name = (payload.name || "").trim();
        const unitType = (payload.unit_type || "").trim();
        const parentCode = (payload.parent_code || "").trim();
        if (!code || !name || !unitType) {
          res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
          res.end(JSON.stringify({ ok: false, message: "Код, назва і тип є обов'язковими." }));
          db.close();
          return;
        }
        db.get(
          `
            SELECT id
            FROM org_units
            WHERE code = ? AND valid_to IS NULL
          `,
          [code],
          (err, existing) => {
            if (err) {
              res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
              res.end(JSON.stringify({ ok: false, message: err.message }));
              db.close();
              return;
            }
            if (existing) {
              res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
              res.end(JSON.stringify({ ok: false, message: "Підрозділ з таким кодом вже існує." }));
              db.close();
              return;
            }
            const insertUnit = (parentId) => {
              db.run(
                `
                  INSERT INTO org_units (parent_id, code, name, unit_type, valid_from, valid_to, created_at, updated_at)
                  VALUES (?, ?, ?, ?, ?, NULL, ?, ?)
                `,
                [parentId, code, name, unitType, today, now, now],
                (insertErr) => {
                  if (insertErr) {
                    res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
                    res.end(JSON.stringify({ ok: false, message: insertErr.message }));
                    db.close();
                    return;
                  }
                  respondWithTree(db, res, "Підрозділ додано.");
                }
              );
            };
            if (!parentCode) {
              insertUnit(null);
              return;
            }
            db.get(
              `
                SELECT id
                FROM org_units
                WHERE code = ? AND valid_to IS NULL
              `,
              [parentCode],
              (parentErr, parentRow) => {
                if (parentErr) {
                  res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
                  res.end(JSON.stringify({ ok: false, message: parentErr.message }));
                  db.close();
                  return;
                }
                if (!parentRow) {
                  res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
                  res.end(JSON.stringify({ ok: false, message: "Батьківський підрозділ не знайдено." }));
                  db.close();
                  return;
                }
                insertUnit(parentRow.id);
              }
            );
          }
        );
        return;
      }

      if (url.pathname === "/api/org-unit/update") {
        const unitCode = (payload.unit_code || "").trim();
        const code = (payload.code || "").trim();
        const name = (payload.name || "").trim();
        const unitType = (payload.unit_type || "").trim();
        if (!unitCode || !code || !name || !unitType) {
          res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
          res.end(JSON.stringify({ ok: false, message: "Код, назва і тип є обов'язковими." }));
          db.close();
          return;
        }
        db.get(
          `
            SELECT id, code
            FROM org_units
            WHERE code = ? AND valid_to IS NULL
          `,
          [unitCode],
          (err, unit) => {
            if (err) {
              res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
              res.end(JSON.stringify({ ok: false, message: err.message }));
              db.close();
              return;
            }
            if (!unit) {
              res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
              res.end(JSON.stringify({ ok: false, message: "Підрозділ не знайдено." }));
              db.close();
              return;
            }
            const ensureUnique = (next) => {
              if (unit.code === code) return next();
              db.get(
                `
                  SELECT id
                  FROM org_units
                  WHERE code = ? AND valid_to IS NULL
                `,
                [code],
                (checkErr, existing) => {
                  if (checkErr) return next(checkErr);
                  if (existing) {
                    res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
                    res.end(JSON.stringify({ ok: false, message: "Код підрозділу вже зайнято." }));
                    db.close();
                    return;
                  }
                  next();
                }
              );
            };
            ensureUnique((uniqueErr) => {
              if (uniqueErr) {
                res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
                res.end(JSON.stringify({ ok: false, message: uniqueErr.message }));
                db.close();
                return;
              }
              db.run(
                `
                  UPDATE org_units
                  SET code = ?, name = ?, unit_type = ?, updated_at = ?
                  WHERE id = ?
                `,
                [code, name, unitType, now, unit.id],
                (updateErr) => {
                  if (updateErr) {
                    res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
                    res.end(JSON.stringify({ ok: false, message: updateErr.message }));
                    db.close();
                    return;
                  }
                  respondWithTree(db, res, "Підрозділ оновлено.");
                }
              );
            });
          }
        );
        return;
      }

      if (url.pathname === "/api/org-unit/move") {
        const unitCode = (payload.unit_code || "").trim();
        const parentCode = (payload.parent_code || "").trim();
        if (!unitCode) {
          res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
          res.end(JSON.stringify({ ok: false, message: "Не вказано підрозділ." }));
          db.close();
          return;
        }
        db.get(
          `
            SELECT id, code, parent_id
            FROM org_units
            WHERE code = ? AND valid_to IS NULL
          `,
          [unitCode],
          (err, unit) => {
            if (err) {
              res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
              res.end(JSON.stringify({ ok: false, message: err.message }));
              db.close();
              return;
            }
            if (!unit) {
              res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
              res.end(JSON.stringify({ ok: false, message: "Підрозділ не знайдено." }));
              db.close();
              return;
            }
            const moveTo = (parentId) => {
              db.all(
                `
                  SELECT id, parent_id
                  FROM org_units
                  WHERE valid_to IS NULL
                `,
                (listErr, rows) => {
                  if (listErr) {
                    res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
                    res.end(JSON.stringify({ ok: false, message: listErr.message }));
                    db.close();
                    return;
                  }
                  const parentMap = new Map(rows.map((row) => [row.id, row.parent_id]));
                  let cursor = parentId;
                  const visited = new Set();
                  while (cursor) {
                    if (cursor === unit.id) {
                      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
                      res.end(JSON.stringify({ ok: false, message: "Неможливо створити цикл у дереві." }));
                      db.close();
                      return;
                    }
                    if (visited.has(cursor)) break;
                    visited.add(cursor);
                    cursor = parentMap.get(cursor);
                  }
                  db.run(
                    `
                      UPDATE org_units
                      SET parent_id = ?, updated_at = ?
                      WHERE id = ?
                    `,
                    [parentId, now, unit.id],
                    (updateErr) => {
                      if (updateErr) {
                        res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
                        res.end(JSON.stringify({ ok: false, message: updateErr.message }));
                        db.close();
                        return;
                      }
                      respondWithTree(db, res, "Підрозділ переміщено.");
                    }
                  );
                }
              );
            };

            if (!parentCode) {
              moveTo(null);
              return;
            }
            db.get(
              `
                SELECT id
                FROM org_units
                WHERE code = ? AND valid_to IS NULL
              `,
              [parentCode],
              (parentErr, parentRow) => {
                if (parentErr) {
                  res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
                  res.end(JSON.stringify({ ok: false, message: parentErr.message }));
                  db.close();
                  return;
                }
                if (!parentRow) {
                  res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
                  res.end(JSON.stringify({ ok: false, message: "Батьківський підрозділ не знайдено." }));
                  db.close();
                  return;
                }
                if (parentRow.id === unit.id) {
                  res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
                  res.end(JSON.stringify({ ok: false, message: "Підрозділ не може бути власним батьком." }));
                  db.close();
                  return;
                }
                moveTo(parentRow.id);
              }
            );
          }
        );
        return;
      }

      if (url.pathname === "/api/org-unit/close") {
        const unitCode = (payload.unit_code || payload.code || "").trim();
        if (!unitCode) {
          res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
          res.end(JSON.stringify({ ok: false, message: "Не вказано підрозділ." }));
          db.close();
          return;
        }
        db.get(
          `
            SELECT id
            FROM org_units
            WHERE code = ? AND valid_to IS NULL
          `,
          [unitCode],
          (err, unit) => {
            if (err) {
              res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
              res.end(JSON.stringify({ ok: false, message: err.message }));
              db.close();
              return;
            }
            if (!unit) {
              res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
              res.end(JSON.stringify({ ok: false, message: "Підрозділ не знайдено або вже закрито." }));
              db.close();
              return;
            }
            db.get(
              `
                SELECT id
                FROM org_units
                WHERE parent_id = ? AND valid_to IS NULL
                LIMIT 1
              `,
              [unit.id],
              (childErr, childRow) => {
                if (childErr) {
                  res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
                  res.end(JSON.stringify({ ok: false, message: childErr.message }));
                  db.close();
                  return;
                }
                if (childRow) {
                  res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
                  res.end(JSON.stringify({ ok: false, message: "Спочатку закрийте дочірні підрозділи." }));
                  db.close();
                  return;
                }
                db.get(
                  `
                    SELECT id
                    FROM employee_org_unit_history
                    WHERE org_unit_id = ? AND valid_to IS NULL
                    LIMIT 1
                  `,
                  [unit.id],
                  (empErr, empRow) => {
                    if (empErr) {
                      res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
                      res.end(JSON.stringify({ ok: false, message: empErr.message }));
                      db.close();
                      return;
                    }
                    if (empRow) {
                      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
                      res.end(JSON.stringify({ ok: false, message: "У підрозділі є активні працівники." }));
                      db.close();
                      return;
                    }
                    db.run(
                      `
                        UPDATE org_units
                        SET valid_to = ?, updated_at = ?
                        WHERE id = ?
                      `,
                      [today, now, unit.id],
                      (updateErr) => {
                        if (updateErr) {
                          res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
                          res.end(JSON.stringify({ ok: false, message: updateErr.message }));
                          db.close();
                          return;
                        }
                        respondWithTree(db, res, "Підрозділ закрито.");
                      }
                    );
                  }
                );
              }
            );
          }
        );
        return;
      }
    });
    return;
  }

  if (url.pathname === "/api/org-structure") {
    if (!fs.existsSync(DB_PATH)) {
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify([]));
      return;
    }

    const db = new sqlite3.Database(DB_PATH);
    fetchActiveOrgData(db, (err, data) => {
      if (err) {
        res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
        res.end(`DB error: ${err.message}`);
        db.close();
        return;
      }
      const tree = buildOrgTree(data.units, data.employees);
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify(tree));
      db.close();
    });
    return;
  }

  if (
    url.pathname !== "/bases" &&
    url.pathname !== "/employee-bases" &&
    url.pathname !== "/employees" &&
    url.pathname !== "/org-structure" &&
    url.pathname !== "/rule-templates"
  ) {
    res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Not found");
    return;
  }

  if (!fs.existsSync(DB_PATH)) {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(renderMissingDb());
    return;
  }

  const db = new sqlite3.Database(DB_PATH);
  const isEmployeeBases = url.pathname === "/employee-bases";
  const isEmployees = url.pathname === "/employees";
  const isOrgStructure = url.pathname === "/org-structure";
  const isRuleTemplates = url.pathname === "/rule-templates";

  if (isEmployees) {
    db.serialize(() => {
      db.all(
        `
          SELECT e.id,
                 e.code,
                 e.full_name,
                 e.hired_at,
                 e.fired_at,
                 ou.code AS org_unit_code,
                 ou.name AS org_unit_name
          FROM employees e
          LEFT JOIN employee_org_unit_history h
            ON h.employee_id = e.id AND h.valid_to IS NULL
          LEFT JOIN org_units ou
            ON ou.id = h.org_unit_id
          ORDER BY e.full_name
        `,
        (employeeErr, employees) => {
          if (employeeErr) {
            res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
            res.end(`DB error: ${employeeErr.message}`);
            db.close();
            return;
          }

          db.all(
            `
              SELECT employee_id, base_code, value, valid_from, valid_to
              FROM employee_bases
              ORDER BY base_code, valid_from
            `,
            (baseErr, bases) => {
              if (baseErr) {
                res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
                res.end(`DB error: ${baseErr.message}`);
                db.close();
                return;
              }

              res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
              res.end(renderEmployees(employees, bases));
              db.close();
            }
          );
        }
      );
    });
    return;
  }

  if (isOrgStructure) {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(renderOrgStructure());
    db.close();
    return;
  }

  if (isRuleTemplates) {
    db.serialize(() => {
      db.all(
        `
          SELECT id, code, name, description, is_active
          FROM calculation_templates
          ORDER BY name
        `,
        (templateErr, templates) => {
          if (templateErr) {
            res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
            res.end(`DB error: ${templateErr.message}`);
            db.close();
            return;
          }
          db.all(
            `
              SELECT tr.template_id,
                     tr.rule_id,
                     tr.execution_order,
                     tr.is_active,
                     cr.code AS rule_code,
                     cr.name AS rule_name
              FROM template_rules tr
              LEFT JOIN calculation_rules cr ON cr.id = tr.rule_id
              ORDER BY tr.template_id, tr.execution_order
            `,
            (ruleErr, rules) => {
              if (ruleErr) {
                res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
                res.end(`DB error: ${ruleErr.message}`);
                db.close();
                return;
              }
              res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
              res.end(renderRuleTemplates(templates, rules));
              db.close();
            }
          );
        }
      );
    });
    return;
  }

  const query = isEmployeeBases
    ? `
        SELECT eb.employee_id,
               eb.base_code,
               eb.value,
               eb.valid_from,
               eb.valid_to,
               e.code AS employee_code,
               e.full_name AS employee_name
        FROM employee_bases eb
        LEFT JOIN employees e ON e.id = eb.employee_id
        ORDER BY eb.base_code, eb.employee_id, eb.valid_from
      `
    : `
        SELECT base_code, value, valid_from, valid_to, comment
        FROM base_values
        ORDER BY base_code, valid_from
      `;

  db.all(query, (err, rows) => {
    if (err) {
      res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
      res.end(`DB error: ${err.message}`);
      db.close();
      return;
    }

    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(isEmployeeBases ? renderEmployeeBases(rows) : renderBaseValues(rows));
    db.close();
  });
});

server.listen(PORT, () => {
  console.log(`✅ Web UI running on http://localhost:${PORT}/bases`);
});
