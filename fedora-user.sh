#!/usr/bin/env bash

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

check_user() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should NOT be run as root. Run as regular user."
    fi
}

log "Starting Fedora user-level initialization..."
check_user

log "Installing Python environment manager (pyenv)..."
if ! command -v pyenv &> /dev/null; then
    curl -fsSL https://pyenv.run | bash || error "Failed to install pyenv"
    export PATH="$HOME/.pyenv/bin:$PATH"
    eval "$(pyenv init -)"
    log "pyenv installed successfully"
else
    log "pyenv already installed"
fi

log "Installing Python 3.13.5..."
if command -v pyenv &> /dev/null; then
    pyenv install 3.13.5 || log "Warning: Failed to install Python 3.13.5"
fi

log "Installing Node.js version manager (fnm)..."
if ! command -v fnm &> /dev/null; then
    curl -fsSL https://fnm.vercel.app/install | bash || error "Failed to install fnm"
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env)"
    log "fnm installed successfully"
else
    log "fnm already installed"
fi

log "Installing Node.js 22..."
if command -v fnm &> /dev/null; then
    fnm install 22 || log "Warning: Failed to install Node.js 22"
fi

log "Installing Rust and Cargo..."
if ! command -v rustc &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || error "Failed to install Rust"
    source "$HOME/.cargo/env"
    log "Rust installed successfully"
else
    log "Rust already installed"
fi

log "Installing Bun..."
if ! command -v bun &> /dev/null; then
    curl -fsSL https://bun.sh/install | bash || error "Failed to install Bun"
    log "Bun installed successfully"
else
    log "Bun already installed"
fi

log "Installing Claude Code globally..."
if command -v npm &> /dev/null; then
    npm install -g @anthropic-ai/claude-code || log "Warning: Failed to install Claude Code"
fi

log "Cloning Claudia repository..."
if [ ! -d "$HOME/claudia" ]; then
    cd "$HOME"
    git clone https://github.com/getAsterisk/claudia.git || log "Warning: Failed to clone Claudia repository"
else
    log "Claudia already cloned"
fi

log "User-level initialization completed successfully!"
log "Please restart your shell or run 'source ~/.bashrc' (or ~/.zshrc) to update your PATH"