import express from 'express';
import cors from 'cors';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { initDb, query, run } from '../backend/src/db.js';
import { parseExcelData } from '../backend/src/excelParser.js';
import { compareBatches } from '../backend/src/deltaEngine.js';

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

const upload = multer({ dest: '/tmp' });

// Ensure DB is initialized
await initDb();

app.get('/api/columns', async (req, res) => {
  try {
    const columns = await query(`SELECT * FROM column_definitions ORDER BY display_order ASC`);
    res.json({ success: true, columns });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/columns', async (req, res) => {
  try {
    const { key_name, display_label, data_type = 'string', is_required = 0, is_active = 1 } = req.body;
    if (!key_name || !display_label) {
      return res.status(400).json({ success: false, error: 'key_name and display_label are required' });
    }
    const maxOrderRes = await query(`SELECT MAX(display_order) as max_ord FROM column_definitions`);
    const nextOrder = (maxOrderRes[0]?.max_ord || 0) + 1;

    await run(
      `INSERT INTO column_definitions (key_name, display_label, data_type, is_required, is_active, display_order)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [key_name, display_label, data_type, is_required ? 1 : 0, is_active ? 1 : 0, nextOrder]
    );

    res.json({ success: true, message: `Column '${display_label}' added successfully` });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/columns/toggle', async (req, res) => {
  try {
    const { id, is_active, is_required } = req.body;
    if (id === undefined) {
      return res.status(400).json({ success: false, error: 'Column ID is required' });
    }

    if (is_active !== undefined) {
      await run(`UPDATE column_definitions SET is_active = ? WHERE id = ?`, [is_active ? 1 : 0, id]);
    }
    if (is_required !== undefined) {
      await run(`UPDATE column_definitions SET is_required = ? WHERE id = ?`, [is_required ? 1 : 0, id]);
    }

    res.json({ success: true, message: 'Column updated successfully' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/excel/scratch-sample', async (req, res) => {
  try {
    const scratchPath = 'C:\\Users\\skamal\\.gemini\\antigravity\\scratch\\Bassem\\Chillers Database_V1.xlsx';
    if (!fs.existsSync(scratchPath)) {
      return res.status(404).json({ success: false, error: `File not found at ${scratchPath}` });
    }

    const result = await parseExcelData(scratchPath);
    res.json({ success: true, filename: 'Chillers Database_V1.xlsx', ...result });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/excel/parse', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'No Excel file provided' });
    }

    const result = await parseExcelData(req.file.path);
    if (fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);

    res.json({ success: true, filename: req.file.originalname, ...result });
  } catch (err) {
    if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/excel/confirm', async (req, res) => {
  try {
    const { filename = 'Uploaded_Sheet.xlsx', rows = [], bypassValidation = false } = req.body;

    if (!Array.isArray(rows) || rows.length === 0) {
      return res.status(400).json({ success: false, error: 'No rows provided to save' });
    }

    const rowsToSave = bypassValidation ? rows : rows.filter(r => r.isValid);
    const validCount = rows.filter(r => r.isValid).length;
    const invalidCount = rows.length - validCount;

    const batchRes = await run(
      `INSERT INTO upload_batches (filename, total_rows, valid_rows, invalid_rows, bypassed_validation)
       VALUES (?, ?, ?, ?, ?)`,
      [filename, rows.length, validCount, invalidCount, bypassValidation ? 1 : 0]
    );
    const batchId = batchRes.lastID;

    for (const r of rowsToSave) {
      const rawJson = JSON.stringify(r.rowObj || {});
      const chillerCode = r.chillerCode || `CH-${Math.random().toString(36).substring(7)}`;

      await run(
        `INSERT INTO chillers (chiller_code, batch_id, latitude, longitude, customer_type, efficiency, branch, chiller_type, chiller_status, condition, customer_name, raw_data_json, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT(chiller_code) DO UPDATE SET
           batch_id = excluded.batch_id,
           latitude = excluded.latitude,
           longitude = excluded.longitude,
           customer_type = excluded.customer_type,
           efficiency = excluded.efficiency,
           branch = excluded.branch,
           chiller_type = excluded.chiller_type,
           chiller_status = excluded.chiller_status,
           condition = excluded.condition,
           customer_name = excluded.customer_name,
           raw_data_json = excluded.raw_data_json,
           updated_at = CURRENT_TIMESTAMP`,
        [chillerCode, batchId, r.latitude, r.longitude, r.customerType, r.efficiency, r.branch, r.chillerType, r.chillerStatus, r.condition, r.customerName, rawJson]
      );

      await run(
        `INSERT INTO chillers_history (batch_id, chiller_code, latitude, longitude, customer_type, efficiency, branch, chiller_type, chiller_status, condition, customer_name, raw_data_json)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [batchId, chillerCode, r.latitude, r.longitude, r.customerType, r.efficiency, r.branch, r.chillerType, r.chillerStatus, r.condition, r.customerName, rawJson]
      );
    }

    res.json({
      success: true,
      batchId,
      savedRowsCount: rowsToSave.length,
      bypassedValidation: Boolean(bypassValidation),
      message: `Successfully saved ${rowsToSave.length} records into SQLite database (Batch #${batchId}).`
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/chillers', async (req, res) => {
  try {
    const { efficiency, customerType, search } = req.query;
    let sql = `SELECT * FROM chillers WHERE latitude IS NOT NULL AND longitude IS NOT NULL`;
    const params = [];

    if (efficiency && efficiency !== 'All') {
      sql += ` AND LOWER(efficiency) = LOWER(?)`;
      params.push(efficiency);
    }

    if (customerType && customerType !== 'All') {
      sql += ` AND LOWER(customer_type) = LOWER(?)`;
      params.push(customerType);
    }

    if (search) {
      sql += ` AND (LOWER(chiller_code) LIKE LOWER(?) OR LOWER(customer_name) LIKE LOWER(?) OR LOWER(branch) LIKE LOWER(?))`;
      const term = `%${search}%`;
      params.push(term, term, term);
    }

    const rows = await query(sql, params);

    const chillers = rows.map(r => ({
      id: r.id,
      chillerCode: r.chiller_code,
      batchId: r.batch_id,
      latitude: r.latitude,
      longitude: r.longitude,
      customerType: r.customer_type,
      efficiency: r.efficiency,
      branch: r.branch,
      chillerType: r.chiller_type,
      chillerStatus: r.chiller_status,
      condition: r.condition,
      customerName: r.customer_name,
      rawData: JSON.parse(r.raw_data_json || '{}')
    }));

    res.json({ success: true, count: chillers.length, chillers });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.delete('/api/chillers/clear', async (req, res) => {
  try {
    await run(`DELETE FROM chillers`);
    res.json({ success: true, message: 'All active database records cleared' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/batches', async (req, res) => {
  try {
    const batches = await query(`SELECT * FROM upload_batches ORDER BY id DESC`);
    res.json({ success: true, batches });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/delta', async (req, res) => {
  try {
    const { startBatchId, endBatchId } = req.query;
    if (!startBatchId || !endBatchId) {
      return res.status(400).json({ success: false, error: 'startBatchId and endBatchId query parameters are required' });
    }

    const delta = await compareBatches(startBatchId, endBatchId);
    res.json({ success: true, ...delta });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

export default app;
