import express from 'express';
import { requireAuth, requireRoles, isAdminRole } from '../middleware/auth.js';
import { dbStore, saveDbStore, ensureFreshCloudSync, persistToBlobIfConfigured } from '../services/storage.js';
import {
  canUserAccessChiller,
  isChillerAssignedToAgent,
  getSupervisedAgentIdSet,
  normalizeCondition
} from '../services/chillerHelpers.js';

const router = express.Router();

const ALLOWED_TICKET_STATUSES = ['open', 'in_progress', 'resolved'];
const PRIORITY_RANK = { critical: 0, high: 1, medium: 2, low: 3 };

function computeSlaMetadata(condition, explicitPriority = null) {
  const normCond = normalizeCondition(condition);
  if (normCond === 'Scrap' || explicitPriority === 'critical') {
    const slaHours = 24;
    return {
      condition: 'Scrap',
      priority: 'critical',
      slaHours,
      dueAt: new Date(Date.now() + slaHours * 3600 * 1000).toISOString()
    };
  }
  if (normCond === 'Requires Maintenance' || explicitPriority === 'high') {
    const slaHours = 72;
    return {
      condition: 'Requires Maintenance',
      priority: 'high',
      slaHours,
      dueAt: new Date(Date.now() + slaHours * 3600 * 1000).toISOString()
    };
  }
  const slaHours = 72;
  return {
    condition: normCond,
    priority: explicitPriority || 'medium',
    slaHours,
    dueAt: new Date(Date.now() + slaHours * 3600 * 1000).toISOString()
  };
}

function findChillerForTicket(store, chillerId, chillerCode) {
  const chillers = store.chillers || [];
  if (chillerId !== undefined && chillerId !== null && String(chillerId).trim() !== '') {
    const byId = chillers.find(c => String(c.id) === String(chillerId).trim());
    if (byId) return byId;
  }
  if (chillerCode && String(chillerCode).trim() !== '') {
    const target = String(chillerCode).trim().toLowerCase();
    return chillers.find(c => (c.chiller_code || c.chillerCode || '').toLowerCase() === target) || null;
  }
  return null;
}

function canUserAccessTicket(ticket, user, store) {
  if (!user) return false;
  if (isAdminRole(user)) return true;

  const chiller = findChillerForTicket(store, ticket.chiller_id, ticket.chiller_code);
  if (chiller) {
    return canUserAccessChiller(chiller, user, store);
  }

  if (user.role === 'agent') {
    return false;
  }

  if (user.role === 'technician') {
    const userBranch = (user.branch || '').toString().trim().toLowerCase();
    if (!userBranch) return true;
    return (ticket.branch || '').toString().trim().toLowerCase() === userBranch;
  }

  if (user.role === 'supervisor') {
    const userBranch = (user.branch || '').toString().trim().toLowerCase();
    const ticketBranch = (ticket.branch || '').toString().trim().toLowerCase();
    if (userBranch && ticketBranch && userBranch === ticketBranch) return true;
    const supervisedSet = getSupervisedAgentIdSet(user);
    if (ticket.assigned_to && supervisedSet.has(Number(ticket.assigned_to))) return true;
    return false;
  }

  return false;
}

export function autoCreateTicketForChiller(store, chiller, user, reason = '') {
  if (!store || !chiller) return null;
  if (!Array.isArray(store.tickets)) store.tickets = [];

  const normCond = normalizeCondition(chiller.condition);
  if (normCond !== 'Requires Maintenance' && normCond !== 'Scrap') {
    return null;
  }

  const chillerCode = chiller.chiller_code || chiller.chillerCode || String(chiller.id);
  const existingOpen = store.tickets.find(t =>
    (t.status === 'open' || t.status === 'in_progress') &&
    ((t.chiller_id !== undefined && t.chiller_id === chiller.id) ||
      (t.chiller_code && t.chiller_code.toLowerCase() === chillerCode.toLowerCase()))
  );
  if (existingOpen) {
    return null;
  }

  const sla = computeSlaMetadata(normCond);
  const nowIso = new Date().toISOString();
  const ticket = {
    id: Date.now() + Math.floor(Math.random() * 1000),
    chiller_id: chiller.id ?? null,
    chiller_code: chillerCode,
    customer_name: chiller.customer_name || chiller.customerName || '',
    branch: chiller.branch || '',
    condition: sla.condition,
    priority: sla.priority,
    sla_hours: sla.slaHours,
    due_at: sla.dueAt,
    status: 'open',
    reason: (reason && String(reason).trim()) || `Auto-created from condition change to ${sla.condition}`,
    assigned_to: null,
    resolution_note: '',
    created_by: user?.email || user?.username || 'system',
    created_at: nowIso,
    updated_at: nowIso,
    resolved_at: null,
    resolved_by: null
  };

  store.tickets.push(ticket);
  return ticket;
}

// GET /api/tickets (role-scoped)
router.get('/tickets', requireAuth, async (req, res) => {
  await ensureFreshCloudSync();
  if (!Array.isArray(dbStore.tickets)) dbStore.tickets = [];

  const { status, priority, chillerCode } = req.query;
  let tickets = dbStore.tickets.filter(t => canUserAccessTicket(t, req.user, dbStore));

  if (status && status !== 'all') {
    tickets = tickets.filter(t => t.status === status);
  }
  if (priority && priority !== 'all') {
    tickets = tickets.filter(t => t.priority === priority);
  }
  if (chillerCode) {
    const target = String(chillerCode).trim().toLowerCase();
    tickets = tickets.filter(t => (t.chiller_code || '').toLowerCase() === target);
  }

  tickets.sort((a, b) => {
    const rankA = PRIORITY_RANK[a.priority] ?? 99;
    const rankB = PRIORITY_RANK[b.priority] ?? 99;
    if (rankA !== rankB) return rankA - rankB;
    return new Date(b.created_at || 0) - new Date(a.created_at || 0);
  });

  res.json({ success: true, count: tickets.length, tickets });
});

// POST /api/tickets
router.post('/tickets', requireRoles('owner', 'admin', 'regional_manager', 'supervisor', 'technician'), async (req, res) => {
  await ensureFreshCloudSync();
  if (!Array.isArray(dbStore.tickets)) dbStore.tickets = [];

  const body = req.body && typeof req.body === 'object' ? req.body : {};
  const chillerCodeInput = body.chillerCode || body.chiller_code || '';
  const chillerIdInput = body.chillerId || body.chiller_id || null;
  const chiller = findChillerForTicket(dbStore, chillerIdInput, chillerCodeInput);

  if (!chiller && !String(chillerCodeInput).trim()) {
    return res.status(400).json({ success: false, error: 'chillerCode or valid chillerId is required' });
  }

  if (chiller && (req.user.role === 'supervisor' || req.user.role === 'technician')) {
    if (!canUserAccessChiller(chiller, req.user, dbStore)) {
      return res.status(403).json({ success: false, error: 'Access denied: Chiller is outside your assigned scope' });
    }
  }

  const rawCondition = body.condition || chiller?.condition || 'Requires Maintenance';
  const sla = computeSlaMetadata(rawCondition, body.priority);
  const nowIso = new Date().toISOString();
  const resolvedCode = chiller
    ? (chiller.chiller_code || chiller.chillerCode || String(chiller.id))
    : String(chillerCodeInput).trim();

  const ticket = {
    id: Date.now() + Math.floor(Math.random() * 1000),
    chiller_id: chiller?.id ?? null,
    chiller_code: resolvedCode,
    customer_name: chiller ? (chiller.customer_name || chiller.customerName || '') : (body.customerName || body.customer_name || ''),
    branch: chiller ? (chiller.branch || '') : (body.branch || req.user.branch || ''),
    condition: sla.condition,
    priority: sla.priority,
    sla_hours: sla.slaHours,
    due_at: sla.dueAt,
    status: 'open',
    reason: typeof body.reason === 'string' && body.reason.trim()
      ? body.reason.trim().slice(0, 500)
      : (typeof body.notes === 'string' ? body.notes.trim().slice(0, 500) : ''),
    assigned_to: body.assignedTo ?? body.assigned_to ?? null,
    resolution_note: '',
    created_by: req.user.email || req.user.username || 'system',
    created_at: nowIso,
    updated_at: nowIso,
    resolved_at: null,
    resolved_by: null
  };

  dbStore.tickets.push(ticket);
  req.auditEvent = {
    category: 'tickets',
    action: 'TICKET_CREATED',
    details: `SLA Ticket #${ticket.id} created for chiller '${ticket.chiller_code}' (${ticket.priority})`,
    metadata: { ticketId: ticket.id, chillerCode: ticket.chiller_code, priority: ticket.priority }
  };

  saveDbStore(dbStore);
  await persistToBlobIfConfigured(dbStore);

  res.status(201).json({ success: true, ticket });
});

// PATCH /api/tickets/:id
router.patch('/tickets/:id', requireRoles('owner', 'admin', 'regional_manager', 'supervisor', 'technician'), async (req, res) => {
  await ensureFreshCloudSync();
  if (!Array.isArray(dbStore.tickets)) dbStore.tickets = [];

  const ticketId = String(req.params.id || '').trim();
  const ticket = dbStore.tickets.find(t => String(t.id) === ticketId);
  if (!ticket) {
    return res.status(404).json({ success: false, error: 'Ticket not found' });
  }

  if ((req.user.role === 'supervisor' || req.user.role === 'technician') && !canUserAccessTicket(ticket, req.user, dbStore)) {
    return res.status(403).json({ success: false, error: 'Access denied: Ticket is outside your assigned scope' });
  }

  const body = req.body && typeof req.body === 'object' ? req.body : {};
  if (body.status !== undefined) {
    const nextStatus = String(body.status).trim();
    if (!ALLOWED_TICKET_STATUSES.includes(nextStatus)) {
      return res.status(400).json({
        success: false,
        error: `Invalid status. Must be one of: ${ALLOWED_TICKET_STATUSES.join(', ')}`
      });
    }
    ticket.status = nextStatus;
    if (nextStatus === 'resolved') {
      ticket.resolved_at = new Date().toISOString();
      ticket.resolved_by = req.user.email || req.user.username || 'system';
    } else {
      ticket.resolved_at = null;
      ticket.resolved_by = null;
    }
  }

  if (body.assignedTo !== undefined || body.assigned_to !== undefined) {
    ticket.assigned_to = body.assignedTo !== undefined ? body.assignedTo : body.assigned_to;
  }

  if (body.resolutionNote !== undefined || body.resolution_note !== undefined) {
    const note = body.resolutionNote !== undefined ? body.resolutionNote : body.resolution_note;
    ticket.resolution_note = typeof note === 'string' ? note.trim().slice(0, 1000) : '';
  }

  ticket.updated_at = new Date().toISOString();

  req.auditEvent = {
    category: 'tickets',
    action: 'TICKET_UPDATED',
    details: `SLA Ticket #${ticket.id} updated (status=${ticket.status})`,
    metadata: { ticketId: ticket.id, status: ticket.status, assignedTo: ticket.assigned_to }
  };

  saveDbStore(dbStore);
  await persistToBlobIfConfigured(dbStore);

  res.json({ success: true, ticket });
});

export default router;
