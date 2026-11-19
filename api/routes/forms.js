import express from 'express';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { requireAuth, requireAdmin, requireRoles } from '../middleware/auth.js';
import { canUserAccessChiller, getSupervisedAgentIdSet } from '../services/chillerHelpers.js';
import { ALLOWED_ATTACHMENT_EXTS, ALLOWED_ATTACHMENT_MIMES } from '../utils/security.js';
import { uploadAttach } from '../services/excel.js';
import { dbStore, saveDbStore } from '../services/storage.js';

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
router.post('/form-responses', requireAuth, requireRoles('owner', 'admin', 'regional_manager', 'supervisor', 'agent'), (req, res) => {
  const { form_id, chiller_code, customer_name, answers, attachments } = req.body;
  if (!form_id) {
    return res.status(400).json({ success: false, error: 'form_id is required' });
  }

  const form = (dbStore.forms || []).find(f => f.id === parseInt(form_id));
  if (!form) {
    return res.status(404).json({ success: false, error: 'Form not found' });
  }

  // Authorization checks when caller is an agent
  if (req.user && req.user.role === 'agent') {
    const assignedAgents = form.assigned_agent_ids || [];
    if (assignedAgents.length > 0 && !assignedAgents.includes(req.user.agentId)) {
      return res.status(403).json({ success: false, error: 'Access denied: You are not assigned to this form' });
    }

    const cleanCode = (chiller_code || '').trim();
    const cleanCust = (customer_name || '').trim().toLowerCase();
    const isAssigned = (dbStore.assignments || []).some(as =>
      as.agent_id === req.user.agentId && (
        (cleanCode && as.chiller_code === cleanCode) ||
        (cleanCust && as.customer_name && as.customer_name.toLowerCase() === cleanCust)
      )
    );

    if (!isAssigned) {
      return res.status(403).json({
        success: false,
        error: 'Access denied: Chiller or customer is not assigned to your territory'
      });
    }
  } else if (req.user && req.user.role === 'supervisor') {
    const cleanCode = (chiller_code || '').trim();
    const cleanCust = (customer_name || '').trim().toLowerCase();
    const chiller = (dbStore.chillers || []).find(c =>
      (cleanCode && (c.chiller_code || c.chillerCode) === cleanCode) ||
      (cleanCust && (c.customer_name || c.customerName || '').toLowerCase() === cleanCust)
    );
    if (!chiller || !canUserAccessChiller(chiller, req.user, dbStore)) {
      return res.status(403).json({
        success: false,
        error: 'Access denied: Chiller or customer is outside your branch/team scope'
      });
    }
  }

  const agentId = req.user.role === 'agent' ? req.user.agentId : (req.user.id || 0);
  const agentName = req.user.name || req.user.username;

  const newResponse = {
    id: Date.now(),
    form_id: form.id,
    form_title: form.title,
    chiller_code: (chiller_code || '').trim(),
    customer_name: (customer_name || '').trim(),
    agent_id: agentId,
    agent_name: agentName,
    answers: (answers && typeof answers === 'object') ? answers : {},
    attachments: Array.isArray(attachments) ? attachments : [],
    status: 'submitted', // submitted | accepted | reopened
    admin_feedback: '',
    submitted_at: new Date().toISOString(),
    reviewed_at: null,
    reviewed_by: null
  };

  dbStore.form_responses = dbStore.form_responses || [];
  dbStore.form_responses.push(newResponse);
  saveDbStore(dbStore);

  res.status(201).json({
    success: true,
    message: 'Visit form submitted successfully',
    response: newResponse
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

export default router;
