import express from 'express';
import { requireAuth, requireAdmin } from '../middleware/auth.js';
import { dbStore, saveDbStore, ensureFreshCloudSync } from '../services/storage.js';
import {
  getChillerVisitInfo,
  parseRawData,
  isChillerAssignedToAgent,
  filterRowsByTerritory,
  parseNumericValue,
  computeKpiStats,
  haversineKm,
  formatChillerRecord
} from '../services/chillerHelpers.js';

const router = express.Router();

router.get('/chillers', requireAuth, async (req, res) => {
  await ensureFreshCloudSync();
  const { efficiency, customerType, search, batchId } = req.query;
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

  // If the requester is an Agent, strictly restrict to their assigned locations ONLY!
  if (req.user && req.user.role === 'agent') {
    rows = filterRowsByTerritory(rows, req.user, dbStore);
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

  // If requester is an agent, strictly isolate to their assigned chillers only
  if (req.user && req.user.role === 'agent') {
    const myAgentId = req.user.agentId;
    chillers = chillers.filter(c => c.assignedAgentId === myAgentId);
  } else if (agentId && agentId !== 'All') {
    const aId = parseInt(agentId);
    chillers = chillers.filter(c => c.assignedAgentId === aId);
  }

  const latestBatch = dbStore.batches.find(b => b.id === latestBatchId) || null;

  res.json({
    success: true,
    selectedBatchId,
    latestBatchId,
    latestBatch,
    batches: req.user?.role === 'agent' ? [] : (dbStore.batches || []),
    totalDbLocations: req.user?.role === 'agent' ? chillers.length : dbStore.chillers.length,
    count: chillers.length,
    chillers
  });
});

router.get('/stats/rep-kpi', requireAuth, async (req, res) => {
  await ensureFreshCloudSync();

  let rows = [...(dbStore.chillers || [])];
  const isAgent = req.user && req.user.role === 'agent';
  const isAdminOrOwner = req.user && (req.user.role === 'admin' || req.user.role === 'owner');

  if (isAgent) {
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

  if (req.user && req.user.role === 'agent' && !isChillerAssignedToAgent(row, req.user.agentId, dbStore)) {
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
  if (nonZeroMonths.length >= 2) {
    const prevAmt = nonZeroMonths[nonZeroMonths.length - 2].amount;
    const currAmt = nonZeroMonths[nonZeroMonths.length - 1].amount;
    if (prevAmt > 0) {
      latestMonthDeltaPct = Math.round(((currAmt - prevAmt) / prevAmt) * 1000) / 10;
    }
  }

  const invoiceSummary = {
    months,
    ytd,
    avgPerMonth,
    latestMonthDeltaPct
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

  const isAgent = req.user && req.user.role === 'agent';
  let rows = [...(dbStore.chillers || [])];
  if (isAgent) {
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
    scope: isAgent ? 'territory' : 'aggregate',
    origin,
    totalStops: stops.length,
    skippedNoCoordsCount,
    totalEstimatedKm,
    estimatedDriveMinutes,
    stops
  });
});

router.delete('/chillers/clear', requireAdmin, (req, res) => {
  dbStore.chillers = [];
  saveDbStore(dbStore);
  res.json({ success: true, message: 'All active database records cleared' });
});

export default router;
