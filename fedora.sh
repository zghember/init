#!/usr/bin/env bash

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_SCRIPT="$SCRIPT_DIR/fedora-system.sh"
USER_SCRIPT="$SCRIPT_DIR/fedora-user.sh"

log "Starting Fedora initialization coordinator..."

if [[ ! -f "$SYSTEM_SCRIPT" ]]; then
    error "System script not found: $SYSTEM_SCRIPT"
fi

if [[ ! -f "$USER_SCRIPT" ]]; then
    error "User script not found: $USER_SCRIPT"
fi

log "Phase 1: Running system-level installations (requires root)..."
if [[ $EUID -eq 0 ]]; then
    log "Running as root, executing system script..."
    bash "$SYSTEM_SCRIPT"
else
    log "Not running as root, attempting to run system script with sudo..."
    sudo bash "$SYSTEM_SCRIPT"
fi

log "Phase 2: Running user-level installations..."
if [[ $EUID -eq 0 ]]; then
    if [[ -n "${SUDO_USER:-}" ]]; then
        log "Running user script as original user: $SUDO_USER"
        sudo -u "$SUDO_USER" bash "$USER_SCRIPT"
    else
        error "Cannot determine original user. Please run user script manually as regular user: bash $USER_SCRIPT"
    fi
else
    log "Running user script as current user..."
    bash "$USER_SCRIPT"
fi

log "Fedora initialization completed successfully!"
log "Please restart your shell or run 'source ~/.bashrc' (or ~/.zshrc) to update your PATH"


