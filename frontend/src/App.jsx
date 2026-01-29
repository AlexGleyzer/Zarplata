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
  const [view, setView] = useState('command');

  const parseCommand = (text) => {
    const words = text.toLowerCase().trim().split(/\s+/);
    const parsed = {
      action: null,
      entity: null,
      period: null,
      scope: null,
      scopeValue: null
    };

    if (words.includes('створити') || words.includes('create')) {
      parsed.action = 'create';
    }
    if (words.includes('розрахувати') || words.includes('calculate')) {
      parsed.action = 'calculate';
    }

    if (words.includes('період') || words.includes('period')) {
      parsed.entity = 'period';
    }

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
      
      const newChips = [];
      if (parsed.action) newChips.push(createChip('Дія', parsed.action));
      if (parsed.entity) newChips.push(createChip('Сутність', parsed.entity));
      if (parsed.period) newChips.push(createChip('Період', parsed.periodName));
      
      setChips(newChips);

      if (parsed.action === 'create' && parsed.entity === 'period') {
        const response = await axios.post(`${API_URL}/periods/`, {
          period_code: parsed.period || '2024-01',
          period_name: parsed.periodName || 'Період',
          start_date: `${parsed.period || '2024-01'}-01`,
          end_date: `${parsed.period || '2024-01'}-31`,
          period_type: 'monthly'
        });

        setResult({
          type: 'success',
          message: `Період створено успішно`,
          data: response.data
        });
      } else if (parsed.action === 'calculate' && parsed.period) {
        // Знайти period_id по коду
        const periodsResponse = await axios.get(`${API_URL}/periods/`);
        const period = periodsResponse.data.items.find(p => p.period_code === parsed.period);
        
        if (!period) {
          throw new Error(`Період ${parsed.periodName} не знайдено. Спочатку створіть період.`);
        }

        const calcResponse = await axios.post(`${API_URL}/calculations/run`, {
          period_id: period.id,
          template_code: 'MONTHLY_SALARY'
        });

        setResult({
          type: 'success',
          message: `Розрахунок виконано успішно!`,
          data: calcResponse.data
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
              Приклади: 
              <br/>• "створити період січень"
              <br/>• "розрахувати січень"
            </p>
            
            <form onSubmit={handleCommandSubmit}>
              <div className="input-container">
                <input
                  type="text"
                  value={command}
                  onChange={(e) => setCommand(e.target.value)}
                  placeholder="створити період... або розрахувати..."
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

        {view === 'employees' && <EmployeesView apiUrl={API_URL} />}
        {view === 'periods' && <PeriodsView apiUrl={API_URL} />}
        {view === 'calculations' && <CalculationsView apiUrl={API_URL} />}
      </main>
    </div>
  );
}

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

  if (loading) return <div className="loading">Завантаження...</div>;

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

  if (loading) return <div className="loading">Завантаження...</div>;

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

function CalculationsView({ apiUrl }) {
  const [calculations, setCalculations] = useState([]);
  const [selectedCalc, setSelectedCalc] = useState(null);
  const [loading, setLoading] = useState(true);

  React.useEffect(() => {
    // Отримати всі періоди з документами нарахувань
    axios.get(`${apiUrl}/periods/`)
      .then(response => {
        const periodsWithCalcs = response.data.items.filter(p => 
          p.accrual_documents && p.accrual_documents.length > 0
        );
        setCalculations(periodsWithCalcs);
        setLoading(false);
      })
      .catch(err => {
        console.error(err);
        setLoading(false);
      });
  }, [apiUrl]);

  const viewCalculation = async (period) => {
    if (!period.accrual_documents || period.accrual_documents.length === 0) return;
    
    try {
      const docId = period.accrual_documents[0].id;
      const response = await axios.get(`${apiUrl}/calculations/${docId}`);
      setSelectedCalc(response.data);
    } catch (err) {
      console.error(err);
    }
  };

  if (loading) return <div className="loading">Завантаження...</div>;

  return (
    <div className="data-view">
      <h2>Розрахунки Зарплати</h2>
      
      {calculations.length === 0 ? (
        <p>Розрахунків ще немає. Виконайте команду "розрахувати січень" щоб створити перший розрахунок.</p>
      ) : (
        <>
          <h3>Періоди з розрахунками:</h3>
          <table>
            <thead>
              <tr>
                <th>Період</th>
                <th>Назва</th>
                <th>Документів</th>
                <th>Дії</th>
              </tr>
            </thead>
            <tbody>
              {calculations.map(period => (
                <tr key={period.id}>
                  <td>{period.period_code}</td>
                  <td>{period.period_name}</td>
                  <td>{period.accrual_documents?.length || 0}</td>
                  <td>
                    <button 
                      onClick={() => viewCalculation(period)}
                      className="view-button"
                    >
                      Переглянути
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}

      {selectedCalc && (
        <div className="calculation-details">
          <h3>Деталі Розрахунку</h3>
          <div className="calc-header">
            <p><strong>Документ:</strong> {selectedCalc.document_number}</p>
            <p><strong>Період:</strong> {selectedCalc.period.name}</p>
            <p><strong>Шаблон:</strong> {selectedCalc.template.name}</p>
            <p><strong>Статус:</strong> <span className={`status ${selectedCalc.status}`}>{selectedCalc.status}</span></p>
          </div>

          <h4>Результати по працівниках:</h4>
          <table>
            <thead>
              <tr>
                <th>Працівник</th>
                <th>Табельний</th>
                <th>Нарахування</th>
                <th>Сума</th>
                <th>До виплати</th>
              </tr>
            </thead>
            <tbody>
              {selectedCalc.employees.map(emp => (
                <tr key={emp.employee.id}>
                  <td>{emp.employee.name}</td>
                  <td>{emp.employee.personnel_number}</td>
                  <td>
                    {emp.results.map(r => (
                      <div key={r.rule_code} className="calculation-line">
                        <span className="rule-name">{r.rule_name}:</span>
                        <span className="rule-amount">{r.amount.toFixed(2)} грн</span>
                      </div>
                    ))}
                  </td>
                  <td>
                    {emp.results.map(r => (
                      <div key={r.rule_code} className="amount-line">
                        {r.amount > 0 ? '+' : ''}{r.amount.toFixed(2)}
                      </div>
                    ))}
                  </td>
                  <td>
                    <strong className={emp.total >= 0 ? 'positive' : 'negative'}>
                      {emp.total.toFixed(2)} грн
                    </strong>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          <div className="calc-summary">
            <h4>Загальна Сума:</h4>
            <p className="total-amount">
              {selectedCalc.employees.reduce((sum, emp) => sum + emp.total, 0).toFixed(2)} грн
            </p>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
