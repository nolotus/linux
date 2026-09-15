#!/bin/bash
# 自动恢复 profiles.yaml 的脚本
# 当 profiles.yaml 被 GUI 覆盖为空时，自动恢复

PROFILE_DIR="$HOME/.local/share/io.github.clash-verge-rev.clash-verge-rev"
PROFILE_FILE="$PROFILE_DIR/profiles.yaml"
BACKUP_FILE="$PROFILE_DIR/profiles.yaml.bak.fixed"

# 如果已有修复版备份，直接恢复
if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" "$PROFILE_FILE"
    echo "[$(date)] profiles.yaml restored from fixed backup" >> "$PROFILE_DIR/restore-profile.log"
fi
