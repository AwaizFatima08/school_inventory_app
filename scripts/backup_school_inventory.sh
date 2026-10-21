#!/usr/bin/env bash
#
# backup_school_inventory.sh
#
# One-shot backup for the School Inventory project: a local timestamped archive,
# a copy of that archive to Google Drive, and a git commit + push.
#
# This backs up the PROJECT SOURCE CODE only. It has nothing to do with the
# Firestore database backups configured in the Firebase console (see
# the Firebase console) — those protect user data in the cloud; this script
# protects the code and docs living on this machine. Both are needed, and
# neither substitutes for the other.
#
# ---------------------------------------------------------------------------
# ONE-TIME SETUP (do this once before the first real run — see also
# scripts/BACKUP_SETUP.md for the full walkthrough):
#
#   1. rclone must be installed and have a remote configured for your Google
#      account. Run `rclone config` once, create a remote named exactly
#      "gdrive" (or change GDRIVE_REMOTE below to match what you chose),
#      type "drive", and follow its browser login prompt.
#
#   2. This folder must already be a git repository with its remote set:
#        cd /mnt/storage/projects/school_inventory_app
#        git remote add origin https://github.com/AwaizFatima08/school_inventory_app.git
#      and push access must already work without a password prompt (an SSH
#      key added to your GitHub account, or a saved credential helper).
#
#   3. Make this script executable once:
#        chmod +x /mnt/storage/projects/school_inventory_app/scripts/backup_school_inventory.sh
#
# USAGE:
#   ./backup_school_inventory.sh
#
# Runs all three legs even if one fails, and prints a clear pass/fail
# summary at the end rather than stopping at the first problem — a failed
# Google Drive upload shouldn't hide the fact that the local backup and the
# git push both worked, or vice versa.
# ---------------------------------------------------------------------------

set -uo pipefail

# ---- Configuration — edit these if paths ever change ----------------------
PROJECT_DIR="/mnt/storage/projects/school_inventory_app"
LOCAL_BACKUP_DIR="/mnt/storage/project_backups/school_inventory_app_backup"
LOCAL_RETENTION_DAYS=30          # local archives older than this are deleted
GDRIVE_REMOTE="gdrive"           # the rclone remote name from `rclone config`
GDRIVE_FOLDER_ID="1WTCRykRcQpp8XO2xiBr31xDvDD8RDW9E"
GIT_REMOTE="origin"
LOG_FILE="${LOCAL_BACKUP_DIR}/backup.log"

# Directories/files excluded from the local archive: regenerable build
# output and dependency caches, not source you'd ever need to restore.
#
# NOTE: tar is invoked below as `tar -C "$(dirname "$PROJECT_DIR")" "$(basename "$PROJECT_DIR")"`,
# so archive member names are relative (e.g. "school_inventory_app/build/...", not
# "/mnt/storage/projects/school_inventory_app/build/..."). --exclude patterns must match
# those relative names — an absolute-path exclude here silently never matches
# and the excluded directory gets archived anyway.
PROJECT_BASENAME="$(basename "$PROJECT_DIR")"
EXCLUDES=(
  "--exclude=${PROJECT_BASENAME}/build"
  "--exclude=${PROJECT_BASENAME}/.dart_tool"
  "--exclude=${PROJECT_BASENAME}/android/.gradle"
  "--exclude=${PROJECT_BASENAME}/android/app/build"
  "--exclude=${PROJECT_BASENAME}/android/build"
  "--exclude=${PROJECT_BASENAME}/ios/Pods"
  "--exclude=${PROJECT_BASENAME}/scripts/*.log"
  "--exclude=${PROJECT_BASENAME}/tests/rules/node_modules"
  "--exclude=${PROJECT_BASENAME}/*.log"
)
# -----------------------------------------------------------------------------

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_NAME="school_inventory_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${LOCAL_BACKUP_DIR}/${ARCHIVE_NAME}"

STATUS_LOCAL="not run"
STATUS_GDRIVE="not run"
STATUS_GIT="not run"

mkdir -p "$LOCAL_BACKUP_DIR"
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "===== School Inventory backup started ====="

# ---- 1. Local timestamped archive ------------------------------------------
if [ ! -d "$PROJECT_DIR" ]; then
  log "ERROR: project directory not found at $PROJECT_DIR — stopping entirely."
  exit 1
fi

log "Step 1/3: creating local archive..."
if tar -czf "$ARCHIVE_PATH" "${EXCLUDES[@]}" -C "$(dirname "$PROJECT_DIR")" "$(basename "$PROJECT_DIR")" 2>>"$LOG_FILE"; then
  SIZE="$(du -h "$ARCHIVE_PATH" | cut -f1)"
  log "  OK — $ARCHIVE_NAME created ($SIZE)."
  STATUS_LOCAL="OK ($SIZE)"

  log "  Pruning local archives older than $LOCAL_RETENTION_DAYS days..."
  find "$LOCAL_BACKUP_DIR" -name 'school_inventory_*.tar.gz' -mtime "+${LOCAL_RETENTION_DAYS}" -print -delete 2>>"$LOG_FILE" | tee -a "$LOG_FILE" || true
else
  log "  FAILED — see $LOG_FILE for details."
  STATUS_LOCAL="FAILED"
fi

# ---- 2. Copy the new archive to Google Drive -------------------------------
log "Step 2/3: uploading archive to Google Drive..."
if ! command -v rclone >/dev/null 2>&1; then
  log "  SKIPPED — rclone is not installed. See scripts/BACKUP_SETUP.md."
  STATUS_GDRIVE="SKIPPED (rclone missing)"
elif [[ "$STATUS_LOCAL" != OK* ]]; then
  log "  SKIPPED — no local archive to upload (step 1 failed)."
  STATUS_GDRIVE="SKIPPED (no archive)"
else
  if rclone copy "$ARCHIVE_PATH" "${GDRIVE_REMOTE}:" --drive-root-folder-id "$GDRIVE_FOLDER_ID" >>"$LOG_FILE" 2>&1; then
    log "  OK — uploaded to Google Drive."
    STATUS_GDRIVE="OK"
  else
    log "  FAILED — see $LOG_FILE for details. Is 'rclone config' still authorized?"
    STATUS_GDRIVE="FAILED"
  fi
fi

# ---- 3. Git commit + push ---------------------------------------------------
log "Step 3/3: committing and pushing to git..."
if [ ! -d "${PROJECT_DIR}/.git" ]; then
  log "  SKIPPED — ${PROJECT_DIR} is not a git repository yet. See scripts/BACKUP_SETUP.md."
  STATUS_GIT="SKIPPED (no .git)"
else
  (
    cd "$PROJECT_DIR" || exit 1
    git add -A >>"$LOG_FILE" 2>&1
    if git diff --cached --quiet; then
      # Nothing new to commit — but still push commits made outside this script.
      BRANCH="$(git rev-parse --abbrev-ref HEAD)"
      if [ -n "$(git log "${GIT_REMOTE}/${BRANCH}..HEAD" --oneline 2>/dev/null)" ]; then
        git push "$GIT_REMOTE" "$BRANCH" >>"$LOG_FILE" 2>&1 || exit 1
        echo "PUSHED"
      else
        echo "NOCHANGES"
      fi
    else
      git commit -m "Backup: ${TIMESTAMP}" >>"$LOG_FILE" 2>&1 || exit 1
      BRANCH="$(git rev-parse --abbrev-ref HEAD)"
      git push "$GIT_REMOTE" "$BRANCH" >>"$LOG_FILE" 2>&1 || exit 1
      echo "PUSHED"
    fi
  ) > /tmp/school_inventory_git_result.$$ 2>>"$LOG_FILE"
  GIT_RESULT="$(cat /tmp/school_inventory_git_result.$$ 2>/dev/null)"
  rm -f /tmp/school_inventory_git_result.$$

  case "$GIT_RESULT" in
    PUSHED)
      log "  OK — committed and pushed to ${GIT_REMOTE}."
      STATUS_GIT="OK"
      ;;
    NOCHANGES)
      log "  OK — nothing changed since the last backup, nothing to commit."
      STATUS_GIT="OK (no changes)"
      ;;
    *)
      log "  FAILED — see $LOG_FILE for details. Common cause: push access not set up."
      STATUS_GIT="FAILED"
      ;;
  esac
fi

# ---- Summary ----------------------------------------------------------------
log "===== Summary ====="
log "  Local archive : $STATUS_LOCAL"
log "  Google Drive  : $STATUS_GDRIVE"
log "  Git push      : $STATUS_GIT"
log "===== School Inventory backup finished ====="
echo
echo "Local archive : $STATUS_LOCAL"
echo "Google Drive  : $STATUS_GDRIVE"
echo "Git push      : $STATUS_GIT"
echo "Full log at   : $LOG_FILE"

# Exit non-zero if anything failed outright, so a cron job can flag it.
if [[ "$STATUS_LOCAL" == FAILED* || "$STATUS_GDRIVE" == FAILED* || "$STATUS_GIT" == FAILED* ]]; then
  exit 1
fi
exit 0
