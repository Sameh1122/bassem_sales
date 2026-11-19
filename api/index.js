import express from 'express';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import auditLogger from './audit_logger.js';
import { attachUser } from './middleware/auth.js';
import {
  ALLOWED_ATTACHMENT_EXTS,
  buildCorsOptions,
  getClientIp
} from './utils/security.js';
import {
  isCloudStorageConfigured,
  getHasSyncedWithCloud,
  syncWithCloudStorage
} from './services/storage.js';

import adminRoutes from './routes/admin.js';
import authRoutes from './routes/auth.js';
import batchesRoutes from './routes/batches.js';
import chillersRoutes from './routes/chillers.js';
import agentsRoutes from './routes/agents.js';
import formsRoutes from './routes/forms.js';
import ticketsRoutes from './routes/tickets.js';
import syncRoutes from './routes/sync.js';
import insightsRoutes from './routes/insights.js';
import integrationsRoutes from './routes/integrations.js';

const app = express();
app.disable('x-powered-by');

// Security headers middleware
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'SAMEORIGIN');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
});

app.use(cors(buildCorsOptions()));
app.use(express.json({ limit: '25mb' }));

const staticUploadOptions = {
  setHeaders: (res, filePath) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    const ext = path.extname(filePath).toLowerCase();
    if (!ALLOWED_ATTACHMENT_EXTS.has(ext)) {
      res.setHeader('Content-Disposition', 'attachment');
    }
  }
};

app.use('/uploads', express.static(path.resolve('public/uploads'), staticUploadOptions));
if (process.env.VERCEL) {
  app.use('/uploads', express.static(path.resolve('/tmp/uploads'), staticUploadOptions));
}

const router = express.Router();

// Middleware to extract user from Authorization header
router.use(attachUser);

// Middleware to ensure database state is synced from persistent cloud storage (Vercel Blob)
router.use(async (req, res, next) => {
  if (isCloudStorageConfigured() && !getHasSyncedWithCloud()) {
    try {
      await syncWithCloudStorage();
    } catch (_) {}
  }
  next();
});

// Audit logging interceptor middleware
router.use((req, res, next) => {
  const startTime = Date.now();
  const clientIp = getClientIp(req);

  req.auditEvent = {
    category: 'system',
    action: `${req.method} ${req.path}`,
    details: null,
    metadata: {}
  };

  res.on('finish', () => {
    // Avoid noisy polling / static file logs unless failed
    if (req.path === '/health' && res.statusCode < 400) return;
    if (req.path.startsWith('/uploads') && res.statusCode < 400) return;

    const duration = Date.now() - startTime;
    let level = 'INFO';
    if (res.statusCode >= 500) level = 'ERROR';
    else if (res.statusCode >= 400) level = 'WARN';

    let category = req.auditEvent.category;
    if (category === 'system') {
      if (req.path.includes('/auth') || req.path.includes('/login')) category = 'auth';
      else if (req.path.includes('/excel') || req.path.includes('/batches') || req.path.includes('/chillers')) category = 'upload';
      else if (req.path.includes('/assignments')) category = 'assignment';
      else if (req.path.includes('/agents')) category = 'agents';
      else if (req.path.includes('/forms') || req.path.includes('/form-responses')) category = 'forms';
      else if (req.path.includes('/tickets')) category = 'tickets';
    }

    const defaultDetails = req.auditEvent.details || `${req.method} ${req.originalUrl || req.url} responded with status ${res.statusCode}`;

    auditLogger.log({
      level,
      category,
      action: req.auditEvent.action,
      actor: {
        id: req.user?.id,
        email: req.user?.email || 'anonymous',
        username: req.user?.username || 'anonymous',
        role: req.user?.role || 'guest',
        ip: clientIp
      },
      method: req.method,
      endpoint: req.originalUrl || req.url,
      statusCode: res.statusCode,
      durationMs: duration,
      details: defaultDetails,
      metadata: req.auditEvent.metadata
    });
  });

  next();
});

// Mount domain routers
router.use(adminRoutes);
router.use(authRoutes);
router.use(batchesRoutes);
router.use(chillersRoutes);
router.use(agentsRoutes);
router.use(formsRoutes);
router.use(ticketsRoutes);
router.use('/sync', syncRoutes);
router.use(insightsRoutes);
router.use('/integrations', integrationsRoutes);

app.get(['/', '/index.html'], (req, res) => {
  const publicIndex = path.resolve('public/index.html');
  if (fs.existsSync(publicIndex)) {
    return res.sendFile(publicIndex);
  }
  res.setHeader('Content-Type', 'text/html');
  res.send('<!DOCTYPE html><html><head><title>Bassem Sales Platform</title><base href="/"><meta charset="UTF-8"><meta content="IE=Edge" http-equiv="X-UA-Compatible"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head><body><script src="flutter_bootstrap.js" async></script></body></html>');
});

app.use('/api', router);
app.use('/', router);

app.use((req, res, next) => {
  if (req.path.startsWith('/api')) {
    return res.status(404).json({ success: false, error: `API endpoint '${req.url}' not found` });
  }
  next();
});

// Auto-start listener if executed directly with node api/index.js
const isMain = process.argv[1]?.endsWith('api/index.js') || process.argv[1]?.endsWith('api\\index.js');
if (isMain) {
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, () => {
    console.log(`🚀 API Server listening at http://localhost:${PORT}`);
  });
}

export { app };
export default (req, res) => {
  return app(req, res);
};
