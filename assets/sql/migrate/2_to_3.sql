-- ============================================================
-- MIGRATION: dari schema awal (hanya projects) ke schema lengkap
-- Jalankan ini jika database sudah ada sebelumnya
-- ============================================================

-- Langkah 1: tambah kolom description ke projects jika belum ada
-- (SQLite tidak punya IF NOT EXISTS untuk ADD COLUMN, pakai try-catch di aplikasi,
--  atau gunakan blok PRAGMA berikut sebagai pengecekan manual)

-- Cek dulu struktur tabel projects, lalu jalankan baris berikut
-- hanya jika kolom 'description' belum ada:

CREATE TABLE projects_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  description TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO projects_new (id, name)
SELECT id, name FROM projects;

DROP TABLE projects;

ALTER TABLE projects_new RENAME TO projects;

-- ============================================================
-- Langkah 2: buat tabel members
-- ============================================================
CREATE TABLE IF NOT EXISTS members (
  id         INTEGER  PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER  NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name       TEXT     NOT NULL,
  phone      TEXT,
  note       TEXT,
  is_active  INTEGER  DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Langkah 3: buat tabel savings
-- ============================================================
CREATE TABLE IF NOT EXISTS savings (
  id               INTEGER  PRIMARY KEY AUTOINCREMENT,
  project_id       INTEGER  NOT NULL REFERENCES projects(id)  ON DELETE CASCADE,
  member_id        INTEGER  NOT NULL REFERENCES members(id)   ON DELETE CASCADE,
  amount           REAL     NOT NULL CHECK(amount > 0),
  type             TEXT     NOT NULL DEFAULT 'deposit'
                            CHECK(type IN ('deposit', 'withdrawal')),
  note             TEXT,
  transaction_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Langkah 4: buat tabel loans
-- ============================================================
CREATE TABLE IF NOT EXISTS loans (
  id            INTEGER  PRIMARY KEY AUTOINCREMENT,
  project_id    INTEGER  NOT NULL REFERENCES projects(id)  ON DELETE CASCADE,
  member_id     INTEGER  NOT NULL REFERENCES members(id)   ON DELETE CASCADE,
  amount        REAL     NOT NULL CHECK(amount > 0),
  interest_rate REAL     DEFAULT 0,
  total_amount  REAL     NOT NULL,
  paid_amount   REAL     DEFAULT 0,
  status        TEXT     NOT NULL DEFAULT 'active'
                         CHECK(status IN ('active', 'paid', 'overdue')),
  due_date      DATETIME,
  note          TEXT,
  loan_date     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Langkah 5: buat tabel loan_payments
-- ============================================================
CREATE TABLE IF NOT EXISTS loan_payments (
  id           INTEGER  PRIMARY KEY AUTOINCREMENT,
  loan_id      INTEGER  NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
  amount       REAL     NOT NULL CHECK(amount > 0),
  note         TEXT,
  payment_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Langkah 6: buat semua trigger
-- ============================================================
CREATE TRIGGER IF NOT EXISTS trg_projects_updated
  AFTER UPDATE ON projects FOR EACH ROW
  BEGIN UPDATE projects SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_members_updated
  AFTER UPDATE ON members FOR EACH ROW
  BEGIN UPDATE members SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_savings_updated
  AFTER UPDATE ON savings FOR EACH ROW
  BEGIN UPDATE savings SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_loans_updated
  AFTER UPDATE ON loans FOR EACH ROW
  BEGIN UPDATE loans SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_loan_payments_updated
  AFTER UPDATE ON loan_payments FOR EACH ROW
  BEGIN UPDATE loan_payments SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_loan_payments_after_insert
  AFTER INSERT ON loan_payments FOR EACH ROW
  BEGIN
    UPDATE loans
    SET
      paid_amount = (
        SELECT COALESCE(SUM(amount), 0)
        FROM loan_payments
        WHERE loan_id = NEW.loan_id
      ),
      status = CASE
        WHEN (
          SELECT COALESCE(SUM(amount), 0)
          FROM loan_payments
          WHERE loan_id = NEW.loan_id
        ) >= total_amount THEN 'paid'
        ELSE status
      END,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.loan_id;
  END;

-- ============================================================
-- Langkah 7: buat semua VIEW
-- ============================================================
CREATE VIEW IF NOT EXISTS v_member_savings AS
SELECT
  p.id           AS project_id,
  p.name         AS project_name,
  m.id           AS member_id,
  m.name         AS member_name,
  COALESCE(SUM(CASE WHEN s.type = 'deposit'    THEN s.amount ELSE 0 END), 0) AS total_deposit,
  COALESCE(SUM(CASE WHEN s.type = 'withdrawal' THEN s.amount ELSE 0 END), 0) AS total_withdrawal,
  COALESCE(SUM(CASE WHEN s.type = 'deposit'    THEN s.amount ELSE 0 END), 0)
  - COALESCE(SUM(CASE WHEN s.type = 'withdrawal' THEN s.amount ELSE 0 END), 0) AS net_savings
FROM projects p
JOIN members  m ON m.project_id = p.id
LEFT JOIN savings s ON s.member_id = m.id
GROUP BY p.id, m.id;

CREATE VIEW IF NOT EXISTS v_member_loans AS
SELECT
  p.id               AS project_id,
  p.name             AS project_name,
  m.id               AS member_id,
  m.name             AS member_name,
  COUNT(l.id)        AS total_loans,
  COALESCE(SUM(l.total_amount),  0) AS total_pinjam,
  COALESCE(SUM(l.paid_amount),   0) AS total_dibayar,
  COALESCE(SUM(l.total_amount - l.paid_amount), 0) AS sisa_hutang,
  COUNT(CASE WHEN l.status = 'active'  THEN 1 END) AS pinjaman_aktif,
  COUNT(CASE WHEN l.status = 'paid'    THEN 1 END) AS pinjaman_lunas,
  COUNT(CASE WHEN l.status = 'overdue' THEN 1 END) AS pinjaman_overdue
FROM projects p
JOIN members  m ON m.project_id = p.id
LEFT JOIN loans l ON l.member_id = m.id
GROUP BY p.id, m.id;

CREATE VIEW IF NOT EXISTS v_project_cashflow AS
SELECT
  p.id   AS project_id,
  p.name AS project_name,
  COALESCE(SUM(CASE WHEN s.type = 'deposit'    THEN s.amount ELSE 0 END), 0) AS total_setoran,
  COALESCE(SUM(CASE WHEN s.type = 'withdrawal' THEN s.amount ELSE 0 END), 0) AS total_penarikan,
  COALESCE((SELECT SUM(amount) FROM loans l WHERE l.project_id = p.id), 0) AS total_dipinjam,
  COALESCE((
    SELECT SUM(lp.amount)
    FROM loan_payments lp
    JOIN loans l ON l.id = lp.loan_id
    WHERE l.project_id = p.id
  ), 0) AS total_kembali,
  COALESCE((
    SELECT SUM(l.total_amount - l.paid_amount)
    FROM loans l
    WHERE l.project_id = p.id AND l.status != 'paid'
  ), 0) AS dana_dipinjam_aktif,
  (
    COALESCE(SUM(CASE WHEN s.type = 'deposit'    THEN s.amount ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN s.type = 'withdrawal' THEN s.amount ELSE 0 END), 0)
    - COALESCE((SELECT SUM(amount) FROM loans l WHERE l.project_id = p.id), 0)
    + COALESCE((
        SELECT SUM(lp.amount)
        FROM loan_payments lp
        JOIN loans l ON l.id = lp.loan_id
        WHERE l.project_id = p.id
      ), 0)
  ) AS dana_di_tangan
FROM projects p
LEFT JOIN savings s ON s.project_id = p.id
GROUP BY p.id;

-- ============================================================
-- Selesai. Migration berhasil dijalankan.
-- ============================================================
