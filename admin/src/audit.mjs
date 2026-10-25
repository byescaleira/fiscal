import { appendFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

export function createAudit({ dataDir, now = () => new Date() }) {
  const file = join(dataDir, 'audit.log');

  function record(action, ip, detail = {}) {
    const entry = { at: now().toISOString(), action, ip, ...detail };
    appendFileSync(file, `${JSON.stringify(entry)}\n`, { mode: 0o600 });
    return entry;
  }

  function recent(limit = 200) {
    let text = '';
    try {
      text = readFileSync(file, 'utf8');
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    return text
      .split('\n')
      .filter(Boolean)
      .slice(-limit)
      .reverse()
      .map((line) => {
        try {
          return JSON.parse(line);
        } catch {
          return null;
        }
      })
      .filter(Boolean);
  }

  return { record, recent };
}
