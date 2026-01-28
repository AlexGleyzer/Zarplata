import { Router } from 'express';
import { employeeQueries, workHoursQueries, payrollQueries } from './database.js';

export const router = Router();

// API для працівників
router.get('/employees', (req, res) => {
  try {
    const status = req.query.status || 'active';
    const employees = employeeQueries.getAll.all(status);
    res.json(employees);
  } catch (error) {
    res.status(500).json({ error: 'Помилка отримання працівників' });
  }
});

router.get('/employees/:id', (req, res) => {
  try {
    const employee = employeeQueries.getById.get(req.params.id);
    if (!employee) {
      return res.status(404).json({ error: 'Працівника не знайдено' });
    }
    res.json(employee);
  } catch (error) {
    res.status(500).json({ error: 'Помилка отримання працівника' });
  }
});

router.post('/employees', (req, res) => {
  try {
    const result = employeeQueries.create.run(req.body);
    res.status(201).json({ id: result.lastInsertRowid, ...req.body });
  } catch (error) {
    res.status(500).json({ error: 'Помилка створення працівника' });
  }
});

router.put('/employees/:id', (req, res) => {
  try {
    employeeQueries.update.run({ ...req.body, id: req.params.id });
    res.json({ id: req.params.id, ...req.body });
  } catch (error) {
    res.status(500).json({ error: 'Помилка оновлення працівника' });
  }
});

router.delete('/employees/:id', (req, res) => {
  try {
    employeeQueries.delete.run('inactive', req.params.id);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: 'Помилка видалення працівника' });
  }
});

// API для робочих годин
router.get('/work-hours/:employeeId', (req, res) => {
  try {
    const { start, end } = req.query;
    const hours = workHoursQueries.getByEmployee.all(
      req.params.employeeId,
      start || '2000-01-01',
      end || '2099-12-31'
    );
    res.json(hours);
  } catch (error) {
    res.status(500).json({ error: 'Помилка отримання робочих годин' });
  }
});

router.post('/work-hours', (req, res) => {
  try {
    const result = workHoursQueries.create.run(req.body);
    res.status(201).json({ id: result.lastInsertRowid, ...req.body });
  } catch (error) {
    res.status(500).json({ error: 'Помилка додавання робочих годин' });
  }
});

router.put('/work-hours/:id', (req, res) => {
  try {
    workHoursQueries.update.run({ ...req.body, id: req.params.id });
    res.json({ id: req.params.id, ...req.body });
  } catch (error) {
    res.status(500).json({ error: 'Помилка оновлення робочих годин' });
  }
});

// API для розрахунку зарплати
router.get('/payroll', (req, res) => {
  try {
    const { start, end } = req.query;
    const payrolls = payrollQueries.getAll.all(
      start || '2000-01-01',
      end || '2099-12-31'
    );
    res.json(payrolls);
  } catch (error) {
    res.status(500).json({ error: 'Помилка отримання даних про зарплату' });
  }
});

router.get('/payroll/:employeeId', (req, res) => {
  try {
    const payrolls = payrollQueries.getByEmployee.all(req.params.employeeId);
    res.json(payrolls);
  } catch (error) {
    res.status(500).json({ error: 'Помилка отримання зарплати працівника' });
  }
});

router.post('/payroll', (req, res) => {
  try {
    const result = payrollQueries.create.run(req.body);
    res.status(201).json({ id: result.lastInsertRowid, ...req.body });
  } catch (error) {
    res.status(500).json({ error: 'Помилка створення запису про зарплату' });
  }
});

router.patch('/payroll/:id/status', (req, res) => {
  try {
    const { status, payment_date } = req.body;
    payrollQueries.updateStatus.run(status, payment_date || null, req.params.id);
    res.json({ id: req.params.id, status, payment_date });
  } catch (error) {
    res.status(500).json({ error: 'Помилка оновлення статусу зарплати' });
  }
});
