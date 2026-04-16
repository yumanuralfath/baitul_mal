CREATE TABLE projects_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO projects_new (id, name)
SELECT id, name FROM projects;

DROP TABLE projects;

ALTER TABLE projects_new RENAME TO projects;
