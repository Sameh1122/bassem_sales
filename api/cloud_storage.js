import fs from 'fs';
import path from 'path';

let vercelBlob = null;
try {
  vercelBlob = await import('@vercel/blob');
} catch (e) {
  // @vercel/blob not installed or failed to import
}

// Try loading local environment files if running in development
['.env.local', '.env.production', '.env'].forEach(file => {
  if (fs.existsSync(file)) {
    try {
      const envContent = fs.readFileSync(file, 'utf8');
      for (const line of envContent.split('\n')) {
        const match = line.match(/^([^#=]+)=(.*)$/);
        if (match) {
          const key = match[1].trim();
          const val = match[2].trim().replace(/^['"]|['"]$/g, '');
          if (!process.env[key]) {
            process.env[key] = val;
          }
        }
      }
    } catch (_) {}
  }
});

const BLOB_FILENAME = 'chillers_db.json';
let cachedBlobUrl = null;
let lastCloudSyncTime = 0;
let inFlightFetchPromise = null;
let inFlightSavePromise = null;

function getBlobOptions(extra = {}) {
  const opts = { ...extra };
  if (process.env.BLOB_READ_WRITE_TOKEN) {
    opts.token = process.env.BLOB_READ_WRITE_TOKEN;
  } else if (process.env.VERCEL_OIDC_TOKEN && process.env.BLOB_STORE_ID) {
    opts.oidcToken = process.env.VERCEL_OIDC_TOKEN;
    opts.storeId = process.env.BLOB_STORE_ID;
  }
  return opts;
}

export function isCloudStorageConfigured() {
  if (!vercelBlob) return false;
  if (process.env.BLOB_READ_WRITE_TOKEN) return true;
  if (process.env.BLOB_STORE_ID && (process.env.VERCEL_OIDC_TOKEN || process.env.VERCEL)) return true;
  return false;
}

/**
 * Fetch the latest database JSON directly from Vercel Blob
 */
export async function fetchDatabaseFromBlob() {
  if (!isCloudStorageConfigured()) {
    return null;
  }

  // Deduplicate concurrent fetch requests during cold starts
  if (inFlightFetchPromise) {
    return inFlightFetchPromise;
  }

  inFlightFetchPromise = (async () => {
    try {
      let targetUrl = cachedBlobUrl;

      if (!targetUrl) {
        const { head, list } = vercelBlob;
        try {
          const details = await head(BLOB_FILENAME, getBlobOptions());
          if (details && details.url) {
            targetUrl = details.url;
            cachedBlobUrl = details.url;
          }
        } catch (headErr) {
          const { blobs } = await list(getBlobOptions({ prefix: BLOB_FILENAME }));
          const match = blobs.find(b => b.pathname === BLOB_FILENAME);
          if (match) {
            targetUrl = match.url;
            cachedBlobUrl = match.url;
          }
        }
      }

      if (!targetUrl) {
        return null;
      }

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 6000);

      const res = await fetch(`${targetUrl}?_cb=${Date.now()}`, {
        cache: 'no-store',
        signal: controller.signal,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache'
        }
      });
      clearTimeout(timeoutId);

      if (!res.ok) {
        if (res.status === 404) return null;
        console.warn(`[CloudStorage] Fetch returned HTTP ${res.status}`);
        return null;
      }

      const data = await res.json();
      if (data && Array.isArray(data.chillers)) {
        lastCloudSyncTime = Date.now();
        return data;
      }
    } catch (err) {
      if (err.name !== 'AbortError') {
        console.warn('[CloudStorage] Notice fetching database from Vercel Blob:', err.message);
      }
    } finally {
      inFlightFetchPromise = null;
    }

    return null;
  })();

  return inFlightFetchPromise;
}

/**
 * Persist the entire database JSON to Vercel Blob
 */
export async function saveDatabaseToBlob(store) {
  if (!isCloudStorageConfigured() || !store) {
    return false;
  }

  try {
    const { put } = vercelBlob;
    const jsonStr = JSON.stringify(store);

    const blob = await put(BLOB_FILENAME, jsonStr, getBlobOptions({
      access: 'public',
      addRandomSuffix: false,
      allowOverwrite: true,
      cacheControlMaxAge: 0,
      contentType: 'application/json'
    }));

    cachedBlobUrl = blob.url;
    lastCloudSyncTime = Date.now();
    return true;
  } catch (err) {
    console.error('[CloudStorage] Failed to save database to Vercel Blob:', err.message);
    return false;
  }
}

export function getLastCloudSyncTime() {
  return lastCloudSyncTime;
}
