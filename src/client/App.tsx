import { useState } from 'react'
import './App.css'

function App() {
  const [activeTab, setActiveTab] = useState<'employees' | 'hours' | 'payroll'>('employees')

  return (
    <div className="app">
      <header className="header">
        <h1>💰 Zarplata</h1>
        <p>Система розрахунку зарплати</p>
      </header>

      <nav className="nav">
        <button
          className={activeTab === 'employees' ? 'active' : ''}
          onClick={() => setActiveTab('employees')}
        >
          👥 Працівники
        </button>
        <button
          className={activeTab === 'hours' ? 'active' : ''}
          onClick={() => setActiveTab('hours')}
        >
          ⏰ Робочі години
        </button>
        <button
          className={activeTab === 'payroll' ? 'active' : ''}
          onClick={() => setActiveTab('payroll')}
        >
          💵 Зарплата
        </button>
      </nav>

      <main className="content">
        {activeTab === 'employees' && (
          <div className="section">
            <h2>Працівники</h2>
            <p>Тут буде список працівників та форма додавання нових працівників.</p>
          </div>
        )}

        {activeTab === 'hours' && (
          <div className="section">
            <h2>Робочі години</h2>
            <p>Тут буде табель обліку робочого часу.</p>
          </div>
        )}

        {activeTab === 'payroll' && (
          <div className="section">
            <h2>Розрахунок зарплати</h2>
            <p>Тут буде розрахунок та виплата зарплати.</p>
          </div>
        )}
      </main>

      <footer className="footer">
        <p>Zarplata v1.0.0</p>
      </footer>
    </div>
  )
}

export default App
