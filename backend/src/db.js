import sqlite3 from 'sqlite3';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const dataDir = path.join(__dirname, '../data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

const dbPath = path.join(dataDir, 'chillers.db');
const db = new sqlite3.Database(dbPath);

// Helper wrapper for async query execution
export const query = (sql, params = []) => {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
};

export const run = (sql, params = []) => {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) reject(err);
      else resolve({ lastID: this.lastID, changes: this.changes });
    });
  });
};

// Default Column Definitions extracted from example dataset
const DEFAULT_COLUMNS = [
  { key_name: 'Branch', display_label: 'Branch', data_type: 'string', is_required: 0, is_active: 1, display_order: 1 },
  { key_name: 'Received Date', display_label: 'Received Date', data_type: 'date', is_required: 0, is_active: 1, display_order: 2 },
  { key_name: 'Chiller Type', display_label: 'Chiller Type', data_type: 'string', is_required: 0, is_active: 1, display_order: 3 },
  { key_name: 'Chiller Configuration', display_label: 'Chiller Configuration', data_type: 'string', is_required: 0, is_active: 1, display_order: 4 },
  { key_name: 'Chiller Code', display_label: 'Chiller Code', data_type: 'string', is_required: 1, is_active: 1, display_order: 5 },
  { key_name: 'Chiller Status', display_label: 'Chiller Status', data_type: 'string', is_required: 0, is_active: 1, display_order: 6 },
  { key_name: 'Condiiton', display_label: 'Condition', data_type: 'string', is_required: 0, is_active: 1, display_order: 7 },
  { key_name: 'Action Date', display_label: 'Action Date', data_type: 'date', is_required: 0, is_active: 1, display_order: 8 },
  { key_name: 'Serial Number', display_label: 'Serial Number', data_type: 'string', is_required: 0, is_active: 1, display_order: 9 },
  { key_name: 'Longitude', display_label: 'Longitude', data_type: 'coords', is_required: 1, is_active: 1, display_order: 10 },
  { key_name: 'Latitude', display_label: 'Latitude', data_type: 'coords', is_required: 1, is_active: 1, display_order: 11 },
  { key_name: 'Truck Code', display_label: 'Truck Code', data_type: 'string', is_required: 0, is_active: 1, display_order: 12 },
  { key_name: 'SR Name', display_label: 'SR Name', data_type: 'string', is_required: 0, is_active: 1, display_order: 13 },
  { key_name: 'SSV Name', display_label: 'SSV Name', data_type: 'string', is_required: 0, is_active: 1, display_order: 14 },
  { key_name: 'Customer Type', display_label: 'Customer Type', data_type: 'string', is_required: 1, is_active: 1, display_order: 15 },
  { key_name: 'Visit Day', display_label: 'Visit Day', data_type: 'string', is_required: 0, is_active: 1, display_order: 16 },
  { key_name: 'Customer Code', display_label: 'Customer Code', data_type: 'string', is_required: 0, is_active: 1, display_order: 17 },
  { key_name: 'Customer Name', display_label: 'Customer Name', data_type: 'string', is_required: 0, is_active: 1, display_order: 18 },
  { key_name: 'Customer Address', display_label: 'Customer Address', data_type: 'string', is_required: 0, is_active: 1, display_order: 19 },
  { key_name: 'Mobile Number', display_label: 'Mobile Number', data_type: 'string', is_required: 0, is_active: 1, display_order: 20 },
  { key_name: 'Jan 2026 Invoice', display_label: 'Jan 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 21 },
  { key_name: 'Feb 2026 Invoice', display_label: 'Feb 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 22 },
  { key_name: 'Mar 2026 Invoice', display_label: 'Mar 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 23 },
  { key_name: 'Apr 2026 Invoice', display_label: 'Apr 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 24 },
  { key_name: 'May 2026 Invoice', display_label: 'May 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 25 },
  { key_name: 'June 2026 Invoice', display_label: 'June 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 26 },
  { key_name: 'July 2026 Invoice', display_label: 'July 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 27 },
  { key_name: 'Aug 2026 Invoice', display_label: 'Aug 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 28 },
  { key_name: 'Sep 2026 Invoice', display_label: 'Sep 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 29 },
  { key_name: 'Oct 2026 Invoice', display_label: 'Oct 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 30 },
  { key_name: 'Nov 2026 Invoice', display_label: 'Nov 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 31 },
  { key_name: 'Dec 2026 Invoice', display_label: 'Dec 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 32 },
  { key_name: 'YTD', display_label: 'YTD', data_type: 'number', is_required: 0, is_active: 1, display_order: 33 },
  { key_name: 'Average / Month', display_label: 'Average / Month', data_type: 'number', is_required: 0, is_active: 1, display_order: 34 },
  { key_name: 'Month Ach. Status', display_label: 'Efficiency (Month Ach. Status)', data_type: 'string', is_required: 1, is_active: 1, display_order: 35 },
  { key_name: 'Notes', display_label: 'Notes', data_type: 'string', is_required: 0, is_active: 1, display_order: 36 }
];

export async function initDb() {
  await run(`
    CREATE TABLE IF NOT EXISTS column_definitions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      key_name TEXT UNIQUE NOT NULL,
      display_label TEXT NOT NULL,
      data_type TEXT NOT NULL DEFAULT 'string',
      is_required INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      display_order INTEGER NOT NULL DEFAULT 0
    )
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS upload_batches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      filename TEXT NOT NULL,
      uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      total_rows INTEGER NOT NULL,
      valid_rows INTEGER NOT NULL,
      invalid_rows INTEGER NOT NULL,
      bypassed_validation INTEGER NOT NULL DEFAULT 0
    )
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS chillers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      chiller_code TEXT UNIQUE,
      batch_id INTEGER,
      latitude REAL,
      longitude REAL,
      customer_type TEXT,
      efficiency TEXT,
      branch TEXT,
      chiller_type TEXT,
      chiller_status TEXT,
      condition TEXT,
      customer_name TEXT,
      raw_data_json TEXT NOT NULL,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (batch_id) REFERENCES upload_batches(id)
    )
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS chillers_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      batch_id INTEGER NOT NULL,
      chiller_code TEXT,
      latitude REAL,
      longitude REAL,
      customer_type TEXT,
      efficiency TEXT,
      branch TEXT,
      chiller_type TEXT,
      chiller_status TEXT,
      condition TEXT,
      customer_name TEXT,
      raw_data_json TEXT NOT NULL,
      snapshot_time DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (batch_id) REFERENCES upload_batches(id)
    )
  `);

  // Seed default columns if table is empty
  const existingCols = await query(`SELECT COUNT(*) as count FROM column_definitions`);
  if (existingCols[0].count === 0) {
    console.log('Seeding default column definitions...');
    for (const col of DEFAULT_COLUMNS) {
      await run(
        `INSERT OR IGNORE INTO column_definitions (key_name, display_label, data_type, is_required, is_active, display_order)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [col.key_name, col.display_label, col.data_type, col.is_required, col.is_active, col.display_order]
      );
    }
  }
}

export default db;
