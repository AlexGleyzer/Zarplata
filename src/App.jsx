import { useState, useEffect } from 'react';
import './styles/App.css';

function App() {
  const [appVersion, setAppVersion] = useState('');

  useEffect(() => {
    if (window.electronAPI) {
      window.electronAPI.getAppVersion().then(setAppVersion);
    }
  }, []);

  return (
    <div className="app">
      <header className="app-header">
        <h1>Zarplata</h1>
        <p className="subtitle">Система управління зарплатою</p>
      </header>

      <main className="app-main">
        <section className="welcome-section">
          <h2>Ласкаво просимо!</h2>
          <p>Ваш надійний помічник для обліку зарплати та управління персоналом.</p>
        </section>

        <section className="features-section">
          <div className="feature-card">
            <h3>Облік працівників</h3>
            <p>Управляйте даними про співробітників у зручному інтерфейсі.</p>
          </div>
          <div className="feature-card">
            <h3>Розрахунок зарплати</h3>
            <p>Автоматичний розрахунок заробітної плати та податків.</p>
          </div>
          <div className="feature-card">
            <h3>Звіти</h3>
            <p>Формуйте звіти та експортуйте дані у зручних форматах.</p>
          </div>
        </section>
      </main>

      <footer className="app-footer">
        {appVersion && <span>Версія {appVersion}</span>}
      </footer>
    </div>
  );
}

export default App;
