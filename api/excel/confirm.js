import { dbStore } from '../_db.js';

export default function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method === 'POST') {
    const { filename = 'Uploaded_Sheet.xlsx', rows = [], bypassValidation = false } = req.body || {};
    const rowsToSave = bypassValidation ? rows : rows.filter(r => r.isValid);
    const batchId = dbStore.batches.length + 1;

    dbStore.batches.push({
      id: batchId,
      filename,
      total_rows: rows.length,
      valid_rows: rows.filter(r => r.isValid).length,
      invalid_rows: rows.length - rows.filter(r => r.isValid).length,
      bypassed_validation: bypassValidation ? 1 : 0,
      uploaded_at: new Date().toISOString()
    });

    for (const r of rowsToSave) {
      const code = r.chillerCode || `CH-${Math.random().toString(36).substring(7)}`;
      const existingIdx = dbStore.chillers.findIndex(c => c.chiller_code === code);
      const item = {
        id: existingIdx >= 0 ? dbStore.chillers[existingIdx].id : dbStore.chillers.length + 1,
        chiller_code: code,
        batch_id: batchId,
        latitude: r.latitude,
        longitude: r.longitude,
        customer_type: r.customerType,
        efficiency: r.efficiency,
        branch: r.branch,
        chiller_type: r.chillerType,
        chiller_status: r.chillerStatus,
        condition: r.condition,
        customer_name: r.customerName,
        raw_data_json: JSON.stringify(r.rowObj || {}),
        updated_at: new Date().toISOString()
      };
      if (existingIdx >= 0) dbStore.chillers[existingIdx] = item;
      else dbStore.chillers.push(item);

      dbStore.history.push({ ...item, id: dbStore.history.length + 1, snapshot_time: new Date().toISOString() });
    }

    return res.status(200).json({
      success: true,
      batchId,
      savedRowsCount: rowsToSave.length,
      message: `Successfully saved ${rowsToSave.length} records into database.`
    });
  }

  res.status(405).json({ error: 'Method not allowed' });
}
