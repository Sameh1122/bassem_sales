import express from 'express';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { requireAuth, requireAdmin, requireRoles } from '../middleware/auth.js';
import { canUserAccessChiller, getSupervisedAgentIdSet } from '../services/chillerHelpers.js';
import { ALLOWED_ATTACHMENT_EXTS, ALLOWED_ATTACHMENT_MIMES } from '../utils/security.js';
import { uploadAttach } from '../services/excel.js';
import { dbStore, saveDbStore, ensureFreshCloudSync, persistToBlobIfConfigured, ensureSyncStoreFields } from '../services/storage.js';
import { processFormResponseSubmission } from '../services/syncOperations.js';

function escapeHtml(val) {
  return String(val ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function isSafeAttachmentUrl(url) {
  if (typeof url !== 'string') return false;
  const trimmed = url.trim();
  if (!trimmed) return false;
  const lower = trimmed.toLowerCase();
  return (
    lower.startsWith('https://') ||
    lower.startsWith('http://') ||
    lower.startsWith('/uploads/') ||
    lower.startsWith('data:image/')
  );
}

const router = express.Router();

// GET all forms (agents see only forms assigned to them or unassigned/universal forms)
router.get('/forms', requireAuth, (req, res) => {
  let forms = dbStore.forms || [];
  if (req.user && req.user.role === 'agent') {
    const agentId = req.user.agentId;
    forms = forms.filter(f => {
      const assigned = f.assigned_agent_ids || [];
      return assigned.length === 0 || assigned.includes(agentId);
    });
  }
  res.json({ success: true, count: forms.length, forms });
});

// GET single form by ID
router.get('/forms/:id', requireAuth, (req, res) => {
  const formId = parseInt(req.params.id);
  const form = (dbStore.forms || []).find(f => f.id === formId);
  if (!form) {
    return res.status(404).json({ success: false, error: 'Form not found' });
  }
  if (req.user && req.user.role === 'agent') {
    const assigned = form.assigned_agent_ids || [];
    if (assigned.length > 0 && !assigned.includes(req.user.agentId)) {
      return res.status(403).json({ success: false, error: 'Access denied to this form' });
    }
  }
  res.json({ success: true, form });
});

// POST create form (Admin only)
router.post('/forms', requireAdmin, (req, res) => {
  const { title, description, fields, assigned_agent_ids } = req.body;
  if (!title || !title.trim()) {
    return res.status(400).json({ success: false, error: 'Form title is required' });
  }

  const newForm = {
    id: Date.now(),
    title: title.trim(),
    description: (description || '').trim(),
    fields: Array.isArray(fields) ? fields : [],
    assigned_agent_ids: Array.isArray(assigned_agent_ids) ? assigned_agent_ids.map(Number).filter(n => !isNaN(n)) : [],
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };

  dbStore.forms = dbStore.forms || [];
  dbStore.forms.push(newForm);
  saveDbStore(dbStore);

  res.status(201).json({ success: true, message: 'Form created successfully', form: newForm });
});

// PUT update form (Admin only)
router.put('/forms/:id', requireAdmin, (req, res) => {
  const formId = parseInt(req.params.id);
  const formIndex = (dbStore.forms || []).findIndex(f => f.id === formId);
  if (formIndex === -1) {
    return res.status(404).json({ success: false, error: 'Form not found' });
  }

  const { title, description, fields, assigned_agent_ids } = req.body;
  const existing = dbStore.forms[formIndex];

  dbStore.forms[formIndex] = {
    ...existing,
    title: title ? title.trim() : existing.title,
    description: description !== undefined ? (description || '').trim() : existing.description,
    fields: Array.isArray(fields) ? fields : existing.fields,
    assigned_agent_ids: Array.isArray(assigned_agent_ids) ? assigned_agent_ids.map(Number).filter(n => !isNaN(n)) : existing.assigned_agent_ids,
    updated_at: new Date().toISOString()
  };

  saveDbStore(dbStore);
  res.json({ success: true, message: 'Form updated successfully', form: dbStore.forms[formIndex] });
});

// DELETE form (Admin only)
router.delete('/forms/:id', requireAdmin, (req, res) => {
  const formId = parseInt(req.params.id);
  const initialCount = (dbStore.forms || []).length;
  dbStore.forms = (dbStore.forms || []).filter(f => f.id !== formId);

  if (dbStore.forms.length === initialCount) {
    return res.status(404).json({ success: false, error: 'Form not found' });
  }

  ensureSyncStoreFields(dbStore);
  dbStore.tombstones.forms.push({ id: formId, deletedAt: new Date().toISOString() });

  saveDbStore(dbStore);
  res.json({ success: true, message: 'Form deleted successfully' });
});

// POST assign form to agents (Admin only)
router.post('/forms/:id/assign', requireAdmin, (req, res) => {
  const formId = parseInt(req.params.id);
  const form = (dbStore.forms || []).find(f => f.id === formId);
  if (!form) {
    return res.status(404).json({ success: false, error: 'Form not found' });
  }

  const { assigned_agent_ids } = req.body;
  if (!Array.isArray(assigned_agent_ids)) {
    return res.status(400).json({ success: false, error: 'assigned_agent_ids must be an array' });
  }

  form.assigned_agent_ids = assigned_agent_ids.map(Number).filter(n => !isNaN(n));
  form.updated_at = new Date().toISOString();
  saveDbStore(dbStore);

  res.json({ success: true, message: 'Form assignments updated', form });
});

// POST upload attachment (file or base64)
router.post('/forms/upload-attachment', requireAuth, (req, res) => {
  uploadAttach.single('file')(req, res, (uploadErr) => {
    if (uploadErr) {
      return res.status(400).json({ success: false, error: uploadErr.message });
    }

    try {
      // Handle base64 JSON payload
      const { base64Data, filename: originalName } = req.body || {};
      if (base64Data) {
        const match = base64Data.match(/^data:([A-Za-z0-9-+/]+);base64,(.+)$/);
        let buffer;
        let ext = '.jpg';
        let mime = 'image/jpeg';
        if (match) {
          mime = match[1].toLowerCase();
          if (!ALLOWED_ATTACHMENT_MIMES.has(mime)) {
            return res.status(400).json({
              success: false,
              error: 'Invalid file MIME type. Only JPEG, PNG, WEBP images and PDF documents are allowed.'
            });
          }
          if (mime === 'image/png') ext = '.png';
          else if (mime === 'image/webp') ext = '.webp';
          else if (mime === 'application/pdf') ext = '.pdf';
          else ext = '.jpg';
          buffer = Buffer.from(match[2], 'base64');
        } else {
          // Plain base64: validate extension if original filename provided
          if (originalName) {
            const reqExt = path.extname(originalName).toLowerCase();
            if (!ALLOWED_ATTACHMENT_EXTS.has(reqExt)) {
              return res.status(400).json({
                success: false,
                error: 'Invalid file extension. Only .jpg, .jpeg, .png, .webp, and .pdf files are allowed.'
              });
            }
            ext = reqExt;
          }
          buffer = Buffer.from(base64Data, 'base64');
        }

        const filename = `attach_${Date.now()}_${crypto.randomBytes(4).toString('hex')}${ext}`;

        try {
          const uploadsDir = path.resolve('public/uploads');
          if (!fs.existsSync(uploadsDir)) {
            fs.mkdirSync(uploadsDir, { recursive: true });
          }
          const filePath = path.join(uploadsDir, filename);
          fs.writeFileSync(filePath, buffer);
        } catch (writeErr) {
          // Read-only filesystem or serverless (e.g., Vercel) - safely caught
        }

        const dataUri = match ? base64Data : `data:${mime};base64,${base64Data}`;
        const returnUrl = process.env.VERCEL ? dataUri : `/uploads/${filename}`;

        return res.json({
          success: true,
          url: returnUrl,
          filename
        });
      }

      // Handle multipart file upload
      if (req.file) {
        const ext = path.extname(req.file.originalname).toLowerCase() || '.jpg';
        const mime = (req.file.mimetype || '').toLowerCase();
        if (!ALLOWED_ATTACHMENT_EXTS.has(ext) || !ALLOWED_ATTACHMENT_MIMES.has(mime)) {
          return res.status(400).json({
            success: false,
            error: 'Invalid file type. Only JPEG, PNG, WEBP images and PDF documents are allowed.'
          });
        }

        const filename = `attach_${Date.now()}_${crypto.randomBytes(4).toString('hex')}${ext}`;

        try {
          const uploadsDir = path.resolve('public/uploads');
          if (!fs.existsSync(uploadsDir)) {
            fs.mkdirSync(uploadsDir, { recursive: true });
          }
          const filePath = path.join(uploadsDir, filename);
          fs.writeFileSync(filePath, req.file.buffer);
        } catch (writeErr) {
          // Read-only filesystem
        }

        const dataUri = `data:${mime};base64,${req.file.buffer.toString('base64')}`;
        const returnUrl = process.env.VERCEL ? dataUri : `/uploads/${filename}`;

        return res.json({
          success: true,
          url: returnUrl,
          filename
        });
      }

      return res.status(400).json({ success: false, error: 'No file or base64 data provided' });
    } catch (err) {
      console.error('Attachment upload error:', err);
      return res.status(500).json({ success: false, error: 'Failed to process attachment: ' + err.message });
    }
  });
});

// POST submit form response (Agent completing a visit)
router.post('/form-responses', requireAuth, requireRoles('owner', 'admin', 'regional_manager', 'supervisor', 'agent'), async (req, res) => {
  await ensureFreshCloudSync();

  const result = processFormResponseSubmission(dbStore, req.user, req.body);
  if (!result.ok) {
    return res.status(result.statusCode).json({ success: false, error: result.error });
  }

  saveDbStore(dbStore);
  await persistToBlobIfConfigured(dbStore);

  res.status(201).json({
    success: true,
    message: 'Visit form submitted successfully',
    response: result.response
  });
});

// GET form responses (Admin monitors all, Agent sees own)
router.get('/form-responses', requireAuth, (req, res) => {
  const { status, chiller_code, search, form_id } = req.query;
  let responses = [...(dbStore.form_responses || [])];

  if (req.user && req.user.role === 'agent') {
    responses = responses.filter(r => r.agent_id === req.user.agentId);
  } else if (req.user && req.user.role === 'supervisor') {
    const supervisedSet = getSupervisedAgentIdSet(req.user);
    responses = responses.filter(r => {
      if (supervisedSet.has(Number(r.agent_id))) return true;
      const chiller = (dbStore.chillers || []).find(c =>
        (r.chiller_code && (c.chiller_code || c.chillerCode) === r.chiller_code) ||
        (r.customer_name && (c.customer_name || c.customerName || '').toLowerCase() === r.customer_name.toLowerCase())
      );
      return chiller ? canUserAccessChiller(chiller, req.user, dbStore) : false;
    });
  } else if (req.user && req.user.role === 'technician') {
    responses = [];
  }

  if (status && status !== 'All') {
    responses = responses.filter(r => (r.status || '').toLowerCase() === status.toLowerCase());
  }

  if (form_id) {
    const fId = parseInt(form_id);
    responses = responses.filter(r => r.form_id === fId);
  }

  if (chiller_code) {
    responses = responses.filter(r => (r.chiller_code || '').toLowerCase() === chiller_code.toLowerCase());
  }

  if (search && search.trim()) {
    const term = search.trim().toLowerCase();
    responses = responses.filter(r =>
      (r.customer_name || '').toLowerCase().includes(term) ||
      (r.chiller_code || '').toLowerCase().includes(term) ||
      (r.agent_name || '').toLowerCase().includes(term) ||
      (r.form_title || '').toLowerCase().includes(term)
    );
  }

  responses.sort((a, b) => new Date(b.submitted_at || 0) - new Date(a.submitted_at || 0));

  res.json({ success: true, count: responses.length, responses });
});

// PUT review form response (Admin/Owner/Regional Manager/Supervisor accepts feedback or re-opens to agent)
router.put('/form-responses/:id/review', requireRoles('owner', 'admin', 'regional_manager', 'supervisor'), (req, res) => {
  const responseId = parseInt(req.params.id);
  const resp = (dbStore.form_responses || []).find(r => r.id === responseId);
  if (!resp) {
    return res.status(404).json({ success: false, error: 'Form response not found' });
  }

  if (req.user.role === 'supervisor') {
    const supervisedSet = getSupervisedAgentIdSet(req.user);
    const inAgents = supervisedSet.has(Number(resp.agent_id));
    const chiller = (dbStore.chillers || []).find(c =>
      (resp.chiller_code && (c.chiller_code || c.chillerCode) === resp.chiller_code) ||
      (resp.customer_name && (c.customer_name || c.customerName || '').toLowerCase() === resp.customer_name.toLowerCase())
    );
    const inBranch = chiller ? canUserAccessChiller(chiller, req.user, dbStore) : false;
    if (!inAgents && !inBranch) {
      return res.status(403).json({ success: false, error: 'Access denied: Form response is outside your supervised scope' });
    }
  }

  const { status, admin_feedback } = req.body;
  if (!status || !['accepted', 'reopened'].includes(status)) {
    return res.status(400).json({ success: false, error: "Status must be 'accepted' or 'reopened'" });
  }

  resp.status = status;
  if (admin_feedback !== undefined) {
    resp.admin_feedback = (admin_feedback || '').trim();
  }
  resp.reviewed_at = new Date().toISOString();
  resp.reviewed_by = req.user.name || req.user.username;

  saveDbStore(dbStore);

  res.json({
    success: true,
    message: status === 'accepted' ? 'Response accepted successfully' : 'Response re-opened to agent with feedback',
    response: resp
  });
});

// GET 1-click printable/PDF audit report for a form response
router.get('/form-responses/:id/report', requireAuth, requireRoles('owner', 'admin', 'regional_manager', 'supervisor', 'agent'), async (req, res) => {
  await ensureFreshCloudSync();

  const resp = (dbStore.form_responses || []).find(r => String(r.id) === String(req.params.id));
  if (!resp) {
    return res.status(404).json({ success: false, error: 'Form response not found' });
  }

  const chiller = (dbStore.chillers || []).find(c =>
    (resp.chiller_code && (c.chiller_code || c.chillerCode) === resp.chiller_code) ||
    (resp.customer_name && (c.customer_name || c.customerName || '').toLowerCase() === resp.customer_name.toLowerCase())
  );

  if (req.user.role === 'agent') {
    if (Number(resp.agent_id) !== Number(req.user.agentId)) {
      return res.status(403).json({ success: false, error: 'Access denied: Form response belongs to another agent' });
    }
  } else if (req.user.role === 'supervisor') {
    const supervisedSet = getSupervisedAgentIdSet(req.user);
    const inAgents = supervisedSet.has(Number(resp.agent_id));
    const inBranch = chiller ? canUserAccessChiller(chiller, req.user, dbStore) : false;
    if (!inAgents && !inBranch) {
      return res.status(403).json({ success: false, error: 'Access denied: Form response is outside your supervised scope' });
    }
  }

  const checkInLat = resp.checkInLat ?? resp.check_in_lat ?? null;
  const checkInLng = resp.checkInLng ?? resp.check_in_lng ?? null;
  const checkInDistanceM = resp.checkInDistanceM ?? resp.check_in_distance_m ?? null;
  const geofenceVerified = resp.geofenceVerified ?? resp.geofence_verified ?? null;

  const normalizedAttachments = (Array.isArray(resp.attachments) ? resp.attachments : []).map(item => {
    if (typeof item === 'string') {
      return { url: item, filename: null, watermark: null };
    }
    if (item && typeof item === 'object') {
      return {
        url: item.url || '',
        filename: item.filename || null,
        watermark: item.watermark || null
      };
    }
    return null;
  }).filter(Boolean);

  const reportPayload = {
    id: resp.id,
    formId: resp.form_id,
    formTitle: resp.form_title || 'Visit Audit',
    status: resp.status || 'submitted',
    submittedAt: resp.submitted_at || null,
    reviewedAt: resp.reviewed_at || null,
    reviewedBy: resp.reviewed_by || null,
    adminFeedback: resp.admin_feedback || '',
    agentId: resp.agent_id,
    agentName: resp.agent_name || 'Field Rep',
    chillerCode: resp.chiller_code || '',
    customerName: resp.customer_name || '',
    branch: chiller?.branch || '',
    customerAddress: chiller?.customer_address || chiller?.customerAddress || '',
    condition: chiller?.condition || 'Operational',
    efficiency: chiller?.efficiency || '',
    checkInLat,
    checkInLng,
    checkInDistanceM,
    geofenceVerified,
    answers: (resp.answers && typeof resp.answers === 'object') ? resp.answers : {},
    attachments: normalizedAttachments
  };

  const format = String(req.query.format || 'html').toLowerCase();
  if (format === 'json') {
    return res.json({ success: true, report: reportPayload });
  }

  const statusUpper = String(reportPayload.status).toUpperCase();
  const statusColor = reportPayload.status === 'accepted'
    ? '#0F9D58'
    : (reportPayload.status === 'reopened' ? '#D93025' : '#1A73E8');

  let geofenceBadgeHtml = '<span class="badge badge-muted">NO GPS</span>';
  if (geofenceVerified === true) {
    geofenceBadgeHtml = `<span class="badge badge-success">VERIFIED &le; 100m (${escapeHtml(checkInDistanceM)}m)</span>`;
  } else if (geofenceVerified === false) {
    geofenceBadgeHtml = `<span class="badge badge-caution">OUT OF RANGE (&gt;100m · ${escapeHtml(checkInDistanceM)}m)</span>`;
  } else if (checkInLat !== null && checkInLng !== null) {
    geofenceBadgeHtml = '<span class="badge badge-muted">GPS RECORDED (NO ASSET PIN)</span>';
  }

  const answerRowsHtml = Object.entries(reportPayload.answers).length > 0
    ? Object.entries(reportPayload.answers).map(([k, v]) => `
        <tr>
          <th>${escapeHtml(k)}</th>
          <td>${escapeHtml(typeof v === 'object' ? JSON.stringify(v) : v)}</td>
        </tr>`).join('')
    : '<tr><td colspan="2" class="muted">No answers recorded.</td></tr>';

  const photosHtml = normalizedAttachments.filter(a => isSafeAttachmentUrl(a.url)).map((att, idx) => {
    const wm = att.watermark;
    const wmParts = [];
    if (wm?.chillerCode || reportPayload.chillerCode) wmParts.push(wm?.chillerCode || reportPayload.chillerCode);
    if (wm?.capturedAt) wmParts.push(wm.capturedAt);
    if (wm?.lat != null && wm?.lng != null) wmParts.push(`${Number(wm.lat).toFixed(5)}, ${Number(wm.lng).toFixed(5)}`);
    if (wm?.agentName) wmParts.push(wm.agentName);
    const wmText = wmParts.length > 0 ? wmParts.join(' · ') : (att.filename || `Photo ${idx + 1}`);

    const isPdf = att.url.toLowerCase().endsWith('.pdf') || att.url.toLowerCase().startsWith('data:application/pdf');
    const mediaHtml = isPdf
      ? `<div class="pdf-link"><a href="${escapeHtml(att.url)}" target="_blank" rel="noopener">Attachment ${idx + 1} (PDF)</a></div>`
      : `<img src="${escapeHtml(att.url)}" alt="Audit photo ${idx + 1}" />`;

    return `
      <div class="photo-card">
        ${mediaHtml}
        <div class="photo-wm">${escapeHtml(wmText)}</div>
      </div>`;
  }).join('');

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Visual Audit Report — ${escapeHtml(reportPayload.chillerCode || reportPayload.customerName || reportPayload.id)}</title>
  <style>
    * { box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; color: #111827; background: #f3f4f6; margin: 0; padding: 24px; }
    .sheet { max-width: 840px; margin: 0 auto; background: #ffffff; border: 1px solid #e5e7eb; border-radius: 10px; padding: 28px; box-shadow: 0 4px 16px rgba(0,0,0,0.06); }
    .toolbar { display: flex; justify-content: flex-end; gap: 8px; margin-bottom: 16px; }
    .btn-print { background: #1a73e8; color: #fff; border: none; border-radius: 6px; padding: 9px 16px; font-weight: 600; cursor: pointer; font-size: 13px; }
    .header { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #e5e7eb; padding-bottom: 16px; margin-bottom: 20px; gap: 12px; }
    .title { font-size: 20px; font-weight: 700; margin: 0 0 4px; }
    .sub { font-size: 12px; color: #6b7280; margin: 0; }
    .badge { display: inline-block; padding: 4px 10px; border-radius: 999px; font-size: 11px; font-weight: 700; letter-spacing: 0.4px; }
    .badge-status { background: ${statusColor}1a; color: ${statusColor}; border: 1px solid ${statusColor}66; }
    .badge-success { background: #0f9d581a; color: #0f9d58; border: 1px solid #0f9d5866; }
    .badge-caution { background: #f59e0b1a; color: #b45309; border: 1px solid #f59e0b66; }
    .badge-muted { background: #f3f4f6; color: #4b5563; border: 1px solid #d1d5db; }
    h2 { font-size: 13px; text-transform: uppercase; letter-spacing: 0.6px; color: #4b5563; margin: 20px 0 8px; border-bottom: 1px solid #e5e7eb; padding-bottom: 4px; }
    .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px 18px; font-size: 13px; }
    .kv strong { display: block; font-size: 11px; color: #6b7280; margin-bottom: 2px; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; margin-top: 6px; }
    th, td { text-align: left; padding: 8px 10px; border: 1px solid #e5e7eb; vertical-align: top; }
    th { width: 38%; background: #f9fafb; color: #374151; font-weight: 600; }
    tr:nth-child(even) td { background: #fcfcfd; }
    .photos { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; margin-top: 8px; }
    .photo-card { border: 1px solid #e5e7eb; border-radius: 8px; overflow: hidden; background: #111827; page-break-inside: avoid; }
    .photo-card img { width: 100%; height: 220px; object-fit: cover; display: block; }
    .photo-wm { padding: 8px 10px; background: #111827; color: #f9fafb; font-size: 11px; font-family: monospace; }
    .pdf-link { padding: 24px; text-align: center; background: #f9fafb; }
    .muted { color: #6b7280; font-style: italic; }
    @media print {
      body { background: #fff; padding: 0; }
      .sheet { border: none; box-shadow: none; padding: 0; max-width: 100%; }
      .toolbar { display: none; }
    }
  </style>
</head>
<body>
  <div class="sheet">
    <div class="toolbar">
      <button class="btn-print" onclick="window.print()">Print / Save as PDF</button>
    </div>
    <div class="header">
      <div>
        <div class="title">Bassem Sales Platform — Visual Visit Audit</div>
        <p class="sub">Report #${escapeHtml(reportPayload.id)} · ${escapeHtml(reportPayload.formTitle)} · Submitted ${escapeHtml(reportPayload.submittedAt || 'N/A')}</p>
      </div>
      <span class="badge badge-status">${escapeHtml(statusUpper)}</span>
    </div>

    <h2>1. Asset &amp; Customer Context</h2>
    <div class="grid">
      <div class="kv"><strong>Customer Name</strong>${escapeHtml(reportPayload.customerName || 'N/A')}</div>
      <div class="kv"><strong>Chiller Code</strong>${escapeHtml(reportPayload.chillerCode || 'N/A')}</div>
      <div class="kv"><strong>Branch</strong>${escapeHtml(reportPayload.branch || 'N/A')}</div>
      <div class="kv"><strong>Asset Condition / Efficiency</strong>${escapeHtml(reportPayload.condition || 'N/A')} ${reportPayload.efficiency ? '· ' + escapeHtml(reportPayload.efficiency) : ''}</div>
      <div class="kv" style="grid-column: span 2;"><strong>Customer Address</strong>${escapeHtml(reportPayload.customerAddress || 'N/A')}</div>
    </div>

    <h2>2. Field Trust &amp; Geofence Verification</h2>
    <div class="grid">
      <div class="kv"><strong>Field Representative</strong>${escapeHtml(reportPayload.agentName)}</div>
      <div class="kv"><strong>Geofence Status</strong>${geofenceBadgeHtml}</div>
      <div class="kv"><strong>Check-In Coordinates</strong>${checkInLat != null && checkInLng != null ? escapeHtml(`${Number(checkInLat).toFixed(6)}, ${Number(checkInLng).toFixed(6)}`) : 'Not captured'}</div>
      <div class="kv"><strong>Distance from Chiller Pin</strong>${checkInDistanceM != null ? escapeHtml(`${checkInDistanceM}m`) : 'N/A'}</div>
    </div>

    <h2>3. Audit Q&amp;A</h2>
    <table>
      <tbody>${answerRowsHtml}</tbody>
    </table>

    <h2>4. Geo-Stamped Photo Evidence (${normalizedAttachments.length})</h2>
    ${photosHtml ? `<div class="photos">${photosHtml}</div>` : '<p class="muted">No photo attachments.</p>'}

    <h2>5. Review Decision</h2>
    <div class="grid">
      <div class="kv"><strong>Reviewed By</strong>${escapeHtml(reportPayload.reviewedBy || 'Pending review')}</div>
      <div class="kv"><strong>Reviewed At</strong>${escapeHtml(reportPayload.reviewedAt || 'N/A')}</div>
      <div class="kv" style="grid-column: span 2;"><strong>Supervisor / Admin Feedback</strong>${escapeHtml(reportPayload.adminFeedback || 'None')}</div>
    </div>
  </div>
</body>
</html>`;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  return res.status(200).send(html);
});

export default router;
