import express from 'express';
import cors from 'cors';
import { router } from './routes.js';

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// API роути
app.use('/api', router);

// Головна сторінка
app.get('/', (req, res) => {
  res.json({
    message: 'Zarplata API Server',
    version: '1.0.0',
    endpoints: {
      employees: '/api/employees',
      workHours: '/api/work-hours',
      payroll: '/api/payroll'
    }
  });
});

// Запуск сервера
app.listen(PORT, () => {
  console.log(`🚀 Сервер запущено на http://localhost:${PORT}`);
  console.log(`📊 API доступний на http://localhost:${PORT}/api`);
});
