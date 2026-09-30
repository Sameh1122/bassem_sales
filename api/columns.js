import { dbStore } from './_db.js';

export default function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method === 'GET') {
    return res.status(200).json({ success: true, columns: dbStore.columns });
  }

  if (req.method === 'POST') {
    const { key_name, display_label, data_type = 'string', is_required = 0, is_active = 1 } = req.body || {};
    const newCol = {
      id: dbStore.columns.length + 1,
      key_name,
      display_label,
      data_type,
      is_required: is_required ? 1 : 0,
      is_active: is_active ? 1 : 0,
      display_order: dbStore.columns.length + 1
    };
    dbStore.columns.push(newCol);
    return res.status(200).json({ success: true, message: `Column '${display_label}' added successfully` });
  }

  res.status(405).json({ error: 'Method not allowed' });
}
