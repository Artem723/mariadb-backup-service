#!/usr/bin/bash

SERVICE_NAME="$1"
# place, where the backups are going to be placed
TARGET_DIR="/home/backup-main/backups/$SERVICE_NAME"

if !  [ -d "$TARGET_DIR" ]; then
   mkdir -p "$TARGET_DIR"
fi

cat > "$TARGET_DIR/$(date +%F_%H-%M-%S).tar.gz"