#!/usr/bin/env bash

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

log "Starting Fedora initialization script..."
check_root

log "Updating system packages..."
dnf -y update || error "Failed to update system packages"
log "Installing development packages..."
dev_packages=(
    git
    vim
    tmux
    zsh
    patch
    g++
    cmake
    @development-tools
    java-21-openjdk
)
dnf -y install "${dev_packages[@]}" || error "Failed to install development packages"

log "Installing GUI development libraries..."
gui_dev_packages=(
    webkit2gtk4.1-devel
    gtk3-devel
    libappindicator-gtk3-devel
    librsvg2-devel
)
dnf -y install "${gui_dev_packages[@]}" || error "Failed to install GUI development libraries"

log "Installing development libraries..."
dev_libraries=(
    openssl-devel
    libxdo-devel
    libsoup3-devel
    javascriptcoregtk4.1-devel
    bzip2-devel
    readline-devel
    sqlite-devel
    libuuid-devel
    gdbm-devel
    xz-devel
    tk-devel
)
dnf -y install "${dev_libraries[@]}" || error "Failed to install development libraries"

log "Installing system utilities..."
utilities=(
    patchelf
    autojump-zsh
    bzip2
)
dnf -y install "${utilities[@]}" || error "Failed to install utilities"

log "Installing database and cache services..."
services=(
    mysql-server
    redis
)
dnf -y install "${services[@]}" || error "Failed to install services"

log "Enabling and starting services..."
systemctl enable --now mysqld || log "Warning: Failed to enable/start MySQL"
systemctl enable --now redis || log "Warning: Failed to enable/start Redis"

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
if [ ! -d "claudia" ]; then
    git clone https://github.com/getAsterisk/claudia.git || log "Warning: Failed to clone Claudia repository"
else
    log "Claudia already cloned"
fi

log "Installing Docker and Docker Compose..."
docker_packages=(
    docker
    docker-compose
)
dnf -y install "${docker_packages[@]}" || error "Failed to install Docker"

log "Enabling and starting Docker service..."
systemctl enable --now docker || error "Failed to enable/start Docker"

log "Installing Nginx web server..."
dnf -y install nginx || error "Failed to install Nginx"

log "Enabling and starting Nginx service..."
systemctl enable --now nginx || error "Failed to enable/start Nginx"

log "Configuring SELinux for Nginx network connections..."
setsebool -P httpd_can_network_connect 1 || log "Warning: Failed to configure SELinux for Nginx"

log "Fedora initialization script completed successfully!"


