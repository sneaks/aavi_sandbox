#!/bin/bash

CONFIG_FILE="/etc/aavi_sandbox.conf"
BACKUPDIR="/var/backups/aavi_sandbox"
SESSION_DIR="/var/log/aavi_sandbox_sessions"
ENABLE_LIST="/var/run/aavi_sandbox_enabled.list"
CURRENT_SESSION="/tmp/.aavi_sandbox_session"

LOWERDIR="/etc"
UPPERDIR="/tmp/aavi_overlay/etc"
WORKDIR="/tmp/aavi_work/etc"
MOUNTPOINT="/etc"

load_config() {
  [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
}

mount_overlay() {
  mkdir -p "$UPPERDIR" "$WORKDIR"
  mount -t overlay overlay \
    -o lowerdir="$LOWERDIR",upperdir="$UPPERDIR",workdir="$WORKDIR" \
    "$MOUNTPOINT"
  echo "Overlay mounted at $MOUNTPOINT"
  echo "$1" > "$CURRENT_SESSION"
  start_command_logger "$1"
}

start_command_logger() {
  mkdir -p "$SESSION_DIR"
  LOGFILE="$SESSION_DIR/$1-$(date +%Y%m%d-%H%M%S).log"
  export PROMPT_COMMAND='history 1 | tee -a "$LOGFILE" >/dev/null'
  echo "Logging to $LOGFILE"
}

commit_overlay() {
  SNAPSHOT_NAME="$1"
  [ -z "$SNAPSHOT_NAME" ] && SNAPSHOT_NAME=$(date +%Y-%m-%d)
  BACKUP_PATH="$BACKUPDIR/$SNAPSHOT_NAME"
  mkdir -p "$BACKUP_PATH"
  find "$UPPERDIR" -type f | while read file; do
    REL_PATH="${file#$UPPERDIR/}"
    [ -f "$LOWERDIR/$REL_PATH" ] && {
      mkdir -p "$BACKUP_PATH/$(dirname "$REL_PATH")"
      cp -a "$LOWERDIR/$REL_PATH" "$BACKUP_PATH/$REL_PATH"
    }
  done
  rsync -a "$UPPERDIR"/ "$LOWERDIR"/
  echo "$SNAPSHOT_NAME" >> "$BACKUPDIR/index.log"
}

clear_overlay() {
  umount "$MOUNTPOINT"
  rm -rf "$UPPERDIR" "$WORKDIR" "$CURRENT_SESSION"
  echo "Overlay cleared"
}

enable_layer() {
  SNAPSHOT="$1"
  SNAPSHOT_DIR="$BACKUPDIR/$SNAPSHOT"
  mount -t overlay overlay \
    -o lowerdir="$LOWERDIR",upperdir="$SNAPSHOT_DIR",workdir="$WORKDIR" \
    "$MOUNTPOINT"
  echo "$SNAPSHOT" >> "$ENABLE_LIST"
}

disable_layer() {
  SNAPSHOT="$1"
  umount "$MOUNTPOINT"
  grep -v "$SNAPSHOT" "$ENABLE_LIST" > "$ENABLE_LIST.tmp" && mv "$ENABLE_LIST.tmp" "$ENABLE_LIST"
  echo "Disabled: $SNAPSHOT"
}

list_snapshots() {
  echo "📚 Available Snapshots:"
  [ -f "$BACKUPDIR/index.log" ] && sort "$BACKUPDIR/index.log" | uniq || echo "❌ No snapshots found."
}

case "$1" in
  --play)
    load_config
    mount_overlay "$2"
    ;;
  --commit)
    commit_overlay "$2"
    ;;
  --clear)
    clear_overlay
    ;;
  --enable)
    enable_layer "$2"
    ;;
  --disable)
    disable_layer "$2"
    ;;
  --list|--lst|--snapshots)
    list_snapshots
    ;;
  *)
    echo "Usage: $0 --play [name] | --commit [name] | --clear | --enable [name] | --disable [name] | --list"
    ;;
esac
