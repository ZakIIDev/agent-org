#!/usr/bin/env bash
set -euo pipefail
API_KEY=$(node -e "const j=require(process.env.HOME+'/.config/moltbook/credentials.json'); process.stdout.write(j.api_key);")
QUEUE="/Users/work/.openclaw/workspace/agent-org/tools/moltbook-automation/moltbook_post_queue.jsonl"
DONE="/Users/work/.openclaw/workspace/agent-org/tools/moltbook-automation/moltbook_post_done.jsonl"
LOG="/Users/work/.openclaw/workspace/agent-org/tools/moltbook-automation/moltbook_post.log"

probe=$(curl --http1.1 -m 3 -sS -o /dev/null -w "%{http_code}" https://www.moltbook.com/api/v1/agents/status -H "Authorization: Bearer $API_KEY" || echo 000)
if [[ "$probe" != "200" ]]; then
  echo "$(date -Iseconds) probe=$probe" >> "$LOG"
  exit 0
fi

# pick next post payload
if [[ ! -s "$QUEUE" ]]; then
  echo "$(date -Iseconds) queue_empty" >> "$LOG"
  exit 0
fi

LINE=$(grep -m1 -v '^[[:space:]]*$' "$QUEUE" || true)
if [[ -z "$LINE" ]]; then
  echo "$(date -Iseconds) queue_empty" >> "$LOG"
  exit 0
fi

TITLE=$(node -e "const j=JSON.parse(process.argv[1]); process.stdout.write(j.title);" "$LINE")
CONTENT=$(node -e "const j=JSON.parse(process.argv[1]); process.stdout.write(j.content);" "$LINE")
SUBMOLT=$(node -e "const j=JSON.parse(process.argv[1]); process.stdout.write(j.submolt||'general');" "$LINE")

RES=$(curl --http1.1 -m 25 -sS -X POST https://www.moltbook.com/api/v1/posts \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"submolt\":\"$SUBMOLT\",\"title\":$(node -p 'JSON.stringify(process.argv[1])' "$TITLE"),\"content\":$(node -p 'JSON.stringify(process.argv[1])' "$CONTENT")}" || true)

# If rate-limited or failed, keep item in queue
if echo "$RES" | grep -q '"success":true'; then
  # pop first non-empty line
  python3 - <<'PY'
import pathlib
q=pathlib.Path('/Users/work/.openclaw/workspace/agent-org/tools/moltbook-automation/moltbook_post_queue.jsonl')
lines=q.read_text().splitlines(True)
while lines and lines[0].strip()=="":
    lines.pop(0)
if lines:
    first=lines.pop(0)
    pathlib.Path('/Users/work/.openclaw/workspace/agent-org/tools/moltbook-automation/moltbook_post_done.jsonl').open('a').write(first)
q.write_text(''.join(lines))
PY
  echo "$(date -Iseconds) posted title=$(printf %q "$TITLE")" >> "$LOG"
else
  echo "$(date -Iseconds) post_failed $RES" >> "$LOG"
fi
