import express from 'express';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { app as apiApp } from './api/index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 5000;

const publicDir = path.join(__dirname, 'public');

// Serve static Flutter web files first
if (fs.existsSync(publicDir)) {
  app.use(express.static(publicDir, {
    setHeaders: (res, filePath) => {
      if (filePath.endsWith('.wasm')) {
        res.setHeader('Content-Type', 'application/wasm');
      } else if (filePath.endsWith('.json')) {
        res.setHeader('Content-Type', 'application/json');
      }
    }
  }));
}

// Mount API router
app.use(apiApp);

// Client-side routing fallback to public/index.html
if (fs.existsSync(publicDir)) {
  app.get('*', (req, res) => {
    res.sendFile(path.join(publicDir, 'index.html'));
  });
}

app.listen(PORT, () => {
  console.log('====================================================');
  console.log(`🚀 Bassem Sales Platform is running locally!`);
  console.log(`👉 Open http://localhost:${PORT} in your browser.`);
  console.log(`👉 API endpoint: http://localhost:${PORT}/api/chillers`);
  console.log('====================================================');
});
