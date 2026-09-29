import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// In-Memory fallback store for serverless environments (Vercel)
const memoryDb = {
  column_definitions: [],
  upload_batches: [],
  chillers: [],
  chillers_history: []
};

let dbInstance = null;
let useMemoryDb = false;

// If running on Vercel Serverless, use pure JS Memory Engine directly to prevent native binary conflicts
if (!process.env.VERCEL) {
  try {
    const sqlite3Module = await import('sqlite3');
    const sqlite3 = sqlite3Module.default;
    const dataDir = path.join(__dirname, '../data');
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    const dbPath = path.join(dataDir, 'chillers.db');
    dbInstance = new sqlite3.Database(dbPath);
  } catch (e) {
    console.warn('Native sqlite3 module not available, using in-memory database engine:', e.message);
    useMemoryDb = true;
  }
} else {
  useMemoryDb = true;
}

export const query = (sql, params = []) => {
  if (useMemoryDb || !dbInstance) {
    return queryMemoryDb(sql, params);
  }
  return new Promise((resolve, reject) => {
    dbInstance.all(sql, params, (err, rows) => {
      if (err) {
        queryMemoryDb(sql, params).then(resolve).catch(reject);
      } else {
        resolve(rows);
      }
    });
  });
};

export const run = (sql, params = []) => {
  if (useMemoryDb || !dbInstance) {
    return runMemoryDb(sql, params);
  }
  return new Promise((resolve, reject) => {
    dbInstance.run(sql, params, function (err) {
      if (err) {
        runMemoryDb(sql, params).then(resolve).catch(reject);
      } else {
        resolve({ lastID: this.lastID, changes: this.changes });
      }
    });
  });
};

// In-Memory Database Engine Implementation for Serverless Compatibility
async function queryMemoryDb(sql, params) {
  const cleanSql = sql.trim().toLowerCase();

  if (cleanSql.includes('from column_definitions')) {
    let cols = [...memoryDb.column_definitions];
    if (cleanSql.includes('is_active = 1')) {
      cols = cols.filter(c => c.is_active === 1);
    }
    cols.sort((a, b) => a.display_order - b.display_order);
    return cols;
  }

  if (cleanSql.includes('from upload_batches')) {
    if (cleanSql.includes('where id =')) {
      const id = params[0];
      return memoryDb.upload_batches.filter(b => b.id == id);
    }
    return [...memoryDb.upload_batches].sort((a, b) => b.id - a.id);
  }

  if (cleanSql.includes('from chillers_history')) {
    if (cleanSql.includes('where batch_id =')) {
      const batchId = params[0];
      return memoryDb.chillers_history.filter(h => h.batch_id == batchId);
    }
    return [...memoryDb.chillers_history];
  }

  if (cleanSql.includes('from chillers')) {
    let rows = [...memoryDb.chillers];
    rows = rows.filter(r => r.latitude !== null && r.longitude !== null);

    let paramIdx = 0;
    if (cleanSql.includes('lower(efficiency) = lower(?)')) {
      const effParam = params[paramIdx++];
      rows = rows.filter(r => (r.efficiency || '').toLowerCase() === effParam.toLowerCase());
    }

    if (cleanSql.includes('lower(customer_type) = lower(?)')) {
      const custParam = params[paramIdx++];
      rows = rows.filter(r => (r.customer_type || '').toLowerCase() === custParam.toLowerCase());
    }

    if (cleanSql.includes('lower(chiller_code) like lower(?)')) {
      const term = (params[paramIdx] || '').replace(/%/g, '').toLowerCase();
      rows = rows.filter(r =>
        (r.chiller_code || '').toLowerCase().includes(term) ||
        (r.customer_name || '').toLowerCase().includes(term) ||
        (r.branch || '').toLowerCase().includes(term)
      );
    }

    return rows;
  }

  return [{ count: 0, max_ord: memoryDb.column_definitions.length }];
}

async function runMemoryDb(sql, params) {
  const cleanSql = sql.trim().toLowerCase();

  if (cleanSql.includes('insert or ignore into column_definitions') || cleanSql.includes('insert into column_definitions')) {
    const id = memoryDb.column_definitions.length + 1;
    const colObj = {
      id,
      key_name: params[0],
      display_label: params[1],
      data_type: params[2],
      is_required: params[3],
      is_active: params[4],
      display_order: params[5]
    };
    if (!memoryDb.column_definitions.some(c => c.key_name === colObj.key_name)) {
      memoryDb.column_definitions.push(colObj);
    }
    return { lastID: id, changes: 1 };
  }

  if (cleanSql.includes('update column_definitions')) {
    const id = params[1];
    const col = memoryDb.column_definitions.find(c => c.id == id);
    if (col) {
      if (cleanSql.includes('is_active =')) col.is_active = params[0];
      if (cleanSql.includes('is_required =')) col.is_required = params[0];
    }
    return { lastID: id, changes: 1 };
  }

  if (cleanSql.includes('insert into upload_batches')) {
    const id = memoryDb.upload_batches.length + 1;
    const batchObj = {
      id,
      filename: params[0],
      total_rows: params[1],
      valid_rows: params[2],
      invalid_rows: params[3],
      bypassed_validation: params[4],
      uploaded_at: new Date().toISOString()
    };
    memoryDb.upload_batches.push(batchObj);
    return { lastID: id, changes: 1 };
  }

  if (cleanSql.includes('insert into chillers')) {
    const chillerCode = params[0];
    const existingIdx = memoryDb.chillers.findIndex(c => c.chiller_code === chillerCode);
    const item = {
      id: existingIdx >= 0 ? memoryDb.chillers[existingIdx].id : memoryDb.chillers.length + 1,
      chiller_code: chillerCode,
      batch_id: params[1],
      latitude: params[2],
      longitude: params[3],
      customer_type: params[4],
      efficiency: params[5],
      branch: params[6],
      chiller_type: params[7],
      chiller_status: params[8],
      condition: params[9],
      customer_name: params[10],
      raw_data_json: params[11],
      updated_at: new Date().toISOString()
    };
    if (existingIdx >= 0) {
      memoryDb.chillers[existingIdx] = item;
    } else {
      memoryDb.chillers.push(item);
    }
    return { lastID: item.id, changes: 1 };
  }

  if (cleanSql.includes('insert into chillers_history')) {
    const id = memoryDb.chillers_history.length + 1;
    memoryDb.chillers_history.push({
      id,
      batch_id: params[0],
      chiller_code: params[1],
      latitude: params[2],
      longitude: params[3],
      customer_type: params[4],
      efficiency: params[5],
      branch: params[6],
      chiller_type: params[7],
      chiller_status: params[8],
      condition: params[9],
      customer_name: params[10],
      raw_data_json: params[11],
      snapshot_time: new Date().toISOString()
    });
    return { lastID: id, changes: 1 };
  }

  if (cleanSql.includes('delete from chillers')) {
    memoryDb.chillers = [];
    return { lastID: 0, changes: 1 };
  }

  return { lastID: 1, changes: 1 };
}

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
  if (useMemoryDb || !dbInstance) {
    if (memoryDb.column_definitions.length === 0) {
      memoryDb.column_definitions = DEFAULT_COLUMNS.map((col, idx) => ({ ...col, id: idx + 1 }));
    }
    return;
  }

  try {
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

    const existingCols = await query(`SELECT COUNT(*) as count FROM column_definitions`);
    if (existingCols[0].count === 0) {
      for (const col of DEFAULT_COLUMNS) {
        await run(
          `INSERT OR IGNORE INTO column_definitions (key_name, display_label, data_type, is_required, is_active, display_order)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [col.key_name, col.display_label, col.data_type, col.is_required, col.is_active, col.display_order]
        );
      }
    }
  } catch (e) {
    console.warn('Error initializing SQLite tables, using in-memory engine fallback:', e.message);
    useMemoryDb = true;
    memoryDb.column_definitions = DEFAULT_COLUMNS.map((col, idx) => ({ ...col, id: idx + 1 }));
  }
}

export default dbInstance;
