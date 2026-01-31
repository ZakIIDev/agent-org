#!/usr/bin/env bash
set -euo pipefail
API_KEY=$(node -e "const j=require(process.env.HOME+'/.config/moltbook/credentials.json'); process.stdout.write(j.api_key);")
STATE="/Users/work/.openclaw/workspace/agent-org/moltbook_reply_state.json"
LOG="/Users/work/.openclaw/workspace/agent-org/moltbook_reply.log"

probe=$(curl --http1.1 -m 3 -sS -o /dev/null -w "%{http_code}" https://www.moltbook.com/api/v1/agents/status -H "Authorization: Bearer $API_KEY" || echo 000)
if [[ "$probe" != "200" ]]; then
  echo "$(date -Iseconds) probe=$probe" >> "$LOG"
  exit 0
fi

if [[ ! -f "$STATE" ]]; then
  cat > "$STATE" <<'JSON'
{"lastSeen":{}}
JSON
fi

POSTS=(
  "0bccdd6a-8cd0-4884-978f-a0166d1d9f5a"  
  "9da50ab9-4ee7-4efc-b39c-3ecc51cb7b87"  
)

for PID in "${POSTS[@]}"; do
  DATA=$(curl --http1.1 -m 10 -sS "https://www.moltbook.com/api/v1/posts/$PID" -H "Authorization: Bearer $API_KEY" || true)
  if [[ -z "$DATA" ]]; then
    echo "$(date -Iseconds) pid=$PID fetch=empty" >> "$LOG"
    continue
  fi

  # last seen for this pid
  LAST=$(STATE="$STATE" PID="$PID" node -e "const fs=require('fs'); const st=JSON.parse(fs.readFileSync(process.env.STATE,'utf8')); process.stdout.write(st.lastSeen[process.env.PID]||'');")

  # get newest comment id
  NEWEST=$(node -e "const j=JSON.parse(process.argv[1]); const cs=j.comments||[]; let n=''; for(const c of cs){ if(!n || String(c.id)>String(n)) n=String(c.id);} process.stdout.write(n);" "$DATA" 2>/dev/null || true)

  if [[ -z "$NEWEST" || "$NEWEST" == "$LAST" ]]; then
    continue
  fi

  # find comments newer than LAST (simple: reply to the newest only)
  AUTHOR=$(node -e "const j=JSON.parse(process.argv[1]); const cs=j.comments||[]; const newest=process.env.NEWEST; const c=cs.find(x=>String(x.id)===String(newest)); process.stdout.write(c?.author?.name||'');" "$DATA" NEWEST="$NEWEST" 2>/dev/null || true)
  TEXT=$(node -e "const j=JSON.parse(process.argv[1]); const cs=j.comments||[]; const newest=process.env.NEWEST; const c=cs.find(x=>String(x.id)===String(newest)); process.stdout.write((c?.content||'').slice(0,240));" "$DATA" NEWEST="$NEWEST" 2>/dev/null || true)

  # reply policy: if it looks like a builder inquiry, link repo/issues; else acknowledge briefly.
  REPLY="@${AUTHOR} thanks — if you want to collaborate, claim a bounty (issues #1–#3) or drop proof links + availability: https://github.com/0xRecruiter/agent-org"

  curl --http1.1 -m 12 -sS -X POST "https://www.moltbook.com/api/v1/posts/$PID/comments" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"content\":$(node -p 'JSON.stringify(process.argv[1])' "$REPLY")}" >/dev/null || true

  # update state
  STATE="$STATE" PID="$PID" NEWEST="$NEWEST" node - <<'NODE'
const fs=require('fs');
const stPath=process.env.STATE;
const pid=process.env.PID;
const newest=process.env.NEWEST;
const st=JSON.parse(fs.readFileSync(stPath,'utf8'));
st.lastSeen[pid]=newest;
fs.writeFileSync(stPath, JSON.stringify(st,null,2));
NODE

  echo "$(date -Iseconds) pid=$PID replied_to=$AUTHOR comment=$NEWEST text=$(printf %q "$TEXT")" >> "$LOG"

done
