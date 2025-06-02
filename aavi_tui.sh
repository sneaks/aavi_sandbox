#!/bin/bash

# Aavi Sandbox TUI
# A beautiful terminal interface for aavi_sandbox using gum
# https://github.com/charmbracelet/gum

# Check for gum
if ! command -v gum &> /dev/null; then
    echo "❌ gum is required but not installed."
    echo "Install with:"
    echo "  brew install gum    # macOS"
    echo "  apt install gum     # Ubuntu/Debian"
    exit 1
fi

# === CONFIG ===
LOWERDIR="/opt/aavi_sandbox_test"
OVERLAY_BASE="/tmp/aavi_overlay"
WORKDIR_BASE="/tmp/aavi_work"
MOUNTPOINT="/opt/aavi_sandbox_test"
SNAPSHOT_NAME=""

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
            gum style --foreground 246 "📄 Loading config: $config"
            # shellcheck source=/dev/null
            source "$config"
        fi
    done

    # Environment variables override config files
    [[ -n "$AAVI_LOWERDIR" ]] && LOWERDIR="$AAVI_LOWERDIR"
    [[ -n "$AAVI_OVERLAY_BASE" ]] && OVERLAY_BASE="$AAVI_OVERLAY_BASE"
    [[ -n "$AAVI_WORKDIR_BASE" ]] && WORKDIR_BASE="$AAVI_WORKDIR_BASE"
    [[ -n "$AAVI_MOUNTPOINT" ]] && MOUNTPOINT="$AAVI_MOUNTPOINT"
}

# Load config at startup
load_config

# === Styling ===
HEADER_STYLE="--border double --border-foreground 212 --padding '1 2'"
MENU_STYLE="--height 15"

# === Helper Functions ===
function show_header() {
    gum style \
        --foreground 212 \
        --border double \
        --border-foreground 212 \
        --padding "1 2" \
        "🧪 Aavi Sandbox Manager" \
        "Interactive overlay management"
}

function show_menu() {
    gum choose \
        --cursor.foreground 212 \
        --selected.foreground 212 \
        --cursor "→ " \
        "Active Snapshots" \
        "Create New Snapshot" \
        "Manage Snapshots" \
        "View Logs" \
        "Settings" \
        "Help" \
        "Exit"
}

function create_snapshot() {
    local name description labels

    gum style \
        $HEADER_STYLE \
        "📦 Create New Snapshot"

    name=$(gum input --placeholder "Snapshot name (e.g. docker_test)" --prompt "Name: ")
    if [[ -z "$name" ]]; then
        return
    fi

    description=$(gum input --placeholder "Optional description" --prompt "Description: ")
    labels=$(gum input --placeholder "comma,separated,labels" --prompt "Labels: ")

    if gum confirm "Create snapshot '$name'?"; then
        if [[ -n "$description" && -n "$labels" ]]; then
            aavi_sandbox --play "$name" "$description" "$labels"
        elif [[ -n "$description" ]]; then
            aavi_sandbox --play "$name" "$description"
        else
            aavi_sandbox --play "$name"
        fi
        gum spin --spinner dot --title "Creating snapshot..." -- sleep 2
        gum style --foreground 212 "✨ Snapshot created successfully!"
    fi
}

function manage_snapshots() {
    local snapshots action snapshot

    while true; do
        gum style \
            $HEADER_STYLE \
            "🗄️ Manage Snapshots"

        # Get list of snapshots
        mapfile -t snapshots < <(aavi_sandbox --list | grep "^📦" | cut -d' ' -f2)

        if ((${#snapshots[@]} == 0)); then
            gum style --foreground 1 "No snapshots found!"
            gum input --placeholder "Press Enter to continue..."
            return
        fi

        snapshot=$(gum choose "${snapshots[@]}" "Back")
        [[ "$snapshot" == "Back" || -z "$snapshot" ]] && return

        action=$(gum choose \
            "View Details" \
            "Edit Description" \
            "Edit Labels" \
            "Commit Changes" \
            "Clear Changes" \
            "Remove Snapshot" \
            "Back")

        case "$action" in
            "View Details")
                gum style --foreground 212 "📋 Snapshot Details"
                echo "----------------------------------------"
                aavi_sandbox --describe "$snapshot"
                echo "----------------------------------------"
                gum input --placeholder "Press Enter to continue..."
                ;;
            "Edit Description")
                description=$(gum input --placeholder "New description" --prompt "Description: ")
                if [[ -n "$description" ]]; then
                    aavi_sandbox --set-description "$snapshot" "$description"
                    gum style --foreground 212 "✨ Description updated!"
                    sleep 1
                fi
                ;;
            "Edit Labels")
                labels=$(gum input --placeholder "comma,separated,labels" --prompt "Labels: ")
                if [[ -n "$labels" ]]; then
                    aavi_sandbox --label "$snapshot" "$labels"
                    gum style --foreground 212 "🏷️  Labels updated!"
                    sleep 1
                fi
                ;;
            "Commit Changes")
                if gum confirm "Commit changes from '$snapshot'?"; then
                    gum spin --spinner dot --title "Committing changes..." -- aavi_sandbox --commit "$snapshot"
                    gum style --foreground 212 "💾 Changes committed successfully!"
                    sleep 1
                fi
                ;;
            "Clear Changes")
                if gum confirm "Clear all changes in '$snapshot'?" --negative; then
                    gum spin --spinner dot --title "Clearing changes..." -- aavi_sandbox --clear "$snapshot"
                    gum style --foreground 212 "🧹 Changes cleared!"
                    sleep 1
                fi
                ;;
            "Remove Snapshot")
                if gum confirm "⚠️  Permanently remove '$snapshot'?" --negative; then
                    gum spin --spinner dot --title "Removing snapshot..." -- aavi_sandbox --remove "$snapshot"
                    gum style --foreground 212 "🗑️  Snapshot removed!"
                    sleep 1
                fi
                ;;
            "Back"|"")
                break
                ;;
        esac
    done
}

function view_logs() {
    gum style \
        $HEADER_STYLE \
        "📋 Session Logs"

    if [[ ! -d "/var/log/aavi_sandbox_sessions" ]]; then
        gum style --foreground 1 "No logs found!"
        return
    fi

    mapfile -t logs < <(ls -1t /var/log/aavi_sandbox_sessions/)
    if ((${#logs[@]} == 0)); then
        gum style --foreground 1 "No logs found!"
        return
    fi

    log=$(gum choose "${logs[@]}")
    if [[ -n "$log" ]]; then
        gum pager < "/var/log/aavi_sandbox_sessions/$log"
    fi
}

function show_help() {
    gum style \
        $HEADER_STYLE \
        "ℹ️  Help & Information"

    gum format << EOF
# Aavi Sandbox TUI

This interface provides easy access to aavi_sandbox functionality:

## 🎯 Quick Actions
- **Active Snapshots**: View and manage mounted overlays
- **Create New**: Start a new sandbox session
- **Manage**: Browse and modify existing snapshots
- **Logs**: View session history

## 💡 Tips
- Use arrow keys or vim keys (j/k) to navigate
- Press q or Esc to go back/exit
- Tab to cycle through options

## 🔗 Resources
- Documentation: https://github.com/sneaks/aavi_sandbox
- Report Issues: https://github.com/sneaks/aavi_sandbox/issues
EOF
}

function get_active_snapshot() {
    # Try to get the active overlay from mount info
    local active_overlay
    active_overlay=$(mount | grep "on $MOUNTPOINT type overlay" | grep -o "upperdir=$OVERLAY_BASE/[^,]*" | cut -d'/' -f4)
    echo "$active_overlay"
}

function show_status() {
    local status_output mounted_status changes_status active_snapshot
    
    # Get the active snapshot name
    active_snapshot=$(get_active_snapshot)
    
    # Get mount status
    if mount | grep -q "on $MOUNTPOINT type overlay"; then
        mounted_status=$(gum style --foreground 2 "✅ Mounted")
        SNAPSHOT_NAME="$active_snapshot"
    else
        mounted_status=$(gum style --foreground 1 "❌ Not Mounted")
        SNAPSHOT_NAME=""
    fi

    # Get changes status
    if [[ -d "$OVERLAY_BASE/$SNAPSHOT_NAME" ]]; then
        changes_status=$(gum style --foreground 3 "📦 Changes Present")
    else
        changes_status=$(gum style --foreground 8 "📭 No Changes")
    fi

    # Format the status display
    gum style \
        --border double \
        --border-foreground 212 \
        --padding "1 2" \
        "🧾 Active Overlay Status" \
        "$(gum style --foreground 248 '----------------------------------------')" \
        "Active Snapshot: $(gum style --foreground 212 "${SNAPSHOT_NAME:-None}")" \
        "Mount Status:    $mounted_status" \
        "Changes:         $changes_status" \
        "" \
        "$(gum style --foreground 246 'Paths')" \
        "$(gum style --foreground 248 '----------------------------------------')" \
        "$(gum style --foreground 246 'Base:')        $LOWERDIR" \
        "$(gum style --foreground 246 'Overlay:')     $OVERLAY_BASE/${SNAPSHOT_NAME:-<none>}" \
        "$(gum style --foreground 246 'Work Dir:')    $WORKDIR_BASE/${SNAPSHOT_NAME:-<none>}" \
        "$(gum style --foreground 246 'Mount Point:') $MOUNTPOINT"

    # If mounted, show additional options
    if [[ -n "$active_snapshot" ]]; then
        echo
        gum style --foreground 212 "Actions available:"
        action=$(gum choose "Unmount Overlay" "View Changes" "Back")
        case "$action" in
            "Unmount Overlay")
                if gum confirm "Unmount the current overlay?"; then
                    gum spin --spinner dot --title "Unmounting overlay..." -- aavi_sandbox --exit
                    gum style --foreground 212 "🚫 Overlay unmounted"
                    sleep 1
                fi
                ;;
            "View Changes")
                echo "Changes in overlay (coming soon):"
                gum input --placeholder "Press Enter to continue..."
                ;;
        esac
    else
        echo
        gum input --placeholder "Press Enter to continue..."
    fi
}

# === Main Loop ===
while true; do
    clear
    show_header

    choice=$(show_menu)
    case "$choice" in
        "Active Snapshots")
            show_status
            ;;
        "Create New Snapshot")
            create_snapshot
            ;;
        "Manage Snapshots")
            manage_snapshots
            ;;
        "View Logs")
            view_logs
            ;;
        "Settings")
            gum style --foreground 93 "⚙️  Settings coming soon!"
            sleep 1
            ;;
        "Help")
            show_help
            gum input --placeholder "Press Enter to continue..."
            ;;
        "Exit"|"")
            gum style --foreground 212 "👋 Goodbye!"
            exit 0
            ;;
    esac
done 