#!/bin/bash

# Aavi Sandbox - Overlay Filesystem Sandbox Tool
# https://github.com/sneaks/aavi_sandbox

set -e

# === CONFIG ===
LOWERDIR="/etc"
OVERLAY_BASE="/tmp/aavi_overlay"
WORKDIR_BASE="/tmp/aavi_work"
MOUNTPOINT="/etc"
LOGDIR="/var/log/aavi_sandbox_sessions"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAPSHOT_NAME=""

mkdir -p "$OVERLAY_BASE" "$WORKDIR_BASE" "$LOGDIR"

# === FUNCTIONS ===
function log_session() {
  SNAPSHOT_NAME="$1"
  SESSION_LOG="$LOGDIR/${SNAPSHOT_NAME}-${TIMESTAMP}.log"
  exec > >(tee -a "$SESSION_LOG") 2>&1
  set -x
}

function mount_overlay() {
  UPPERDIR="$OVERLAY_BASE/$SNAPSHOT_NAME"
  WORKDIR="$WORKDIR_BASE/$SNAPSHOT_NAME"
  mkdir -p "$UPPERDIR" "$WORKDIR"

  mount -t overlay overlay \
    -o lowerdir=$LOWERDIR,upperdir=$UPPERDIR,workdir=$WORKDIR \
    $MOUNTPOINT
  echo "✅ Overlay mounted at $MOUNTPOINT"
}

function unmount_overlay() {
  umount $MOUNTPOINT
  echo "🚫 Overlay unmounted from $MOUNTPOINT"
}

function clear_overlay() {
  rm -rf "$OVERLAY_BASE/$SNAPSHOT_NAME" "$WORKDIR_BASE/$SNAPSHOT_NAME"
  echo "🧹 Cleared snapshot '$SNAPSHOT_NAME' overlay data."
}

function commit_changes() {
  rsync -a "$OVERLAY_BASE/$SNAPSHOT_NAME"/ "$LOWERDIR"/
  echo "💾 Changes committed from snapshot '$SNAPSHOT_NAME' to $LOWERDIR"
}

function status_report() {
  echo "🧾 Aavi Sandbox Status"
  echo "Lowerdir:     $LOWERDIR"
  echo "Upperdir:     $OVERLAY_BASE/$SNAPSHOT_NAME"
  echo "Workdir:      $WORKDIR_BASE/$SNAPSHOT_NAME"
  echo "Mountpoint:   $MOUNTPOINT"

  if mount | grep -q "on $MOUNTPOINT type overlay"; then
    echo "✅ Overlay is mounted."
  else
    echo "❌ Overlay is NOT mounted."
  fi

  if [ -d "$OVERLAY_BASE/$SNAPSHOT_NAME" ]; then
    echo "📦 Snapshot '$SNAPSHOT_NAME' exists."
  else
    echo "📭 No changes staged."
  fi
}

function list_snapshots() {
  echo "📚 Available Snapshots:"
  find "$OVERLAY_BASE" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | grep -v '^etc$'
}

# === CLI SWITCHES ===
case "$1" in
  --play)
    SNAPSHOT_NAME="${2:-default_$TIMESTAMP}"
    log_session "$SNAPSHOT_NAME"
    mount_overlay
    ;;

  --commit)
    if [ -z "$2" ]; then echo "❌ Please provide a snapshot name for --commit"; exit 1; fi
    SNAPSHOT_NAME="$2"
    commit_changes
    ;;

  --clear)
    if [ -z "$2" ]; then echo "❌ Please provide a snapshot name for --clear"; exit 1; fi
    SNAPSHOT_NAME="$2"
    clear_overlay
    ;;

  --exit)
    unmount_overlay
    ;;

  --status)
    SNAPSHOT_NAME="${2:-default_$TIMESTAMP}"
    status_report
    ;;

  --list)
    list_snapshots
    ;;

  --remove)
    if [ -z "$2" ]; then echo "❌ Please provide a snapshot name for --remove"; exit 1; fi
    SNAPSHOT_NAME="$2"
    rm -rf "$OVERLAY_BASE/$SNAPSHOT_NAME" "$WORKDIR_BASE/$SNAPSHOT_NAME"
    echo "🗑️ Removed snapshot '$SNAPSHOT_NAME' from sandbox storage."
    ;;
  *)
    echo "Usage: aavi_sandbox [--play SNAPSHOT] [--commit SNAPSHOT] [--clear SNAPSHOT] [--exit] [--status] [--list]"
    ;;
esac