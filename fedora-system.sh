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

log "Starting Fedora system-level initialization..."
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

log "System-level initialization completed successfully!"