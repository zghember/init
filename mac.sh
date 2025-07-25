#!/usr/bin/env bash

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

log "Starting macOS initialization script..."

if ! xcode-select --install 2>/dev/null; then
    log "Xcode command line tools already installed or installation in progress"
fi

log "Requesting administrator privileges..."
sudo -v || error "Failed to obtain administrator privileges"

log "Setting up sudo keep-alive..."
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

log "Installing Homebrew..."
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error "Failed to install Homebrew"
    log "Homebrew installed successfully"
else
    log "Homebrew already installed"
fi

log "Updating Homebrew..."
brew update && brew upgrade || error "Failed to update Homebrew"


log "Installing Mac App Store CLI..."
brew install mas || error "Failed to install mas"

log "Installing Mac App Store applications..."
mas_apps=(
    "1487937127"  # Craft (2.5.3)
    "1435957248"  # Drafts (38.0.1)
    "1265704574"  # Bandizip (7.22)
)

for app in "${mas_apps[@]}"; do
    if ! mas install "$app"; then
        log "Warning: Failed to install MAS app $app"
    fi
done

log "Installing development tools..."
dev_tools=(
    pyenv
    rust
    node
    temurin17
)
brew install "${dev_tools[@]}" || error "Failed to install development tools"

log "Installing command line utilities..."
cli_tools=(
    wget
    vim
    aria2
    p7zip
    autojump
    stormssh
    ack
    tmux
)
brew install "${cli_tools[@]}" || error "Failed to install CLI tools"

log "Installing essential applications..."
essential_casks=(
    wechat
    lark
    arc
    qqmusic
    bilibili
    onedrive
    rar
    adguard
    todesk
    typora
    surge
    flomo
    notion
    clash-verge-rev
)
brew install --cask "${essential_casks[@]}" || log "Warning: Some essential applications failed to install"

log "Installing development applications..."
dev_casks=(
    iterm2
    jetbrains-toolbox
    cursor
    sourcetree
)
brew install --cask "${dev_casks[@]}" || log "Warning: Some development applications failed to install"

log "Installing productivity applications..."
productivity_casks=(
    wechatwork
    qq
    docker
    alfred
    iina
    neteasemusic
)
brew install --cask "${productivity_casks[@]}" || log "Warning: Some productivity applications failed to install"

log "Installing utility applications..."
utility_casks=(
    timing
    thunder
    cleanshot
    pdf-expert
    imazing
)
brew install --cask "${utility_casks[@]}" || log "Warning: Some utility applications failed to install"

log "Installing large applications..."
large_casks=(
    parallels
)
brew install --cask "${large_casks[@]}" || log "Warning: Large applications failed to install"

log "Cleaning up Homebrew..."
brew cleanup || log "Warning: Homebrew cleanup failed"

log "macOS initialization script completed successfully!"

