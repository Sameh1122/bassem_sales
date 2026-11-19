import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { dbStore, ensureFreshCloudSync } from '../services/storage.js';
import {
  parseRawData,
  filterRowsByTerritory,
  canUserAccessChiller,
  parseNumericValue,
  extractChillerAchievement,
  normalizeCondition,
  extractYtdInvoice
} from '../services/chillerHelpers.js';

const router = express.Router();

const MONTH_ORDER = [
  { pattern: /^jan\b/i, index: 0 },
  { pattern: /^feb\b/i, index: 1 },
  { pattern: /^mar\b/i, index: 2 },
  { pattern: /^apr\b/i, index: 3 },
  { pattern: /^may\b/i, index: 4 },
  { pattern: /^jun(e)?\b/i, index: 5 },
  { pattern: /^jul(y)?\b/i, index: 6 },
  { pattern: /^aug\b/i, index: 7 },
  { pattern: /^sep\b/i, index: 8 },
  { pattern: /^oct\b/i, index: 9 },
  { pattern: /^nov\b/i, index: 10 },
  { pattern: /^dec\b/i, index: 11 }
];

function extractMonthlyInvoices(rawData) {
  if (!rawData || typeof rawData !== 'object') return [];
  const entries = [];
  for (const [key, val] of Object.entries(rawData)) {
    if (!/invoice/i.test(key)) continue;
    const monthMatch = MONTH_ORDER.find(m => m.pattern.test(key.trim()));
    if (!monthMatch) continue;
    const num = parseNumericValue(val);
    if (num !== null) {
      entries.push({ monthLabel: key.trim(), monthIndex: monthMatch.index, value: num });
    }
  }
  entries.sort((a, b) => a.monthIndex - b.monthIndex);
  return entries;
}

function isNegativeValue(val) {
  if (val === false) return true;
  const s = String(val ?? '').trim().toLowerCase();
  return s === 'no' || s === 'false' || s === '0' || s === 'fail' || s === 'failed' ||
    s === 'missing' || s === 'damaged' || s === 'poor' || s === 'bad' || s === 'none' || s === 'off';
}

function isAffirmativeValue(val) {
  if (val === true) return true;
  const s = String(val ?? '').trim().toLowerCase();
  return s === 'yes' || s === 'true' || s === '1' || s === 'present' || s === 'found' || s === 'high';
}

export function scoreAuditPayload(answers = {}, attachments = [], chillerCode = '') {
  let purityScore = 100;
  let oosRisk = 'low';
  let posmCompliant = true;
  const recommendations = [];

  const safeAnswers = (answers && typeof answers === 'object' && !Array.isArray(answers)) ? answers : {};
  let purityFlagged = false;
  let oosFlagged = false;
  let posmFlagged = false;

  for (const [rawKey, rawVal] of Object.entries(safeAnswers)) {
    const k = String(rawKey).toLowerCase();
    const vStr = String(rawVal ?? '').toLowerCase();

    // 1. Competitor / Purity checks
    if (!purityFlagged) {
      if (k.includes('competitor') && (isAffirmativeValue(rawVal) || vStr.includes('pepsi') || vStr.includes('cola') || vStr.includes('other'))) {
        purityScore -= 35;
        purityFlagged = true;
        recommendations.push('Remove competitor products and restore brand purity facing');
      } else if ((k.includes('purity') || k.includes('clean') || k.includes('merchandising')) && isNegativeValue(rawVal)) {
        purityScore -= 30;
        purityFlagged = true;
        recommendations.push('Clean chiller interior and correct product planogram purity');
      } else if (k.includes('purity') && parseNumericValue(rawVal) !== null && parseNumericValue(rawVal) < 80) {
        purityScore -= 25;
        purityFlagged = true;
        recommendations.push('Improve brand purity above 80% threshold');
      } else if (vStr.includes('competitor') || vStr.includes('contaminated') || vStr.includes('dirty')) {
        purityScore -= 25;
        purityFlagged = true;
        recommendations.push('Address reported contamination or competitor presence');
      }
    }

    // 2. OOS (Out-of-Stock) checks
    if (k.includes('oos') || k.includes('out of stock') || k.includes('stock') || k.includes('fill') || k.includes('availab')) {
      const numericFill = parseNumericValue(rawVal);
      if (
        (k.includes('oos') && isAffirmativeValue(rawVal)) ||
        vStr.includes('out of stock') ||
        vStr.includes('empty') ||
        vStr === 'high' ||
        (numericFill !== null && numericFill < 40)
      ) {
        if (oosRisk !== 'high') {
          oosRisk = 'high';
          purityScore -= 30;
          if (!oosFlagged) {
            recommendations.push('Trigger urgent replenishment order to resolve Out-of-Stock risk');
            oosFlagged = true;
          }
        }
      } else if (
        vStr.includes('low') ||
        vStr.includes('medium') ||
        vStr.includes('partial') ||
        (numericFill !== null && numericFill < 75)
      ) {
        if (oosRisk === 'low') {
          oosRisk = 'medium';
          purityScore -= 15;
          if (!oosFlagged) {
            recommendations.push('Schedule top-up delivery on next route cycle');
            oosFlagged = true;
          }
        }
      }
    } else if (vStr.includes('out of stock') || vStr.includes('oos')) {
      if (oosRisk !== 'high') {
        oosRisk = 'high';
        purityScore -= 25;
        if (!oosFlagged) {
          recommendations.push('Trigger urgent replenishment order to resolve Out-of-Stock risk');
          oosFlagged = true;
        }
      }
    }

    // 3. POSM compliance checks
    if (!posmFlagged && (k.includes('posm') || k.includes('branding') || k.includes('signage') || k.includes('sticker') || k.includes('header'))) {
      if (isNegativeValue(rawVal) || vStr.includes('missing') || vStr.includes('damaged')) {
        posmCompliant = false;
        purityScore -= 15;
        posmFlagged = true;
        recommendations.push('Replace or install missing POSM branding & signage');
      }
    }
  }

  const safeAttachments = Array.isArray(attachments) ? attachments : [];
  if (safeAttachments.length === 0) {
    purityScore -= 5;
    recommendations.push('Capture geo-stamped chiller photo for visual verification');
  }

  purityScore = Math.max(0, Math.min(100, Math.round(purityScore)));
  if (recommendations.length === 0) {
    recommendations.push('Chiller meets retail execution standards; maintain current visit cadence');
  }

  return {
    chillerCode: chillerCode || null,
    purityScore,
    oosRisk,
    posmCompliant,
    recommendations
  };
}

router.get('/insights/anomalies', requireAuth, async (req, res) => {
  await ensureFreshCloudSync();

  const { branch, batchId } = req.query;
  let rows = [...(dbStore.chillers || [])];

  if (batchId && batchId !== 'All' && batchId !== 'all') {
    const bId = parseInt(batchId, 10);
    if (!Number.isNaN(bId)) {
      const historicalRows = (dbStore.history || []).filter(h => (h.batch_id || h.batchId) === bId);
      rows = historicalRows.length > 0 ? historicalRows : rows.filter(r => (r.batch_id || r.batchId) === bId);
    }
  }

  rows = filterRowsByTerritory(rows, req.user, dbStore);

  const branchParam = (branch || '').toString().trim();
  if (branchParam && branchParam.toLowerCase() !== 'all') {
    const targetBranch = branchParam.toLowerCase();
    rows = rows.filter(r => ((r.branch || '').toString().trim() || 'Unassigned').toLowerCase() === targetBranch);
  }

  // Compute branch-level target monthly revenue from performing operational chillers
  const branchAvgMap = new Map();
  let globalSum = 0;
  let globalCount = 0;

  for (const r of rows) {
    if (normalizeCondition(r.condition) !== 'Operational') continue;
    const rawData = parseRawData(r);
    const ytd = extractYtdInvoice(rawData);
    const avgMonth = parseNumericValue(rawData['Average / Month']) ?? (ytd > 0 ? ytd / 12 : 0);
    if (avgMonth > 0) {
      const bName = (r.branch || '').toString().trim() || 'Unassigned';
      const entry = branchAvgMap.get(bName) || { sum: 0, count: 0 };
      entry.sum += avgMonth;
      entry.count += 1;
      branchAvgMap.set(bName, entry);
      globalSum += avgMonth;
      globalCount += 1;
    }
  }

  const globalTargetMonthly = globalCount > 0 ? (globalSum / globalCount) : 1500;

  const allRelocationCandidates = [];
  const allRevenueDrops = [];
  const scopedCodeSet = new Set();
  const scopedNameSet = new Set();

  for (const r of rows) {
    const code = r.chiller_code || r.chillerCode || '';
    const custName = r.customer_name || r.customerName || '';
    const bName = (r.branch || '').toString().trim() || 'Unassigned';
    if (code) scopedCodeSet.add(String(code).toLowerCase());
    if (custName) scopedNameSet.add(custName.toLowerCase());

    const rawData = parseRawData(r);
    const condition = normalizeCondition(r.condition);
    const ach = extractChillerAchievement(r, rawData);
    const ytd = extractYtdInvoice(rawData);
    const avgMonth = parseNumericValue(rawData['Average / Month']) ?? (ytd > 0 ? ytd / 12 : 0);

    // 1. Relocation Candidates: Operational chillers with < 50% efficiency or low YTD
    if (condition === 'Operational') {
      const isLowEff = ach !== null && ach < 50;
      const isLowYtd = ach === null && ytd < 1000 && avgMonth < 100;
      if (isLowEff || isLowYtd) {
        const bStats = branchAvgMap.get(bName);
        const branchTarget = bStats && bStats.count > 0 ? (bStats.sum / bStats.count) : globalTargetMonthly;
        const uplift = Math.max(250, Math.round((branchTarget - avgMonth) * 100) / 100);
        allRelocationCandidates.push({
          id: r.id,
          chillerCode: code,
          customerName: custName,
          customerAddress: r.customer_address || r.customerAddress || '',
          branch: bName,
          condition,
          efficiency: r.efficiency || '',
          achievement: ach,
          ytdInvoice: Math.round(ytd * 100) / 100,
          estimatedMonthlyUplift: uplift,
          reason: isLowEff
            ? `Low efficiency (${ach}% achievement)`
            : 'Low YTD invoice volume',
          latitude: r.latitude,
          longitude: r.longitude
        });
      }
    }

    // 2. Revenue Drops: >= 25% MoM invoice decline
    const monthly = extractMonthlyInvoices(rawData);
    if (monthly.length >= 2) {
      const prev = monthly[monthly.length - 2];
      const curr = monthly[monthly.length - 1];
      if (prev.value > 0) {
        const dropPct = ((prev.value - curr.value) / prev.value) * 100;
        if (dropPct >= 25) {
          allRevenueDrops.push({
            id: r.id,
            chillerCode: code,
            customerName: custName,
            branch: bName,
            condition,
            efficiency: r.efficiency || '',
            prevMonth: prev.monthLabel,
            currMonth: curr.monthLabel,
            prevInvoice: Math.round(prev.value * 100) / 100,
            currInvoice: Math.round(curr.value * 100) / 100,
            dropPct: Math.round(dropPct * 10) / 10,
            latitude: r.latitude,
            longitude: r.longitude
          });
        }
      }
    }
  }

  allRelocationCandidates.sort((a, b) => b.estimatedMonthlyUplift - a.estimatedMonthlyUplift);
  allRevenueDrops.sort((a, b) => b.dropPct - a.dropPct);

  const relocationCandidates = allRelocationCandidates.slice(0, 20);
  const revenueDrops = allRevenueDrops.slice(0, 20);

  // 3. Purity / OOS / POSM flags from scoped form_responses
  const purityOosFlags = [];
  const seenChillerCodes = new Set();
  const responses = [...(dbStore.form_responses || [])].sort(
    (a, b) => new Date(b.submitted_at || 0) - new Date(a.submitted_at || 0)
  );

  for (const resp of responses) {
    const rCode = (resp.chiller_code || '').toLowerCase();
    const rName = (resp.customer_name || '').toLowerCase();
    const inScope = (rCode && scopedCodeSet.has(rCode)) || (rName && scopedNameSet.has(rName));
    if (!inScope) {
      const matchedChiller = (dbStore.chillers || []).find(c =>
        (resp.chiller_code && (c.chiller_code || c.chillerCode) === resp.chiller_code) ||
        (resp.customer_name && (c.customer_name || c.customerName || '').toLowerCase() === rName)
      );
      if (!matchedChiller || !canUserAccessChiller(matchedChiller, req.user, dbStore)) {
        continue;
      }
    }

    const dedupeKey = rCode || rName || String(resp.id);
    if (seenChillerCodes.has(dedupeKey)) continue;

    const scored = scoreAuditPayload(resp.answers, resp.attachments, resp.chiller_code);
    if (scored.purityScore < 80 || scored.oosRisk !== 'low' || !scored.posmCompliant) {
      seenChillerCodes.add(dedupeKey);
      purityOosFlags.push({
        responseId: resp.id,
        chillerCode: resp.chiller_code || '',
        customerName: resp.customer_name || '',
        purityScore: scored.purityScore,
        oosRisk: scored.oosRisk,
        posmCompliant: scored.posmCompliant,
        recommendations: scored.recommendations,
        submittedAt: resp.submitted_at || null
      });
    }
  }

  purityOosFlags.sort((a, b) => a.purityScore - b.purityScore);
  const topPurityFlags = purityOosFlags.slice(0, 20);

  const estimatedMonthlyUplift = Math.round(
    relocationCandidates.reduce((sum, item) => sum + (item.estimatedMonthlyUplift || 0), 0) * 100
  ) / 100;

  res.json({
    success: true,
    summary: {
      relocationCandidatesCount: allRelocationCandidates.length,
      revenueDropCount: allRevenueDrops.length,
      purityOosCount: purityOosFlags.length,
      estimatedMonthlyUplift
    },
    relocationCandidates,
    revenueDrops,
    purityOosFlags: topPurityFlags
  });
});

router.post('/insights/analyze-audit', requireAuth, (req, res) => {
  const { answers = {}, attachments = [], chillerCode = '' } = req.body || {};
  const result = scoreAuditPayload(answers, attachments, chillerCode);
  res.json({
    success: true,
    ...result
  });
});

export default router;
