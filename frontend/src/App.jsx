import React, { useState } from 'react';
import axios from 'axios';
import './App.css';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000/api/v1';

function App() {
  const [command, setCommand] = useState('');
  const [chips, setChips] = useState([]);
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [view, setView] = useState('command'); // command, employees, periods, calculations

  const parseCommand = (text) => {
    const words = text.toLowerCase().trim().split(/\s+/);
    const parsed = {
      action: null,
      entity: null,
      period: null,
      scope: null,
      scopeValue: null
    };

    // Визначити дію
    if (words.includes('створити') || words.includes('create')) {
      parsed.action = 'create';
    }

    // Визначити сутність
    if (words.includes('період') || words.includes('period')) {
      parsed.entity = 'period';
    }

    // Визначити період
    const months = {
      'січень': '01', 'лютий': '02', 'березень': '03', 'квітень': '04',
      'травень': '05', 'червень': '06', 'липень': '07', 'серпень': '08',
      'вересень': '09', 'жовтень': '10', 'листопад': '11', 'грудень': '12'
    };
    
    for (const [month, num] of Object.entries(months)) {
      if (words.includes(month)) {
        parsed.period = `2024-${num}`;
        parsed.periodName = month.charAt(0).toUpperCase() + month.slice(1) + ' 2024';
      }
    }

    // Визначити scope
    if (words.includes('відділ') || words.includes('підрозділ')) {
      parsed.scope = 'unit';
      // Знайти назву підрозділу після ключового слова
      const unitIndex = Math.max(words.indexOf('відділ'), words.indexOf('підрозділ'));
      if (unitIndex >= 0 && unitIndex < words.length - 1) {
        parsed.scopeValue = words.slice(unitIndex + 1).join(' ');
      }
    } else if (words.includes('працівник')) {
      parsed.scope = 'employee';
      const empIndex = words.indexOf('працівник');
      if (empIndex >= 0 && empIndex < words.length - 1) {
        parsed.scopeValue = words.slice(empIndex + 1).join(' ');
      }
    } else if (words.includes('підприємство') || words.includes('компанія')) {
      parsed.scope = 'company';
    }

    return parsed;
  };

  const createChip = (type, value) => {
    return {
      id: Date.now() + Math.random(),
      type,
      value,
      display: `${type}: ${value}`
    };
  };

  const handleCommandSubmit = async (e) => {
    e.preventDefault();
    if (!command.trim()) return;

    setLoading(true);
    setError(null);

    try {
      const parsed = parseCommand(command);
      
      // Створити чіпи з розпізнаної команди
      const newChips = [];
      if (parsed.action) newChips.push(createChip('Дія', parsed.action));
      if (parsed.entity) newChips.push(createChip('Сутність', parsed.entity));
      if (parsed.period) newChips.push(createChip('Період', parsed.periodName));
      if (parsed.scope) newChips.push(createChip('Scope', parsed.scope));
      if (parsed.scopeValue) newChips.push(createChip('Значення', parsed.scopeValue));
      
      setChips(newChips);

      // Виконати команду
      if (parsed.action === 'create' && parsed.entity === 'period') {
        const response = await axios.post(`${API_URL}/periods/`, {
          period_code: parsed.period || '2024-01',
          period_name: parsed.periodName || 'Період',
          start_date: `${parsed.period || '2024-01'}-01`,
          end_date: `${parsed.period || '2024-01'}-31`,
          period_type: 'monthly',
          organizational_unit_id: null,
          employee_id: null
        });

        setResult({
          type: 'success',
          message: `Період створено успішно`,
          data: response.data
        });
      }
    } catch (err) {
      setError(err.response?.data?.detail || err.message || 'Помилка виконання команди');
      setResult({
        type: 'error',
        message: err.response?.data?.detail || err.message
      });
    } finally {
      setLoading(false);
    }
  };

  const removeChip = (chipId) => {
    setChips(chips.filter(c => c.id !== chipId));
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Система Розрахунку Зарплати</h1>
        <nav>
          <button onClick={() => setView('command')} className={view === 'command' ? 'active' : ''}>
            Команди
          </button>
          <button onClick={() => setView('employees')} className={view === 'employees' ? 'active' : ''}>
            Працівники
          </button>
          <button onClick={() => setView('periods')} className={view === 'periods' ? 'active' : ''}>
            Періоди
          </button>
          <button onClick={() => setView('calculations')} className={view === 'calculations' ? 'active' : ''}>
            Розрахунки
          </button>
          <button onClick={() => setView('schema')} className={view === 'schema' ? 'active' : ''}>
            Схема БД
          </button>
        </nav>
      </header>

      <main className="App-main">
        {view === 'command' && (
          <div className="command-section">
            <h2>Введіть команду</h2>
            <p className="hint">
              Приклад: "створити період січень для відділу продажів"
            </p>
            
            <form onSubmit={handleCommandSubmit}>
              <div className="input-container">
                <input
                  type="text"
                  value={command}
                  onChange={(e) => setCommand(e.target.value)}
                  placeholder="створити період..."
                  disabled={loading}
                  className="command-input"
                />
                <button type="submit" disabled={loading} className="submit-button">
                  {loading ? 'Обробка...' : 'Виконати'}
                </button>
              </div>
            </form>

            {chips.length > 0 && (
              <div className="chips-container">
                <h3>Розпізнані параметри:</h3>
                <div className="chips">
                  {chips.map(chip => (
                    <div key={chip.id} className="chip">
                      <span>{chip.display}</span>
                      <button onClick={() => removeChip(chip.id)} className="chip-remove">
                        ×
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {error && (
              <div className="error-message">
                <strong>Помилка:</strong> {error}
              </div>
            )}

            {result && (
              <div className={`result-message ${result.type}`}>
                <h3>{result.type === 'success' ? '✓ Успіх' : '✗ Помилка'}</h3>
                <p>{result.message}</p>
                {result.data && (
                  <pre>{JSON.stringify(result.data, null, 2)}</pre>
                )}
              </div>
            )}
          </div>
        )}

        {view === 'employees' && (
          <EmployeesView apiUrl={API_URL} />
        )}

        {view === 'periods' && (
          <PeriodsView apiUrl={API_URL} />
        )}

        {view === 'calculations' && (
          <CalculationsView apiUrl={API_URL} />
        )}

        {view === 'schema' && (
          <DBSchemaView />
        )}
      </main>
    </div>
  );
}

// Компонент для перегляду працівників
function EmployeesView({ apiUrl }) {
  const [employees, setEmployees] = useState([]);
  const [loading, setLoading] = useState(true);

  React.useEffect(() => {
    axios.get(`${apiUrl}/employees/`)
      .then(response => {
        setEmployees(response.data.items);
        setLoading(false);
      })
      .catch(err => {
        console.error(err);
        setLoading(false);
      });
  }, [apiUrl]);

  if (loading) return <div>Завантаження...</div>;

  return (
    <div className="data-view">
      <h2>Працівники ({employees.length})</h2>
      <table>
        <thead>
          <tr>
            <th>№</th>
            <th>Табельний</th>
            <th>Ім'я</th>
            <th>Прізвище</th>
            <th>Підрозділ</th>
            <th>Статус</th>
          </tr>
        </thead>
        <tbody>
          {employees.map((emp, idx) => (
            <tr key={emp.id}>
              <td>{idx + 1}</td>
              <td>{emp.personnel_number}</td>
              <td>{emp.first_name}</td>
              <td>{emp.last_name}</td>
              <td>{emp.organizational_unit?.name || '-'}</td>
              <td>{emp.is_active ? '✓ Активний' : '✗ Неактивний'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// Компонент для перегляду періодів
function PeriodsView({ apiUrl }) {
  const [periods, setPeriods] = useState([]);
  const [loading, setLoading] = useState(true);

  React.useEffect(() => {
    axios.get(`${apiUrl}/periods/`)
      .then(response => {
        setPeriods(response.data.items);
        setLoading(false);
      })
      .catch(err => {
        console.error(err);
        setLoading(false);
      });
  }, [apiUrl]);

  if (loading) return <div>Завантаження...</div>;

  return (
    <div className="data-view">
      <h2>Розрахункові періоди ({periods.length})</h2>
      {periods.length === 0 ? (
        <p>Періодів ще немає. Створіть перший через команди.</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>Код</th>
              <th>Назва</th>
              <th>Період</th>
              <th>Тип</th>
              <th>Статус</th>
            </tr>
          </thead>
          <tbody>
            {periods.map(period => (
              <tr key={period.id}>
                <td>{period.period_code}</td>
                <td>{period.period_name}</td>
                <td>{period.start_date} - {period.end_date}</td>
                <td>{period.period_type}</td>
                <td><span className={`status ${period.status}`}>{period.status}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

// Компонент для перегляду розрахунків
function CalculationsView({ apiUrl }) {
  return (
    <div className="data-view">
      <h2>Розрахунки</h2>
      <p>Тут будуть відображатися результати розрахунків</p>
    </div>
  );
}

// Компонент для візуалізації схеми БД
function DBSchemaView() {
  const [expandedModule, setExpandedModule] = useState(null);
  const [selectedTable, setSelectedTable] = useState(null);

  const dbSchema = {
    modules: [
      {
        id: 1,
        name: 'Модуль 1: Структура підприємства',
        color: '#4CAF50',
        tables: [
          {
            name: 'organizational_units',
            displayName: 'Організаційні підрозділи',
            icon: '🏢',
            fields: ['id', 'code', 'name', 'parent_id', 'level (1-6)', 'is_active'],
            description: 'Ієрархічна структура підрозділів (до 6 рівнів)',
            relations: ['employees', 'contracts']
          },
          {
            name: 'employees',
            displayName: 'Співробітники',
            icon: '👤',
            fields: ['id', 'personnel_number', 'first_name', 'last_name', 'hire_date', 'is_active', 'organizational_unit_id'],
            description: 'Інформація про працівників',
            relations: ['contracts', 'timesheets', 'production_results', 'accrual_results']
          },
          {
            name: 'contracts',
            displayName: 'Трудові договори',
            icon: '📄',
            fields: ['id', 'contract_number', 'employee_id', 'contract_type', 'salary_amount', 'hourly_rate', 'start_date', 'end_date'],
            description: 'Типи: salary, hourly, piecework, task_based',
            relations: ['employees']
          },
          {
            name: 'calculation_rules',
            displayName: 'Правила розрахунку',
            icon: '⚙️',
            fields: ['id', 'rule_code', 'rule_name', 'sql_code', 'organizational_unit_id', 'is_active'],
            description: 'SQL-правила для розрахунків',
            relations: ['template_rules']
          },
          {
            name: 'calculation_templates',
            displayName: 'Шаблони розрахунків',
            icon: '📋',
            fields: ['id', 'template_code', 'template_name', 'description', 'is_active'],
            description: 'Набори правил для розрахунку ЗП',
            relations: ['template_rules']
          },
          {
            name: 'template_rules',
            displayName: "Зв'язок шаблонів та правил",
            icon: '🔗',
            fields: ['id', 'template_id', 'rule_id', 'execution_order'],
            description: 'Порядок виконання правил у шаблоні',
            relations: ['calculation_templates', 'calculation_rules']
          }
        ]
      },
      {
        id: 2,
        name: 'Модуль 2: Результати роботи',
        color: '#2196F3',
        tables: [
          {
            name: 'work_results',
            displayName: 'Загальні результати роботи',
            icon: '📊',
            fields: ['id', 'employee_id', 'period_id', 'result_type', 'value', 'date'],
            description: 'Відстеження результатів роботи',
            relations: ['employees', 'calculation_periods']
          },
          {
            name: 'timesheets',
            displayName: 'Табелі обліку часу',
            icon: '⏰',
            fields: ['id', 'employee_id', 'work_date', 'hours_worked', 'work_type'],
            description: 'Почасовий облік робочого часу',
            relations: ['employees']
          },
          {
            name: 'production_results',
            displayName: 'Результати виробництва',
            icon: '🏭',
            fields: ['id', 'employee_id', 'production_date', 'units_produced', 'quality_coefficient'],
            description: 'Відрядні результати виробництва',
            relations: ['employees']
          }
        ]
      },
      {
        id: 3,
        name: 'Модуль 3: Періоди та нарахування',
        color: '#FF9800',
        tables: [
          {
            name: 'calculation_periods',
            displayName: 'Розрахункові періоди',
            icon: '📅',
            fields: ['id', 'period_code', 'period_name', 'start_date', 'end_date', 'period_type', 'status'],
            description: 'Періоди для розрахунку ЗП',
            relations: ['accrual_documents']
          },
          {
            name: 'accrual_documents',
            displayName: 'Документи нарахувань',
            icon: '📑',
            fields: ['id', 'document_number', 'period_id', 'status', 'created_by', 'approved_by', 'created_at'],
            description: 'Статуси: draft → in_review → approved → cancelled',
            relations: ['calculation_periods', 'accrual_results', 'change_requests']
          },
          {
            name: 'accrual_results',
            displayName: 'Результати нарахувань',
            icon: '💰',
            fields: ['id', 'document_id', 'employee_id', 'rule_id', 'amount', 'is_cancelled'],
            description: 'Незмінні результати розрахунків',
            relations: ['accrual_documents', 'employees', 'calculation_rules']
          },
          {
            name: 'change_requests',
            displayName: 'Запити на зміни',
            icon: '🔄',
            fields: ['id', 'document_id', 'requested_by', 'change_reason', 'status', 'created_at'],
            description: 'Workflow для модифікації нарахувань',
            relations: ['accrual_documents']
          }
        ]
      },
      {
        id: 4,
        name: 'Модуль 4: Виплати',
        color: '#9C27B0',
        tables: [
          {
            name: 'payment_rules',
            displayName: 'Правила виплат',
            icon: '📐',
            fields: ['id', 'rule_code', 'rule_name', 'payment_method', 'is_active'],
            description: 'individual, grouped, bank_statement',
            relations: ['payment_documents']
          },
          {
            name: 'payment_documents',
            displayName: 'Платіжні документи',
            icon: '💳',
            fields: ['id', 'document_number', 'period_id', 'payment_rule_id', 'status', 'created_at'],
            description: 'Документи на виплату ЗП',
            relations: ['payment_rules', 'payment_items', 'bank_statements']
          },
          {
            name: 'payment_items',
            displayName: 'Позиції виплат',
            icon: '💵',
            fields: ['id', 'payment_document_id', 'employee_id', 'amount', 'payment_status'],
            description: 'Індивідуальні виплати працівникам',
            relations: ['payment_documents', 'employees']
          },
          {
            name: 'bank_statements',
            displayName: 'Банківські виписки',
            icon: '🏦',
            fields: ['id', 'statement_number', 'payment_document_id', 'bank_name', 'execution_date'],
            description: 'Підтвердження виплат від банку',
            relations: ['payment_documents']
          }
        ]
      }
    ]
  };

  const toggleModule = (moduleId) => {
    setExpandedModule(expandedModule === moduleId ? null : moduleId);
    setSelectedTable(null);
  };

  const selectTable = (table) => {
    setSelectedTable(selectedTable?.name === table.name ? null : table);
  };

  return (
    <div className="db-schema-view">
      <h2>🗄️ Структура бази даних</h2>
      <p className="schema-description">
        17 таблиць, організованих у 4 бізнес-модулі
      </p>

      <div className="modules-container">
        {dbSchema.modules.map(module => (
          <div key={module.id} className="module-card">
            <div
              className="module-header"
              style={{ borderLeftColor: module.color }}
              onClick={() => toggleModule(module.id)}
            >
              <h3>{module.name}</h3>
              <span className="module-count">{module.tables.length} таблиць</span>
              <span className="expand-icon">
                {expandedModule === module.id ? '▼' : '▶'}
              </span>
            </div>

            {expandedModule === module.id && (
              <div className="tables-list">
                {module.tables.map((table, idx) => (
                  <div key={idx} className="table-item">
                    <div
                      className="table-header"
                      onClick={() => selectTable(table)}
                    >
                      <span className="table-icon">{table.icon}</span>
                      <div className="table-info">
                        <strong>{table.displayName}</strong>
                        <code className="table-name">{table.name}</code>
                      </div>
                      <span className="expand-icon-sm">
                        {selectedTable?.name === table.name ? '−' : '+'}
                      </span>
                    </div>

                    {selectedTable?.name === table.name && (
                      <div className="table-details">
                        <p className="table-description">{table.description}</p>

                        <div className="table-section">
                          <h4>📋 Поля ({table.fields.length})</h4>
                          <ul className="fields-list">
                            {table.fields.map((field, i) => (
                              <li key={i}><code>{field}</code></li>
                            ))}
                          </ul>
                        </div>

                        {table.relations.length > 0 && (
                          <div className="table-section">
                            <h4>🔗 Зв'язки ({table.relations.length})</h4>
                            <ul className="relations-list">
                              {table.relations.map((rel, i) => (
                                <li key={i}>→ <code>{rel}</code></li>
                              ))}
                            </ul>
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>

      <div className="schema-legend">
        <h3>Легенда</h3>
        <ul>
          <li>🏢 Структура та персонал</li>
          <li>📊 Облік робочого часу</li>
          <li>💰 Розрахунки та нарахування</li>
          <li>💳 Виплати та банківські операції</li>
        </ul>
      </div>
    </div>
  );
}

export default App;
