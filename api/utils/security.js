import crypto from 'crypto';

/**
 * Persistent 256-bit runtime secret if not supplied via environment.
 */
export function resolveJwtSecret() {
  if (process.env.JWT_SECRET && process.env.JWT_SECRET.trim().length >= 32) {
    return process.env.JWT_SECRET.trim();
  }
  if (process.env.NODE_ENV === 'production' || process.env.VERCEL) {
    if (process.env.JWT_SECRET && process.env.JWT_SECRET.trim().length > 0) {
      return process.env.JWT_SECRET.trim();
    }
    console.error('⚠️ [SECURITY WARNING] Explicit JWT_SECRET is missing in production. Generating ephemeral runtime key.');
    return crypto.randomBytes(32).toString('hex');
  }
  return 'bassem_sales_secure_persistent_jwt_secret_2026_prod_fmcg_key_9981';
}

export const JWT_SECRET = resolveJwtSecret();

export function safeTimingCompare(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

export function validateComplexPassword(password) {
  if (!password || typeof password !== 'string') {
    return { valid: false, error: 'Password is required' };
  }
  if (password.length < 8) {
    return { valid: false, error: 'Password must be at least 8 characters long' };
  }
  if (!/[A-Z]/.test(password)) {
    return { valid: false, error: 'Password must contain at least one uppercase letter (A-Z)' };
  }
  if (!/[a-z]/.test(password)) {
    return { valid: false, error: 'Password must contain at least one lowercase letter (a-z)' };
  }
  if (!/[0-9]/.test(password)) {
    return { valid: false, error: 'Password must contain at least one number (0-9)' };
  }
  if (!/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) {
    return { valid: false, error: 'Password must contain at least one special character (!@#$%^&*...)' };
  }
  return { valid: true };
}

export function hashPassword(password, salt = null) {
  const generatedSalt = salt || crypto.randomBytes(16).toString('hex');
  const hash = crypto.pbkdf2Sync(password, generatedSalt, 100000, 64, 'sha512').toString('hex');
  return { hash, salt: generatedSalt };
}

export function verifyPassword(password, storedHash, salt) {
  if (!password || !storedHash || !salt) return false;
  // Primary check: 100,000 PBKDF2 iterations (maximum security) with timing-safe comparison
  const check100k = crypto.pbkdf2Sync(password, salt, 100000, 64, 'sha512').toString('hex');
  if (safeTimingCompare(check100k, storedHash)) return true;
  // Fallback check: 1,000 iterations for backwards compatibility
  const check1k = crypto.pbkdf2Sync(password, salt, 1000, 64, 'sha512').toString('hex');
  return safeTimingCompare(check1k, storedHash);
}

// In-memory rate limiting map: identifier -> { count, lockoutUntil, lastAttempt }
const loginAttempts = new Map();

// Periodic cleanup every 10 minutes to prevent memory leak
setInterval(() => {
  const now = Date.now();
  for (const [key, record] of loginAttempts.entries()) {
    if (now > record.lockoutUntil && (now - (record.lastAttempt || 0)) > 15 * 60 * 1000) {
      loginAttempts.delete(key);
    }
  }
}, 10 * 60 * 1000).unref();

export function getClientIp(req) {
  return (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown')
    .toString()
    .split(',')[0]
    .trim();
}

export function checkRateLimit(key) {
  const forceRateLimit = process.env.ENABLE_RATE_LIMIT_TEST === 'true';
  if (!forceRateLimit && (key.includes('127.0.0.1') || key.includes('::1') || key.includes('localhost') || !process.env.NODE_ENV || process.env.NODE_ENV !== 'production')) {
    return { limited: false };
  }
  const now = Date.now();
  const rec = loginAttempts.get(key);
  if (rec && rec.count >= 5 && now < rec.lockoutUntil) {
    const minutesLeft = Math.ceil((rec.lockoutUntil - now) / 60000);
    return { limited: true, minutesLeft };
  }
  return { limited: false };
}

export function recordFailedAttempt(key) {
  const now = Date.now();
  const rec = loginAttempts.get(key) || { count: 0, lockoutUntil: 0, lastAttempt: now };
  rec.count += 1;
  rec.lastAttempt = now;
  if (rec.count >= 5) {
    rec.lockoutUntil = now + 5 * 60 * 1000; // 5-minute security lockout
  }
  loginAttempts.set(key, rec);
}

export function clearFailedAttempts(key) {
  loginAttempts.delete(key);
}

export function createToken(payload) {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const body = Buffer.from(JSON.stringify({ ...payload, exp: Date.now() + 7 * 24 * 60 * 60 * 1000 })).toString('base64url');
  const signature = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest('base64url');
  return `${header}.${body}.${signature}`;
}

export function verifyToken(token) {
  if (!token || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [header, body, signature] = parts;
  const expectedSignature = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest('base64url');
  if (!safeTimingCompare(expectedSignature, signature)) return null;
  try {
    const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    if (payload.exp && Date.now() > payload.exp) return null;
    return payload;
  } catch (e) {
    return null;
  }
}

export function extractUserFromReq(req) {
  const authHeader = req.headers.authorization || req.headers.Authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7).trim();
    return verifyToken(token);
  }
  return null;
}

export function neutralizeFormula(s) {
  // Prevent CSV / Excel Formula Injection (DDE injection) while preserving negative numbers
  if (/^[=\+\-@]/.test(s) && !/^-?\d+(\.\d+)?$/.test(s)) {
    return `'${s}`;
  }
  return s;
}

export const ALLOWED_ATTACHMENT_EXTS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.pdf']);
export const ALLOWED_ATTACHMENT_MIMES = new Set(['image/jpeg', 'image/png', 'image/webp', 'application/pdf']);

/**
 * ADR-005: Configurable CORS allowlist via CORS_ORIGINS env var (comma-separated).
 * Safely defaults to allowing same-origin / non-browser requests, localhost/127.0.0.1,
 * and *.vercel.app origins when CORS_ORIGINS is not explicitly configured.
 */
export function buildCorsOptions() {
  const raw = process.env.CORS_ORIGINS;
  const configured = raw
    ? raw.split(',').map(o => o.trim()).filter(Boolean)
    : null;

  return {
    origin: (origin, callback) => {
      // Allow requests with no Origin header (curl, server-to-server, mobile, same-origin)
      if (!origin) return callback(null, true);

      if (configured) {
        if (configured.includes('*') || configured.includes(origin)) {
          return callback(null, true);
        }
        return callback(null, false);
      }

      // Safe defaults for local dev and Vercel preview/prod deployments
      if (
        /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin) ||
        /^https:\/\/[a-z0-9-]+\.vercel\.app$/i.test(origin) ||
        (process.env.VERCEL_URL && origin === `https://${process.env.VERCEL_URL}`)
      ) {
        return callback(null, true);
      }

      return callback(null, false);
    }
  };
}
