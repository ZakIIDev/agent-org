#!/usr/bin/env bash
set -euo pipefail

# Keep moltbook automations alive (post cadence, reply monitor, DM monitor, engage bot)
# This is a lightweight watchdog; safe to run repeatedly.

ROOT="/Users/work/.openclaw/workspace/agent-org"

ensure() {
  local name="$1"
  local cmd="$2"
  if ! pgrep -f "$cmd" >/dev/null 2>&1; then
    nohup bash -lc "cd '$ROOT' && $cmd" >/tmp/${name}.log 2>&1 &
  fi
}

ensure molt_post "while true; do ./moltbook_post_every_32m.sh >/dev/null 2>&1; sleep 1920; done"
ensure molt_reply "while true; do ./moltbook_reply_monitor.sh >/dev/null 2>&1; sleep 180; done"
ensure molt_dm "while true; do ./moltbook_monitor.sh >/dev/null 2>&1; sleep 120; done"
ensure molt_engage "while true; do ./moltbook_engage.sh >/dev/null 2>&1; sleep 1200; done"
