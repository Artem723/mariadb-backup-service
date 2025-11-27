#!/usr/bin/bash
echo "[RECEIVER - info] Received backup for $SSH_ORIGINAL_COMMAND"

SERVICE_NAME="$SSH_ORIGINAL_COMMAND"
TARGET_DIR="/home/backup-main/backups/$SERVICE_NAME"
echo "[RECEIVER - info] Target dir: $TARGET_DIR"

if !  [ -d "$TARGET_DIR" ]; then
   mkdir -p "$TARGET_DIR"
fi

cat > "$TARGET_DIR/$(date +%F_%H-%M-%S).tar.gz"
