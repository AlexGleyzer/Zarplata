import React, { useState } from 'react';
import axios from 'axios';
import './App.css';

const API_URL = 'http://localhost:8000/api/v1';
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

export default App;
