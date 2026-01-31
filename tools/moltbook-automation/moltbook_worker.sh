#!/usr/bin/env bash
set -euo pipefail

CREDS="$HOME/.config/moltbook/credentials.json"
QUEUE="/Users/work/.openclaw/workspace/agent-org/moltbook_queue.jsonl"
DONE="/Users/work/.openclaw/workspace/agent-org/moltbook_done.jsonl"

if [[ ! -f "$CREDS" ]]; then
  echo "missing creds $CREDS" >&2
  exit 2
fi

API_KEY=$(CREDS="$CREDS" node -e "const fs=require('fs'); const j=JSON.parse(fs.readFileSync(process.env.CREDS,'utf8')); process.stdout.write(j.api_key);")

probe() {
  curl --http1.1 -m 3 -sS -o /dev/null -w "%{http_code}" \
    https://www.moltbook.com/api/v1/agents/status \
    -H "Authorization: Bearer $API_KEY" || echo "000"
}

do_post() {
  local title="$1"
  local content="$2"
  local submolt="$3"
  curl --http1.1 -m 20 -sS -X POST https://www.moltbook.com/api/v1/posts \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"submolt\":\"$submolt\",\"title\":$(node -p 'JSON.stringify(process.argv[1])' "$title"),\"content\":$(node -p 'JSON.stringify(process.argv[1])' "$content")}" 
}

CODE=$(CREDS="$CREDS" probe)
if [[ "$CODE" != "200" ]]; then
  echo "probe=$CODE" >&2
  exit 0
fi

# take first queued item (jsonl) — skip blank lines
if [[ ! -s "$QUEUE" ]]; then
  echo "queue empty" >&2
  exit 0
fi

LINE=$(grep -m1 -v '^[[:space:]]*$' "$QUEUE" || true)
if [[ -z "$LINE" ]]; then
  echo "queue empty" >&2
  exit 0
fi

# remove the first occurrence of that exact line from the queue
REST=$(python3 - <<'PY'
import pathlib
q=pathlib.Path("/Users/work/.openclaw/workspace/agent-org/moltbook_queue.jsonl")
lines=q.read_text().splitlines(True)
# drop leading blank lines
while lines and lines[0].strip()=="":
    lines.pop(0)
# drop first non-empty line
if lines:
    lines.pop(0)
q.write_text(''.join(lines))
print('ok')
PY
)

# parse kind safely
KIND=$(node -e "try{const j=JSON.parse(process.argv[1]); process.stdout.write(j.kind||'');}catch(e){process.stdout.write('');}" "$LINE")
if [[ -z "$KIND" ]]; then
  echo "bad queue line (not json), skipping" >&2
  echo "$LINE" >> "${DONE%.jsonl}_bad.jsonl"
  exit 0
fi

if [[ "$KIND" == "post" ]]; then
  TITLE=$(node -e "const j=JSON.parse(process.argv[1]); process.stdout.write(j.title);" "$LINE")
  CONTENT=$(node -e "const j=JSON.parse(process.argv[1]); process.stdout.write(j.content);" "$LINE")
  SUBMOLT=$(node -e "const j=JSON.parse(process.argv[1]); process.stdout.write(j.submolt||'general');" "$LINE")
  RES=$(do_post "$TITLE" "$CONTENT" "$SUBMOLT")
  echo "$LINE" >> "$DONE"
  printf "%s\n" "$REST" > "$QUEUE"
  echo "$RES" | head -c 400
else
  echo "unknown kind=$KIND" >&2
fi
