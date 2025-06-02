function mount_overlay() {
  # Validate snapshot name and check mount conflicts
  validate_snapshot_name "$SNAPSHOT_NAME"
  check_mount_conflicts "$MOUNTPOINT"

  UPPERDIR="$OVERLAY_BASE/$SNAPSHOT_NAME"
  WORKDIR="$WORKDIR_BASE/$SNAPSHOT_NAME"
  mkdir -p "$UPPERDIR" "$WORKDIR"

  # Ensure the mountpoint directory exists
  if [[ ! -d "$MOUNTPOINT" ]]; then
    echo "📂 Creating mountpoint directory: $MOUNTPOINT"
    mkdir -p "$MOUNTPOINT"
  fi

  mount -t overlay overlay \
    -o lowerdir=$LOWERDIR,upperdir=$UPPERDIR,workdir=$WORKDIR \
    $MOUNTPOINT

  # Log session start
  LOGFILE="$LOGDIR/${SNAPSHOT_NAME}-$(date +%Y%m%d-%H%M%S).log"
  mkdir -p "$LOGDIR"
  echo "[$(date -u)] 🔧 Started sandbox session '$SNAPSHOT_NAME'" >> "$LOGFILE"
  echo "Lowerdir: $LOWERDIR" >> "$LOGFILE"
  echo "Upperdir: $UPPERDIR" >> "$LOGFILE"
  echo "Workdir: $WORKDIR" >> "$LOGFILE"
  echo "Mountpoint: $MOUNTPOINT" >> "$LOGFILE"

  echo "✅ Overlay mounted at $MOUNTPOINT"
}