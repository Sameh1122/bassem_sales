import { extractUserFromReq } from '../utils/security.js';

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
  if (req.user.role !== 'admin' && req.user.role !== 'owner') {
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
