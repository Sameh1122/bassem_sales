import fs from 'fs';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';
import {
  isCloudStorageConfigured,
  fetchDatabaseFromBlob,
  saveDatabaseToBlob,
  getLastCloudSyncTime
} from '../cloud_storage.js';

export { isCloudStorageConfigured, saveDatabaseToBlob, getLastCloudSyncTime };

export const DEFAULT_USERS = [
  {
    id: 0,
    email: 'owner@sales.com',
    username: 'owner',
    name: 'System Owner',
    role: 'owner',
    agent_id: null,
    salt: '9aa5135892163d09db25a2fe3d136610',
    password_hash: 'dc96b38e73feef9c390e3e7080c5d83c5581fdc61b9fcb50df2318d049dda6083336e5ffe8e6b56ea1b966337720dea8e2787d8a6141fd9ea92128be2cf7d9eb',
    created_at: new Date().toISOString()
  },
  {
    id: 1,
    email: 'admin@sales.com',
    username: 'admin',
    name: 'System Administrator',
    role: 'admin',
    agent_id: null,
    salt: '1f9deb23e4a9e7bcf5ca03ccfc8c0d26',
    password_hash: 'd3a3182db515d8fa9ae1038adbfab10ccc141f00ef5ac7afcf15565ccf90b4cf937964a90ba9a7004f6c4f03c033669cfee76391b0dda65e3a1fe2f86c2aac07',
    created_at: new Date().toISOString()
  },
  {
    id: 2,
    email: 'omnia@sales.com',
    username: 'omnia',
    name: 'أمنية',
    role: 'agent',
    agent_id: 1,
    salt: '66f2a51f2e3b6561849c34edfe35ada0',
    password_hash: 'b53bd15e04d46227401883ddd7b6d8a2dcaf5616a0fe9ad5acf31d95246702816b9ab95b9acc8b687e33f22ddeea1588b2aef7ee61fe4f5fc48f480408f44304',
    created_at: new Date().toISOString()
  },
  {
    id: 3,
    email: 'mina@sales.com',
    username: 'mina',
    name: 'مينا',
    role: 'agent',
    agent_id: 2,
    salt: '03e9fdeae99fe36067782642b2b02fad',
    password_hash: 'fd35adf2b0f09b8c1ad3442e546bb4cbe3a7a93e7536c657ea2728d928844106825905cfbc0b692872446f0440bd26080b82ee4179c4b1dcb4113a213d7362e9',
    created_at: new Date().toISOString()
  },
  {
    id: 4,
    email: 'supervisor@sales.com',
    username: 'supervisor',
    name: 'Branch Supervisor',
    role: 'supervisor',
    agent_id: null,
    branch: 'CE',
    supervised_agent_ids: [1, 2],
    salt: 'fd7107f0476e9ae6ddd21815416cda6f',
    password_hash: '53d60ec51a217ff5cf67cbeaaa83a201af75496676dc7e2d7234bef32cf4a1375ef047928cba7f5b599f6caaf2b509bc0be5335da322abba4a99a75f2443269c',
    created_at: new Date().toISOString()
  },
  {
    id: 5,
    email: 'tech@sales.com',
    username: 'tech',
    name: 'Field Technician',
    role: 'technician',
    agent_id: null,
    branch: null,
    supervised_agent_ids: [],
    salt: '7fe859f5676213620270b0de690d26bf',
    password_hash: 'b0f7b7c37e4eeb89ea93bb2b8dfcc4ad70d3b6e7f57b4e46ff2b041f0fc2a176decaa27bfb9ca8afca949af2af65cfa237366aa9bd0446f66a14f95422c81512',
    created_at: new Date().toISOString()
  }
];

export const DEFAULT_AGENTS = [
  { id: 1, name: 'أمنية', area: 'مصر الجديدة', phone: '+20 100 000 0000', email: 'omnia@sales.com', login_email: 'omnia@sales.com', created_at: new Date().toISOString() },
  { id: 2, name: 'مينا', area: 'مدينة نصر', phone: '+20 101 000 0000', email: 'mina@sales.com', login_email: 'mina@sales.com', created_at: new Date().toISOString() }
];

export const DEFAULT_COLUMNS = [
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

export const DEFAULT_FORMS = [
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

export const DB_FILE = process.env.VERCEL ? '/tmp/chillers_db.json' : path.resolve(os.tmpdir(), 'chillers_db.json');

export function reconcileMasterDataset(store) {
  if (!store) return false;
  if (!Array.isArray(store.chillers)) store.chillers = [];
  if (!Array.isArray(store.history) || store.history.length === 0) return false;

  // Auto-restore if active chillers is unexpectedly small compared to history
  if (store.chillers.length < 500 && store.history.length >= 500) {
    console.log(`[MasterDataset] Reconciling active master dataset: current=${store.chillers.length}, history=${store.history.length}...`);
    const map = new Map();

    // 1. Rebuild from history in chronological order
    for (const item of store.history) {
      const code = (item.chiller_code || item.chillerCode || '').toString().trim();
      if (code) {
        map.set(code.toLowerCase(), { ...item });
      }
    }

    // 2. Overlay any active chillers that might have updates
    for (const item of store.chillers) {
      const code = (item.chiller_code || item.chillerCode || '').toString().trim();
      if (code) {
        map.set(code.toLowerCase(), { ...item });
      }
    }

    store.chillers = Array.from(map.values());
    console.log(`[MasterDataset] Reconciled master dataset with ${store.chillers.length} chillers.`);
    return true;
  }
  return false;
}

export function loadDbStore() {
  try {
    if (fs.existsSync(DB_FILE)) {
      const content = fs.readFileSync(DB_FILE, 'utf8');
      const parsed = JSON.parse(content);
      if (parsed && Array.isArray(parsed.chillers)) {
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
        reconcileMasterDataset(parsed);
        return parsed;
      }
    }
  } catch (e) {
    console.warn('⚠️ Error reading persistent DB file:', e.message);
  }

  const store = {
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
      path.join(__dirname, '..', 'seedData.json'),
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

export const dbStore = loadDbStore();

let hasSyncedWithCloud = false;

export function getHasSyncedWithCloud() {
  return hasSyncedWithCloud;
}

export function setHasSyncedWithCloud(val) {
  hasSyncedWithCloud = Boolean(val);
}

export async function syncWithCloudStorage(force = false) {
  if (!isCloudStorageConfigured()) return;
  const now = Date.now();
  if (!force && hasSyncedWithCloud && (now - getLastCloudSyncTime() < 30000)) {
    return;
  }
  try {
    const cloudData = await fetchDatabaseFromBlob();
    if (cloudData && Array.isArray(cloudData.chillers)) {
      if (Array.isArray(cloudData.users)) {
        DEFAULT_USERS.forEach(defUser => {
          const idx = cloudData.users.findIndex(u => u.email && u.email.toLowerCase() === defUser.email.toLowerCase());
          if (idx !== -1) {
            cloudData.users[idx].password_hash = defUser.password_hash;
            cloudData.users[idx].salt = defUser.salt;
          } else {
            cloudData.users.push({ ...defUser });
          }
        });
      }

      const needsSave = reconcileMasterDataset(cloudData);

      Object.assign(dbStore, cloudData);
      hasSyncedWithCloud = true;

      if (needsSave) {
        console.log('[Auto-Recovery] Persisting reconciled master dataset to Blob...');
        try {
          await saveDatabaseToBlob(dbStore);
        } catch (saveErr) {
          console.warn('[Auto-Recovery] Notice saving to blob:', saveErr.message);
        }
      }

      try {
        fs.writeFileSync(DB_FILE, JSON.stringify(dbStore, null, 2), 'utf8');
      } catch (_) {}
    } else if (cloudData === null) {
      hasSyncedWithCloud = true;
    }
  } catch (err) {
    console.warn('[CloudStorage] Notice during syncWithCloudStorage:', err.message);
  }
}

export async function ensureFreshCloudSync() {
  if (isCloudStorageConfigured() && (!hasSyncedWithCloud || (Date.now() - getLastCloudSyncTime() > 30000))) {
    try {
      await syncWithCloudStorage();
    } catch (_) {}
  }
}

export function saveDbStore(store) {
  try {
    fs.writeFileSync(DB_FILE, JSON.stringify(store, null, 2), 'utf8');
  } catch (e) {
    console.error('⚠️ Error writing to persistent DB file:', e.message);
  }
  hasSyncedWithCloud = true;
  if (isCloudStorageConfigured()) {
    saveDatabaseToBlob(store).catch(err => {
      console.warn('[CloudStorage] Background save warning:', err.message);
    });
  }
}

export async function persistToBlobIfConfigured(store) {
  if (isCloudStorageConfigured()) {
    try {
      await saveDatabaseToBlob(store);
    } catch (saveErr) {
      console.warn('[CloudStorage] Notice awaiting blob save:', saveErr.message);
    }
  }
}
