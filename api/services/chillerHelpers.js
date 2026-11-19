import { dbStore, loadDbStore } from './storage.js';
import { isAdminRole } from '../middleware/auth.js';

export function getChillerVisitInfo(chillerCode, customerName, store = null) {
  const currentStore = store || dbStore || loadDbStore();
  const responses = (currentStore.form_responses || []).filter(r => {
    const codeMatch = chillerCode && r.chiller_code && r.chiller_code === chillerCode;
    const nameMatch = customerName && r.customer_name && r.customer_name.toLowerCase() === customerName.toLowerCase();
    return codeMatch || nameMatch;
  });

  if (responses.length === 0) {
    return {
      visitStatus: 'not_visited',
      latestResponseId: null,
      latestResponseDate: null,
      adminFeedback: null,
      formId: null
    };
  }

  const sorted = [...responses].sort((a, b) => new Date(b.submitted_at || 0) - new Date(a.submitted_at || 0));
  const latest = sorted[0];

  return {
    visitStatus: latest.status || 'submitted',
    latestResponseId: latest.id,
    latestResponseDate: latest.submitted_at,
    adminFeedback: latest.admin_feedback || null,
    formId: latest.form_id || null
  };
}

export function parseRawData(r) {
  if (!r) return {};
  if (typeof r.raw_data_json === 'string') {
    try {
      return JSON.parse(r.raw_data_json || '{}') || {};
    } catch (_) {
      return {};
    }
  }
  return r.rawData || r.raw_data_json || {};
}

export function getAgentAssignedSets(agentId, store = null) {
  const currentStore = store || dbStore || loadDbStore();
  const assignments = (currentStore.assignments || []).filter(as => as.agent_id === agentId);
  const assignedCodes = new Set(assignments.map(as => as.chiller_code).filter(Boolean));
  const assignedNames = new Set(assignments.map(as => (as.customer_name || '').toLowerCase()).filter(Boolean));
  return { assignedCodes, assignedNames };
}

export function isChillerAssignedToAgent(r, agentId, store = null) {
  const { assignedCodes, assignedNames } = getAgentAssignedSets(agentId, store);
  const code = r.chiller_code || r.chillerCode;
  const name = (r.customer_name || r.customerName || '').toLowerCase();
  return Boolean((code && assignedCodes.has(code)) || (name && assignedNames.has(name)));
}

export function getSupervisedAgentIdSet(user) {
  if (!user || !Array.isArray(user.supervisedAgentIds)) return new Set();
  return new Set(user.supervisedAgentIds.map(id => Number(id)).filter(id => Number.isFinite(id)));
}

export function canUserAccessChiller(row, user, store = null) {
  if (!user) return false;
  if (isAdminRole(user)) return true;

  if (user.role === 'agent') {
    return isChillerAssignedToAgent(row, user.agentId, store);
  }

  if (user.role === 'supervisor') {
    const userBranch = (user.branch || '').toString().trim().toLowerCase();
    const rowBranch = (row.branch || '').toString().trim().toLowerCase();
    const supervisedSet = getSupervisedAgentIdSet(user);

    if (!userBranch && supervisedSet.size === 0) return false;
    if (userBranch && rowBranch && rowBranch === userBranch) return true;

    for (const aId of supervisedSet) {
      if (isChillerAssignedToAgent(row, aId, store)) return true;
    }
    return false;
  }

  if (user.role === 'technician') {
    const userBranch = (user.branch || '').toString().trim().toLowerCase();
    if (!userBranch) return true;
    const rowBranch = (row.branch || '').toString().trim().toLowerCase();
    return rowBranch === userBranch;
  }

  return false;
}

export function filterRowsByTerritory(rows, user, store = null) {
  if (!user || isAdminRole(user)) return rows;

  if (user.role === 'agent') {
    const { assignedCodes, assignedNames } = getAgentAssignedSets(user.agentId, store);
    return rows.filter(r => {
      const code = r.chiller_code || r.chillerCode;
      const name = (r.customer_name || r.customerName || '').toLowerCase();
      return (code && assignedCodes.has(code)) || (name && assignedNames.has(name));
    });
  }

  if (user.role === 'supervisor') {
    const userBranch = (user.branch || '').toString().trim().toLowerCase();
    const supervisedSet = getSupervisedAgentIdSet(user);
    if (!userBranch && supervisedSet.size === 0) return [];

    const combinedCodes = new Set();
    const combinedNames = new Set();
    for (const aId of supervisedSet) {
      const sets = getAgentAssignedSets(aId, store);
      sets.assignedCodes.forEach(c => combinedCodes.add(c));
      sets.assignedNames.forEach(n => combinedNames.add(n));
    }

    return rows.filter(r => {
      const rowBranch = (r.branch || '').toString().trim().toLowerCase();
      if (userBranch && rowBranch && rowBranch === userBranch) return true;
      const code = r.chiller_code || r.chillerCode;
      const name = (r.customer_name || r.customerName || '').toLowerCase();
      return (code && combinedCodes.has(code)) || (name && combinedNames.has(name));
    });
  }

  if (user.role === 'technician') {
    const userBranch = (user.branch || '').toString().trim().toLowerCase();
    if (!userBranch) return rows;
    return rows.filter(r => (r.branch || '').toString().trim().toLowerCase() === userBranch);
  }

  return [];
}

export function normalizeCondition(condition) {
  const str = String(condition || '').trim().toLowerCase();
  if (str.includes('scrap')) return 'Scrap';
  if (str.includes('maint') || str.includes('damaged')) return 'Requires Maintenance';
  return 'Operational';
}

export function extractYtdInvoice(rawData) {
  if (!rawData || typeof rawData !== 'object') return 0;
  if (Object.prototype.hasOwnProperty.call(rawData, 'YTD')) {
    const ytd = parseNumericValue(rawData['YTD']);
    if (ytd !== null) return ytd;
  }
  let sum = 0;
  let foundMonth = false;
  const monthRegex = /^(jan|feb|mar|apr|may|jun|june|jul|july|aug|sep|oct|nov|dec)\b.*invoice/i;
  for (const [k, v] of Object.entries(rawData)) {
    if (monthRegex.test(k)) {
      const val = parseNumericValue(v);
      if (val !== null) {
        sum += val;
        foundMonth = true;
      }
    }
  }
  return foundMonth ? sum : 0;
}

export function classifyEfficiencyBucket(r, rawData) {
  const effLower = String(r.efficiency || '').trim().toLowerCase();
  if (effLower.includes('critical') || effLower.includes('at risk') || effLower === 'zero') {
    return 'critical';
  }
  if (effLower.includes('underperforming') || effLower.includes('non-performing') || effLower.includes('non performing')) {
    return 'underperforming';
  }
  if (effLower.includes('performing')) {
    return 'performing';
  }
  const ach = extractChillerAchievement(r, rawData);
  if (ach === null) return 'other';
  if (ach >= 100) return 'performing';
  if (ach >= 75) return 'underperforming';
  return 'critical';
}

export function parseNumericValue(val) {
  if (val === null || val === undefined) return null;
  if (typeof val === 'number') return Number.isFinite(val) ? val : null;
  const str = String(val).trim();
  if (!str || str === '-' || str.toLowerCase() === 'n/a' || str.toLowerCase() === 'na') return null;
  const cleaned = str.replace(/[,%\s]/g, '');
  const num = Number(cleaned);
  return Number.isFinite(num) ? num : null;
}

export function extractChillerAchievement(r, rawData) {
  const achKeys = ['Month Ach.', 'Month Ach %', 'Achievement', 'Achievement %', 'Ach %'];
  for (const key of achKeys) {
    if (Object.prototype.hasOwnProperty.call(rawData, key)) {
      const parsed = parseNumericValue(rawData[key]);
      if (parsed !== null) return parsed;
    }
  }
  const effStr = String(r.efficiency || '').trim();
  if (effStr.includes('%')) {
    const parsedEff = parseNumericValue(effStr);
    if (parsedEff !== null) return parsedEff;
  }
  const effLower = effStr.toLowerCase();
  if (!effLower) return null;
  if (effLower.includes('performing') && !effLower.includes('non') && !effLower.includes('under')) return 100;
  if (effLower.includes('underperforming') || effLower.includes('non-performing') || effLower.includes('non performing')) return 50;
  if (effLower.includes('critical') || effLower.includes('at risk') || effLower === 'zero') return 25;
  return null;
}

export function computeKpiStats(rows, store = null) {
  let visitedCount = 0;
  let achSum = 0;
  let achCount = 0;

  for (const r of rows) {
    const code = r.chiller_code || r.chillerCode;
    const custName = r.customer_name || r.customerName || '';
    const visitInfo = getChillerVisitInfo(code, custName, store);
    if (visitInfo.visitStatus === 'submitted' || visitInfo.visitStatus === 'accepted') {
      visitedCount++;
    }
    const rawData = parseRawData(r);
    const ach = extractChillerAchievement(r, rawData);
    if (ach !== null) {
      achSum += ach;
      achCount++;
    }
  }

  const assignedCount = rows.length;
  const pendingCount = assignedCount - visitedCount;
  const completionRate = assignedCount > 0 ? Math.round((visitedCount / assignedCount) * 1000) / 10 : 0;
  const avgAchievement = achCount > 0 ? Math.round((achSum / achCount) * 10) / 10 : 0;

  return {
    assignedCount,
    visitedCount,
    pendingCount,
    completionRate,
    avgAchievement
  };
}

export function haversineKm(lat1, lng1, lat2, lng2) {
  const toRad = deg => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function formatChillerRecord(r, store = null) {
  const currentStore = store || dbStore;
  const code = r.chiller_code || r.chillerCode;
  const custName = r.customer_name || r.customerName || '';
  const visitInfo = getChillerVisitInfo(code, custName, currentStore);
  const assignment = (currentStore.assignments || []).find(as =>
    (code && as.chiller_code === code) ||
    (custName && as.customer_name && as.customer_name.toLowerCase() === custName.toLowerCase())
  );
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
    assignedAgentName: assignment ? (assignment.agent_name || null) : null,
    visitStatus: visitInfo.visitStatus,
    latestResponseId: visitInfo.latestResponseId,
    latestResponseDate: visitInfo.latestResponseDate,
    adminFeedback: visitInfo.adminFeedback,
    formId: visitInfo.formId,
    rawData: parseRawData(r)
  };
}

export function extractDistrictName(r, rawData) {
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

export function isMissingGps(r) {
  const lat = parseNumericValue(r.latitude);
  const lng = parseNumericValue(r.longitude);
  return lat === null || lng === null || (lat === 0 && lng === 0);
}

export function isUnspecifiedCondition(r, rawData) {
  const cond = r.condition || rawData?.['Condition'] || rawData?.['Condiiton'] || '';
  const s = String(cond).trim().toLowerCase();
  return !s || s === 'unknown' || s === 'unspecified' || s === 'n/a' || s === 'na' || s === '-';
}

export function isUnknownEfficiency(r, rawData) {
  const eff = String(r.efficiency || '').trim().toLowerCase();
  const hasEffText = Boolean(eff && eff !== 'unknown' && eff !== 'unspecified' && eff !== 'n/a' && eff !== 'na' && eff !== '-');
  return !hasEffText && extractChillerAchievement(r, rawData) === null;
}
