import { dbStore } from './_db.js';

export default function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method === 'DELETE') {
    dbStore.chillers = [];
    return res.status(200).json({ success: true, message: 'All active database records cleared' });
  }

  if (req.method === 'GET') {
    const { efficiency, customerType, search } = req.query || {};
    let rows = [...dbStore.chillers];

    if (efficiency && efficiency !== 'All') {
      rows = rows.filter(r => (r.efficiency || '').toLowerCase() === efficiency.toLowerCase());
    }

    if (customerType && customerType !== 'All') {
      rows = rows.filter(r => (r.customer_type || '').toLowerCase() === customerType.toLowerCase());
    }

    if (search) {
      const term = search.toLowerCase();
      rows = rows.filter(r =>
        (r.chiller_code || '').toLowerCase().includes(term) ||
        (r.customer_name || '').toLowerCase().includes(term) ||
        (r.branch || '').toLowerCase().includes(term)
      );
    }

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

    return res.status(200).json({ success: true, count: chillers.length, chillers });
  }

  res.status(405).json({ error: 'Method not allowed' });
}
