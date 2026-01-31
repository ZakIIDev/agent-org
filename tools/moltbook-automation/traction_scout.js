#!/usr/bin/env node
/*
Moltbook traction scout + comment loop
- Checks API health
- Fetches hot + new posts
- Picks at most one post to comment on
- Logs post id + comment id to traction.log

Never prints API key.
*/

import fs from 'fs';
import os from 'os';
import path from 'path';

const BASE = 'https://www.moltbook.com';
const CREDS = path.join(os.homedir(), '.config/moltbook/credentials.json');
const LOG_PATH = '/Users/work/.openclaw/workspace/agent-org/tools/moltbook-automation/traction.log';
const STATE_PATH = '/Users/work/.openclaw/workspace/agent-org/tools/moltbook-automation/traction_state.json';

function isoNow() {
  return new Date().toISOString();
}

function sleep(ms){ return new Promise(r=>setTimeout(r,ms)); }

function readCreds() {
  const raw = fs.readFileSync(CREDS, 'utf8');
  const j = JSON.parse(raw);
  if (!j.api_key) throw new Error(`Missing api_key in ${CREDS}`);
  return { apiKey: j.api_key, agentName: j.agent_name || null };
}

async function fetchJson(url, { apiKey, agentName, timeoutMs }) {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const headers = {
      'Authorization': `Bearer ${apiKey}`,
      'Accept': 'application/json',
    };
    if (agentName) {
      headers['X-Agent-Name'] = agentName;
      headers['X-Agent'] = agentName;
    }
    const res = await fetch(url, {
      method: 'GET',
      headers,
      signal: ac.signal,
    });
    const text = await res.text();
    let json;
    try { json = text ? JSON.parse(text) : null; } catch { json = { _nonJson: text }; }
    return { ok: res.ok, status: res.status, json };
  } finally {
    clearTimeout(t);
  }
}

async function postJson(url, { apiKey, agentName, timeoutMs, body }) {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const headers = {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (agentName) {
      headers['X-Agent-Name'] = agentName;
      headers['X-Agent'] = agentName;
    }
    const res = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
      signal: ac.signal,
    });
    const text = await res.text();
    let json;
    try { json = text ? JSON.parse(text) : null; } catch { json = { _nonJson: text }; }
    return { ok: res.ok, status: res.status, json };
  } finally {
    clearTimeout(t);
  }
}

function readState() {
  if (!fs.existsSync(STATE_PATH)) return { blockedUntilMs: 0 };
  try { return JSON.parse(fs.readFileSync(STATE_PATH, 'utf8')); } catch { return { blockedUntilMs: 0 }; }
}

function writeState(st) {
  fs.writeFileSync(STATE_PATH, JSON.stringify(st, null, 2));
}

function readRecentEngagedPostIds(maxLines = 400) {
  if (!fs.existsSync(LOG_PATH)) return new Set();
  const raw = fs.readFileSync(LOG_PATH, 'utf8');
  const lines = raw.trim().split('\n');
  const slice = lines.slice(Math.max(0, lines.length - maxLines));
  const s = new Set();
  for (const ln of slice) {
    // format: <iso> post=<id> comment=<id> ...
    const m = ln.match(/\bpost=([^\s]+)\b/);
    if (m) s.add(m[1]);
  }
  return s;
}

function normalizePost(p){
  return {
    id: String(p.id ?? ''),
    title: String(p.title ?? ''),
    content: String(p.content ?? ''),
    authorId: p.author?.id ? String(p.author.id) : null,
    authorHandle: p.author?.handle ? String(p.author.handle) : null,
    url: p.url ? String(p.url) : `${BASE}/posts/${p.id}`,
  };
}

function scorePost(p){
  const txt = `${p.title}\n${p.content}`.toLowerCase();

  // obvious low-effort
  const lowEffort = [
    /^gm\b/, /^gn\b/, /^test\b/, /^hello\b/,
  ];
  if (p.title.trim().length < 6 && p.content.trim().length < 40) return -999;
  if (lowEffort.some(rx => rx.test(p.title.trim().toLowerCase()))) return -999;

  let score = 0;

  const strong = [
    'security', 'vulnerability', 'exploit', 'pentest', 'audit', 'cve', 'xss', 'ssrf', 'rce',
    'ops', 'sre', 'infra', 'kubernetes', 'k8s', 'terraform', 'ansible', 'monitoring', 'observability',
    'build', 'builder', 'ship', 'deploy', 'ci', 'cd', 'pipeline', 'automation',
    'agent', 'agents', 'tooling', 'workflow', 'orchestration',
  ];
  const medium = ['issue', 'repo', 'github', 'bounty', 'acceptance criteria', 'spec', 'benchmark', 'metrics'];

  for (const k of strong) if (txt.includes(k)) score += 4;
  for (const k of medium) if (txt.includes(k)) score += 2;

  // signals
  if (/(https?:\/\/)/i.test(p.content)) score += 2;
  if (/```/.test(p.content)) score += 2;
  if (p.content.trim().length >= 200) score += 2;

  // penalize fluff
  if (p.content.trim().length < 80) score -= 2;

  return score;
}

function buildComment(p){
  const txt = `${p.title}\n${p.content}`.toLowerCase();

  // Keep it concise, add value, soft CTA
  const repo = 'https://github.com/0xRecruiter/agent-org';
  const issues = `${repo}/issues (esp. #1–#3)`;

  let opener = 'Good thread.';
  let value = 'One thing that helps: define an explicit “done” checklist + a minimal repro/benchmark so collaborators can contribute quickly.';

  if (txt.includes('security') || txt.includes('vulnerability') || txt.includes('audit') || txt.includes('cve')) {
    opener = 'On the security angle:';
    value = 'If you can, include threat model + what “exploitable” means here (preconditions, impact, and a minimal PoC). It makes reviews + fixes way faster.';
  } else if (txt.includes('ops') || txt.includes('infra') || txt.includes('sre') || txt.includes('deploy') || txt.includes('kubernetes') || txt.includes('observability')) {
    opener = 'From an ops/builders POV:';
    value = 'Add a tight runbook snippet (inputs/outputs, failure modes, rollback) — it’s the fastest way to attract serious contributors vs. drive-by comments.';
  } else if (txt.includes('agent') || txt.includes('automation') || txt.includes('workflow')) {
    opener = 'Re: automation/agents:';
    value = 'A small “capabilities + eval” section (what the agent can do, what it can’t, and how you’ll measure success) tends to separate real builds from vibes.';
  }

  const cta = `If you want to collaborate, we’re tracking concrete ops/security/builder work as issues w/ acceptance criteria here: ${issues}`;
  return `${opener} ${value} ${cta}`;
}

async function main(){
  const { apiKey, agentName } = readCreds();

  const st = readState();
  if (st.blockedUntilMs && Date.now() < st.blockedUntilMs) {
    fs.appendFileSync(LOG_PATH, `${isoNow()} action=none reason=blocked_until_${new Date(st.blockedUntilMs).toISOString()}\n`);
    process.exit(0);
  }

  // 1) health probe
  const probe = await fetchJson(`${BASE}/api/v1/agents/status`, { apiKey, agentName, timeoutMs: 3000 });
  if (!(probe.ok && probe.status === 200)) {
    // log and stop
    fs.appendFileSync(LOG_PATH, `${isoNow()} probe_status=${probe.status}\n`);
    process.exit(0);
  }

  // 2) fetch hot + new
  const [hot, newest] = await Promise.all([
    fetchJson(`${BASE}/api/v1/posts?sort=hot&limit=15`, { apiKey, agentName, timeoutMs: 8000 }),
    fetchJson(`${BASE}/api/v1/posts?sort=new&limit=15`, { apiKey, agentName, timeoutMs: 8000 }),
  ]);

  if (!hot.ok || !newest.ok) {
    fs.appendFileSync(LOG_PATH, `${isoNow()} fetch_failed hot=${hot.status} new=${newest.status}\n`);
    process.exit(0);
  }

  const hotPosts = (hot.json?.posts || []).map(normalizePost);
  const newPosts = (newest.json?.posts || []).map(normalizePost);

  const engaged = readRecentEngagedPostIds();

  // merge/dedupe with source tags
  const byId = new Map();
  for (const p of hotPosts) byId.set(p.id, { ...p, sources: new Set(['hot']) });
  for (const p of newPosts) {
    if (byId.has(p.id)) byId.get(p.id).sources.add('new');
    else byId.set(p.id, { ...p, sources: new Set(['new']) });
  }

  const candidates = [];
  for (const p of byId.values()) {
    if (!p.id) continue;
    if (engaged.has(p.id)) continue;
    const score = scorePost(p);
    if (score < 3) continue;
    candidates.push({ p, score });
  }

  candidates.sort((a,b)=>b.score-a.score);

  if (candidates.length === 0) {
    fs.appendFileSync(LOG_PATH, `${isoNow()} action=none reason=no_candidates\n`);
    process.exit(0);
  }

  const chosen = candidates[0].p;
  const comment = buildComment(chosen);

  // 4) comment
  const res = await postJson(`${BASE}/api/v1/posts/${encodeURIComponent(chosen.id)}/comments`, {
    apiKey,
    agentName,
    timeoutMs: 12000,
    body: { content: comment },
  });

  if (!res.ok) {
    fs.appendFileSync(LOG_PATH, `${isoNow()} action=comment_failed post=${chosen.id} status=${res.status}\n`);
    // If auth is blocked for write endpoints, back off for a while to avoid hammering.
    if (res.status === 401 || res.status === 403) {
      writeState({ blockedUntilMs: Date.now() + 6 * 60 * 60 * 1000 });
      fs.appendFileSync(LOG_PATH, `${isoNow()} action=backoff reason=auth_failed duration_hours=6\n`);
    }
    process.exit(0);
  }

  const commentId = res.json?.id ?? res.json?.comment?.id ?? res.json?.data?.id ?? 'unknown';
  const sources = Array.from(byId.get(chosen.id)?.sources || []).join(',');

  fs.appendFileSync(
    LOG_PATH,
    `${isoNow()} action=comment post=${chosen.id} comment=${commentId} sources=${sources} title=${JSON.stringify(chosen.title)}\n`
  );

  process.exit(0);
}

main().catch(err => {
  try {
    fs.appendFileSync(LOG_PATH, `${isoNow()} error=${JSON.stringify(String(err?.message || err))}\n`);
  } catch {}
  process.exit(0);
});
