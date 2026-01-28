-- 004_seed_employees.sql
-- Seed 10 fictional employees

PRAGMA foreign_keys = ON;

INSERT INTO employees (code, full_name, tax_id, hired_at, fired_at)
VALUES
  ('EMP001', 'Alex Storm', '1000000001', '2023-02-15', NULL),
  ('EMP002', 'Mira Vale', '1000000002', '2022-11-01', NULL),
  ('EMP003', 'Oren Pike', '1000000003', '2021-06-10', NULL),
  ('EMP004', 'Lina Frost', '1000000004', '2020-04-20', NULL),
  ('EMP005', 'Dara Bloom', '1000000005', '2019-09-05', NULL),
  ('EMP006', 'Ilan West', '1000000006', '2023-07-03', NULL),
  ('EMP007', 'Rhea Stone', '1000000007', '2022-01-17', NULL),
  ('EMP008', 'Niko Reed', '1000000008', '2021-12-08', NULL),
  ('EMP009', 'Tara Quinn', '1000000009', '2020-03-12', NULL),
  ('EMP010', 'Zane Brook', '1000000010', '2018-08-27', NULL);
