/**
 * Edge CDP Controller
 * Directly queries and controls Microsoft Edge via CDP HTTP & WebSocket API on 127.0.0.1:9222
 */
const http = require('http');

const CDP_PORT = 9222;
const CDP_HOST = '127.0.0.1';

function fetchPages() {
  return new Promise((resolve, reject) => {
    http.get(`http://${CDP_HOST}:${CDP_PORT}/json/list`, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

function activateTab(pageId) {
  return new Promise((resolve, reject) => {
    http.get(`http://${CDP_HOST}:${CDP_PORT}/json/activate/${pageId}`, (res) => {
      resolve(true);
    }).on('error', reject);
  });
}

function newTab(url = 'about:blank') {
  return new Promise((resolve, reject) => {
    http.get(`http://${CDP_HOST}:${CDP_PORT}/json/new?${encodeURIComponent(url)}`, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); } catch (e) { resolve(null); }
      });
    }).on('error', reject);
  });
}

async function main() {
  const cmd = process.argv[2] || 'status';
  const target = process.argv[3];

  try {
    const pages = await fetchPages();
    const appPages = pages.filter(p => p.type === 'page');

    if (cmd === 'status') {
      console.log(`[EdgeCDP] Found ${appPages.length} active page(s) in Edge:`);
      appPages.forEach((p, idx) => {
        console.log(`  [${idx + 1}] "${p.title}"`);
        console.log(`      URL: ${p.url}`);
        console.log(`      ID:  ${p.id}`);
      });
    } else if (cmd === 'focus') {
      const match = appPages.find(p => 
        p.title.toLowerCase().includes(target.toLowerCase()) || 
        p.url.toLowerCase().includes(target.toLowerCase())
      );
      if (match) {
        await activateTab(match.id);
        console.log(`[EdgeCDP] Focused tab: "${match.title}" (${match.id})`);
      } else {
        console.log(`[EdgeCDP] No tab found matching "${target}"`);
      }
    } else if (cmd === 'open') {
      if (!target) {
        console.log('[EdgeCDP] URL required for open command');
        return;
      }
      const created = await newTab(target);
      console.log(`[EdgeCDP] Opened new tab for ${target}: ID ${created?.id}`);
    }
  } catch (err) {
    console.error('[EdgeCDP Error]', err.message);
  }
}

main();
