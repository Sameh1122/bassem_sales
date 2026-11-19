import { canUserAccessChiller, haversineKm } from './chillerHelpers.js';

const FORM_RESPONSE_ROLES = new Set(['owner', 'admin', 'regional_manager', 'supervisor', 'agent']);
const CONDITION_UPDATE_ROLES = new Set(['owner', 'admin', 'regional_manager', 'supervisor', 'technician']);
const ALLOWED_CONDITIONS = ['Operational', 'Requires Maintenance', 'Scrap'];

function isPresentCoord(val) {
  return val !== undefined && val !== null && String(val).trim() !== '';
}

export function normalizeAttachments(attachments) {
  if (!Array.isArray(attachments)) return [];
  const normalized = [];
  for (const item of attachments) {
    if (typeof item === 'string') {
      const trimmed = item.trim();
      if (trimmed) normalized.push(trimmed);
      continue;
    }
    if (item && typeof item === 'object') {
      const url = typeof item.url === 'string' ? item.url.trim() : '';
      if (!url) continue;
      const entry = { url };
      if (typeof item.filename === 'string' && item.filename.trim()) {
        entry.filename = item.filename.trim().slice(0, 255);
      }
      if (item.watermark && typeof item.watermark === 'object') {
        const wm = item.watermark;
        const lat = isPresentCoord(wm.lat) ? Number(wm.lat) : null;
        const lng = isPresentCoord(wm.lng) ? Number(wm.lng) : null;
        entry.watermark = {
          capturedAt: typeof wm.capturedAt === 'string' && wm.capturedAt.trim()
            ? wm.capturedAt.trim().slice(0, 64)
            : null,
          lat: lat !== null && Number.isFinite(lat) && lat >= -90 && lat <= 90 ? lat : null,
          lng: lng !== null && Number.isFinite(lng) && lng >= -180 && lng <= 180 ? lng : null,
          agentName: typeof wm.agentName === 'string' && wm.agentName.trim()
            ? wm.agentName.trim().slice(0, 120)
            : null,
          chillerCode: typeof wm.chillerCode === 'string' && wm.chillerCode.trim()
            ? wm.chillerCode.trim().slice(0, 80)
            : null
        };
      }
      normalized.push(entry);
    }
  }
  return normalized;
}

export function computeGeofence(rawLat, rawLng, chiller) {
  const hasLat = isPresentCoord(rawLat);
  const hasLng = isPresentCoord(rawLng);

  if (!hasLat && !hasLng) {
    return {
      ok: true,
      checkInLat: null,
      checkInLng: null,
      checkInDistanceM: null,
      geofenceVerified: null
    };
  }

  if (hasLat !== hasLng) {
    return {
      ok: false,
      statusCode: 400,
      error: 'Both checkInLat and checkInLng must be provided together'
    };
  }

  const lat = Number(rawLat);
  const lng = Number(rawLng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return {
      ok: false,
      statusCode: 400,
      error: 'Invalid checkInLat or checkInLng: must be finite WGS84 coordinates (lat [-90, 90], lng [-180, 180])'
    };
  }

  let checkInDistanceM = null;
  let geofenceVerified = null;

  if (chiller) {
    const chillerLat = Number(chiller.latitude);
    const chillerLng = Number(chiller.longitude);
    if (
      Number.isFinite(chillerLat) &&
      Number.isFinite(chillerLng) &&
      !(chillerLat === 0 && chillerLng === 0) &&
      chillerLat >= -90 && chillerLat <= 90 &&
      chillerLng >= -180 && chillerLng <= 180
    ) {
      checkInDistanceM = Math.round(haversineKm(lat, lng, chillerLat, chillerLng) * 1000);
      geofenceVerified = checkInDistanceM <= 100;
    }
  }

  return {
    ok: true,
    checkInLat: lat,
    checkInLng: lng,
    checkInDistanceM,
    geofenceVerified
  };
}

export function processFormResponseSubmission(store, user, payload) {
  if (!user || !FORM_RESPONSE_ROLES.has(user.role)) {
    return { ok: false, statusCode: 403, error: 'Access forbidden. Insufficient role permissions.' };
  }

  const body = payload && typeof payload === 'object' ? payload : {};
  const {
    form_id,
    chiller_code,
    customer_name,
    answers,
    attachments,
    checkInLat: camelLat,
    checkInLng: camelLng,
    check_in_lat: snakeLat,
    check_in_lng: snakeLng
  } = body;

  if (!form_id) {
    return { ok: false, statusCode: 400, error: 'form_id is required' };
  }

  const form = (store.forms || []).find(f => f.id === parseInt(form_id, 10));
  if (!form) {
    return { ok: false, statusCode: 404, error: 'Form not found' };
  }

  const cleanCode = (chiller_code || '').toString().trim();
  const cleanCust = (customer_name || '').toString().trim();
  const cleanCustLower = cleanCust.toLowerCase();

  const chiller = (store.chillers || []).find(c =>
    (cleanCode && (c.chiller_code || c.chillerCode) === cleanCode) ||
    (cleanCustLower && (c.customer_name || c.customerName || '').toLowerCase() === cleanCustLower)
  );

  if (user.role === 'agent') {
    const assignedAgents = form.assigned_agent_ids || [];
    if (assignedAgents.length > 0 && !assignedAgents.includes(user.agentId)) {
      return { ok: false, statusCode: 403, error: 'Access denied: You are not assigned to this form' };
    }

    const isAssigned = (store.assignments || []).some(as =>
      as.agent_id === user.agentId && (
        (cleanCode && as.chiller_code === cleanCode) ||
        (cleanCustLower && as.customer_name && as.customer_name.toLowerCase() === cleanCustLower)
      )
    );

    if (!isAssigned) {
      return {
        ok: false,
        statusCode: 403,
        error: 'Access denied: Chiller or customer is not assigned to your territory'
      };
    }
  } else if (user.role === 'supervisor') {
    if (!chiller || !canUserAccessChiller(chiller, user, store)) {
      return {
        ok: false,
        statusCode: 403,
        error: 'Access denied: Chiller or customer is outside your branch/team scope'
      };
    }
  }

  const rawLat = camelLat !== undefined ? camelLat : snakeLat;
  const rawLng = camelLng !== undefined ? camelLng : snakeLng;
  const geo = computeGeofence(rawLat, rawLng, chiller);
  if (!geo.ok) {
    return { ok: false, statusCode: geo.statusCode, error: geo.error };
  }

  const nowIso = new Date().toISOString();
  store.form_responses = store.form_responses || [];
  let newId = Date.now();
  while (store.form_responses.some(r => r.id === newId)) {
    newId += 1;
  }

  const agentId = user.role === 'agent' ? user.agentId : (user.id || 0);
  const agentName = user.name || user.username;

  const newResponse = {
    id: newId,
    form_id: form.id,
    form_title: form.title,
    chiller_code: cleanCode,
    customer_name: cleanCust,
    agent_id: agentId,
    agent_name: agentName,
    answers: (answers && typeof answers === 'object') ? answers : {},
    attachments: normalizeAttachments(attachments),
    status: 'submitted',
    admin_feedback: '',
    submitted_at: nowIso,
    reviewed_at: null,
    reviewed_by: null,
    check_in_lat: geo.checkInLat,
    check_in_lng: geo.checkInLng,
    check_in_distance_m: geo.checkInDistanceM,
    geofence_verified: geo.geofenceVerified,
    checkInLat: geo.checkInLat,
    checkInLng: geo.checkInLng,
    checkInDistanceM: geo.checkInDistanceM,
    geofenceVerified: geo.geofenceVerified
  };

  store.form_responses.push(newResponse);
  if (chiller) {
    chiller.updated_at = nowIso;
  }

  return { ok: true, statusCode: 201, response: newResponse };
}

export function applyConditionUpdate(store, user, idParam, body) {
  if (!user || !CONDITION_UPDATE_ROLES.has(user.role)) {
    return { ok: false, statusCode: 403, error: 'Access forbidden. Insufficient role permissions.' };
  }

  const cleanId = String(idParam || '').trim();
  const chiller = (store.chillers || []).find(r =>
    String(r.id) === cleanId ||
    (r.chiller_code || r.chillerCode || '').toLowerCase() === cleanId.toLowerCase()
  );

  if (!chiller) {
    return { ok: false, statusCode: 404, error: 'Chiller not found' };
  }

  if ((user.role === 'supervisor' || user.role === 'technician') && !canUserAccessChiller(chiller, user, store)) {
    return { ok: false, statusCode: 403, error: 'Access denied: Chiller is outside your assigned scope' };
  }

  const payload = body && typeof body === 'object' ? body : {};
  const condition = typeof payload.condition === 'string' ? payload.condition.trim() : '';
  if (!ALLOWED_CONDITIONS.includes(condition)) {
    return {
      ok: false,
      statusCode: 400,
      error: `Invalid condition. Must be one of: ${ALLOWED_CONDITIONS.join(', ')}`
    };
  }

  const rawNotes = typeof payload.notes === 'string' ? payload.notes.trim().slice(0, 500) : '';
  const previousCondition = chiller.condition || 'Operational';
  const chillerCode = chiller.chiller_code || chiller.chillerCode || String(chiller.id);
  const nowIso = new Date().toISOString();

  chiller.condition = condition;
  chiller.condition_updated_at = nowIso;
  chiller.updated_at = nowIso;
  chiller.condition_updated_by = user.email || user.username || 'system';
  if (rawNotes) {
    chiller.condition_notes = rawNotes;
  }

  if (typeof chiller.raw_data_json === 'string' && chiller.raw_data_json.trim()) {
    try {
      const parsedRaw = JSON.parse(chiller.raw_data_json);
      if (parsedRaw && typeof parsedRaw === 'object') {
        if (Object.prototype.hasOwnProperty.call(parsedRaw, 'Condiiton')) parsedRaw['Condiiton'] = condition;
        if (Object.prototype.hasOwnProperty.call(parsedRaw, 'Condition')) parsedRaw['Condition'] = condition;
        chiller.raw_data_json = JSON.stringify(parsedRaw);
      }
    } catch (_) {}
  } else if (chiller.rawData && typeof chiller.rawData === 'object') {
    if (Object.prototype.hasOwnProperty.call(chiller.rawData, 'Condiiton')) chiller.rawData['Condiiton'] = condition;
    if (Object.prototype.hasOwnProperty.call(chiller.rawData, 'Condition')) chiller.rawData['Condition'] = condition;
  }

  const auditEvent = {
    category: 'chiller',
    action: 'CHILLER_CONDITION_UPDATED',
    details: `Chiller '${chillerCode}' condition changed from '${previousCondition}' to '${condition}'`,
    metadata: {
      chillerId: chiller.id,
      chillerCode,
      previousCondition,
      newCondition: condition,
      notes: rawNotes || null
    }
  };

  return { ok: true, statusCode: 200, chiller, auditEvent };
}
