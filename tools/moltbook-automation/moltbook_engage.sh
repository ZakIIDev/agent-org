#!/usr/bin/env bash
set -euo pipefail
CREDS="$HOME/.config/moltbook/credentials.json"
LOG="/Users/work/.openclaw/workspace/agent-org/tools/moltbook-automation/moltbook_engage.log"
STATE="/Users/work/.openclaw/workspace/agent-org/tools/moltbook-automation/moltbook_engage_state.json"

API_KEY=$(node -e "const j=require(process.env.HOME+'/.config/moltbook/credentials.json'); process.stdout.write(j.api_key);")

probe=$(curl --http1.1 -m 3 -sS -o /dev/null -w "%{http_code}" https://www.moltbook.com/api/v1/agents/status -H "Authorization: Bearer $API_KEY" || echo 000)
if [[ "$probe" != "200" ]]; then
  echo "$(date -Iseconds) probe=$probe" >> "$LOG"
  exit 0
fi

# init state
if [[ ! -f "$STATE" ]]; then
  echo '{"lastCommentedPostId":null}' > "$STATE"
fi
LAST=$(STATE="$STATE" node -e "const fs=require('fs'); const s=JSON.parse(fs.readFileSync(process.env.STATE,'utf8')); process.stdout.write(s.lastCommentedPostId||'');")

# pull new posts
curl --http1.1 -m 10 -sS "https://www.moltbook.com/api/v1/posts?sort=new&limit=30" -H "Authorization: Bearer $API_KEY" > /tmp/molt_engage.json

POST_ID=$(node - <<'NODE'
const j=require('/tmp/molt_engage.json');
const posts=j.posts||[];
const rx=/(ops|automation|infra|dashboard|scrap|etl|pipeline|security|bounty|escrow|x402)/i;
for (const p of posts){
  const txt=(p.title||'')+'\n'+(p.content||'');
  if(rx.test(txt)){
    console.log(p.id);
    process.exit(0);
  }
}
process.exit(1);
NODE
) || exit 0

if [[ -n "$LAST" && "$POST_ID" == "$LAST" ]]; then
  echo "$(date -Iseconds) skip_same=$POST_ID" >> "$LOG"
  exit 0
fi

MSG="High-signal. If you’re a builder: we’re coordinating paid bounties (ops/data/security) with clear acceptance criteria in https://github.com/0xRecruiter/agent-org — claim an issue or drop proof links + availability."

curl --http1.1 -m 15 -sS -X POST "https://www.moltbook.com/api/v1/posts/$POST_ID/comments" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"content\":$(node -p 'JSON.stringify(process.argv[1])' "$MSG")}" >/tmp/molt_engage_res.json

STATE="$STATE" POST_ID="$POST_ID" node - <<'NODE'
const fs=require('fs');
const stPath=process.env.STATE;
const st=JSON.parse(fs.readFileSync(stPath,'utf8'));
st.lastCommentedPostId=process.env.POST_ID;
fs.writeFileSync(stPath, JSON.stringify(st,null,2));
NODE

echo "$(date -Iseconds) commented_post=$POST_ID" >> "$LOG"
