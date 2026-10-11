import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

class AuditLogger {
  constructor(options = {}) {
    this.maxMemoryLogs = options.maxMemoryLogs || 2500;
    this.logsDir = options.logsDir || path.resolve('logs');
    this.logFilePath = path.join(this.logsDir, 'audit_logs.json');
    this.logs = [];
    this.init();
  }

  init() {
    try {
      if (!fs.existsSync(this.logsDir)) {
        fs.mkdirSync(this.logsDir, { recursive: true });
      }
      if (fs.existsSync(this.logFilePath)) {
        const raw = fs.readFileSync(this.logFilePath, 'utf8');
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed)) {
          this.logs = parsed.slice(-this.maxMemoryLogs);
        }
      }
    } catch (err) {
      console.warn('⚠️ [AuditLogger] Could not load existing logs from disk:', err.message);
      this.logs = [];
    }
  }

  save() {
    try {
      if (!fs.existsSync(this.logsDir)) {
        fs.mkdirSync(this.logsDir, { recursive: true });
      }
      fs.writeFileSync(this.logFilePath, JSON.stringify(this.logs.slice(-this.maxMemoryLogs), null, 2), 'utf8');
    } catch (err) {
      // In serverless / read-only contexts, safely catch and proceed
    }
  }

  log({
    level = 'INFO',
    category = 'system',
    action = 'API_REQUEST',
    actor = null,
    method = 'GET',
    endpoint = '',
    statusCode = 200,
    durationMs = 0,
    details = '',
    metadata = {}
  }) {
    const logEntry = {
      id: 'log_' + Date.now() + '_' + crypto.randomBytes(3).toString('hex'),
      timestamp: new Date().toISOString(),
      level: (level || 'INFO').toUpperCase(),
      category: category || 'system',
      action: action || 'ACTION',
      actor: {
        id: actor?.id ?? null,
        email: actor?.email ?? 'anonymous',
        username: actor?.username ?? 'anonymous',
        role: actor?.role ?? 'guest',
        ip: actor?.ip ?? 'unknown'
      },
      method: (method || 'GET').toUpperCase(),
      endpoint: endpoint || '/',
      statusCode: Number(statusCode) || 200,
      durationMs: Math.round(Number(durationMs) || 0),
      details: details || (method + ' ' + endpoint + ' finished with ' + statusCode),
      metadata: metadata || {}
    };

    this.logs.unshift(logEntry);
    if (this.logs.length > this.maxMemoryLogs) {
      this.logs.length = this.maxMemoryLogs;
    }

    this.scheduleSave();
    return logEntry;
  }

  scheduleSave() {
    if (this._saveTimeout) return;
    this._saveTimeout = setTimeout(() => {
      this._saveTimeout = null;
      this.save();
    }, 1500);
  }

  getLogs({
    level = 'all',
    category = 'all',
    search = '',
    statusCode = null,
    page = 1,
    limit = 50
  } = {}) {
    let filtered = this.logs;

    if (level && level.toLowerCase() !== 'all') {
      const targetLevel = level.toUpperCase();
      filtered = filtered.filter(l => l.level === targetLevel);
    }

    if (category && category.toLowerCase() !== 'all') {
      const targetCat = category.toLowerCase();
      filtered = filtered.filter(l => l.category?.toLowerCase() === targetCat);
    }

    if (statusCode != null && !isNaN(Number(statusCode))) {
      const code = Number(statusCode);
      if (code === 2) {
        filtered = filtered.filter(l => l.statusCode >= 200 && l.statusCode < 300);
      } else if (code === 4) {
        filtered = filtered.filter(l => l.statusCode >= 400 && l.statusCode < 500);
      } else if (code === 5) {
        filtered = filtered.filter(l => l.statusCode >= 500);
      } else {
        filtered = filtered.filter(l => l.statusCode === code);
      }
    }

    if (search && search.trim().length > 0) {
      const q = search.trim().toLowerCase();
      filtered = filtered.filter(l =>
        (l.details && l.details.toLowerCase().includes(q)) ||
        (l.action && l.action.toLowerCase().includes(q)) ||
        (l.endpoint && l.endpoint.toLowerCase().includes(q)) ||
        (l.actor?.email && l.actor.email.toLowerCase().includes(q)) ||
        (l.actor?.role && l.actor.role.toLowerCase().includes(q)) ||
        (l.actor?.ip && l.actor.ip.toLowerCase().includes(q))
      );
    }

    const total = filtered.length;
    const p = Math.max(1, Number(page) || 1);
    const l = Math.max(1, Math.min(200, Number(limit) || 50));
    const start = (p - 1) * l;
    const paginated = filtered.slice(start, start + l);

    return {
      total,
      page: p,
      limit: l,
      totalPages: Math.ceil(total / l) || 1,
      logs: paginated,
      stats: this.getStats()
    };
  }

  getStats() {
    let total = this.logs.length;
    let infoCount = 0;
    let warnCount = 0;
    let errorCount = 0;
    let successCount = 0;
    const actorsSet = new Set();

    for (const log of this.logs) {
      if (log.level === 'ERROR') errorCount++;
      else if (log.level === 'WARN') warnCount++;
      else infoCount++;

      if (log.statusCode >= 200 && log.statusCode < 300) {
        successCount++;
      }
      if (log.actor?.email && log.actor.email !== 'anonymous') {
        actorsSet.add(log.actor.email);
      }
    }

    return {
      totalEvents: total,
      infoCount,
      warnCount,
      errorCount,
      successCount,
      activeActorsCount: actorsSet.size,
      lastEventAt: this.logs[0]?.timestamp || null
    };
  }

  clear() {
    this.logs = [];
    this.save();
    return { success: true, message: 'Audit logs cleared successfully' };
  }

  export(format = 'json') {
    if (format === 'csv') {
      const headers = ['ID', 'Timestamp', 'Level', 'Category', 'Action', 'Actor Email', 'Actor Role', 'Actor IP', 'Method', 'Endpoint', 'Status Code', 'Duration (ms)', 'Details'];
      const escape = (val) => {
        if (val == null) return '""';
        const str = String(val).replace(/"/g, '""');
        return '"' + str + '"';
      };
      const rows = this.logs.map(l => [
        escape(l.id),
        escape(l.timestamp),
        escape(l.level),
        escape(l.category),
        escape(l.action),
        escape(l.actor?.email),
        escape(l.actor?.role),
        escape(l.actor?.ip),
        escape(l.method),
        escape(l.endpoint),
        escape(l.statusCode),
        escape(l.durationMs),
        escape(l.details)
      ].join(','));
      return [headers.join(','), ...rows].join('\n');
    }
    return JSON.stringify(this.logs, null, 2);
  }
}

export const auditLogger = new AuditLogger();
export default auditLogger;
