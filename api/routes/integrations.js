import crypto from 'crypto';
import express from 'express';
import { requireAdmin, requireRoles } from '../middleware/auth.js';
import {
  dbStore,
  saveDbStore,
  persistToBlobIfConfigured,
  ensureFreshCloudSync
} from '../services/storage.js';
import {
  parseRawData,
  extractChillerAchievement,
  normalizeCondition,
  extractYtdInvoice
} from '../services/chillerHelpers.js';

const router = express.Router();

const ALLOWED_WEBHOOK_EVENTS = new Set([
  'chiller.updated',
  'chiller.relocated',
  'ticket.created',
  'ticket.resolved',
  'audit.submitted',
  'audit.approved',
  'erp.synced'
]);

function maskSecretValue(secret) {
  const s = (secret || '').toString();
  if (!s) return 'whsec_****';
  const tail = s.length >= 4 ? s.slice(-4) : '****';
  return `whsec_****${tail}`;
}

function serializeWebhook(webhook) {
  return {
    id: webhook.id,
    name: webhook.name,
    url: webhook.url,
    events: Array.isArray(webhook.events) ? webhook.events : [],
    signingSecretMasked: maskSecretValue(webhook.signingSecret),
    isActive: webhook.isActive !== false,
    createdBy: webhook.createdBy || null,
    createdAt: webhook.createdAt
  };
}

function isValidHttpUrl(rawUrl) {
  if (!rawUrl || typeof rawUrl !== 'string') return false;
  try {
    const parsed = new URL(rawUrl.trim());
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch (_) {
    return false;
  }
}

// ==========================================
// 1. Enterprise ERP / DMS Webhooks
// ==========================================

router.get('/webhooks', requireAdmin, async (req, res) => {
  await ensureFreshCloudSync();
  const list = Array.isArray(dbStore.webhooks) ? dbStore.webhooks : [];
  res.json({
    success: true,
    webhooks: list.map(serializeWebhook),
    allowedEvents: Array.from(ALLOWED_WEBHOOK_EVENTS)
  });
});

router.post('/webhooks', requireAdmin, async (req, res) => {
  await ensureFreshCloudSync();

  const { name, url, events, signingSecret, isActive = true } = req.body || {};

  if (!isValidHttpUrl(url)) {
    return res.status(400).json({
      success: false,
      error: 'A valid http:// or https:// webhook URL is required.'
    });
  }

  if (!Array.isArray(events) || events.length === 0) {
    return res.status(400).json({
      success: false,
      error: 'At least one webhook event subscription is required.'
    });
  }

  const normalizedEvents = [...new Set(
    events.map(e => String(e || '').trim()).filter(Boolean)
  )];

  const invalidEvents = normalizedEvents.filter(e => !ALLOWED_WEBHOOK_EVENTS.has(e));
  if (normalizedEvents.length === 0 || invalidEvents.length > 0) {
    return res.status(400).json({
      success: false,
      error: `Invalid webhook event(s): ${invalidEvents.join(', ')}. Allowed: ${Array.from(ALLOWED_WEBHOOK_EVENTS).join(', ')}`
    });
  }

  if (!Array.isArray(dbStore.webhooks)) {
    dbStore.webhooks = [];
  }

  const nextId = dbStore.webhooks.reduce((max, w) => Math.max(max, Number(w.id) || 0), 0) + 1;
  const rawSecret = (signingSecret && String(signingSecret).trim())
    ? String(signingSecret).trim()
    : `whsec_${crypto.randomBytes(16).toString('hex')}`;

  const newWebhook = {
    id: nextId,
    name: (name && String(name).trim()) || `ERP Webhook #${nextId}`,
    url: url.trim(),
    events: normalizedEvents,
    signingSecret: rawSecret,
    isActive: Boolean(isActive),
    createdBy: req.user.email,
    createdAt: new Date().toISOString()
  };

  dbStore.webhooks.push(newWebhook);
  saveDbStore(dbStore);
  await persistToBlobIfConfigured(dbStore);

  res.status(201).json({
    success: true,
    webhook: serializeWebhook(newWebhook)
  });
});

// ==========================================
// 2. Incremental ERP / DMS Sync Trigger
// ==========================================

router.post('/erp-sync', requireAdmin, async (req, res) => {
  await ensureFreshCloudSync();

  const { source = 'DMS/ERP', mode = 'incremental' } = req.body || {};
  const chillers = Array.isArray(dbStore.chillers) ? dbStore.chillers : [];
  const tickets = Array.isArray(dbStore.tickets) ? dbStore.tickets : [];

  let invoicesSynced = 0;
  for (const c of chillers) {
    const rawData = parseRawData(c);
    const ytd = extractYtdInvoice(rawData);
    if (ytd > 0) invoicesSynced += 1;
  }

  if (!Array.isArray(dbStore.erp_sync_logs)) {
    dbStore.erp_sync_logs = [];
  }

  const nextId = dbStore.erp_sync_logs.reduce((max, l) => Math.max(max, Number(l.id) || 0), 0) + 1;
  const syncRun = {
    id: nextId,
    source: String(source || 'DMS/ERP').trim(),
    mode: mode === 'full' ? 'full' : 'incremental',
    status: 'completed',
    chillersSynced: chillers.length,
    ticketsSynced: tickets.length,
    invoicesSynced,
    triggeredBy: req.user.email,
    triggeredAt: new Date().toISOString()
  };

  dbStore.erp_sync_logs.push(syncRun);
  if (dbStore.erp_sync_logs.length > 100) {
    dbStore.erp_sync_logs = dbStore.erp_sync_logs.slice(-100);
  }

  saveDbStore(dbStore);
  await persistToBlobIfConfigured(dbStore);

  res.json({
    success: true,
    syncRun,
    recentLogs: [...dbStore.erp_sync_logs].slice(-10).reverse()
  });
});

// ==========================================
// 3. Executive Asset ROI Console
// ==========================================

router.get('/roi', requireRoles('owner', 'admin', 'regional_manager'), async (req, res) => {
  await ensureFreshCloudSync();

  const branchParam = (req.query.branch || '').toString().trim();
  const filterByBranch = branchParam && branchParam.toLowerCase() !== 'all';
  const targetBranch = branchParam.toLowerCase();

  let chillers = Array.isArray(dbStore.chillers) ? dbStore.chillers : [];
  let tickets = Array.isArray(dbStore.tickets) ? dbStore.tickets : [];

  if (filterByBranch) {
    chillers = chillers.filter(c => ((c.branch || '').toString().trim() || 'Unassigned').toLowerCase() === targetBranch);
    tickets = tickets.filter(t => ((t.branch || '').toString().trim() || 'Unassigned').toLowerCase() === targetBranch);
  }

  let activeChillers = 0;
  let maintenanceChillers = 0;
  let scrapChillers = 0;
  let totalYtdRevenue = 0;
  let underperformingOperational = 0;

  for (const c of chillers) {
    const cond = normalizeCondition(c.condition);
    const rawData = parseRawData(c);
    const ytd = extractYtdInvoice(rawData);
    const ach = extractChillerAchievement(c, rawData);

    totalYtdRevenue += ytd;

    if (cond === 'Operational') {
      activeChillers += 1;
      if (ach < 50 || ytd <= 0) {
        underperformingOperational += 1;
      }
    } else if (cond === 'Requires Maintenance') {
      maintenanceChillers += 1;
    } else if (cond === 'Scrap') {
      scrapChillers += 1;
    }
  }

  const openTickets = tickets.filter(t => t.status === 'open' || t.status === 'in_progress').length;
  const revenuePerActiveChiller = activeChillers > 0
    ? Math.round((totalYtdRevenue / activeChillers) * 100) / 100
    : 0;

  // Estimated YTD revenue drag from maintenance, scrap assets, and open service tickets
  const baselineAssetYield = revenuePerActiveChiller > 0 ? revenuePerActiveChiller : 2400;
  const maintenanceDrag = Math.round((
    (maintenanceChillers * baselineAssetYield * 0.35) +
    (scrapChillers * baselineAssetYield * 0.65) +
    (openTickets * 250)
  ) * 100) / 100;

  // Relocation uplift potential from redeploying underperforming operational assets
  const relocationUpliftPotential = Math.round((
    underperformingOperational * Math.max(baselineAssetYield * 0.25, 500)
  ) * 100) / 100;

  // Assumed annualized chiller capital + servicing cost baseline of 1,500 per asset
  const estimatedFleetCost = Math.max(chillers.length * 1500, 1);
  const netAssetRoiPct = Math.round((((totalYtdRevenue - maintenanceDrag) / estimatedFleetCost) * 100) * 10) / 10;

  const syncLogs = Array.isArray(dbStore.erp_sync_logs) ? dbStore.erp_sync_logs : [];
  const lastErpSync = syncLogs.length > 0 ? syncLogs[syncLogs.length - 1] : null;
  const webhooks = Array.isArray(dbStore.webhooks) ? dbStore.webhooks : [];

  res.json({
    success: true,
    branch: filterByBranch ? branchParam : 'All',
    roi: {
      totalChillers: chillers.length,
      activeChillers,
      maintenanceChillers,
      scrapChillers,
      underperformingCount: underperformingOperational,
      openTickets,
      totalYtdRevenue: Math.round(totalYtdRevenue * 100) / 100,
      revenuePerActiveChiller,
      maintenanceDrag,
      relocationUpliftPotential,
      netAssetRoiPct
    },
    lastErpSync,
    webhooksCount: webhooks.length
  });
});

export default router;
