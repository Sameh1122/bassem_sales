import { dbStore } from './_db.js';

export default function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method === 'GET') {
    const { startBatchId, endBatchId } = req.query || {};
    const startId = parseInt(startBatchId);
    const endId = parseInt(endBatchId);

    const startSnapshot = dbStore.history.filter(h => h.batch_id === startId);
    const endSnapshot = dbStore.history.filter(h => h.batch_id === endId);

    const startMap = new Map(startSnapshot.map(item => [item.chiller_code, item]));
    const endMap = new Map(endSnapshot.map(item => [item.chiller_code, item]));

    const added = [];
    const removed = [];
    const modified = [];

    for (const [code, item] of endMap.entries()) {
      if (!startMap.has(code)) {
        added.push(item);
      } else {
        const prev = startMap.get(code);
        if (prev.efficiency !== item.efficiency || prev.latitude !== item.latitude || prev.longitude !== item.longitude || prev.branch !== item.branch) {
          modified.push({ previous: prev, current: item });
        }
      }
    }

    for (const [code, item] of startMap.entries()) {
      if (!endMap.has(code)) {
        removed.push(item);
      }
    }

    return res.status(200).json({
      success: true,
      startBatchId: startId,
      endBatchId: endId,
      summary: {
        added: added.length,
        removed: removed.length,
        modified: modified.length
      },
      added,
      removed,
      modified
    });
  }

  res.status(405).json({ error: 'Method not allowed' });
}
