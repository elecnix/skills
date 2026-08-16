#!/usr/bin/env node
// Export Vimeo session cookies from a logged-in Chrome tab via CDP,
// writing them in Netscape format for yt-dlp.
//
// Usage: node get-vimeo-cookies.mjs [output-file]
//   default output: /tmp/vimeo_cookies.txt
//
// Requires:
//   - Chrome with remote debugging enabled (chrome://inspect/#remote-debugging toggle)
//   - An open tab on vimeo.com logged into a Vimeo account
//   - Node.js 22+ (built-in WebSocket and fetch)
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { homedir } from 'os';
import { join, resolve } from 'path';

const OUT = process.argv[2] ? resolve(process.argv[2]) : '/tmp/vimeo_cookies.txt';

// Read Chrome's DevToolsActivePort: line 1 = port, line 2 = browser WS path
function findDebugUrl() {
  const candidates = [
    join(homedir(), 'Library/Application Support/Google/Chrome/DevToolsActivePort'),
    join(homedir(), '.config/google-chrome/DevToolsActivePort'),
    join(homedir(), '.config/chromium/DevToolsActivePort'),
  ];
  for (const f of candidates) {
    if (existsSync(f)) {
      const [port, path] = readFileSync(f, 'utf8').trim().split('\n');
      return `ws://127.0.0.1:${port}${path || '/devtools/browser/'}`;
    }
  }
  return 'ws://127.0.0.1:9222/devtools/browser/';
}

// Minimal CDP client over the browser WebSocket
async function cdpCall(ws, method, params = {}, sessionId) {
  const id = Math.floor(Math.random() * 1e9);
  const result = new Promise((res, rej) => {
    const handler = (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id !== id) return;
      ws.removeEventListener('message', handler);
      if (msg.error) rej(new Error(`${method}: ${msg.error.message}`));
      else res(msg.result);
    };
    ws.addEventListener('message', handler);
  });
  ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
  return result;
}

const ws = new WebSocket(findDebugUrl());
const opened = new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('WebSocket error — is Chrome remote debugging enabled?')); });
try {
  await Promise.race([opened, new Promise((_, rej) => setTimeout(() => rej(new Error('CDP connect timeout')), 10000))]);
} catch (e) {
  console.error(`Cannot connect to Chrome CDP: ${e.message}`);
  process.exit(1);
}

// Find a Vimeo page tab (fall back to any page tab)
const { targetInfos } = await cdpCall(ws, 'Target.getTargets');
let tab = targetInfos.find(t => t.type === 'page' && /vimeo\.com/.test(t.url));
if (!tab) tab = targetInfos.find(t => t.type === 'page');
if (!tab) {
  console.error('No open page tab found in Chrome.');
  process.exit(1);
}
if (!/vimeo\.com/.test(tab.url)) {
  console.error(`No vimeo.com tab found; using "${tab.title}" — cookies only valid if the user is logged into Vimeo there.`);
}

// Attach to the tab and read all cookies
const { sessionId } = await cdpCall(ws, 'Target.attachToTarget', { targetId: tab.targetId, flatten: true });
const { cookies } = await cdpCall(ws, 'Network.getAllCookies', {}, sessionId);
ws.close();

const vimeoCookies = cookies.filter(c => c.domain.includes('vimeo'));
if (vimeoCookies.length === 0) {
  console.error('No vimeo.com cookies found. Open https://vimeo.com in Chrome and log in first.');
  process.exit(1);
}

const lines = ['# Netscape HTTP Cookie File'];
for (const c of vimeoCookies) {
  const includeSub = c.domain.startsWith('.') ? 'TRUE' : 'FALSE';
  const secure = c.secure ? 'TRUE' : 'FALSE';
  const expires = c.session ? 0 : Math.trunc(c.expires || 0);
  const value = (c.value || '').replace(/[\t\n]/g, '');
  // Keep the leading dot when includeSubdomains=TRUE (required by Python's cookiejar)
  lines.push(`${c.domain}\t${includeSub}\t${c.path || '/'}\t${secure}\t${expires}\t${c.name}\t${value}`);
}

writeFileSync(OUT, lines.join('\n') + '\n');
const loggedIn = vimeoCookies.some(c => c.name === 'is_logged_in' && c.value === '1');
console.log(`Wrote ${vimeoCookies.length} vimeo.com cookies -> ${OUT}`);
console.log(`Logged in: ${loggedIn}`);
if (!loggedIn) console.warn('Warning: is_logged_in cookie not set — ask the user to log in at vimeo.com first.');
