import express from 'express';
import { requireAuth, requireAdmin } from '../middleware/auth.js';
import { validateComplexPassword, hashPassword } from '../utils/security.js';
import { dbStore, saveDbStore } from '../services/storage.js';

const router = express.Router();

// GET all sales agents
router.get('/agents', requireAuth, (req, res) => {
  let sourceAgents = dbStore.agents || [];
  // Restrict agents to only see their own profile to prevent PII exposure of other sales reps
  if (req.user && req.user.role === 'agent') {
    sourceAgents = sourceAgents.filter(a => a.id === req.user.agentId);
  }

  const agents = sourceAgents.map(a => {
    const assignedCount = (dbStore.assignments || []).filter(as => as.agent_id === a.id).length;
    const linkedUser = (dbStore.users || []).find(u => u.agent_id === a.id);
    return {
      ...a,
      assigned_count: assignedCount,
      login_email: linkedUser ? linkedUser.email : a.email,
      username: linkedUser ? linkedUser.username : null
    };
  });
  res.json({ success: true, count: agents.length, agents });
});

// POST create new sales agent (Admin only)
router.post('/agents', requireAdmin, (req, res) => {
  const { name, area, phone = '', email, password } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ success: false, error: 'Agent name is required' });
  }

  if (!email || !email.trim()) {
    return res.status(400).json({ success: false, error: 'Agent login email is required' });
  }

  const cleanEmail = email.trim().toLowerCase();
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(cleanEmail)) {
    return res.status(400).json({ success: false, error: 'Please enter a valid email address for the agent' });
  }

  if (!password || !password.trim()) {
    return res.status(400).json({ success: false, error: 'Agent login password is required' });
  }

  const complexity = validateComplexPassword(password);
  if (!complexity.valid) {
    return res.status(400).json({ success: false, error: `Password complexity error: ${complexity.error}` });
  }

  // Check if email already in use
  if (!Array.isArray(dbStore.users)) dbStore.users = [];
  const existingUser = dbStore.users.find(u => u.email && u.email.toLowerCase() === cleanEmail);
  if (existingUser) {
    return res.status(400).json({ success: false, error: `The email '${cleanEmail}' is already registered` });
  }

  const newId = (dbStore.agents && dbStore.agents.length > 0)
    ? Math.max(...dbStore.agents.map(a => a.id || 0)) + 1
    : 1;

  const newAgent = {
    id: newId,
    name: name.trim(),
    area: (area || '').trim(),
    phone: (phone || '').trim(),
    email: cleanEmail,
    created_at: new Date().toISOString()
  };

  const { hash, salt } = hashPassword(password);
  const baseUsername = cleanEmail.split('@')[0];

  const newUser = {
    id: Date.now() + Math.floor(Math.random() * 1000),
    email: cleanEmail,
    username: baseUsername,
    name: newAgent.name,
    role: 'agent',
    agent_id: newAgent.id,
    password_hash: hash,
    salt,
    created_at: new Date().toISOString()
  };

  dbStore.users.push(newUser);
  dbStore.agents.push(newAgent);
  saveDbStore(dbStore);

  res.json({
    success: true,
    message: `Agent '${newAgent.name}' created successfully with login email '${cleanEmail}'`,
    agent: {
      ...newAgent,
      login_email: cleanEmail,
      username: baseUsername
    }
  });
});

// PUT update existing sales agent (Admin only)
router.put('/agents/:id', requireAdmin, (req, res) => {
  const agentId = parseInt(req.params.id);
  const agent = (dbStore.agents || []).find(a => a.id === agentId);
  if (!agent) {
    return res.status(404).json({ success: false, error: `Agent #${agentId} not found` });
  }

  const { name, area, phone, email } = req.body;
  if (name !== undefined) agent.name = name.trim();
  if (area !== undefined) agent.area = (area || '').trim();
  if (phone !== undefined) agent.phone = (phone || '').trim();
  if (email !== undefined) {
    const cleanEmail = email.trim().toLowerCase();
    agent.email = cleanEmail;
    const linkedUser = (dbStore.users || []).find(u => u.agent_id === agentId);
    if (linkedUser) {
      linkedUser.email = cleanEmail;
    }
  }

  // Also update agent_name across assignments and linked user
  if (name !== undefined) {
    if (dbStore.assignments) {
      dbStore.assignments.forEach(as => {
        if (as.agent_id === agentId) {
          as.agent_name = agent.name;
          as.agent_area = agent.area;
        }
      });
    }
    const linkedUser = (dbStore.users || []).find(u => u.agent_id === agentId);
    if (linkedUser) {
      linkedUser.name = agent.name;
    }
  }

  saveDbStore(dbStore);
  res.json({ success: true, message: `Agent #${agentId} updated successfully`, agent });
});

// DELETE sales agent (Admin only)
router.delete('/agents/:id', requireAdmin, (req, res) => {
  const agentId = parseInt(req.params.id);
  const idx = (dbStore.agents || []).findIndex(a => a.id === agentId);
  if (idx === -1) {
    return res.status(404).json({ success: false, error: `Agent #${agentId} not found` });
  }

  const removed = dbStore.agents.splice(idx, 1)[0];
  // Unassign any customers previously assigned to this agent
  if (dbStore.assignments) {
    dbStore.assignments = dbStore.assignments.filter(as => as.agent_id !== agentId);
  }
  // Remove linked login user
  if (dbStore.users) {
    dbStore.users = dbStore.users.filter(u => u.agent_id !== agentId);
  }

  saveDbStore(dbStore);
  res.json({ success: true, message: `Agent '${removed.name}' deleted successfully`, deletedId: agentId });
});

// GET assignments
router.get('/assignments', requireAuth, (req, res) => {
  let assignments = dbStore.assignments || [];
  if (req.user && req.user.role === 'agent') {
    assignments = assignments.filter(as => as.agent_id === req.user.agentId);
  }
  res.json({ success: true, count: assignments.length, assignments });
});

// POST assign location(s) / customer(s) to an agent (Admin only)
router.post('/assignments', requireAdmin, (req, res) => {
  const { agent_id, chiller_codes, customer_names } = req.body;
  const agentId = parseInt(agent_id);
  const agent = (dbStore.agents || []).find(a => a.id === agentId);

  if (!agent) {
    return res.status(400).json({ success: false, error: 'Valid sales agent ID is required' });
  }

  if (!Array.isArray(dbStore.assignments)) {
    dbStore.assignments = [];
  }

  let assignedCount = 0;

  // Support assigning by customer_names or chiller_codes
  if (Array.isArray(customer_names) && customer_names.length > 0) {
    for (const cName of customer_names) {
      if (!cName) continue;
      dbStore.assignments = dbStore.assignments.filter(as => as.customer_name?.toLowerCase() !== cName.toLowerCase());
      dbStore.assignments.push({
        id: Date.now() + Math.floor(Math.random() * 1000),
        customer_name: cName,
        agent_id: agent.id,
        agent_name: agent.name,
        agent_area: agent.area,
        assigned_at: new Date().toISOString()
      });
      assignedCount++;
    }
  } else if (Array.isArray(chiller_codes) && chiller_codes.length > 0) {
    for (const code of chiller_codes) {
      if (!code) continue;
      const ch = dbStore.chillers.find(c => (c.chiller_code || c.chillerCode) === code);
      const custName = ch ? (ch.customer_name || ch.customerName) : '';

      dbStore.assignments = dbStore.assignments.filter(as => as.chiller_code !== code);
      dbStore.assignments.push({
        id: Date.now() + Math.floor(Math.random() * 1000),
        chiller_code: code,
        chiller_id: ch?.id,
        customer_name: custName,
        agent_id: agent.id,
        agent_name: agent.name,
        agent_area: agent.area,
        assigned_at: new Date().toISOString()
      });
      assignedCount++;
    }
  } else {
    return res.status(400).json({ success: false, error: 'Please provide chiller_codes or customer_names to assign' });
  }

  saveDbStore(dbStore);
  res.json({
    success: true,
    message: `Successfully assigned ${assignedCount} location(s) to ${agent.name}`,
    assignedCount,
    agent
  });
});

// DELETE unassign (Admin only)
router.delete('/assignments', requireAdmin, (req, res) => {
  const { customer_name, chiller_code } = req.body;
  if (!customer_name && !chiller_code) {
    return res.status(400).json({ success: false, error: 'customer_name or chiller_code required' });
  }

  const initialCount = (dbStore.assignments || []).length;
  if (customer_name) {
    dbStore.assignments = dbStore.assignments.filter(as => as.customer_name?.toLowerCase() !== customer_name.toLowerCase());
  } else if (chiller_code) {
    dbStore.assignments = dbStore.assignments.filter(as => as.chiller_code !== chiller_code);
  }

  const removedCount = initialCount - dbStore.assignments.length;
  saveDbStore(dbStore);
  res.json({ success: true, message: `Removed ${removedCount} assignment(s)`, removedCount });
});

export default router;
