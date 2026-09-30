import { dbStore } from '../_db.js';

export default function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method === 'POST') {
    const { id, is_active, is_required } = req.body || {};
    const col = dbStore.columns.find(c => c.id === id);
    if (col) {
      if (is_active !== undefined) col.is_active = is_active ? 1 : 0;
      if (is_required !== undefined) col.is_required = is_required ? 1 : 0;
    }
    return res.status(200).json({ success: true, message: 'Column updated successfully' });
  }

  res.status(405).json({ error: 'Method not allowed' });
}
