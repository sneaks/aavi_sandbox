#!/bin/bash

CONFIG_FILE="/etc/aavi_sandbox.conf"

# Default config
LOWERDIR="/etc"
UPPERDIR="/tmp/aavi_overlay/etc"
WORKDIR="/tmp/aavi_work/etc"
MOUNTPOINT="/etc"

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

mount_overlay() {
    echo "🔁 Entering sandbox mode..."
    mkdir -p "$UPPERDIR" "$WORKDIR"
    mount -t overlay overlay \
        -o lowerdir="$LOWERDIR",upperdir="$UPPERDIR",workdir="$WORKDIR" \
        "$MOUNTPOINT"
    echo "⚠️  Sandbox active. Changes are in RAM only." > /etc/motd
}

commit_changes() {
    echo "💾 Committing changes..."
    rsync -a --info=progress2 --exclude='.wh.*' "$UPPERDIR"/ "$LOWERDIR"/
    echo "✅ Changes committed to $LOWERDIR"
#!/bin/bash

CONFIG_FILE="/etc/aavi_sandbox.conf"

# Default config
LOWERDIR="/etc"
UPPERDIR="/tmp/aavi_overlay/etc"
WORKDIR="/tmp/aavi_work/etc"
MOUNTPOINT="/etc"
BACKUPDIR="/var/backups/aavi_sandbox"

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

mount_overlay() {
    echo "🔁 Entering sandbox mode..."
    mkdir -p "$UPPERDIR" "$WORKDIR"
    mount -t overlay overlay \
        -o lowerdir="$LOWERDIR",upperdir="$UPPERDIR",workdir="$WORKDIR" \
        "$MOUNTPOINT"
    echo "⚠️  Sandbox active. Changes are in RAM only." > /etc/motd
}

commit_changes() {
    echo "💾 Creating backup before commit..."
    BACKUP_PATH="$BACKUPDIR/2025-06-01"
    mkdir -p "$BACKUP_PATH"
    find "$UPPERDIR" -type f | while read file; do
        REL_PATH="${file#$UPPERDIR/}"
        if [ -f "$LOWERDIR/$REL_PATH" ]; then
            mkdir -p "$BACKUP_PATH/$(dirname "$REL_PATH")"
            cp -a "$LOWERDIR/$REL_PATH" "$BACKUP_PATH/$REL_PATH"
        fi
    done

    echo "💾 Committing changes..."
    rsync -a --exclude='.wh.*' "$UPPERDIR"/ "$LOWERDIR"/
    echo "✅ Changes committed to $LOWERDIR"
    echo "📝 Backup created at $BACKUP_PATH"
}

clear_overlay() {
    echo "🧹 Clearing overlay and exiting sandbox..."
    umount "$MOUNTPOINT"
    rm -rf "$UPPERDIR" "$WORKDIR"
    rm -f /etc/motd
}

status_report() {
    echo "🧾 Aavi Sandbox Status"
    echo "Lowerdir:     $LOWERDIR"
    echo "Upperdir:     $UPPERDIR"
    echo "Workdir:      $WORKDIR"
    echo "Mountpoint:   $MOUNTPOINT"
    echo ""

    mount | grep "$MOUNTPOINT" && echo "✅ Overlay is currently mounted." || echo "❌ Overlay is NOT mounted."

    echo ""
    if [ -d "$UPPERDIR" ]; then
        echo "📁 Changes staged in overlay:"
        find "$UPPERDIR" -type f
    else
        echo "📭 No changes staged."
    fi
}

undo_commit() {
    if [ -z "$2" ]; then
        echo "⚠️  Please specify a date to undo. Example: --undo 2025-06-01"
        exit 1
    fi
    RESTORE_PATH="$BACKUPDIR/$2"
    if [ ! -d "$RESTORE_PATH" ]; then
        echo "❌ Backup directory $RESTORE_PATH does not exist."
        exit 1
    fi
    echo "♻️  Rolling back to backup from $2..."
    rsync -a "$RESTORE_PATH"/ "$LOWERDIR"/
    echo "✅ Rollback complete."
}

load_config

case "$1" in
    --play)
        mount_overlay
        ;;
    --commit)
        commit_changes
        ;;
    --clear)
        clear_overlay
        ;;
    --status)
        status_report
        ;;
    --undo)
        undo_commit "$@"
        ;;
    *)
        echo "Usage: $0 --play | --commit | --clear | --status | --undo YYYY-MM-DD"
        ;;
esac
