import { extractUserFromReq } from '../utils/security.js';

export const ADMIN_ROLES = new Set(['owner', 'admin', 'regional_manager']);

export function isAdminRole(user) {
  return Boolean(user && ADMIN_ROLES.has(user.role));
}

export function attachUser(req, res, next) {
  req.user = extractUserFromReq(req);
  next();
}

export function requireAuth(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ success: false, error: 'Authentication required. Please login.' });
  }
  next();
}

export function requireAdmin(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ success: false, error: 'Authentication required. Please login.' });
  }
  if (!isAdminRole(req.user)) {
    return res.status(403).json({ success: false, error: 'Access forbidden. Administrator privileges required.' });
  }
  next();
}

export function requireOwner(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ success: false, error: 'Authentication required. Please login.' });
  }
  if (req.user.role !== 'owner') {
    return res.status(403).json({ success: false, error: 'Access forbidden. System Owner privileges required.' });
  }
  next();
}

export function requireRoles(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, error: 'Authentication required. Please login.' });
    }
    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ success: false, error: 'Access forbidden. Insufficient role permissions.' });
    }
    next();
  };
}
