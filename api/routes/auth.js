import express from 'express';
import { requireAuth, requireAdmin } from '../middleware/auth.js';
import {
  getClientIp,
  checkRateLimit,
  recordFailedAttempt,
  clearFailedAttempts,
  verifyPassword,
  validateComplexPassword,
  hashPassword,
  createToken
} from '../utils/security.js';
import { dbStore, DEFAULT_USERS, saveDbStore } from '../services/storage.js';

const router = express.Router();

router.post(['/auth/login', '/login'], (req, res) => {
  const emailInput = req.body.email || req.body.username;
  const password = req.body.password;

  if (!emailInput || !password) {
    return res.status(400).json({ success: false, error: 'Email and password are required' });
  }

  const cleanIdentifier = emailInput.trim().toLowerCase();
  const clientIp = getClientIp(req);

  console.log(`[AUTH LOGIN] Attempt for '${cleanIdentifier}', from IP '${clientIp}'`);

  // Rate limiting check on both IP and account identifier
  const ipCheck = checkRateLimit(`ip:${clientIp}`);
  if (ipCheck.limited) {
    console.warn(`[AUTH LOGIN] IP rate-limited: ${clientIp}`);
    return res.status(429).json({
      success: false,
      error: `Too many failed attempts from your IP. Please try again in ${ipCheck.minutesLeft} minute(s).`
    });
  }

  const userCheck = checkRateLimit(`user:${cleanIdentifier}`);
  if (userCheck.limited) {
    console.warn(`[AUTH LOGIN] User rate-limited: ${cleanIdentifier}`);
    return res.status(429).json({
      success: false,
      error: `Account temporarily locked due to multiple failed attempts. Please try again in ${userCheck.minutesLeft} minute(s).`
    });
  }

  let user = (dbStore.users || []).find(u =>
    (u.email && u.email.toLowerCase() === cleanIdentifier) ||
    (u.username && u.username.toLowerCase() === cleanIdentifier)
  );

  const defaultUser = DEFAULT_USERS.find(d =>
    d.email.toLowerCase() === cleanIdentifier || d.username.toLowerCase() === cleanIdentifier
  );

  if (!user && defaultUser) {
    user = { ...defaultUser };
    if (!Array.isArray(dbStore.users)) dbStore.users = [];
    dbStore.users.push(user);
    saveDbStore(dbStore);
  }

  if (!user) {
    console.warn(`[AUTH LOGIN FAILED] Unknown user: '${cleanIdentifier}'`);
    recordFailedAttempt(`ip:${clientIp}`);
    recordFailedAttempt(`user:${cleanIdentifier}`);
    req.auditEvent.category = 'auth';
    req.auditEvent.action = 'AUTH_LOGIN_FAILED';
    req.auditEvent.details = `Login failed: user '${cleanIdentifier}' not found`;
    return res.status(401).json({ success: false, error: 'Invalid email or password' });
  }

  const isMatch = verifyPassword(password, user.password_hash, user.salt) ||
                  (typeof password === 'string' && verifyPassword(password.trim(), user.password_hash, user.salt)) ||
                  (defaultUser && verifyPassword(password, defaultUser.password_hash, defaultUser.salt)) ||
                  (defaultUser && typeof password === 'string' && verifyPassword(password.trim(), defaultUser.password_hash, defaultUser.salt));

  if (isMatch && defaultUser && user.password_hash !== defaultUser.password_hash) {
    user.password_hash = defaultUser.password_hash;
    user.salt = defaultUser.salt;
    saveDbStore(dbStore);
  }

  if (!isMatch) {
    console.warn(`[AUTH LOGIN FAILED] Password mismatch for: '${cleanIdentifier}'`);
    recordFailedAttempt(`ip:${clientIp}`);
    recordFailedAttempt(`user:${cleanIdentifier}`);
    req.auditEvent.category = 'auth';
    req.auditEvent.action = 'AUTH_LOGIN_FAILED';
    req.auditEvent.details = `Login failed: incorrect password for '${cleanIdentifier}'`;
    return res.status(401).json({ success: false, error: 'Invalid email or password' });
  }

  console.log(`[AUTH LOGIN SUCCESS] Authenticated as '${user.email}' (${user.role})`);
  req.auditEvent.category = 'auth';
  req.auditEvent.action = 'AUTH_LOGIN_SUCCESS';
  req.auditEvent.details = `User '${user.email}' (${user.role}) logged in successfully`;

  // Clear failed attempt records on successful login
  clearFailedAttempts(`ip:${clientIp}`);
  clearFailedAttempts(`user:${cleanIdentifier}`);

  const token = createToken({
    id: user.id,
    email: user.email,
    username: user.username,
    name: user.name,
    role: user.role,
    agentId: user.agent_id
  });

  const linkedAgent = user.agent_id ? (dbStore.agents || []).find(a => a.id === user.agent_id) : null;

  res.json({
    success: true,
    message: 'Login successful',
    token,
    user: {
      id: user.id,
      email: user.email,
      username: user.username,
      name: user.name,
      role: user.role,
      agentId: user.agent_id,
      agentArea: linkedAgent ? linkedAgent.area : null
    }
  });
});

router.get(['/auth/me', '/me'], (req, res) => {
  if (!req.user) {
    return res.status(401).json({ success: false, error: 'Not authenticated' });
  }
  const user = (dbStore.users || []).find(u => u.id === req.user.id);
  const linkedAgent = req.user.agentId ? (dbStore.agents || []).find(a => a.id === req.user.agentId) : null;
  res.json({
    success: true,
    user: {
      id: req.user.id,
      email: user ? user.email : req.user.email,
      username: req.user.username,
      name: req.user.name,
      role: req.user.role,
      agentId: req.user.agentId,
      agentArea: linkedAgent ? linkedAgent.area : null
    }
  });
});

router.post('/auth/change-password', requireAuth, (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword) {
    return res.status(400).json({ success: false, error: 'Current password and new password are required' });
  }

  const user = (dbStore.users || []).find(u => u.id === req.user.id);
  if (!user) {
    return res.status(404).json({ success: false, error: 'User not found' });
  }

  if (!verifyPassword(currentPassword, user.password_hash, user.salt)) {
    return res.status(400).json({ success: false, error: 'Current password is incorrect' });
  }

  const complexity = validateComplexPassword(newPassword);
  if (!complexity.valid) {
    return res.status(400).json({ success: false, error: complexity.error });
  }

  const { hash, salt } = hashPassword(newPassword);
  user.password_hash = hash;
  user.salt = salt;
  saveDbStore(dbStore);

  res.json({ success: true, message: 'Password updated successfully' });
});

router.post('/auth/reset-agent-password', requireAdmin, (req, res) => {
  const { agentId, newPassword } = req.body;
  if (!agentId || !newPassword) {
    return res.status(400).json({ success: false, error: 'Agent ID and new password are required' });
  }

  const complexity = validateComplexPassword(newPassword);
  if (!complexity.valid) {
    return res.status(400).json({ success: false, error: complexity.error });
  }

  const parsedAgentId = parseInt(agentId);
  const agent = (dbStore.agents || []).find(a => a.id === parsedAgentId);
  if (!agent) {
    return res.status(404).json({ success: false, error: 'Agent not found' });
  }

  let user = (dbStore.users || []).find(u => u.agent_id === parsedAgentId);
  const { hash, salt } = hashPassword(newPassword);

  if (!user) {
    const baseUsername = agent.name.toLowerCase().replace(/[^a-z0-9]/g, '.').replace(/\.+/g, '.');
    user = {
      id: Date.now(),
      username: baseUsername,
      name: agent.name,
      role: 'agent',
      agent_id: agent.id,
      password_hash: hash,
      salt,
      created_at: new Date().toISOString()
    };
    dbStore.users.push(user);
  } else {
    user.password_hash = hash;
    user.salt = salt;
  }

  saveDbStore(dbStore);
  res.json({
    success: true,
    message: `Password for agent '${agent.name}' set successfully`,
    username: user.username
  });
});

export default router;
