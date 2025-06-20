#!/bin/bash

# Aavi Sandbox - Overlay Filesystem Sandbox Tool
# https://github.com/sneaks/aavi_sandbox

# === REQUIREMENTS ===
# Requires Bash 4.0+ for associative arrays and other features
if ((BASH_VERSINFO[0] < 4)); then
    echo "❌ Error: This script requires Bash version 4.0 or higher"
    exit 1
fi

# === SYSTEM CHECKS ===
function check_system_requirements() {
    # Check if overlay filesystem is supported
    if ! grep -q overlay /proc/filesystems; then
        echo "❌ Error: Overlay filesystem not supported by this kernel"
        exit 1
    fi

    # Check if running with necessary privileges
    if [[ $EUID -ne 0 ]]; then
        echo "⚠️  Warning: This script typically requires root privileges"
        echo "   Some operations may fail without sudo"
    fi

    # Check for required commands
    local missing_deps=()
    local required_cmds=("jq" "mount" "rsync")

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    if ((${#missing_deps[@]} > 0)); then
        echo "❌ Error: Missing required dependencies:"
        printf '   - %s\n' "${missing_deps[@]}"
        echo
        echo "Please install missing dependencies:"
        echo "   Ubuntu/Debian: sudo apt-get install ${missing_deps[*]}"
        echo "   macOS: brew install ${missing_deps[*]}"
        echo "   Fedora: sudo dnf install ${missing_deps[*]}"
        exit 1
    fi
}

# === CONFIG MANAGEMENT ===
function load_config() {
    # Default config locations
    local config_files=(
        "/etc/aavi_sandbox.conf"
        "$HOME/.aavi_sandbox.conf"
        "./.aavi_sandbox.conf"
    )

    # Load configs in order (later files override earlier ones)
    for config in "${config_files[@]}"; do
        if [[ -f "$config" ]]; then
            echo "📄 Loading config: $config"
            # shellcheck source=/dev/null
            source "$config"
        fi
    done

    # Environment variables override config files
    [[ -n "$AAVI_LOWERDIR" ]] && LOWERDIR="$AAVI_LOWERDIR"
    [[ -n "$AAVI_OVERLAY_BASE" ]] && OVERLAY_BASE="$AAVI_OVERLAY_BASE"
    [[ -n "$AAVI_WORKDIR_BASE" ]] && WORKDIR_BASE="$AAVI_WORKDIR_BASE"
    [[ -n "$AAVI_MOUNTPOINT" ]] && MOUNTPOINT="$AAVI_MOUNTPOINT"
    [[ -n "$AAVI_LOGDIR" ]] && LOGDIR="$AAVI_LOGDIR"
}

# === VALIDATION ===
function error_exit() {
    local message="$1"
    set +x  # Disable debug mode immediately
    echo "❌ Error: $message"
    cleanup_logging
    exit 1
}

function validate_snapshot_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error_exit "Invalid snapshot name '$name'\n   Use only letters, numbers, underscores, and hyphens"
    fi
}

function check_mount_conflicts() {
    local mount_point="$1"
    
    # Check if already mounted
    if mount | grep -q "on $mount_point type overlay"; then
        error_exit "An overlay is already mounted at $mount_point"
    fi

    # Check for nested mounts
    while [[ "$mount_point" != "/" ]]; do
        if mount | grep -q "on $mount_point "; then
            echo "⚠️  Warning: Parent directory '$mount_point' is a mount point"
            echo "   This may cause unexpected behavior"
            return 1
        fi
        mount_point=$(dirname "$mount_point")
    done
}

# === METADATA MANAGEMENT ===
function get_metadata_path() {
    local snapshot_name="$1"
    echo "$OVERLAY_BASE/$snapshot_name/.aavi_metadata.json"
}

function create_metadata() {
    local snapshot_name="$1"
    local description="${2:-}"
    local labels="${3:-}"
    local metadata_path
    mkdir -p "$(dirname "$(get_metadata_path "$snapshot_name")")"
    metadata_path=$(get_metadata_path "$snapshot_name")
    
    # Create metadata JSON
    cat > "$metadata_path" << EOF
{
    "name": "$snapshot_name",
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "description": "$description",
    "labels": ${labels:-"[]"},
    "created_by": "$USER",
    "base_path": "$LOWERDIR",
    "mount_point": "$MOUNTPOINT"
}
EOF
}

function read_metadata() {
    local snapshot_name="$1"
    local metadata_path
    metadata_path=$(get_metadata_path "$snapshot_name")
    
    if [[ ! -d "$OVERLAY_BASE/$snapshot_name" ]]; then
        echo "❌ Error: Snapshot '$snapshot_name' not found"
        echo "Use --list to see available snapshots"
        return 1
    elif [[ ! -f "$metadata_path" ]]; then
        echo "❌ Error: No metadata found for snapshot '$snapshot_name'"
        echo "The snapshot directory exists but may be corrupted"
        return 1
    fi
    
    cat "$metadata_path"
}

function update_metadata() {
    local snapshot_name="$1"
    local key="$2"
    local value="$3"
    local metadata_path
    metadata_path=$(get_metadata_path "$snapshot_name")
    
    if [[ ! -f "$metadata_path" ]]; then
        create_metadata "$snapshot_name"
    fi
    
    # Use temp file for atomic update
    local temp_file
    temp_file=$(mktemp)
    jq ".$key = \"$value\"" "$metadata_path" > "$temp_file"
    mv "$temp_file" "$metadata_path"
}

function list_snapshots_with_metadata() {
    echo "📚 Available Snapshots:"
    echo "----------------------------------------"
    
    # Check if overlay directory exists and has snapshots
    if [[ ! -d "$OVERLAY_BASE" ]] || [[ -z "$(find "$OVERLAY_BASE" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]]; then
        echo "�� No snapshots found"
        echo
        echo "To create a new snapshot:"
        echo "  aavi_sandbox --play my_snapshot    # Named snapshot"
        echo "  aavi_sandbox --play                # Temporary snapshot"
        return 0
    fi
    
    find "$OVERLAY_BASE" -mindepth 1 -maxdepth 1 -type d | while read -r snapshot_dir; do
        snapshot_name=$(basename "$snapshot_dir")
        metadata_path=$(get_metadata_path "$snapshot_name")
        
        echo "📦 $snapshot_name"
        if [[ -f "$metadata_path" ]]; then
            # Extract and format key metadata
            created_at=$(jq -r '.created_at' "$metadata_path")
            description=$(jq -r '.description' "$metadata_path")
            labels=$(jq -r '.labels | join(", ")' "$metadata_path")
            
            echo "   Created: $created_at"
            [[ "$description" != "null" && -n "$description" ]] && echo "   Description: $description"
            [[ "$labels" != "null" && -n "$labels" ]] && echo "   Labels: $labels"
        fi
        echo "----------------------------------------"
    done
}

# Run initial checks
check_system_requirements
load_config

set -e

# === CONFIG ===
LOWERDIR="/opt/aavi_sandbox_test"
OVERLAY_BASE="/tmp/aavi_overlay"
WORKDIR_BASE="/tmp/aavi_work"
MOUNTPOINT="/opt/aavi_sandbox_test"
LOGDIR="/var/log/aavi_sandbox_sessions"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAPSHOT_NAME=""

mkdir -p "$OVERLAY_BASE" "$WORKDIR_BASE" "$LOGDIR"

# === FUNCTIONS ===
function log_session() {
  SNAPSHOT_NAME="$1"
  SESSION_LOG="$LOGDIR/${SNAPSHOT_NAME}-${TIMESTAMP}.log"
  
  # Create log directory if it doesn't exist
  mkdir -p "$(dirname "$SESSION_LOG")"
  
  # Initialize the log file
  : > "$SESSION_LOG"
  
  # Save original file descriptors
  exec 4>&1
  exec 5>&2
  
  # Set up logging to both terminal and file
  exec 1> >(tee -a "$SESSION_LOG")
  exec 2> >(tee -a "$SESSION_LOG" >&2)
  
  # Set up debug trace logging to file only
  exec 3>"$SESSION_LOG"
  BASH_XTRACEFD=3
  
  # Set up cleanup trap
  trap cleanup_logging EXIT
  
  set -x
}

function mount_overlay() {
  # Validate snapshot name and check mount conflicts
  validate_snapshot_name "$SNAPSHOT_NAME"
  check_mount_conflicts "$MOUNTPOINT"

  UPPERDIR="$OVERLAY_BASE/$SNAPSHOT_NAME"
  WORKDIR="$WORKDIR_BASE/$SNAPSHOT_NAME"
  mkdir -p "$UPPERDIR" "$WORKDIR"

  mkdir -p "$MOUNTPOINT"
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
        
        # Check for changes in the overlay
        if [[ -n "$(find "$OVERLAY_BASE/$SNAPSHOT_NAME" -mindepth 1 -not -path '*/\.*' 2>/dev/null)" ]]; then
            echo "💾 Changes are present in the overlay."
        else
            echo "📭 No changes staged (empty overlay)."
        fi
        
        # Show metadata if it exists
        echo
        echo "📋 Snapshot Metadata:"
        if [[ -f "$OVERLAY_BASE/$SNAPSHOT_NAME/.aavi_metadata.json" ]]; then
            jq -r '. | "Name:        \(.name)\nCreated:     \(.created_at)\nDescription: \(.description)\nLabels:      \(.labels | join(", "))"' \
                "$OVERLAY_BASE/$SNAPSHOT_NAME/.aavi_metadata.json"
        elif [[ "$SNAPSHOT_NAME" == default_* ]]; then
            echo "This is a temporary sandbox session."
            echo "Use --commit with a name to save it permanently."
        fi
    else
        echo "📭 No changes staged."
        if [[ -n "$SNAPSHOT_NAME" ]]; then
            echo
            echo "💡 Tip: Create a new snapshot with:"
            echo "  aavi_sandbox --play $SNAPSHOT_NAME"
        fi
    fi
}

function list_snapshots() {
  echo "📚 Available Snapshots:"
  find "$OVERLAY_BASE" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | grep -v '^etc$'
}

function cleanup_logging() {
  # Disable debug tracing first
  set +x 2>/dev/null || true
  
  # Close the trace file descriptor
  if [[ -n "$BASH_XTRACEFD" ]]; then
    exec 3>&-
    unset BASH_XTRACEFD
  fi
  
  # Restore original stdout if saved
  if [[ -n "$4" ]]; then
    exec 1>&4 4>&-
  fi
  
  # Restore original stderr if saved
  if [[ -n "$5" ]]; then
    exec 2>&5 5>&-
  fi
}

# === CLI SWITCHES ===
case "$1" in
  --play)
    SNAPSHOT_NAME="${2:-default_$TIMESTAMP}"
    validate_snapshot_name "$SNAPSHOT_NAME"
    
    # Set up logging first, before any other operations
    log_session "$SNAPSHOT_NAME"
    
    # Create initial metadata with description for default snapshots
    if [[ "$SNAPSHOT_NAME" == default_* ]]; then
        create_metadata "$SNAPSHOT_NAME" "Temporary sandbox session created at $(date '+%Y-%m-%d %H:%M:%S')" "temporary,default"
    else
        create_metadata "$SNAPSHOT_NAME" "${3:-}" "${4:-}"
    fi
    
    mount_overlay
    ;;

  --describe)
    if [ -z "$2" ]; then 
      echo "❌ Error: Please provide a snapshot name for --describe"
      echo "Usage: aavi_sandbox --describe SNAPSHOT"
      exit 1
    fi
    SNAPSHOT_NAME="$2"
    validate_snapshot_name "$SNAPSHOT_NAME"
    if ! read_metadata "$SNAPSHOT_NAME"; then
      exit 1
    fi
    ;;

  --label)
    if [ -z "$2" ] || [ -z "$3" ]; then 
      echo "❌ Usage: aavi_sandbox --label SNAPSHOT 'label1,label2'"
      exit 1
    fi
    SNAPSHOT_NAME="$2"
    validate_snapshot_name "$SNAPSHOT_NAME"
    # Convert comma-separated labels to JSON array
    LABELS="[\"${3//,/\",\"}\"]"
    update_metadata "$SNAPSHOT_NAME" "labels" "$LABELS"
    echo "🏷️  Updated labels for snapshot '$SNAPSHOT_NAME'"
    ;;

  --set-description)
    if [ -z "$2" ] || [ -z "$3" ]; then 
      echo "❌ Usage: aavi_sandbox --set-description SNAPSHOT 'description text'"
      exit 1
    fi
    SNAPSHOT_NAME="$2"
    validate_snapshot_name "$SNAPSHOT_NAME"
    update_metadata "$SNAPSHOT_NAME" "description" "$3"
    echo "📝 Updated description for snapshot '$SNAPSHOT_NAME'"
    ;;

  --commit)
    if [ -z "$2" ]; then echo "❌ Please provide a snapshot name for --commit"; exit 1; fi
    SNAPSHOT_NAME="$2"
    validate_snapshot_name "$SNAPSHOT_NAME"
    commit_changes
    # Update commit timestamp in metadata
    update_metadata "$SNAPSHOT_NAME" "last_committed" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    ;;

  --clear)
    if [ -z "$2" ]; then echo "❌ Please provide a snapshot name for --clear"; exit 1; fi
    SNAPSHOT_NAME="$2"
    validate_snapshot_name "$SNAPSHOT_NAME"
    clear_overlay
    ;;

  --exit)
    cleanup_logging
    unmount_overlay
    ;;

  --status)
    SNAPSHOT_NAME="${2:-default_$TIMESTAMP}"
    validate_snapshot_name "$SNAPSHOT_NAME"
    status_report
    echo
    echo "📋 Snapshot Metadata:"
    read_metadata "$SNAPSHOT_NAME" || true
    ;;

  --list)
    list_snapshots_with_metadata
    ;;

  --remove)
    if [ -z "$2" ]; then echo "❌ Please provide a snapshot name for --remove"; exit 1; fi
    SNAPSHOT_NAME="$2"
    validate_snapshot_name "$SNAPSHOT_NAME"
    rm -rf "$OVERLAY_BASE/$SNAPSHOT_NAME" "$WORKDIR_BASE/$SNAPSHOT_NAME"
    echo "🗑️ Removed snapshot '$SNAPSHOT_NAME' from sandbox storage."
    ;;

  --search)
    if [ -z "$2" ]; then echo "❌ Please provide a search term"; exit 1; fi
    echo "🔍 Searching snapshots..."
    find "$OVERLAY_BASE" -name ".aavi_metadata.json" -exec sh -c '
      jq -r "select(.description | contains(\"'"$2"'\") or .labels | join(\",\") | contains(\"'"$2"'\")) | \"\(.name) (\(.created_at))\"" "{}"
    ' \;
    ;;

  *)
    echo "Usage: aavi_sandbox [command] [options]"
    echo
    echo "Snapshot Management:"
    echo "  --play SNAPSHOT [description] [labels]  Start a sandbox session"
    echo "  --commit SNAPSHOT                      Commit changes"
    echo "  --clear SNAPSHOT                       Clear snapshot"
    echo "  --exit                                 Exit session"
    echo "  --remove SNAPSHOT                      Delete snapshot"
    echo
    echo "Metadata Commands:"
    echo "  --describe SNAPSHOT                    Show snapshot metadata"
    echo "  --label SNAPSHOT 'label1,label2'       Set snapshot labels"
    echo "  --set-description SNAPSHOT 'text'      Set snapshot description"
    echo "  --search 'term'                        Search snapshots by description/labels"
    echo
    echo "Information:"
    echo "  --status [SNAPSHOT]                    Show status and metadata"
    echo "  --list                                 List all snapshots with details"
    echo "  --target PATH                          Override mount location"
    ;;
esac

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --target)
      TARGET_PATH="$2"
      LOWERDIR="$TARGET_PATH"
      MOUNTPOINT="$TARGET_PATH"
      shift 2
      ;;
    *) break ;;
  esac
done