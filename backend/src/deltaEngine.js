import { query } from './db.js';

export async function compareBatches(startBatchId, endBatchId) {
  const startRows = await query(
    `SELECT chiller_code, latitude, longitude, customer_type, efficiency, branch, chiller_type, chiller_status, condition, customer_name, raw_data_json 
     FROM chillers_history WHERE batch_id = ?`,
    [startBatchId]
  );

  const endRows = await query(
    `SELECT chiller_code, latitude, longitude, customer_type, efficiency, branch, chiller_type, chiller_status, condition, customer_name, raw_data_json 
     FROM chillers_history WHERE batch_id = ?`,
    [endBatchId]
  );

  const startMap = new Map();
  startRows.forEach(r => {
    if (r.chiller_code) startMap.set(r.chiller_code, r);
  });

  const endMap = new Map();
  endRows.forEach(r => {
    if (r.chiller_code) endMap.set(r.chiller_code, r);
  });

  const added = [];
  const removed = [];
  const modified = [];
  let unchangedCount = 0;

  // Check end batch items
  for (const [code, endRecord] of endMap.entries()) {
    if (!startMap.has(code)) {
      added.push(endRecord);
    } else {
      const startRecord = startMap.get(code);
      const changes = [];

      // Compare key attributes
      if (startRecord.efficiency !== endRecord.efficiency) {
        changes.push({ field: 'Efficiency (Month Ach. Status)', oldValue: startRecord.efficiency, newValue: endRecord.efficiency });
      }
      if (startRecord.customer_type !== endRecord.customer_type) {
        changes.push({ field: 'Customer Type', oldValue: startRecord.customer_type, newValue: endRecord.customer_type });
      }
      if (startRecord.chiller_status !== endRecord.chiller_status) {
        changes.push({ field: 'Chiller Status', oldValue: startRecord.chiller_status, newValue: endRecord.chiller_status });
      }
      if (startRecord.condition !== endRecord.condition) {
        changes.push({ field: 'Condition', oldValue: startRecord.condition, newValue: endRecord.condition });
      }
      if (startRecord.latitude !== endRecord.latitude || startRecord.longitude !== endRecord.longitude) {
        changes.push({ field: 'GPS Coordinates', oldValue: `${startRecord.latitude}, ${startRecord.longitude}`, newValue: `${endRecord.latitude}, ${endRecord.longitude}` });
      }

      if (changes.length > 0) {
        modified.push({
          chillerCode: code,
          customerName: endRecord.customer_name || startRecord.customer_name,
          changes,
          startRecord,
          endRecord
        });
      } else {
        unchangedCount++;
      }
    }
  }

  // Check removed items
  for (const [code, startRecord] of startMap.entries()) {
    if (!endMap.has(code)) {
      removed.push(startRecord);
    }
  }

  return {
    startBatchId: Number(startBatchId),
    endBatchId: Number(endBatchId),
    summary: {
      addedCount: added.length,
      removedCount: removed.length,
      modifiedCount: modified.length,
      unchangedCount
    },
    added,
    removed,
    modified
  };
}
