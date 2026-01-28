-- Migration 004: Seed Employees
-- Test employees for MVP

INSERT INTO employees (employee_code, first_name, last_name, email, hire_date, status) VALUES
('EMP001', 'Alex', 'Storm', 'alex.storm@futura.io', '2023-01-15', 'active'),
('EMP002', 'Mira', 'Vale', 'mira.vale@futura.io', '2023-02-01', 'active'),
('EMP003', 'Oren', 'Pike', 'oren.pike@futura.io', '2023-03-10', 'active'),
('EMP004', 'Lina', 'Frost', 'lina.frost@futura.io', '2023-04-05', 'active'),
('EMP005', 'Dara', 'Bloom', 'dara.bloom@futura.io', '2023-05-20', 'active'),
('EMP006', 'Ilan', 'West', 'ilan.west@futura.io', '2023-06-15', 'active'),
('EMP007', 'Rhea', 'Stone', 'rhea.stone@futura.io', '2023-07-01', 'active'),
('EMP008', 'Niko', 'Reed', 'niko.reed@futura.io', '2023-08-10', 'active'),
('EMP009', 'Tara', 'Quinn', 'tara.quinn@futura.io', '2023-09-05', 'active'),
('EMP010', 'Zane', 'Brook', 'zane.brook@futura.io', '2023-10-20', 'active');
