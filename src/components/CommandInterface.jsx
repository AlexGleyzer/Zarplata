import { useState, useRef, useEffect } from 'react';

/**
 * Командний інтерфейс з динамічними чіпами
 * Кожен крок команди представлений як чіп з dropdown
 */

// Структура команд (зчитується з БД, тут для прикладу)
const COMMAND_STRUCTURE = {
  action: {
    label: 'Дія',
    options: [
      { id: 'calculate', label: 'Нарахувати', icon: '💰', next: 'calc_type' },
      { id: 'create_period', label: 'Створити період', icon: '📅', next: 'period_type' },
      { id: 'create_payment', label: 'Виплатити', icon: '💳', next: 'scope' },
      { id: 'create_timesheet', label: 'Табель', icon: '⏰', next: 'scope' },
      { id: 'view_report', label: 'Звіт', icon: '📊', next: 'report_type' },
    ]
  },
  calc_type: {
    label: 'Що нарахувати',
    options: [
      { id: 'salary', label: 'Зарплату', icon: '💵', next: 'scope' },
      { id: 'bonus', label: 'Премію', icon: '🎁', next: 'bonus_type' },
      { id: 'allowance', label: 'Надбавку', icon: '➕', next: 'scope' },
      { id: 'vacation', label: 'Відпускні', icon: '🏖️', next: 'scope' },
      { id: 'sick', label: 'Лікарняні', icon: '🏥', next: 'scope' },
    ]
  },
  bonus_type: {
    label: 'Тип премії',
    options: [
      { id: 'monthly', label: 'Місячна премія', next: 'scope' },
      { id: 'quarterly', label: 'Квартальна премія', next: 'scope' },
      { id: 'yearly', label: 'Річна премія', next: 'scope' },
      { id: 'onetime', label: 'Разова премія', next: 'scope' },
      { id: 'project', label: 'Проєктна премія', next: 'scope' },
    ]
  },
  scope: {
    label: 'Для кого',
    options: [
      { id: 'enterprise', label: 'Все підприємство', icon: '🏢', next: 'amount', count: 67 },
      { id: 'department', label: 'Підрозділ', icon: '🏛️', next: 'select_department' },
      { id: 'position', label: 'Посада', icon: '💼', next: 'select_position' },
      { id: 'category', label: 'Категорія', icon: '👥', next: 'select_category' },
      { id: 'employee', label: 'Людина', icon: '👤', next: 'select_employee' },
    ]
  },
  select_department: {
    label: 'Підрозділ',
    type: 'dynamic',
    source: 'departments',
    next: 'amount'
  },
  select_employee: {
    label: 'Працівник',
    type: 'search',
    source: 'employees',
    next: 'amount'
  },
  amount: {
    label: 'Сума',
    type: 'input',
    inputType: 'number',
    placeholder: 'Введіть суму',
    next: 'confirm'
  },
  confirm: {
    label: 'Виконати',
    type: 'final'
  }
};

// Тестові дані підрозділів
const DEPARTMENTS = [
  { id: 'all', label: 'Весь підрозділ', count: 12, isWhole: true },
  { id: 1, label: 'Адміністрація', count: 8 },
  { id: 2, label: 'Фінансовий департамент', count: 12, children: [
    { id: 6, label: 'Бухгалтерія', count: 5 },
    { id: 7, label: 'Планово-економічний', count: 7 },
  ]},
  { id: 3, label: 'IT-департамент', count: 15, children: [
    { id: 8, label: 'Розробка', count: 8 },
    { id: 9, label: 'Тестування', count: 4 },
    { id: 10, label: 'DevOps', count: 2 },
    { id: 11, label: 'Підтримка', count: 1 },
  ]},
  { id: 4, label: 'Виробництво', count: 30, children: [
    { id: 12, label: 'Цех №1', count: 15 },
    { id: 13, label: 'Цех №2', count: 12 },
    { id: 14, label: 'Контроль якості', count: 3 },
  ]},
  { id: 5, label: 'Продажі', count: 10 },
];

// Тестові дані працівників
const EMPLOYEES = [
  { id: 1, name: 'Петренко Іван Миколайович', position: 'Директор', department: 'Адміністрація', salary: 120000, tab: '0001' },
  { id: 2, name: 'Коваленко Олена Петрівна', position: 'Головний бухгалтер', department: 'Бухгалтерія', salary: 65000, tab: '0002' },
  { id: 3, name: 'Шевченко Андрій Васильович', position: 'Бухгалтер', department: 'Бухгалтерія', salary: 35000, tab: '0003' },
  { id: 6, name: 'Ткаченко Наталія Ігорівна', position: 'Senior Developer', department: 'Розробка', salary: 95000, tab: '0006' },
  { id: 7, name: 'Кравченко Дмитро Олегович', position: 'Middle Developer', department: 'Розробка', salary: 60000, tab: '0007' },
  { id: 8, name: 'Іваненко Тетяна Андріївна', position: 'Junior Developer', department: 'Розробка', salary: 30000, tab: '0008' },
  { id: 9, name: 'Сидоренко Максим Юрійович', position: 'QA Engineer', department: 'Тестування', salary: 50000, tab: '0009' },
  { id: 10, name: 'Павленко Ольга Миколаївна', position: 'DevOps Engineer', department: 'DevOps', salary: 75000, tab: '0010' },
];

// Стилі
const styles = {
  container: {
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px',
    background: '#1a1a2e',
    minHeight: '100vh',
    color: '#eee',
  },
  header: {
    fontSize: '24px',
    fontWeight: 'bold',
    marginBottom: '20px',
    color: '#fff',
  },
  commandLine: {
    display: 'flex',
    flexWrap: 'wrap',
    alignItems: 'center',
    gap: '8px',
    padding: '16px',
    background: '#16213e',
    borderRadius: '12px',
    minHeight: '60px',
    border: '2px solid #0f3460',
  },
  chip: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '6px',
    padding: '8px 14px',
    borderRadius: '20px',
    fontSize: '14px',
    fontWeight: '500',
    cursor: 'pointer',
    transition: 'all 0.2s',
    position: 'relative',
  },
  chipSelected: {
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    color: '#fff',
    boxShadow: '0 2px 8px rgba(102, 126, 234, 0.4)',
  },
  chipPending: {
    background: '#2d3748',
    color: '#a0aec0',
    border: '2px dashed #4a5568',
  },
  chipDelete: {
    marginLeft: '4px',
    opacity: 0,
    transition: 'opacity 0.2s',
    cursor: 'pointer',
    fontSize: '12px',
  },
  dropdown: {
    position: 'absolute',
    top: '100%',
    left: '0',
    marginTop: '8px',
    background: '#1e293b',
    borderRadius: '12px',
    boxShadow: '0 10px 40px rgba(0,0,0,0.5)',
    minWidth: '280px',
    maxHeight: '400px',
    overflowY: 'auto',
    zIndex: 1000,
    border: '1px solid #334155',
  },
  dropdownItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    padding: '12px 16px',
    cursor: 'pointer',
    transition: 'background 0.15s',
    borderBottom: '1px solid #334155',
  },
  dropdownItemHover: {
    background: '#334155',
  },
  dropdownItemIcon: {
    fontSize: '18px',
  },
  dropdownItemLabel: {
    flex: 1,
    fontSize: '14px',
  },
  dropdownItemCount: {
    fontSize: '12px',
    color: '#94a3b8',
    background: '#475569',
    padding: '2px 8px',
    borderRadius: '10px',
  },
  searchInput: {
    width: '100%',
    padding: '12px 16px',
    border: 'none',
    borderBottom: '1px solid #334155',
    background: '#0f172a',
    color: '#fff',
    fontSize: '14px',
    outline: 'none',
  },
  amountInput: {
    width: '120px',
    padding: '8px 12px',
    border: '2px solid #4a5568',
    borderRadius: '8px',
    background: '#1e293b',
    color: '#fff',
    fontSize: '14px',
    outline: 'none',
  },
  executeBtn: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '6px',
    padding: '10px 20px',
    background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
    color: '#fff',
    border: 'none',
    borderRadius: '20px',
    fontSize: '14px',
    fontWeight: '600',
    cursor: 'pointer',
    transition: 'transform 0.2s, box-shadow 0.2s',
  },
  result: {
    marginTop: '20px',
    padding: '20px',
    background: '#16213e',
    borderRadius: '12px',
    border: '2px solid #0f3460',
  },
  resultSuccess: {
    borderColor: '#10b981',
  },
  employeeCard: {
    display: 'flex',
    flexDirection: 'column',
    gap: '4px',
    padding: '12px 16px',
    cursor: 'pointer',
    transition: 'background 0.15s',
    borderBottom: '1px solid #334155',
  },
  employeeName: {
    fontWeight: '500',
    fontSize: '14px',
  },
  employeeDetails: {
    fontSize: '12px',
    color: '#94a3b8',
    display: 'flex',
    gap: '12px',
  },
  quickActions: {
    display: 'flex',
    gap: '10px',
    marginTop: '20px',
    flexWrap: 'wrap',
  },
  quickBtn: {
    padding: '10px 16px',
    background: '#2d3748',
    color: '#e2e8f0',
    border: '1px solid #4a5568',
    borderRadius: '8px',
    fontSize: '13px',
    cursor: 'pointer',
    transition: 'all 0.2s',
  },
};

export default function CommandInterface() {
  const [chips, setChips] = useState([]);
  const [activeStep, setActiveStep] = useState('action');
  const [openDropdown, setOpenDropdown] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [amountValue, setAmountValue] = useState('');
  const [hoveredItem, setHoveredItem] = useState(null);
  const [result, setResult] = useState(null);
  const [selectedDept, setSelectedDept] = useState(null);
  const dropdownRef = useRef(null);

  // Закриття dropdown при кліку зовні
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setOpenDropdown(null);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Отримання конфігурації поточного кроку
  const getStepConfig = (stepKey) => COMMAND_STRUCTURE[stepKey];

  // Вибір опції
  const selectOption = (stepKey, option) => {
    const newChips = [...chips, { step: stepKey, ...option }];
    setChips(newChips);
    setOpenDropdown(null);
    setSearchQuery('');

    if (option.next) {
      setActiveStep(option.next);

      // Автоматично відкриваємо dropdown для наступного кроку
      const nextConfig = getStepConfig(option.next);
      if (nextConfig && nextConfig.type !== 'input' && nextConfig.type !== 'final') {
        setTimeout(() => setOpenDropdown(option.next), 100);
      }
    } else {
      setActiveStep(null);
    }
  };

  // Вибір підрозділу (з підтримкою вкладеності)
  const selectDepartment = (dept) => {
    if (dept.children && !dept.isWhole) {
      setSelectedDept(dept);
      return;
    }

    selectOption('select_department', {
      id: dept.id,
      label: dept.label,
      icon: '🏛️',
      count: dept.count,
      next: 'amount'
    });
    setSelectedDept(null);
  };

  // Вибір працівника
  const selectEmployee = (emp) => {
    selectOption('select_employee', {
      id: emp.id,
      label: emp.name,
      icon: '👤',
      details: emp,
      next: 'amount'
    });
  };

  // Видалення чіпа
  const removeChip = (index) => {
    const newChips = chips.slice(0, index);
    setChips(newChips);

    if (newChips.length === 0) {
      setActiveStep('action');
    } else {
      const lastChip = newChips[newChips.length - 1];
      const option = COMMAND_STRUCTURE[lastChip.step]?.options?.find(o => o.id === lastChip.id);
      if (option?.next) {
        setActiveStep(option.next);
      }
    }
    setResult(null);
  };

  // Введення суми
  const handleAmountSubmit = () => {
    if (amountValue) {
      const newChips = [...chips, {
        step: 'amount',
        id: 'amount',
        label: `${Number(amountValue).toLocaleString()} грн`,
        value: amountValue,
        next: 'confirm'
      }];
      setChips(newChips);
      setActiveStep('confirm');
      setAmountValue('');
    }
  };

  // Виконання команди
  const executeCommand = () => {
    // Збираємо дані з чіпів
    const commandData = {};
    chips.forEach(chip => {
      commandData[chip.step] = {
        id: chip.id,
        label: chip.label,
        value: chip.value || chip.id,
        details: chip.details
      };
    });

    // Симуляція виконання
    setResult({
      success: true,
      documentNumber: `ПРЕМІЯ-2024-${String(Math.floor(Math.random() * 1000)).padStart(3, '0')}`,
      message: 'Документ створено успішно!',
      data: commandData
    });
  };

  // Швидка дія
  const quickAction = (action) => {
    setChips([]);
    setActiveStep('action');
    setResult(null);

    if (action === 'bonus_it') {
      // Приклад: Премія IT-відділу
      setChips([
        { step: 'action', id: 'calculate', label: 'Нарахувати', icon: '💰', next: 'calc_type' },
        { step: 'calc_type', id: 'bonus', label: 'Премію', icon: '🎁', next: 'bonus_type' },
        { step: 'bonus_type', id: 'onetime', label: 'Разова премія', next: 'scope' },
      ]);
      setActiveStep('scope');
    }
  };

  // Фільтрація працівників
  const filteredEmployees = EMPLOYEES.filter(emp =>
    emp.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    emp.tab.includes(searchQuery) ||
    emp.position.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // Рендер dropdown для підрозділів
  const renderDepartmentDropdown = () => {
    const depts = selectedDept?.children || DEPARTMENTS;
    const showBack = selectedDept !== null;

    return (
      <div style={styles.dropdown} ref={dropdownRef}>
        {showBack && (
          <div
            style={{...styles.dropdownItem, color: '#94a3b8'}}
            onClick={() => setSelectedDept(null)}
            onMouseEnter={() => setHoveredItem('back')}
            onMouseLeave={() => setHoveredItem(null)}
          >
            ← Назад
          </div>
        )}
        {selectedDept && (
          <div
            style={{
              ...styles.dropdownItem,
              ...(hoveredItem === 'whole' ? styles.dropdownItemHover : {}),
              background: '#1e3a5f'
            }}
            onClick={() => selectDepartment({ ...selectedDept, isWhole: true })}
            onMouseEnter={() => setHoveredItem('whole')}
            onMouseLeave={() => setHoveredItem(null)}
          >
            <span style={styles.dropdownItemIcon}>✓</span>
            <span style={styles.dropdownItemLabel}>Весь підрозділ "{selectedDept.label}"</span>
            <span style={styles.dropdownItemCount}>{selectedDept.count}</span>
          </div>
        )}
        {depts.filter(d => !d.isWhole).map(dept => (
          <div
            key={dept.id}
            style={{
              ...styles.dropdownItem,
              ...(hoveredItem === dept.id ? styles.dropdownItemHover : {})
            }}
            onClick={() => selectDepartment(dept)}
            onMouseEnter={() => setHoveredItem(dept.id)}
            onMouseLeave={() => setHoveredItem(null)}
          >
            <span style={styles.dropdownItemIcon}>{dept.children ? '📁' : '🏛️'}</span>
            <span style={styles.dropdownItemLabel}>{dept.label}</span>
            <span style={styles.dropdownItemCount}>{dept.count}</span>
            {dept.children && <span style={{color: '#64748b'}}>▶</span>}
          </div>
        ))}
      </div>
    );
  };

  // Рендер dropdown для працівників
  const renderEmployeeDropdown = () => (
    <div style={styles.dropdown} ref={dropdownRef}>
      <input
        type="text"
        style={styles.searchInput}
        placeholder="Пошук за ПІБ, таб.номером..."
        value={searchQuery}
        onChange={(e) => setSearchQuery(e.target.value)}
        autoFocus
      />
      {filteredEmployees.map(emp => (
        <div
          key={emp.id}
          style={{
            ...styles.employeeCard,
            ...(hoveredItem === emp.id ? styles.dropdownItemHover : {})
          }}
          onClick={() => selectEmployee(emp)}
          onMouseEnter={() => setHoveredItem(emp.id)}
          onMouseLeave={() => setHoveredItem(null)}
        >
          <div style={styles.employeeName}>👤 {emp.name}</div>
          <div style={styles.employeeDetails}>
            <span>📋 {emp.tab}</span>
            <span>💼 {emp.position}</span>
            <span>🏛️ {emp.department}</span>
          </div>
        </div>
      ))}
    </div>
  );

  // Рендер стандартного dropdown
  const renderDropdown = (stepKey) => {
    const config = getStepConfig(stepKey);
    if (!config?.options) return null;

    return (
      <div style={styles.dropdown} ref={dropdownRef}>
        {config.options.map(option => (
          <div
            key={option.id}
            style={{
              ...styles.dropdownItem,
              ...(hoveredItem === option.id ? styles.dropdownItemHover : {})
            }}
            onClick={() => selectOption(stepKey, option)}
            onMouseEnter={() => setHoveredItem(option.id)}
            onMouseLeave={() => setHoveredItem(null)}
          >
            {option.icon && <span style={styles.dropdownItemIcon}>{option.icon}</span>}
            <span style={styles.dropdownItemLabel}>{option.label}</span>
            {option.count && <span style={styles.dropdownItemCount}>{option.count}</span>}
          </div>
        ))}
      </div>
    );
  };

  return (
    <div style={styles.container}>
      <div style={styles.header}>💬 Командний центр</div>

      {/* Командна стрічка з чіпами */}
      <div style={styles.commandLine}>
        {/* Обрані чіпи */}
        {chips.map((chip, index) => (
          <div
            key={index}
            style={{
              ...styles.chip,
              ...styles.chipSelected,
            }}
            onMouseEnter={(e) => e.currentTarget.querySelector('.delete-btn').style.opacity = 1}
            onMouseLeave={(e) => e.currentTarget.querySelector('.delete-btn').style.opacity = 0}
          >
            {chip.icon && <span>{chip.icon}</span>}
            <span>{chip.label}</span>
            <span
              className="delete-btn"
              style={styles.chipDelete}
              onClick={(e) => { e.stopPropagation(); removeChip(index); }}
            >
              ✕
            </span>
          </div>
        ))}

        {/* Поточний крок */}
        {activeStep && activeStep !== 'confirm' && (
          <div style={{ position: 'relative' }}>
            {getStepConfig(activeStep)?.type === 'input' ? (
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <input
                  type="number"
                  style={styles.amountInput}
                  placeholder="Сума"
                  value={amountValue}
                  onChange={(e) => setAmountValue(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && handleAmountSubmit()}
                  autoFocus
                />
                <span style={{ color: '#94a3b8' }}>грн</span>
              </div>
            ) : (
              <div
                style={{...styles.chip, ...styles.chipPending}}
                onClick={() => setOpenDropdown(openDropdown === activeStep ? null : activeStep)}
              >
                {getStepConfig(activeStep)?.label || activeStep}
                <span style={{ marginLeft: '4px' }}>▼</span>
              </div>
            )}

            {/* Dropdown */}
            {openDropdown === activeStep && (
              activeStep === 'select_department' ? renderDepartmentDropdown() :
              activeStep === 'select_employee' ? renderEmployeeDropdown() :
              renderDropdown(activeStep)
            )}
          </div>
        )}

        {/* Кнопка виконання */}
        {activeStep === 'confirm' && (
          <button
            style={styles.executeBtn}
            onClick={executeCommand}
          >
            ✓ Виконати
          </button>
        )}
      </div>

      {/* Швидкі дії */}
      <div style={styles.quickActions}>
        <span style={{ color: '#94a3b8', fontSize: '13px', marginRight: '8px' }}>Швидкі дії:</span>
        <button style={styles.quickBtn} onClick={() => quickAction('bonus_it')}>
          🎁 Премія IT
        </button>
        <button style={styles.quickBtn} onClick={() => { setChips([]); setActiveStep('action'); setResult(null); }}>
          🔄 Очистити
        </button>
      </div>

      {/* Результат */}
      {result && (
        <div style={{...styles.result, ...(result.success ? styles.resultSuccess : {})}}>
          <div style={{ fontSize: '18px', fontWeight: 'bold', marginBottom: '12px' }}>
            ✅ {result.message}
          </div>
          <div style={{ color: '#94a3b8' }}>
            Документ: <strong style={{ color: '#10b981' }}>{result.documentNumber}</strong>
          </div>
          <div style={{ marginTop: '12px', fontSize: '13px', color: '#64748b' }}>
            Команда: {chips.map(c => c.label).join(' → ')}
          </div>
        </div>
      )}
    </div>
  );
}
