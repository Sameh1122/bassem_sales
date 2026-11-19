import express from 'express';
import { requireAuth, requireAdmin, requireRoles, isAdminRole } from '../middleware/auth.js';
import { dbStore, saveDbStore, ensureFreshCloudSync, persistToBlobIfConfigured } from '../services/storage.js';
import {
  getChillerVisitInfo,
  parseRawData,
  isChillerAssignedToAgent,
  canUserAccessChiller,
  filterRowsByTerritory,
  getSupervisedAgentIdSet,
  parseNumericValue,
  extractChillerAchievement,
  computeKpiStats,
  haversineKm,
  formatChillerRecord,
  normalizeCondition,
  extractYtdInvoice,
  classifyEfficiencyBucket
} from '../services/chillerHelpers.js';
import { applyConditionUpdate } from '../services/syncOperations.js';
import { autoCreateTicketForChiller } from './tickets.js';

const router = express.Router();

function isMissingGps(r) {
  const lat = parseNumericValue(r.latitude);
  const lng = parseNumericValue(r.longitude);
  return lat === null || lng === null || (lat === 0 && lng === 0);
}

function isUnspecifiedCondition(r, rawData) {
  const cond = r.condition || rawData?.['Condition'] || rawData?.['Condiiton'] || '';
  const s = String(cond).trim().toLowerCase();
  return !s || s === 'unknown' || s === 'unspecified' || s === 'n/a' || s === 'na' || s === '-';
}

function isUnknownEfficiency(r, rawData) {
  const eff = String(r.efficiency || '').trim().toLowerCase();
  const hasEffText = Boolean(eff && eff !== 'unknown' && eff !== 'unspecified' && eff !== 'n/a' && eff !== 'na' && eff !== '-');
  return !hasEffText && extractChillerAchievement(r, rawData) === null;
}

function extractDistrictName(r, rawData) {
  const candidates = [
    r.district,
    r.area,
    r.city,
    rawData?.['District'],
    rawData?.['Sub-District'],
    rawData?.['Sub District'],
    rawData?.['Area'],
    rawData?.['City'],
    rawData?.['Zone'],
    rawData?.['Region']
  ];
  for (const c of candidates) {
    const str = String(c ?? '').trim();
    if (str && str !== '-' && str.toLowerCase() !== 'n/a') return str;
  }
  return String(r.branch || '').trim() || 'Unspecified';
}

router.get('/chillers', requireAuth, async (req, res) => {
  await ensureFreshCloudSync();
  const { efficiency, customerType, search, batchId, incomplete } = req.query;
  let rows = [...(dbStore.chillers || [])];

  if (batchId && batchId !== 'All' && batchId !== 'all') {
    const bId = parseInt(batchId);
    if (!isNaN(bId)) {
      // Check if batch exists in history snapshots for exact point-in-time state
      const historicalRows = dbStore.history.filter(h => (h.batch_id || h.batchId) === bId);
      if (historicalRows.length > 0) {
        rows = historicalRows;
      } else {
        rows = rows.filter(r => (r.batch_id || r.batchId) === bId);
      }
    }
  }

  if (efficiency && efficiency !== 'All') {
    rows = rows.filter(r => (r.efficiency || '').toLowerCase() === efficiency.toLowerCase());
  }

  if (customerType && customerType !== 'All') {
    rows = rows.filter(r => (r.customer_type || r.customerType || '').toLowerCase() === customerType.toLowerCase());
  }

  // Scope chillers by role/territory/branch
  if (req.user && !isAdminRole(req.user)) {
    rows = filterRowsByTerritory(rows, req.user, dbStore);
  }

  const incompleteMode = String(incomplete || '').trim().toLowerCase();
  if (incompleteMode === 'gps' || incompleteMode === 'condition' || incompleteMode === 'efficiency' || incompleteMode === 'any') {
    rows = rows.filter(r => {
      const rawData = parseRawData(r);
      const missGps = isMissingGps(r);
      const missCond = isUnspecifiedCondition(r, rawData);
      const missEff = isUnknownEfficiency(r, rawData);
      if (incompleteMode === 'gps') return missGps;
      if (incompleteMode === 'condition') return missCond;
      if (incompleteMode === 'efficiency') return missEff;
      return missGps || missCond || missEff;
    });
  }

  if (search) {
    const term = search.toLowerCase();
    rows = rows.filter(r =>
      (r.chiller_code || r.chillerCode || '').toLowerCase().includes(term) ||
      (r.customer_name || r.customerName || '').toLowerCase().includes(term) ||
      (r.branch || '').toLowerCase().includes(term)
    );
  }

  const chillers = rows.map(r => {
    const code = r.chiller_code || r.chillerCode;
    const custName = r.customer_name || r.customerName || '';
    const visitInfo = getChillerVisitInfo(code, custName);
    return {
      id: r.id,
      chillerCode: code,
      batchId: r.batch_id || r.batchId,
      latitude: r.latitude,
      longitude: r.longitude,
      customerType: r.customer_type || r.customerType,
      efficiency: r.efficiency,
      branch: r.branch,
      chillerType: r.chiller_type || r.chillerType,
      chillerStatus: r.chiller_status || r.chillerStatus,
      condition: r.condition,
      customerName: custName,
      customerAddress: r.customer_address || r.customerAddress || '',
      mobileNumber: r.mobile_number || r.mobileNumber || '',
      visitStatus: visitInfo.visitStatus,
      latestResponseId: visitInfo.latestResponseId,
      latestResponseDate: visitInfo.latestResponseDate,
      adminFeedback: visitInfo.adminFeedback,
      formId: visitInfo.formId,
      rawData: parseRawData(r)
    };
  });

  res.json({ success: true, count: chillers.length, chillers });
});

router.get('/chillers/latest-batch', requireAuth, (req, res) => {
  const { search, agentId, assignmentStatus, batchId } = req.query;

  // Determine latest batch
  let latestBatchId = null;
  if (dbStore.batches && dbStore.batches.length > 0) {
    const sorted = [...dbStore.batches].sort((a, b) => (b.id || 0) - (a.id || 0));
    latestBatchId = sorted[0].id;
  }

  let selectedBatchId = batchId || 'all';
  let rows = [];

  if (selectedBatchId === 'all') {
    rows = [...dbStore.chillers];
  } else {
    const targetId = selectedBatchId === 'latest' ? latestBatchId : parseInt(selectedBatchId);
    if (!isNaN(targetId) && targetId !== null) {
      const historicalRows = dbStore.history.filter(h => (h.batch_id || h.batchId) === targetId);
      if (historicalRows.length > 0) {
        rows = historicalRows;
      } else {
        rows = dbStore.chillers.filter(r => (r.batch_id || r.batchId) === targetId);
      }
    } else {
      rows = [...dbStore.chillers];
      selectedBatchId = 'all';
    }
  }

  // Fallback to all chillers ONLY if batchId was omitted, 'all', or 'latest' without data
  const isExplicitBatch = batchId !== undefined && batchId !== null && batchId !== '' && batchId !== 'all';
  if (rows.length === 0 && !isExplicitBatch && dbStore.chillers.length > 0) {
    rows = [...dbStore.chillers];
    selectedBatchId = 'all';
  }

  // Create assignments lookup map
  const assignmentMap = new Map();
  (dbStore.assignments || []).forEach(as => {
    if (as.chiller_code) assignmentMap.set(as.chiller_code, as);
    if (as.customer_name) assignmentMap.set(as.customer_name.toLowerCase(), as);
  });

  let chillers = rows.map(r => {
    const code = r.chiller_code || r.chillerCode;
    const custName = r.customer_name || r.customerName || '';
    const assignment = assignmentMap.get(code) || (custName ? assignmentMap.get(custName.toLowerCase()) : null);

    const visitInfo = getChillerVisitInfo(code, custName);

    return {
      id: r.id,
      chillerCode: code,
      batchId: r.batch_id || r.batchId,
      latitude: r.latitude,
      longitude: r.longitude,
      customerType: r.customer_type || r.customerType,
      efficiency: r.efficiency,
      branch: r.branch,
      chillerType: r.chiller_type || r.chillerType,
      chillerStatus: r.chiller_status || r.chillerStatus,
      condition: r.condition,
      customerName: custName,
      customerAddress: r.customer_address || r.customerAddress || '',
      mobileNumber: r.mobile_number || r.mobileNumber || '',
      assignedAgentId: assignment?.agent_id || null,
      assignedAgentName: assignment?.agent_name || null,
      assignedAgentArea: assignment?.agent_area || null,
      assignedAt: assignment?.assigned_at || null,
      visitStatus: visitInfo.visitStatus,
      latestResponseId: visitInfo.latestResponseId,
      latestResponseDate: visitInfo.latestResponseDate,
      adminFeedback: visitInfo.adminFeedback,
      formId: visitInfo.formId,
      rawData: parseRawData(r)
    };
  });

  // Filter by customer name / general search
  if (search && search.trim()) {
    const term = search.trim().toLowerCase();
    chillers = chillers.filter(c =>
      (c.customerName || '').toLowerCase().includes(term) ||
      (c.chillerCode || '').toLowerCase().includes(term) ||
      (c.branch || '').toLowerCase().includes(term) ||
      (c.customerAddress || '').toLowerCase().includes(term)
    );
  }

  // Filter by assignment status
  if (assignmentStatus === 'assigned') {
    chillers = chillers.filter(c => c.assignedAgentId !== null);
  } else if (assignmentStatus === 'unassigned') {
    chillers = chillers.filter(c => c.assignedAgentId === null);
  }

  // Scope by role/territory/branch
  if (req.user && !isAdminRole(req.user)) {
    const allowedRows = filterRowsByTerritory(rows, req.user, dbStore);
    const allowedIds = new Set(allowedRows.map(r => r.id));
    chillers = chillers.filter(c => allowedIds.has(c.id));
  }
  if (agentId && agentId !== 'All' && req.user?.role !== 'agent') {
    const aId = parseInt(agentId);
    chillers = chillers.filter(c => c.assignedAgentId === aId);
  }

  const latestBatch = dbStore.batches.find(b => b.id === latestBatchId) || null;

  res.json({
    success: true,
    selectedBatchId,
    latestBatchId,
    latestBatch,
    batches: !isAdminRole(req.user) ? [] : (dbStore.batches || []),
    totalDbLocations: !isAdminRole(req.user) ? chillers.length : dbStore.chillers.length,
    count: chillers.length,
    chillers
  });
});

router.get('/stats/rep-kpi', requireAuth, async (req, res) => {
  await ensureFreshCloudSync();

  let rows = [...(dbStore.chillers || [])];
  const isAgent = req.user && req.user.role === 'agent';
  const isAdminOrOwner = isAdminRole(req.user);

  if (!isAdminOrOwner) {
    rows = filterRowsByTerritory(rows, req.user, dbStore);
  }

  let branchRollups;
  if (isAdminOrOwner) {
    const groups = new Map();
    for (const r of rows) {
      const bName = (r.branch || '').toString().trim() || 'Unassigned';
      if (!groups.has(bName)) groups.set(bName, []);
      groups.get(bName).push(r);
    }
    branchRollups = Array.from(groups.entries())
      .map(([branch, groupRows]) => ({
        branch,
        ...computeKpiStats(groupRows, dbStore)
      }))
      .sort((a, b) => b.assignedCount - a.assignedCount);
  }

  const branchParam = (req.query.branch || '').toString().trim();
  const hasBranchFilter = branchParam && branchParam.toLowerCase() !== 'all';
  if (hasBranchFilter) {
    const target = branchParam.toLowerCase();
    rows = rows.filter(r => {
      const bName = ((r.branch || '').toString().trim() || 'Unassigned').toLowerCase();
      return bName === target;
    });
  }

  const stats = computeKpiStats(rows, dbStore);

  res.json({
    success: true,
    scope: isAgent ? 'territory' : 'aggregate',
    branchFilter: hasBranchFilter ? branchParam : 'All',
    ...stats,
    ...(isAdminOrOwner ? { branchRollups } : {})
  });
});

router.get('/chillers/:id/360', requireAuth, async (req, res) => {
  await ensureFreshCloudSync();

  const idParam = String(req.params.id || '').trim();
  const row = (dbStore.chillers || []).find(r =>
    String(r.id) === idParam ||
    (r.chiller_code || r.chillerCode || '').toLowerCase() === idParam.toLowerCase()
  );

  if (!row) {
    return res.status(404).json({ success: false, error: 'Chiller not found' });
  }

  if (req.user && !canUserAccessChiller(row, req.user, dbStore)) {
    return res.status(403).json({ success: false, error: 'Access denied: Chiller is not assigned to your territory' });
  }

  const chiller = formatChillerRecord(row, dbStore);
  const rawData = chiller.rawData || {};

  // 12-month Jan-Dec invoice summary
  const monthOrder = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const monthRegex = /^(jan|feb|mar|apr|may|jun|june|jul|july|aug|sep|oct|nov|dec)\b.*invoice/i;
  const matchedByMonth = new Map();

  for (const [key, val] of Object.entries(rawData)) {
    const match = key.trim().match(monthRegex);
    if (match) {
      let m = match[1].toLowerCase();
      if (m === 'june') m = 'jun';
      if (m === 'july') m = 'jul';
      const normalized = m.charAt(0).toUpperCase() + m.slice(1);
      if (!matchedByMonth.has(normalized)) {
        const amt = parseNumericValue(val);
        matchedByMonth.set(normalized, {
          month: normalized,
          label: key,
          amount: amt !== null ? Math.round(amt * 100) / 100 : 0
        });
      }
    }
  }

  const months = monthOrder.map(m => matchedByMonth.get(m) || {
    month: m,
    label: `${m} Invoice`,
    amount: 0
  });

  const sumMonths = Math.round(months.reduce((s, m) => s + m.amount, 0) * 100) / 100;
  const parsedYtd = parseNumericValue(rawData['YTD']);
  const ytd = parsedYtd !== null ? Math.round(parsedYtd * 100) / 100 : sumMonths;

  const nonZeroMonths = months.filter(m => m.amount > 0);
  const parsedAvg = parseNumericValue(rawData['Average / Month']);
  const avgPerMonth = parsedAvg !== null
    ? Math.round(parsedAvg * 100) / 100
    : (nonZeroMonths.length > 0 ? Math.round((ytd / nonZeroMonths.length) * 100) / 100 : 0);

  let latestMonthDeltaPct = null;
  let comparedMonthsLabel = null;
  if (nonZeroMonths.length >= 2) {
    const prevMonth = nonZeroMonths[nonZeroMonths.length - 2];
    const currMonth = nonZeroMonths[nonZeroMonths.length - 1];
    const prevAmt = prevMonth.amount;
    const currAmt = currMonth.amount;
    if (prevAmt > 0) {
      latestMonthDeltaPct = Math.round(((currAmt - prevAmt) / prevAmt) * 1000) / 10;
      comparedMonthsLabel = `${prevMonth.month} \u2192 ${currMonth.month}`;
    }
  }

  const invoiceSummary = {
    months,
    ytd,
    avgPerMonth,
    latestMonthDeltaPct,
    comparedMonthsLabel
  };

  // Visit Audit History (newest-first)
  const code = chiller.chillerCode;
  const custName = chiller.customerName;
  const formsById = new Map((dbStore.forms || []).map(f => [f.id, f.title]));
  const visitHistory = (dbStore.form_responses || [])
    .filter(r => {
      const codeMatch = code && r.chiller_code && r.chiller_code === code;
      const nameMatch = custName && r.customer_name && r.customer_name.toLowerCase() === custName.toLowerCase();
      return codeMatch || nameMatch;
    })
    .sort((a, b) => new Date(b.submitted_at || 0) - new Date(a.submitted_at || 0))
    .map(r => ({
      id: r.id,
      formId: r.form_id || null,
      formTitle: r.form_title || formsById.get(r.form_id) || 'Visit Audit Form',
      status: r.status || 'submitted',
      agentName: r.agent_name || null,
      adminFeedback: r.admin_feedback || null,
      submittedAt: r.submitted_at || null,
      reviewedAt: r.reviewed_at || null,
      answers: r.answers || {},
      attachments: r.attachments || []
    }));

  // Deterministic 5-tier Next Best Action (NBA)
  const effLower = String(chiller.efficiency || '').toLowerCase();
  const isUnderperformingOrCritical = effLower.includes('underperforming') ||
    effLower.includes('non-performing') ||
    effLower.includes('non performing') ||
    effLower.includes('critical') ||
    effLower.includes('at risk');
  const latestVisitDate = chiller.latestResponseDate ? new Date(chiller.latestResponseDate) : null;
  const isOlderThan30Days = latestVisitDate && !isNaN(latestVisitDate.getTime())
    ? (Date.now() - latestVisitDate.getTime()) > (30 * 24 * 60 * 60 * 1000)
    : false;

  let nextBestAction;
  if (chiller.visitStatus === 'reopened') {
    nextBestAction = {
      actionCode: 'reopened_audit',
      title: 'Resolve Reopened Audit',
      reason: chiller.adminFeedback
        ? `Admin feedback: ${chiller.adminFeedback}`
        : 'The latest visit audit was reopened by an admin and requires correction.',
      priority: 'high',
      suggestedAction: 'Resubmit Visit Audit'
    };
  } else if ((chiller.visitStatus === 'not_visited' || isOlderThan30Days) && isUnderperformingOrCritical) {
    nextBestAction = {
      actionCode: 'overdue_visit',
      title: 'Priority Recovery Visit',
      reason: `Chiller is ${chiller.efficiency || 'underperforming'} and has no recent completed audit.`,
      priority: 'high',
      suggestedAction: 'Complete Visit Audit'
    };
  } else if (latestMonthDeltaPct !== null && latestMonthDeltaPct <= -20) {
    nextBestAction = {
      actionCode: 'revenue_drop',
      title: 'Investigate Sales Drop & Check Stock',
      reason: `Latest invoice month dropped ${Math.abs(latestMonthDeltaPct)}% compared to the prior active month.`,
      priority: 'medium',
      suggestedAction: 'Pitch Restock / Promo'
    };
  } else if (chiller.visitStatus === 'not_visited') {
    nextBestAction = {
      actionCode: 'pending_visit',
      title: 'Schedule Routine Chiller Audit',
      reason: 'No visit audit has been recorded for this chiller yet.',
      priority: 'medium',
      suggestedAction: 'Complete Visit Audit'
    };
  } else {
    nextBestAction = {
      actionCode: 'healthy_upsell',
      title: 'Maintain & Cross-Sell New SKUs',
      reason: 'Chiller audit is up to date and performance is on track.',
      priority: 'low',
      suggestedAction: 'Check POSM & Upsell'
    };
  }

  res.json({
    success: true,
    chiller,
    invoiceSummary,
    visitHistory,
    nextBestAction
  });
});

router.get('/routes/daily', requireAuth, async (req, res) => {
  await ensureFreshCloudSync();

  let rows = [...(dbStore.chillers || [])];
  if (req.user && !isAdminRole(req.user)) {
    rows = filterRowsByTerritory(rows, req.user, dbStore);
  }

  const branchParam = (req.query.branch || '').toString().trim();
  if (branchParam && branchParam.toLowerCase() !== 'all') {
    const targetBranch = branchParam.toLowerCase();
    rows = rows.filter(r => ((r.branch || '').toString().trim() || 'Unassigned').toLowerCase() === targetBranch);
  }

  const visitDayParam = (req.query.visitDay || '').toString().trim();
  if (visitDayParam && visitDayParam.toLowerCase() !== 'all') {
    const targetDay = visitDayParam.toLowerCase();
    rows = rows.filter(r => {
      const rawData = parseRawData(r);
      const day = String(rawData['Visit Day'] || '').trim().toLowerCase();
      return day === targetDay;
    });
  }

  const pendingOnly = String(req.query.pendingOnly || '').toLowerCase() === 'true';
  const parsedLimit = parseInt(req.query.limit, 10);
  const limit = Number.isFinite(parsedLimit) ? Math.min(50, Math.max(1, parsedLimit)) : 25;

  let skippedNoCoordsCount = 0;
  const candidates = [];

  for (const r of rows) {
    const lat = Number(r.latitude);
    const lng = Number(r.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat === 0 || lng === 0) {
      skippedNoCoordsCount++;
      continue;
    }

    const code = r.chiller_code || r.chillerCode;
    const custName = r.customer_name || r.customerName || '';
    const visitInfo = getChillerVisitInfo(code, custName, dbStore);
    const visitStatus = visitInfo.visitStatus;

    if (pendingOnly && (visitStatus === 'submitted' || visitStatus === 'accepted')) {
      continue;
    }

    const eff = String(r.efficiency || '');
    const effLower = eff.toLowerCase();
    const isUnderperforming = effLower.includes('underperforming') ||
      effLower.includes('non-performing') ||
      effLower.includes('non performing') ||
      effLower.includes('critical') ||
      effLower.includes('at risk');

    let priorityScore = 0;
    const reasons = [];
    if (visitStatus === 'reopened') {
      priorityScore += 100;
      reasons.push('Reopened Audit');
    } else if (visitStatus === 'not_visited') {
      priorityScore += 60;
      reasons.push('Unvisited');
    } else {
      priorityScore += 10;
      reasons.push('Visited');
    }

    if (isUnderperforming) {
      priorityScore += 40;
      reasons.push(eff || 'Underperforming');
    }

    candidates.push({
      id: r.id,
      chillerCode: code,
      customerName: custName,
      customerAddress: r.customer_address || r.customerAddress || '',
      branch: r.branch || '',
      latitude: lat,
      longitude: lng,
      visitStatus,
      efficiency: eff,
      priorityScore,
      priorityReason: reasons.join(' + ')
    });
  }

  const reqLat = parseFloat(req.query.lat);
  const reqLng = parseFloat(req.query.lng);
  const hasOriginParam = Number.isFinite(reqLat) && Number.isFinite(reqLng) && reqLat !== 0 && reqLng !== 0;

  let origin = null;
  const stops = [];

  if (candidates.length > 0) {
    const remaining = [...candidates];
    let currentLat;
    let currentLng;

    if (hasOriginParam) {
      currentLat = reqLat;
      currentLng = reqLng;
      origin = { lat: reqLat, lng: reqLng };
    } else {
      // Start at highest-priorityScore stop
      remaining.sort((a, b) => b.priorityScore - a.priorityScore);
      const first = remaining.shift();
      origin = { lat: first.latitude, lng: first.longitude };
      stops.push({
        order: 1,
        ...first,
        legDistanceKm: 0,
        cumulativeKm: 0
      });
      currentLat = first.latitude;
      currentLng = first.longitude;
    }

    let cumulativeKm = 0;
    while (remaining.length > 0 && stops.length < limit) {
      let bestIdx = 0;
      let bestCost = Infinity;
      let bestDistKm = 0;

      for (let i = 0; i < remaining.length; i++) {
        const cand = remaining[i];
        const distKm = haversineKm(currentLat, currentLng, cand.latitude, cand.longitude);
        const weightedCost = distKm / (1 + cand.priorityScore / 100);
        if (weightedCost < bestCost) {
          bestCost = weightedCost;
          bestIdx = i;
          bestDistKm = distKm;
        }
      }

      const chosen = remaining.splice(bestIdx, 1)[0];
      const legDistanceKm = Math.round(bestDistKm * 100) / 100;
      cumulativeKm = Math.round((cumulativeKm + bestDistKm) * 100) / 100;

      stops.push({
        order: stops.length + 1,
        ...chosen,
        legDistanceKm,
        cumulativeKm
      });

      currentLat = chosen.latitude;
      currentLng = chosen.longitude;
    }
  } else if (hasOriginParam) {
    origin = { lat: reqLat, lng: reqLng };
  }

  const totalEstimatedKm = stops.length > 0 ? stops[stops.length - 1].cumulativeKm : 0;
  const estimatedDriveMinutes = Math.round((totalEstimatedKm / 30) * 60);

  res.json({
    success: true,
    scope: (req.user && req.user.role === 'agent') ? 'territory' : 'aggregate',
    origin,
    totalStops: stops.length,
    skippedNoCoordsCount,
    totalEstimatedKm,
    estimatedDriveMinutes,
    stops
  });
});

router.get('/stats/dashboard', requireAuth, async (req, res) => {
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
  const hasBranchFilter = branchParam && branchParam.toLowerCase() !== 'all';
  if (hasBranchFilter) {
    const targetBranch = branchParam.toLowerCase();
    rows = rows.filter(r => ((r.branch || '').toString().trim() || 'Unassigned').toLowerCase() === targetBranch);
  }

  let visitedCount = 0;
  let achSum = 0;
  let achCount = 0;
  let ytdInvoiceTotal = 0;
  let requiresMaintenance = 0;
  let scrapCount = 0;

  const efficiencyBuckets = { performing: 0, underperforming: 0, critical: 0, other: 0 };
  const branchGroups = new Map();
  const districtGroups = new Map();
  const maintenanceQueue = [];
  const scopedCodeSet = new Set();
  const scopedNameSet = new Set();
  let missingGpsCount = 0;
  let unspecifiedConditionCount = 0;
  let unknownEfficiencyCount = 0;

  for (const r of rows) {
    const code = r.chiller_code || r.chillerCode || '';
    const custName = r.customer_name || r.customerName || '';
    if (code) scopedCodeSet.add(String(code).toLowerCase());
    if (custName) scopedNameSet.add(custName.toLowerCase());

    const rawData = parseRawData(r);
    const visitInfo = getChillerVisitInfo(code, custName, dbStore);
    const isVisited = visitInfo.visitStatus === 'submitted' || visitInfo.visitStatus === 'accepted';
    if (isVisited) visitedCount++;

    const ach = extractChillerAchievement(r, rawData);
    if (ach !== null) {
      achSum += ach;
      achCount++;
    }

    const ytd = extractYtdInvoice(rawData);
    ytdInvoiceTotal += ytd;

    const normCond = normalizeCondition(r.condition);
    if (normCond === 'Requires Maintenance') requiresMaintenance++;
    else if (normCond === 'Scrap') scrapCount++;

    const bucket = classifyEfficiencyBucket(r, rawData);
    efficiencyBuckets[bucket]++;

    const missGps = isMissingGps(r);
    if (missGps) missingGpsCount++;
    if (isUnspecifiedCondition(r, rawData)) unspecifiedConditionCount++;
    if (isUnknownEfficiency(r, rawData)) unknownEfficiencyCount++;

    const dName = extractDistrictName(r, rawData);
    if (!districtGroups.has(dName)) {
      districtGroups.set(dName, {
        district: dName,
        totalAssets: 0,
        visitedCount: 0,
        achSum: 0,
        achCount: 0,
        ytdInvoiceTotal: 0,
        missingGpsCount: 0
      });
    }
    const dg = districtGroups.get(dName);
    dg.totalAssets++;
    if (isVisited) dg.visitedCount++;
    if (ach !== null) {
      dg.achSum += ach;
      dg.achCount++;
    }
    dg.ytdInvoiceTotal += ytd;
    if (missGps) dg.missingGpsCount++;

    const bName = (r.branch || '').toString().trim() || 'Unassigned';
    if (!branchGroups.has(bName)) {
      branchGroups.set(bName, {
        branch: bName,
        totalAssets: 0,
        visitedCount: 0,
        achSum: 0,
        achCount: 0,
        ytdInvoiceTotal: 0,
        requiresMaintenance: 0
      });
    }
    const bg = branchGroups.get(bName);
    bg.totalAssets++;
    if (isVisited) bg.visitedCount++;
    if (ach !== null) {
      bg.achSum += ach;
      bg.achCount++;
    }
    bg.ytdInvoiceTotal += ytd;
    if (normCond === 'Requires Maintenance' || normCond === 'Scrap') {
      bg.requiresMaintenance++;
    }

    if (normCond === 'Requires Maintenance' || normCond === 'Scrap') {
      maintenanceQueue.push({
        id: r.id,
        chillerCode: code,
        customerName: custName,
        customerAddress: r.customer_address || r.customerAddress || '',
        branch: bName,
        condition: normCond,
        efficiency: r.efficiency || '',
        latitude: r.latitude,
        longitude: r.longitude,
        lastUpdated: r.condition_updated_at || visitInfo.latestResponseDate || r.updated_at || null
      });
    }
  }

  maintenanceQueue.sort((a, b) => {
    if (a.condition === b.condition) return String(a.chillerCode).localeCompare(String(b.chillerCode));
    return a.condition === 'Requires Maintenance' ? -1 : 1;
  });

  const totalAssets = rows.length;
  const activeOperational = Math.max(0, totalAssets - requiresMaintenance - scrapCount);
  const pendingCount = Math.max(0, totalAssets - visitedCount);
  const completionRate = totalAssets > 0 ? Math.round((visitedCount / totalAssets) * 1000) / 10 : 0;
  const avgAchievement = achCount > 0 ? Math.round((achSum / achCount) * 10) / 10 : 0;
  const roundedYtd = Math.round(ytdInvoiceTotal * 100) / 100;

  const branchLeaderboard = Array.from(branchGroups.values())
    .map(bg => ({
      branch: bg.branch,
      totalAssets: bg.totalAssets,
      visitedCount: bg.visitedCount,
      pendingCount: Math.max(0, bg.totalAssets - bg.visitedCount),
      completionRate: bg.totalAssets > 0 ? Math.round((bg.visitedCount / bg.totalAssets) * 1000) / 10 : 0,
      avgAchievement: bg.achCount > 0 ? Math.round((bg.achSum / bg.achCount) * 10) / 10 : 0,
      ytdInvoiceTotal: Math.round(bg.ytdInvoiceTotal * 100) / 100,
      requiresMaintenance: bg.requiresMaintenance
    }))
    .sort((a, b) => (b.avgAchievement - a.avgAchievement) || (b.totalAssets - a.totalAssets));

  const totalChecks = totalAssets * 3;
  const missingChecks = missingGpsCount + unspecifiedConditionCount + unknownEfficiencyCount;
  const completenessScorePct = totalChecks > 0
    ? Math.round(((totalChecks - missingChecks) / totalChecks) * 1000) / 10
    : 100;

  const dataCompleteness = {
    missingGpsCount,
    unspecifiedConditionCount,
    unknownEfficiencyCount,
    completenessScorePct
  };

  const districtRollups = Array.from(districtGroups.values())
    .map(dg => ({
      district: dg.district,
      totalAssets: dg.totalAssets,
      visitedCount: dg.visitedCount,
      pendingCount: Math.max(0, dg.totalAssets - dg.visitedCount),
      completionRate: dg.totalAssets > 0 ? Math.round((dg.visitedCount / dg.totalAssets) * 1000) / 10 : 0,
      avgAchievement: dg.achCount > 0 ? Math.round((dg.achSum / dg.achCount) * 10) / 10 : 0,
      ytdInvoiceTotal: Math.round(dg.ytdInvoiceTotal * 100) / 100,
      missingGpsCount: dg.missingGpsCount
    }))
    .sort((a, b) => (b.totalAssets - a.totalAssets) || (b.avgAchievement - a.avgAchievement));

  let agentLeaderboard = [];
  if (req.user.role !== 'technician') {
    let candidateAgents = [...(dbStore.agents || [])];
    if (req.user.role === 'agent') {
      candidateAgents = candidateAgents.filter(a => a.id === req.user.agentId);
    } else if (req.user.role === 'supervisor') {
      const supervisedSet = getSupervisedAgentIdSet(req.user);
      if (supervisedSet.size > 0) {
        candidateAgents = candidateAgents.filter(a => supervisedSet.has(a.id));
      } else {
        const scopedAssignments = new Set();
        for (const r of rows) {
          const code = r.chiller_code || r.chillerCode;
          const custName = (r.customer_name || r.customerName || '').toLowerCase();
          const as = (dbStore.assignments || []).find(x =>
            (code && x.chiller_code === code) ||
            (custName && x.customer_name && x.customer_name.toLowerCase() === custName)
          );
          if (as) scopedAssignments.add(as.agent_id);
        }
        candidateAgents = candidateAgents.filter(a => scopedAssignments.has(a.id));
      }
    }

    agentLeaderboard = candidateAgents
      .map(agent => {
        const agentRows = rows.filter(r => isChillerAssignedToAgent(r, agent.id, dbStore));
        const stats = computeKpiStats(agentRows, dbStore);
        return {
          agentId: agent.id,
          agentName: agent.name,
          area: agent.area || '',
          assignedCount: stats.assignedCount,
          visitedCount: stats.visitedCount,
          pendingCount: stats.pendingCount,
          completionRate: stats.completionRate,
          avgAchievement: stats.avgAchievement
        };
      })
      .sort((a, b) => (b.completionRate - a.completionRate) || (b.visitedCount - a.visitedCount));
  }

  let pendingReviewsCount = 0;
  if (req.user.role === 'supervisor') {
    const supervisedSet = getSupervisedAgentIdSet(req.user);
    pendingReviewsCount = (dbStore.form_responses || []).filter(resp => {
      if ((resp.status || '').toLowerCase() !== 'submitted') return false;
      if (supervisedSet.has(Number(resp.agent_id))) return true;
      const chiller = (dbStore.chillers || []).find(c =>
        (resp.chiller_code && (c.chiller_code || c.chillerCode) === resp.chiller_code) ||
        (resp.customer_name && (c.customer_name || c.customerName || '').toLowerCase() === resp.customer_name.toLowerCase())
      );
      return chiller ? canUserAccessChiller(chiller, req.user, dbStore) : false;
    }).length;
  } else if (req.user.role !== 'agent' && req.user.role !== 'technician') {
    pendingReviewsCount = (dbStore.form_responses || []).filter(resp => {
      if ((resp.status || '').toLowerCase() !== 'submitted') return false;
      const rCode = (resp.chiller_code || '').toLowerCase();
      const rName = (resp.customer_name || '').toLowerCase();
      return (rCode && scopedCodeSet.has(rCode)) || (rName && scopedNameSet.has(rName));
    }).length;
  }

  const scope = isAdminRole(req.user)
    ? 'global'
    : (req.user.role === 'supervisor' ? 'branch' : (req.user.role === 'technician' ? 'maintenance' : 'territory'));

  res.json({
    success: true,
    role: req.user.role,
    scope,
    branchFilter: hasBranchFilter ? branchParam : 'All',
    kpis: {
      totalAssets,
      activeOperational,
      requiresMaintenance,
      scrapCount,
      visitedCount,
      pendingCount,
      completionRate,
      avgAchievement,
      ytdInvoiceTotal: roundedYtd
    },
    conditionBreakdown: {
      operational: activeOperational,
      requiresMaintenance,
      scrap: scrapCount
    },
    efficiencyBuckets,
    dataCompleteness,
    districtRollups,
    branchLeaderboard,
    agentLeaderboard,
    pendingReviewsCount,
    maintenanceQueue
  });
});

router.patch('/chillers/:id/condition', requireAuth, requireRoles('owner', 'admin', 'regional_manager', 'supervisor', 'technician'), async (req, res) => {
  await ensureFreshCloudSync();

  const result = applyConditionUpdate(dbStore, req.user, req.params.id, req.body);
  if (!result.ok) {
    return res.status(result.statusCode).json({ success: false, error: result.error });
  }

  let autoTicket = null;
  if (result.chiller.condition === 'Requires Maintenance' || result.chiller.condition === 'Scrap') {
    autoTicket = autoCreateTicketForChiller(dbStore, result.chiller, req.user, req.body?.notes);
  }

  req.auditEvent = result.auditEvent;
  saveDbStore(dbStore);
  await persistToBlobIfConfigured(dbStore);

  res.json({
    success: true,
    message: 'Chiller condition updated',
    chiller: formatChillerRecord(result.chiller, dbStore),
    ticket: autoTicket
  });
});

// GET /api/stats/gamification (role-scoped)
router.get('/stats/gamification', requireAuth, async (req, res) => {
  await ensureFreshCloudSync();

  let rows = filterRowsByTerritory(dbStore.chillers || [], req.user, dbStore);
  const branchParam = req.query.branch ? String(req.query.branch).trim() : '';
  if (branchParam && branchParam.toLowerCase() !== 'all' && isAdminRole(req.user)) {
    rows = rows.filter(r => (r.branch || '').toString().trim().toLowerCase() === branchParam.toLowerCase());
  }

  const isPerfectChiller = (r) => {
    const cond = normalizeCondition(r.condition);
    if (cond !== 'Operational') return false;
    const rawData = parseRawData(r);
    if (classifyEfficiencyBucket(r, rawData) !== 'performing') return false;
    const code = r.chiller_code || r.chillerCode;
    const custName = r.customer_name || r.customerName || '';
    const visitInfo = getChillerVisitInfo(code, custName, dbStore);
    return visitInfo.visitStatus === 'submitted' || visitInfo.visitStatus === 'accepted';
  };

  let perfectChillersCount = 0;
  for (const r of rows) {
    if (isPerfectChiller(r)) {
      perfectChillersCount++;
    }
  }
  const totalEvaluated = rows.length;
  const perfectRate = totalEvaluated > 0
    ? Math.round((perfectChillersCount / totalEvaluated) * 1000) / 10
    : 0;

  let agents = [...(dbStore.agents || [])];
  if (req.user.role === 'agent') {
    agents = agents.filter(a => a.id === req.user.agentId);
  } else if (req.user.role === 'supervisor') {
    const supervisedSet = getSupervisedAgentIdSet(req.user);
    agents = supervisedSet.size > 0 ? agents.filter(a => supervisedSet.has(a.id)) : [];
  } else if (req.user.role === 'technician') {
    agents = [];
  }

  const responses = dbStore.form_responses || [];
  const computeStreakDays = (agentId) => {
    const daySet = new Set();
    for (const resp of responses) {
      if (resp.agent_id === agentId && resp.submitted_at) {
        const d = new Date(resp.submitted_at);
        if (!Number.isNaN(d.getTime())) {
          daySet.add(d.toISOString().slice(0, 10));
        }
      }
    }
    if (daySet.size === 0) return 0;
    const sortedDays = Array.from(daySet).sort((a, b) => b.localeCompare(a));
    let streak = 1;
    for (let i = 1; i < sortedDays.length; i++) {
      const prev = new Date(`${sortedDays[i - 1]}T00:00:00Z`);
      const curr = new Date(`${sortedDays[i]}T00:00:00Z`);
      const diffDays = Math.round((prev - curr) / (24 * 3600 * 1000));
      if (diffDays === 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  };

  const leaderboard = agents.map(agent => {
    const agentRows = rows.filter(r => isChillerAssignedToAgent(r, agent.id, dbStore));
    const assignedCount = agentRows.length;
    let visitedCount = 0;
    let perfectCount = 0;

    for (const r of agentRows) {
      const code = r.chiller_code || r.chillerCode;
      const custName = r.customer_name || r.customerName || '';
      const visitInfo = getChillerVisitInfo(code, custName, dbStore);
      if (visitInfo.visitStatus === 'submitted' || visitInfo.visitStatus === 'accepted') {
        visitedCount++;
      }
      if (isPerfectChiller(r)) {
        perfectCount++;
      }
    }

    const streakDays = computeStreakDays(agent.id);
    const points = (visitedCount * 10) + (perfectCount * 25) + (streakDays * 5);

    return {
      agentId: agent.id,
      name: agent.name,
      area: agent.area || '',
      points,
      streakDays,
      perfectCount,
      visitedCount,
      assignedCount
    };
  }).sort((a, b) => {
    if (b.points !== a.points) return b.points - a.points;
    if (b.perfectCount !== a.perfectCount) return b.perfectCount - a.perfectCount;
    return b.visitedCount - a.visitedCount;
  });

  res.json({
    success: true,
    perfectChillersCount,
    totalEvaluated,
    perfectRate,
    leaderboard
  });
});

router.delete('/chillers/clear', requireAdmin, (req, res) => {
  dbStore.chillers = [];
  saveDbStore(dbStore);
  res.json({ success: true, message: 'All active database records cleared' });
});

export default router;
