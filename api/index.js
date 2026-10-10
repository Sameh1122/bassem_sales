import express from 'express';
import cors from 'cors';
import multer from 'multer';
import XLSXModule from 'xlsx';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import os from 'os';
import { fileURLToPath } from 'url';

const XLSX = XLSXModule.default || XLSXModule;

const app = express();
app.disable('x-powered-by');

// Security headers middleware
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'SAMEORIGIN');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
});

app.use(cors());
app.use(express.json({ limit: '25mb' }));

const storage = multer.memoryStorage();
const upload = multer({
  storage,
  limits: {
    fileSize: 25 * 1024 * 1024, // 25 MB max to protect against memory exhaustion
    files: 1
  },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ext === '.xlsx' || ext === '.xls' || ext === '.csv') {
      cb(null, true);
    } else {
      cb(new Error('Only Excel (.xlsx, .xls) and CSV spreadsheet files are allowed'));
    }
  }
});

const uploadAttach = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 15 * 1024 * 1024 // 15 MB for visit photos and attachments
  }
});

app.use('/uploads', express.static(path.resolve('public/uploads')));
if (process.env.VERCEL) {
  app.use('/uploads', express.static(path.resolve('/tmp/uploads')));
}

// Persistent 256-bit runtime secret if not supplied via environment
const JWT_SECRET = process.env.JWT_SECRET || 'bassem_sales_secure_persistent_jwt_secret_2026_prod_fmcg_key_9981';

function safeTimingCompare(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

function validateComplexPassword(password) {
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

function hashPassword(password, salt = null) {
  const generatedSalt = salt || crypto.randomBytes(16).toString('hex');
  const hash = crypto.pbkdf2Sync(password, generatedSalt, 100000, 64, 'sha512').toString('hex');
  return { hash, salt: generatedSalt };
}

function verifyPassword(password, storedHash, salt) {
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

function getClientIp(req) {
  return (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown')
    .toString()
    .split(',')[0]
    .trim();
}

function checkRateLimit(key) {
  if (key.includes('127.0.0.1') || key.includes('::1') || key.includes('localhost') || !process.env.NODE_ENV || process.env.NODE_ENV !== 'production') {
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

function recordFailedAttempt(key) {
  const now = Date.now();
  const rec = loginAttempts.get(key) || { count: 0, lockoutUntil: 0, lastAttempt: now };
  rec.count += 1;
  rec.lastAttempt = now;
  if (rec.count >= 5) {
    rec.lockoutUntil = now + 5 * 60 * 1000; // 5-minute security lockout
  }
  loginAttempts.set(key, rec);
}

function clearFailedAttempts(key) {
  loginAttempts.delete(key);
}

function createToken(payload) {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const body = Buffer.from(JSON.stringify({ ...payload, exp: Date.now() + 7 * 24 * 60 * 60 * 1000 })).toString('base64url');
  const signature = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest('base64url');
  return `${header}.${body}.${signature}`;
}

function verifyToken(token) {
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

function extractUserFromReq(req) {
  const authHeader = req.headers.authorization || req.headers.Authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7).trim();
    return verifyToken(token);
  }
  return null;
}

const DEFAULT_USERS = [
  {
    id: 1,
    email: 'admin@sales.com',
    username: 'admin',
    name: 'System Administrator',
    role: 'admin',
    agent_id: null,
    salt: '144ed1248dffddc9c8098f5a098bcd75',
    password_hash: 'f0ce70c0a291b4e17db02f2a66ebfdb00328fc0688a348c91b99b5f8abcd4d250e32b1fbce9d559ebfcb3a843f24f51046990d06ae163308c8468189cc3cbcfc',
    created_at: new Date().toISOString()
  },
  {
    id: 2,
    email: 'omnia@sales.com',
    username: 'omnia',
    name: 'أمنية',
    role: 'agent',
    agent_id: 1,
    salt: '05008a113085b5e27a6a68af74385dd1',
    password_hash: 'f652719fd4c1dba59367955e28caf67c27aad20f925247a25789b8a782cc2236dd7b7cbe26ad9e55ef504e6e615b91c112ff1a9f88fa0488a8ca215bb61720db',
    created_at: new Date().toISOString()
  },
  {
    id: 3,
    email: 'mina@sales.com',
    username: 'mina',
    name: 'مينا',
    role: 'agent',
    agent_id: 2,
    salt: 'fb563aa05ddaa0ceecb31178145fdfaa',
    password_hash: '3ea7a2bfd27c5cbd96ae7e57d110fd06e71cd0e3f520041ce10e709af94079385959077a55d0257163d787f7c50f2610f56cae4805913cc99e2d6d14033944d5',
    created_at: new Date().toISOString()
  }
];

const DEFAULT_AGENTS = [
  { id: 1, name: 'أمنية', area: 'مصر الجديدة', phone: '+20 100 000 0000', email: 'omnia@sales.com', login_email: 'omnia@sales.com', created_at: new Date().toISOString() },
  { id: 2, name: 'مينا', area: 'مدينة نصر', phone: '+20 101 000 0000', email: 'mina@sales.com', login_email: 'mina@sales.com', created_at: new Date().toISOString() }
];

// Default Columns Definitions
const DEFAULT_COLUMNS = [
  { id: 1, key_name: 'Branch', display_label: 'Branch', data_type: 'string', is_required: 0, is_active: 1, display_order: 1 },
  { id: 2, key_name: 'Received Date', display_label: 'Received Date', data_type: 'date', is_required: 0, is_active: 1, display_order: 2 },
  { id: 3, key_name: 'Chiller Type', display_label: 'Chiller Type', data_type: 'string', is_required: 0, is_active: 1, display_order: 3 },
  { id: 4, key_name: 'Chiller Configuration', display_label: 'Chiller Configuration', data_type: 'string', is_required: 0, is_active: 1, display_order: 4 },
  { id: 5, key_name: 'Chiller Code', display_label: 'Chiller Code', data_type: 'string', is_required: 1, is_active: 1, display_order: 5 },
  { id: 6, key_name: 'Chiller Status', display_label: 'Chiller Status', data_type: 'string', is_required: 0, is_active: 1, display_order: 6 },
  { id: 7, key_name: 'Condiiton', display_label: 'Condition', data_type: 'string', is_required: 0, is_active: 1, display_order: 7 },
  { id: 8, key_name: 'Action Date', display_label: 'Action Date', data_type: 'date', is_required: 0, is_active: 1, display_order: 8 },
  { id: 9, key_name: 'Serial Number', display_label: 'Serial Number', data_type: 'string', is_required: 0, is_active: 1, display_order: 9 },
  { id: 10, key_name: 'Longitude', display_label: 'Longitude', data_type: 'coords', is_required: 1, is_active: 1, display_order: 10 },
  { id: 11, key_name: 'Latitude', display_label: 'Latitude', data_type: 'coords', is_required: 1, is_active: 1, display_order: 11 },
  { id: 12, key_name: 'Truck Code', display_label: 'Truck Code', data_type: 'string', is_required: 0, is_active: 1, display_order: 12 },
  { id: 13, key_name: 'SR Name', display_label: 'SR Name', data_type: 'string', is_required: 0, is_active: 1, display_order: 13 },
  { id: 14, key_name: 'SSV Name', display_label: 'SSV Name', data_type: 'string', is_required: 0, is_active: 1, display_order: 14 },
  { id: 15, key_name: 'Customer Type', display_label: 'Customer Type', data_type: 'string', is_required: 1, is_active: 1, display_order: 15 },
  { id: 16, key_name: 'Visit Day', display_label: 'Visit Day', data_type: 'string', is_required: 0, is_active: 1, display_order: 16 },
  { id: 17, key_name: 'Customer Code', display_label: 'Customer Code', data_type: 'string', is_required: 0, is_active: 1, display_order: 17 },
  { id: 18, key_name: 'Customer Name', display_label: 'Customer Name', data_type: 'string', is_required: 0, is_active: 1, display_order: 18 },
  { id: 19, key_name: 'Customer Address', display_label: 'Customer Address', data_type: 'string', is_required: 0, is_active: 1, display_order: 19 },
  { id: 20, key_name: 'Mobile Number', display_label: 'Mobile Number', data_type: 'string', is_required: 0, is_active: 1, display_order: 20 },
  { id: 21, key_name: 'Jan 2026 Invoice', display_label: 'Jan 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 21 },
  { id: 22, key_name: 'Feb 2026 Invoice', display_label: 'Feb 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 22 },
  { id: 23, key_name: 'Mar 2026 Invoice', display_label: 'Mar 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 23 },
  { id: 24, key_name: 'Apr 2026 Invoice', display_label: 'Apr 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 24 },
  { id: 25, key_name: 'May 2026 Invoice', display_label: 'May 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 25 },
  { id: 26, key_name: 'June 2026 Invoice', display_label: 'June 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 26 },
  { id: 27, key_name: 'July 2026 Invoice', display_label: 'July 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 27 },
  { id: 28, key_name: 'Aug 2026 Invoice', display_label: 'Aug 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 28 },
  { id: 29, key_name: 'Sep 2026 Invoice', display_label: 'Sep 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 29 },
  { id: 30, key_name: 'Oct 2026 Invoice', display_label: 'Oct 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 30 },
  { id: 31, key_name: 'Nov 2026 Invoice', display_label: 'Nov 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 31 },
  { id: 32, key_name: 'Dec 2026 Invoice', display_label: 'Dec 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 32 },
  { id: 33, key_name: 'YTD', display_label: 'YTD', data_type: 'number', is_required: 0, is_active: 1, display_order: 33 },
  { id: 34, key_name: 'Average / Month', display_label: 'Average / Month', data_type: 'number', is_required: 0, is_active: 1, display_order: 34 },
  { id: 35, key_name: 'Month Ach. Status', display_label: 'Efficiency (Month Ach. Status)', data_type: 'string', is_required: 1, is_active: 1, display_order: 35 },
  { id: 36, key_name: 'Notes', display_label: 'Notes', data_type: 'string', is_required: 0, is_active: 1, display_order: 36 }
];

const DEFAULT_FORMS = [
  {
    id: 1,
    title: 'Chiller Operational & Hygiene Audit',
    description: 'Standard inspection form for field visit verification, temperature audit, cleanliness check, and photo attachments.',
    assigned_agent_ids: [],
    is_active: 1,
    created_at: new Date().toISOString(),
    fields: [
      {
        id: 'f_cleanliness',
        label: 'Chiller Cleanliness & Hygiene',
        type: 'choose',
        required: true,
        placeholder: '',
        options: ['Clean & Sanitized', 'Acceptable / Minor Dust', 'Needs Urgent Deep Clean', 'Severely Dirty']
      },
      {
        id: 'f_temp',
        label: 'Operating Temperature (°C)',
        type: 'text',
        required: true,
        placeholder: 'e.g. 4.0',
        options: []
      },
      {
        id: 'f_branding',
        label: 'Brand Sticker & Asset Branding Visibility',
        type: 'choose',
        required: true,
        placeholder: '',
        options: ['100% Intact & Clear', 'Peeling / Damaged', 'Covered by Competitive Stock', 'Missing Logos']
      },
      {
        id: 'f_stock_level',
        label: 'Chiller Stock Fill Level',
        type: 'choose',
        required: false,
        placeholder: '',
        options: ['Full (80-100%)', 'Moderate (40-79%)', 'Low (10-39%)', 'Empty (<10%)']
      },
      {
        id: 'f_notes',
        label: 'Merchant Notes & Customer Feedback',
        type: 'text',
        required: false,
        placeholder: 'Enter merchant feedback or maintenance alerts...',
        options: []
      },
      {
        id: 'f_photos',
        label: 'Chiller & Store Front Photos',
        type: 'attachments',
        required: true,
        placeholder: '',
        options: []
      }
    ]
  }
];

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const DB_FILE = process.env.VERCEL ? '/tmp/chillers_db.json' : path.resolve(os.tmpdir(), 'chillers_db.json');

function loadDbStore() {
  try {
    if (fs.existsSync(DB_FILE)) {
      const content = fs.readFileSync(DB_FILE, 'utf8');
      const parsed = JSON.parse(content);
      if (parsed && Array.isArray(parsed.chillers) && parsed.chillers.length > 0) {
        if (!Array.isArray(parsed.users) || parsed.users.length === 0) {
          parsed.users = [...DEFAULT_USERS];
        } else {
          DEFAULT_USERS.forEach(defUser => {
            const idx = parsed.users.findIndex(u => u.email && u.email.toLowerCase() === defUser.email.toLowerCase());
            if (idx !== -1) {
              parsed.users[idx].password_hash = defUser.password_hash;
              parsed.users[idx].salt = defUser.salt;
            } else {
              parsed.users.push({ ...defUser });
            }
          });
        }
        if (!Array.isArray(parsed.agents) || parsed.agents.length === 0) {
          parsed.agents = [...DEFAULT_AGENTS];
        }
        if (!Array.isArray(parsed.assignments)) {
          parsed.assignments = [];
        }
        if (!Array.isArray(parsed.forms) || parsed.forms.length === 0) {
          parsed.forms = JSON.parse(JSON.stringify(DEFAULT_FORMS));
        } else {
          parsed.forms.forEach(f => {
            if (Array.isArray(f.assigned_agent_ids)) {
              f.assigned_agent_ids = f.assigned_agent_ids.map(Number).filter(n => !isNaN(n));
            } else {
              f.assigned_agent_ids = [];
            }
          });
        }
        if (!Array.isArray(parsed.form_responses)) {
          parsed.form_responses = [];
        }
        return parsed;
      }
    }
  } catch (e) {
    console.warn('⚠️ Error reading persistent DB file:', e.message);
  }

  let store = {
    columns: [...DEFAULT_COLUMNS],
    batches: [],
    chillers: [],
    history: [],
    agents: [...DEFAULT_AGENTS],
    assignments: [],
    forms: JSON.parse(JSON.stringify(DEFAULT_FORMS)),
    form_responses: [],
    users: [...DEFAULT_USERS]
  };

  try {
    const candidateSeedPaths = [
      path.join(__dirname, 'seedData.json'),
      path.resolve('api/seedData.json'),
      path.resolve('seedData.json'),
      path.join(process.cwd(), 'api/seedData.json')
    ];
    const seedPath = candidateSeedPaths.find(p => fs.existsSync(p));
    if (seedPath) {
      console.log('📦 Loading seedData from:', seedPath);
      const seed = JSON.parse(fs.readFileSync(seedPath, 'utf8'));
      if (seed.columns && seed.columns.length > 0) store.columns = seed.columns;
      if (seed.batches && seed.batches.length > 0) store.batches = seed.batches;
      if (seed.chillers && seed.chillers.length > 0) store.chillers = seed.chillers;
      if (seed.history && seed.history.length > 0) store.history = seed.history;
      if (seed.assignments && seed.assignments.length > 0) store.assignments = seed.assignments;
      store.agents = [...DEFAULT_AGENTS];
      store.users = [...DEFAULT_USERS];
      console.log(`✅ Loaded ${store.chillers.length} initial chillers from seedData`);
    }
  } catch (err) {
    console.warn('⚠️ Could not load seedData:', err.message);
  }

  if (!Array.isArray(store.assignments)) {
    store.assignments = [];
  }

  if (!Array.isArray(store.forms) || store.forms.length === 0) {
    store.forms = JSON.parse(JSON.stringify(DEFAULT_FORMS));
  }
  if (!Array.isArray(store.form_responses)) {
    store.form_responses = [];
  }

  return store;
}

function saveDbStore(store) {
  try {
    fs.writeFileSync(DB_FILE, JSON.stringify(store, null, 2), 'utf8');
  } catch (e) {
    console.error('⚠️ Error writing to persistent DB file:', e.message);
  }
}

let dbStore = loadDbStore();
saveDbStore(dbStore);

function cleanStr(val) {
  if (val === null || val === undefined) return '';
  let s = String(val).trim();
  if (s === '-' || s === 'None' || s === 'null' || s === 'undefined' || s === '#N/A') return '';
  // Prevent CSV / Excel Formula Injection (DDE injection)
  if (/^[=\+\-@]/.test(s)) {
    // If it's a numeric negative number, keep as is
    if (!/^-?\d+(\.\d+)?$/.test(s)) {
      s = `'${s}`;
    }
  }
  return s;
}

function findVal(row, aliases) {
  const keys = Object.keys(row);
  for (const alias of aliases) {
    const cleanAlias = alias.toLowerCase().replace(/[\s_\-\.]/g, '');
    for (const k of keys) {
      const cleanKey = k.toLowerCase().trim().replace(/[\s_\-\.]/g, '');
      if (cleanKey === cleanAlias) {
        const val = cleanStr(row[k]);
        if (val) return val;
      }
    }
  }
  return '';
}

function parseCoords(rowObj) {
  // Check common latitude aliases
  let rawLat = findVal(rowObj, ['latitude', 'lat', 'gps_lat', 'gps lat', 'lat (n)', 'y', 'خط العرض', 'خط_العرض']);
  // Check common longitude aliases
  let rawLng = findVal(rowObj, ['longitude', 'long', 'lng', 'gps_lng', 'gps lng', 'lng (e)', 'x', 'خط الطول', 'خط_الطول']);

  // Fallback to checking rawObj keys directly
  if (!rawLat) rawLat = cleanStr(rowObj['Latitude'] ?? rowObj['lat'] ?? rowObj['LATITUDE'] ?? rowObj['Lat']);
  if (!rawLng) rawLng = cleanStr(rowObj['Longitude'] ?? rowObj['long'] ?? rowObj['lng'] ?? rowObj['LONGITUDE'] ?? rowObj['Lng']);

  // Handle potential comma as decimal separator (e.g. 30,0906)
  if (typeof rawLat === 'string') rawLat = rawLat.replace(',', '.');
  if (typeof rawLng === 'string') rawLng = rawLng.replace(',', '.');

  let numLat = parseFloat(rawLat);
  let numLng = parseFloat(rawLng);

  if (isNaN(numLat) || isNaN(numLng)) {
    return { lat: null, lng: null, isValid: false, reason: 'Invalid or missing numbers' };
  }

  // Detect header inverted Cairo coordinates (where "Latitude" is ~31.32 and "Longitude" is ~30.09)
  if (numLat >= 31.25 && numLat <= 32.5 && numLng >= 29.8 && numLng <= 30.5) {
    return { lat: numLng, lng: numLat, isValid: true };
  }

  // Standard coordinates check
  if (numLat >= -90 && numLat <= 90 && numLng >= -180 && numLng <= 180) {
    return { lat: numLat, lng: numLng, isValid: true };
  }

  return { lat: null, lng: null, isValid: false, reason: 'Coordinates out of bounds' };
}

function parseExcelBuffer(buffer) {
  const workbook = XLSX.read(buffer, { type: 'buffer', cellDates: true, cellText: false });

  // Find best sheet: prefer CE_Database or CW_Database, else sheet with most rows
  let sheetName = workbook.SheetNames.find(s => s === 'CE_Database' || s === 'CW_Database');
  if (!sheetName) {
    let maxRows = -1;
    for (const name of workbook.SheetNames) {
      const sheet = workbook.Sheets[name];
      const range = XLSX.utils.decode_range(sheet['!ref'] || 'A1:A1');
      const rowCount = range.e.r - range.s.r + 1;
      if (rowCount > maxRows) {
        maxRows = rowCount;
        sheetName = name;
      }
    }
  }
  sheetName = sheetName || workbook.SheetNames[0];

  const worksheet = workbook.Sheets[sheetName];
  const rawRows = XLSX.utils.sheet_to_json(worksheet, { defval: null });

  const parsedRows = [];
  let validCount = 0;
  let invalidCount = 0;

  rawRows.forEach((row, idx) => {
    const rowObj = {};
    const missingFields = [];
    const errors = [];

    // Clean keys and values
    Object.keys(row).forEach(key => {
      const trimmedKey = key ? key.trim() : '';
      if (trimmedKey && !trimmedKey.startsWith('__EMPTY')) {
        const val = row[key];
        rowObj[trimmedKey] = val instanceof Date ? val.toISOString().split('T')[0] : (val !== null && val !== undefined ? String(val).trim() : '');
      }
    });

    // Smart field extraction with flexible aliases
    const code = findVal(rowObj, ['chiller code', 'chillercode', 'code', 'serial number', 'serial', 'chiller id', 'id', 'كود']) || `CH-${idx + 1}`;
    const branch = findVal(rowObj, ['branch', 'فرع']) || cleanStr(rowObj['Branch']);
    const customerType = findVal(rowObj, ['customer type', 'customertype', 'type', 'channel', 'نوع العميل']) || 'Retail';
    const efficiency = findVal(rowObj, ['month ach. status', 'month ach status', 'efficiency', 'status', 'ach. status', 'achievement', 'الكفاءة']) || 'Performing';
    const customerName = findVal(rowObj, ['customer name', 'customername', 'customer', 'client', 'name', 'اسم العميل']) || cleanStr(rowObj['Customer Name']);
    const chillerType = findVal(rowObj, ['chiller type', 'chillertype']) || cleanStr(rowObj['Chiller Type']);
    const chillerStatus = findVal(rowObj, ['chiller status', 'chillerstatus']) || cleanStr(rowObj['Chiller Status']);
    const condition = findVal(rowObj, ['condition', 'condiiton']) || cleanStr(rowObj['Condition'] || rowObj['Condiiton']);
    const customerAddress = findVal(rowObj, ['customer address', 'address', 'عنوان']) || cleanStr(rowObj['Customer Address']);
    const mobileNumber = findVal(rowObj, ['mobile number', 'mobile', 'phone', 'هاتف']) || cleanStr(rowObj['Mobile Number']);

    const coordCheck = parseCoords(rowObj);
    if (!coordCheck.isValid) {
      errors.push('Missing or invalid GPS Latitude/Longitude coordinates');
      missingFields.push('Latitude/Longitude');
    }

    const isValid = coordCheck.isValid && code.length > 0;
    if (isValid) validCount++;
    else invalidCount++;

    parsedRows.push({
      rowIndex: idx + 2,
      chillerCode: code,
      latitude: coordCheck.lat,
      longitude: coordCheck.lng,
      customerType,
      efficiency,
      branch,
      chillerType,
      chillerStatus,
      condition,
      customerName,
      customerAddress,
      mobileNumber,
      rowObj,
      isValid,
      missingFields,
      errors
    });
  });

  return {
    sheetName,
    totalRows: parsedRows.length,
    validCount,
    invalidCount,
    rows: parsedRows
  };
}

const router = express.Router();

// Middleware to extract user from Authorization header
router.use((req, res, next) => {
  req.user = extractUserFromReq(req);
  next();
});

function requireAuth(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ success: false, error: 'Authentication required. Please login.' });
  }
  next();
}

function requireAdmin(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ success: false, error: 'Authentication required. Please login.' });
  }
  if (req.user.role !== 'admin') {
    return res.status(403).json({ success: false, error: 'Access forbidden. Administrator privileges required.' });
  }
  next();
}

router.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    version: '2.2.0',
    users: (dbStore.users || []).map(u => ({ email: u.email, role: u.role, salt: u.salt, hash_prefix: u.password_hash?.substring(0, 10) })),
    timestamp: new Date().toISOString()
  });
});

// ==========================================
// Authentication Endpoints
// ==========================================

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
    console.warn(`[AUTH LOGIN FAILED] Unknown user: '${cleanIdentifier}'. Available in DB:`, (dbStore.users || []).map(u => u.email));
    recordFailedAttempt(`ip:${clientIp}`);
    recordFailedAttempt(`user:${cleanIdentifier}`);
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
    return res.status(401).json({ success: false, error: 'Invalid email or password' });
  }

  console.log(`[AUTH LOGIN SUCCESS] Authenticated as '${user.email}' (${user.role})`);

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

router.get('/columns', requireAuth, (req, res) => {
  res.json({ success: true, columns: dbStore.columns });
});

router.post('/columns', requireAdmin, (req, res) => {
  const { key_name, display_label, data_type = 'string', is_required = 0, is_active = 1 } = req.body;
  const newCol = {
    id: dbStore.columns.length + 1,
    key_name,
    display_label,
    data_type,
    is_required: is_required ? 1 : 0,
    is_active: is_active ? 1 : 0,
    display_order: dbStore.columns.length + 1
  };
  dbStore.columns.push(newCol);
  res.json({ success: true, message: `Column '${display_label}' added successfully` });
});

router.post('/columns/toggle', requireAdmin, (req, res) => {
  const { id, is_active, is_required } = req.body;
  const col = dbStore.columns.find(c => c.id === id);
  if (col) {
    if (is_active !== undefined) col.is_active = is_active ? 1 : 0;
    if (is_required !== undefined) col.is_required = is_required ? 1 : 0;
  }
  res.json({ success: true, message: 'Column updated successfully' });
});

router.post('/excel/parse', requireAdmin, (req, res) => {
  upload.single('file')(req, res, (err) => {
    try {
      if (err) {
        return res.status(400).json({ success: false, error: err.message || 'File upload error' });
      }

      let buffer = null;
      let filename = 'Uploaded_Sheet.xlsx';

      if (req.file) {
        filename = path.basename(req.file.originalname).replace(/[^a-zA-Z0-9_\-\.\u0600-\u06FF]/g, '_');
        buffer = req.file.buffer || (req.file.path && fs.existsSync(req.file.path) ? fs.readFileSync(req.file.path) : null);
      } else if (req.body && req.body.fileBase64) {
        buffer = Buffer.from(req.body.fileBase64, 'base64');
        if (req.body.filename) {
          filename = path.basename(req.body.filename).replace(/[^a-zA-Z0-9_\-\.\u0600-\u06FF]/g, '_');
        }
      }

      if (!buffer) {
        return res.status(400).json({ success: false, error: 'No Excel file provided' });
      }

      const result = parseExcelBuffer(buffer);
      res.json({ success: true, filename, ...result });
    } catch (e) {
      res.status(500).json({ success: false, error: e.message });
    }
  });
});

router.get('/excel/scratch-sample', requireAdmin, (req, res) => {
  try {
    const candidatePaths = [
      path.resolve('api/sample_chillers.xlsx'),
      path.join(__dirname, 'sample_chillers.xlsx'),
      path.resolve('public/sample_chillers.xlsx'),
      path.resolve('sample_chillers.xlsx')
    ];
    const foundPath = candidatePaths.find(p => fs.existsSync(p));
    if (foundPath) {
      const buffer = fs.readFileSync(foundPath);
      const result = parseExcelBuffer(buffer);
      return res.json({ success: true, filename: 'sample_chillers.xlsx', ...result });
    }
    res.status(404).json({ success: false, error: 'Sample file not found. Please upload a custom .xlsx file.' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.post('/excel/confirm', requireAdmin, (req, res) => {
  dbStore = loadDbStore();
  const { filename = 'Uploaded_Sheet.xlsx', rows = [], bypassValidation = false } = req.body || {};
  const rowsToSave = bypassValidation 
    ? rows 
    : rows.filter(r => r.isValid !== false || (r.latitude != null && r.longitude != null));
    
  const batchId = dbStore.batches.length + 1;

  dbStore.batches.push({
    id: batchId,
    filename,
    total_rows: rows.length,
    valid_rows: rowsToSave.length,
    invalid_rows: rows.length - rowsToSave.length,
    bypassed_validation: bypassValidation ? 1 : 0,
    uploaded_at: new Date().toISOString()
  });

  for (const r of rowsToSave) {
    const code = r.chillerCode || `CH-${Math.random().toString(36).substring(7)}`;
    const existingIdx = dbStore.chillers.findIndex(c => (c.chiller_code || c.chillerCode) === code);
    const item = {
      id: existingIdx >= 0 ? dbStore.chillers[existingIdx].id : dbStore.chillers.length + 1,
      chiller_code: code,
      batch_id: batchId,
      latitude: r.latitude,
      longitude: r.longitude,
      customer_type: r.customerType,
      efficiency: r.efficiency,
      branch: r.branch,
      chiller_type: r.chillerType,
      chiller_status: r.chillerStatus,
      condition: r.condition,
      customer_name: r.customerName,
      raw_data_json: typeof (r.rowObj || r.rawData) === 'object' ? JSON.stringify(r.rowObj || r.rawData || {}) : String(r.rowObj || r.rawData || '{}'),
      updated_at: new Date().toISOString()
    };
    if (existingIdx >= 0) dbStore.chillers[existingIdx] = item;
    else dbStore.chillers.push(item);

    dbStore.history.push({ ...item, id: dbStore.history.length + 1, snapshot_time: new Date().toISOString() });
  }

  saveDbStore(dbStore);

  const formattedChillers = dbStore.chillers.map(r => ({
    id: r.id,
    chillerCode: r.chiller_code || r.chillerCode,
    batchId: r.batch_id || r.batchId,
    latitude: r.latitude,
    longitude: r.longitude,
    customerType: r.customer_type || r.customerType,
    efficiency: r.efficiency,
    branch: r.branch,
    chillerType: r.chiller_type || r.chillerType,
    chillerStatus: r.chiller_status || r.chillerStatus,
    condition: r.condition,
    customerName: r.customer_name || r.customerName,
    rawData: typeof r.raw_data_json === 'string' ? JSON.parse(r.raw_data_json || '{}') : (r.rawData || r.raw_data_json || {})
  }));

  res.json({
    success: true,
    batchId,
    savedRowsCount: rowsToSave.length,
    chillers: formattedChillers,
    message: `Successfully saved ${rowsToSave.length} records into database.`
  });
});

function getChillerVisitInfo(chillerCode, customerName, store = null) {
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

router.get('/chillers', requireAuth, (req, res) => {
  const dbStore = loadDbStore();
  const { efficiency, customerType, search, batchId } = req.query;
  let rows = [...dbStore.chillers];

  if (batchId && batchId !== 'All' && batchId !== 'all') {
    const bId = parseInt(batchId);
    if (!isNaN(bId)) {
      // Check if batch exists in history snapshots for exact point-in-time state
      const historicalRows = dbStore.history.filter(h => (h.batch_id || h.batchId) === bId);
      if (historicalRows.length > 0) {
        rows = historicalRows;
      } else {
        rows = rows.filter(r => (r.batch_id || r.batchId) === bId);
      }
    }
  }

  if (efficiency && efficiency !== 'All') {
    rows = rows.filter(r => (r.efficiency || '').toLowerCase() === efficiency.toLowerCase());
  }

  if (customerType && customerType !== 'All') {
    rows = rows.filter(r => (r.customer_type || r.customerType || '').toLowerCase() === customerType.toLowerCase());
  }

  // If the requester is an Agent, strictly restrict to their assigned locations ONLY!
  if (req.user && req.user.role === 'agent') {
    const agentId = req.user.agentId;
    const assignments = (dbStore.assignments || []).filter(as => as.agent_id === agentId);
    const assignedCodes = new Set(assignments.map(as => as.chiller_code).filter(Boolean));
    const assignedNames = new Set(assignments.map(as => (as.customer_name || '').toLowerCase()).filter(Boolean));

    rows = rows.filter(r => {
      const code = r.chiller_code || r.chillerCode;
      const name = (r.customer_name || r.customerName || '').toLowerCase();
      return (code && assignedCodes.has(code)) || (name && assignedNames.has(name));
    });
  }

  if (search) {
    const term = search.toLowerCase();
    rows = rows.filter(r =>
      (r.chiller_code || r.chillerCode || '').toLowerCase().includes(term) ||
      (r.customer_name || r.customerName || '').toLowerCase().includes(term) ||
      (r.branch || '').toLowerCase().includes(term)
    );
  }

  const chillers = rows.map(r => {
    const code = r.chiller_code || r.chillerCode;
    const custName = r.customer_name || r.customerName || '';
    const visitInfo = getChillerVisitInfo(code, custName);
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
      visitStatus: visitInfo.visitStatus,
      latestResponseId: visitInfo.latestResponseId,
      latestResponseDate: visitInfo.latestResponseDate,
      adminFeedback: visitInfo.adminFeedback,
      formId: visitInfo.formId,
      rawData: typeof r.raw_data_json === 'string' ? JSON.parse(r.raw_data_json || '{}') : (r.rawData || r.raw_data_json || {})
    };
  });

  res.json({ success: true, count: chillers.length, chillers });
});

router.delete('/chillers/clear', requireAdmin, (req, res) => {
  dbStore.chillers = [];
  saveDbStore(dbStore);
  res.json({ success: true, message: 'All active database records cleared' });
});

router.get('/batches', requireAuth, (req, res) => {
  const batches = dbStore.batches || [];
  res.json({ success: true, batches: [...batches].reverse() });
});

router.delete('/batches/:id', requireAdmin, (req, res) => {
  const batchId = parseInt(req.params.id);
  if (isNaN(batchId)) {
    return res.status(400).json({ success: false, error: 'Invalid batch ID' });
  }

  const batchIdx = dbStore.batches.findIndex(b => b.id === batchId);
  if (batchIdx === -1) {
    return res.status(404).json({ success: false, error: `Batch #${batchId} not found` });
  }

  const deletedBatch = dbStore.batches.splice(batchIdx, 1)[0];

  // Remove chillers belonging directly to this batch
  const initialChillersCount = dbStore.chillers.length;
  dbStore.chillers = dbStore.chillers.filter(c => (c.batch_id || c.batchId) !== batchId);
  const deletedChillersCount = initialChillersCount - dbStore.chillers.length;

  // Remove history snapshots for this batch
  dbStore.history = dbStore.history.filter(h => (h.batch_id || h.batchId) !== batchId);

  saveDbStore(dbStore);

  res.json({
    success: true,
    message: `Batch #${batchId} ('${deletedBatch.filename}') deleted successfully. Removed ${deletedChillersCount} chiller records.`,
    deletedBatchId: batchId
  });
});


router.get('/delta', requireAdmin, (req, res) => {
  const { startBatchId, endBatchId } = req.query;
  const startId = parseInt(startBatchId);
  const endId = parseInt(endBatchId);

  const startSnapshot = dbStore.history.filter(h => (h.batch_id || h.batchId) === startId);
  const endSnapshot = dbStore.history.filter(h => (h.batch_id || h.batchId) === endId);

  const startMap = new Map(startSnapshot.map(item => [item.chiller_code || item.chillerCode, item]));
  const endMap = new Map(endSnapshot.map(item => [item.chiller_code || item.chillerCode, item]));

  const added = [];
  const removed = [];
  const modified = [];

  for (const [code, item] of endMap.entries()) {
    if (!startMap.has(code)) {
      added.push(item);
    } else {
      const prev = startMap.get(code);
      if (prev.efficiency !== item.efficiency || prev.latitude !== item.latitude || prev.longitude !== item.longitude || prev.branch !== item.branch) {
        modified.push({ previous: prev, current: item });
      }
    }
  }

  for (const [code, item] of startMap.entries()) {
    if (!endMap.has(code)) {
      removed.push(item);
    }
  }

  res.json({
    success: true,
    startBatchId: startId,
    endBatchId: endId,
    summary: {
      added: added.length,
      removed: removed.length,
      modified: modified.length
    },
    added,
    removed,
    modified
  });
});

// ==========================================
// Sales Agents & Assignments Endpoints
// ==========================================

// GET all sales agents
router.get('/agents', requireAuth, (req, res) => {
  const agents = (dbStore.agents || []).map(a => {
    // calculate how many customers/chillers assigned
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
  const { agent_id, chiller_codes, chiller_ids, customer_names } = req.body;
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
      // Remove any existing assignment for this customer name
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
      // find chiller info
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

// GET chillers for assignment (supports batchId='all', specific batch, or latest batch)
router.get('/chillers/latest-batch', requireAuth, (req, res) => {
  const { search, agentId, assignmentStatus, batchId } = req.query;

  // Determine latest batch
  let latestBatchId = null;
  if (dbStore.batches && dbStore.batches.length > 0) {
    const sorted = [...dbStore.batches].sort((a, b) => (b.id || 0) - (a.id || 0));
    latestBatchId = sorted[0].id;
  }

  let selectedBatchId = batchId || 'all';
  let rows = [];

  if (selectedBatchId === 'all') {
    rows = [...dbStore.chillers];
  } else {
    const targetId = selectedBatchId === 'latest' ? latestBatchId : parseInt(selectedBatchId);
    if (targetId) {
      const historicalRows = dbStore.history.filter(h => (h.batch_id || h.batchId) === targetId);
      if (historicalRows.length > 0) {
        rows = historicalRows;
      } else {
        rows = dbStore.chillers.filter(r => (r.batch_id || r.batchId) === targetId);
      }
    } else {
      rows = [...dbStore.chillers];
    }
  }

  // Fallback to all chillers if batch yielded no rows
  if (rows.length === 0 && dbStore.chillers.length > 0) {
    rows = [...dbStore.chillers];
    selectedBatchId = 'all';
  }

  // Create assignments lookup map
  const assignmentMap = new Map();
  (dbStore.assignments || []).forEach(as => {
    if (as.chiller_code) assignmentMap.set(as.chiller_code, as);
    if (as.customer_name) assignmentMap.set(as.customer_name.toLowerCase(), as);
  });

  let chillers = rows.map(r => {
    const code = r.chiller_code || r.chillerCode;
    const custName = r.customer_name || r.customerName || '';
    const assignment = assignmentMap.get(code) || (custName ? assignmentMap.get(custName.toLowerCase()) : null);

    const visitInfo = getChillerVisitInfo(code, custName);

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
      assignedAgentId: assignment?.agent_id || null,
      assignedAgentName: assignment?.agent_name || null,
      assignedAgentArea: assignment?.agent_area || null,
      assignedAt: assignment?.assigned_at || null,
      visitStatus: visitInfo.visitStatus,
      latestResponseId: visitInfo.latestResponseId,
      latestResponseDate: visitInfo.latestResponseDate,
      adminFeedback: visitInfo.adminFeedback,
      formId: visitInfo.formId,
      rawData: typeof r.raw_data_json === 'string' ? JSON.parse(r.raw_data_json || '{}') : (r.rawData || r.raw_data_json || {})
    };
  });

  // Filter by customer name / general search
  if (search && search.trim()) {
    const term = search.trim().toLowerCase();
    chillers = chillers.filter(c =>
      (c.customerName || '').toLowerCase().includes(term) ||
      (c.chillerCode || '').toLowerCase().includes(term) ||
      (c.branch || '').toLowerCase().includes(term) ||
      (c.customerAddress || '').toLowerCase().includes(term)
    );
  }

  // Filter by assignment status
  if (assignmentStatus === 'assigned') {
    chillers = chillers.filter(c => c.assignedAgentId !== null);
  } else if (assignmentStatus === 'unassigned') {
    chillers = chillers.filter(c => c.assignedAgentId === null);
  }

  // If requester is an agent, strictly isolate to their assigned chillers only
  if (req.user && req.user.role === 'agent') {
    const myAgentId = req.user.agentId;
    chillers = chillers.filter(c => c.assignedAgentId === myAgentId);
  } else if (agentId && agentId !== 'All') {
    const aId = parseInt(agentId);
    chillers = chillers.filter(c => c.assignedAgentId === aId);
  }

  const latestBatch = dbStore.batches.find(b => b.id === latestBatchId) || null;

  res.json({
    success: true,
    selectedBatchId,
    latestBatchId,
    latestBatch,
    batches: req.user?.role === 'agent' ? [] : (dbStore.batches || []),
    totalDbLocations: req.user?.role === 'agent' ? chillers.length : dbStore.chillers.length,
    count: chillers.length,
    chillers
  });
});

// --- DYNAMIC FORMS & AUDIT VISITS ENDPOINTS ---

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
router.post('/forms/upload-attachment', requireAuth, uploadAttach.single('file'), (req, res) => {
  try {
    // Handle base64 JSON payload
    const { base64Data, filename: originalName } = req.body || {};
    if (base64Data) {
      const match = base64Data.match(/^data:([A-Za-z-+\/]+);base64,(.+)$/);
      let buffer;
      let ext = '.jpg';
      let mime = 'image/jpeg';
      if (match) {
        mime = match[1];
        if (mime.includes('png')) ext = '.png';
        else if (mime.includes('pdf')) ext = '.pdf';
        buffer = Buffer.from(match[2], 'base64');
      } else {
        buffer = Buffer.from(base64Data, 'base64');
      }

      const filename = `attach_${Date.now()}_${crypto.randomBytes(4).toString('hex')}${ext}`;

      // Try saving to disk for persistent environments
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

      // On serverless/cloud platforms (Vercel) where static files can't be dynamically written to disk,
      // return self-contained data URI to ensure 100% durable and instantaneous image preview without 404s
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
      const ext = path.extname(req.file.originalname) || '.jpg';
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

      const mime = req.file.mimetype || 'image/jpeg';
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

// POST submit form response (Agent completing a visit)
router.post('/form-responses', requireAuth, (req, res) => {
  const { form_id, chiller_code, customer_name, answers, attachments } = req.body;
  if (!form_id) {
    return res.status(400).json({ success: false, error: 'form_id is required' });
  }

  const form = (dbStore.forms || []).find(f => f.id === parseInt(form_id));
  if (!form) {
    return res.status(404).json({ success: false, error: 'Form not found' });
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

// PUT review form response (Admin accepts feedback or re-opens to agent)
router.put('/form-responses/:id/review', requireAdmin, (req, res) => {
  const responseId = parseInt(req.params.id);
  const resp = (dbStore.form_responses || []).find(r => r.id === responseId);
  if (!resp) {
    return res.status(404).json({ success: false, error: 'Form response not found' });
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

app.get(['/', '/index.html'], (req, res) => {
  const publicIndex = path.resolve('public/index.html');
  if (fs.existsSync(publicIndex)) {
    return res.sendFile(publicIndex);
  }
  res.setHeader('Content-Type', 'text/html');
  res.send('<!DOCTYPE html><html><head><title>Bassem Sales Platform</title><base href="/"><meta charset="UTF-8"><meta content="IE=Edge" http-equiv="X-UA-Compatible"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head><body><script src="flutter_bootstrap.js" async></script></body></html>');
});

app.use('/api', router);
app.use('/', router);

app.use((req, res, next) => {
  if (req.path.startsWith('/api')) {
    return res.status(404).json({ success: false, error: `API endpoint '${req.url}' not found` });
  }
  next();
});

// Auto-start listener if executed directly with node api/index.js
const isMain = process.argv[1]?.endsWith('api/index.js') || process.argv[1]?.endsWith('api\\index.js');
if (isMain) {
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, () => {
    console.log(`🚀 API Server listening at http://localhost:${PORT}`);
  });
}

export { app };
export default (req, res) => {
  return app(req, res);
};
