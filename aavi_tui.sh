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

# === Main Loop ===
while true; do
    clear
    show_header

    choice=$(show_menu)
    case "$choice" in
        "Active Snapshots")
            gum style --foreground 212 "🔄 Fetching active snapshots..."
            aavi_sandbox --status | gum pager
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