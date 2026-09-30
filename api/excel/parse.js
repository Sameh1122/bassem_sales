import { parseExcelBuffer } from '../_excel.js';

export default function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method === 'POST') {
    try {
      let buffer = null;
      let filename = 'Uploaded_Sheet.xlsx';

      if (req.body && req.body.fileBase64) {
        buffer = Buffer.from(req.body.fileBase64, 'base64');
        if (req.body.filename) filename = req.body.filename;
      }

      if (!buffer) {
        return res.status(400).json({ success: false, error: 'No Excel file payload provided' });
      }

      const result = parseExcelBuffer(buffer);
      return res.status(200).json({ success: true, filename, ...result });
    } catch (e) {
      return res.status(500).json({ success: false, error: e.message });
    }
  }

  res.status(405).json({ error: 'Method not allowed' });
}
