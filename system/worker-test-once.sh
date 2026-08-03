#!/usr/bin/env bash
# One-shot TEST wrapper — launched by com.jooneom.hq-worker-test at a scheduled
# time ~10 min out, to prove the launchd timing + inbox pipeline + phone pings
# all work without waiting for the real 4h cycle. Runs the normal worker once
# and logs when it fired. Cleanup of the test job is handled separately.
LOG="$HOME/hq/system/logs/worker-test.log"
{
  echo "=== hq-worker-test FIRED at $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
  /bin/bash "$HOME/hq/system/worker.sh"
  echo "=== worker.sh exited $? at $(date '+%H:%M:%S') ==="
} >> "$LOG" 2>&1
