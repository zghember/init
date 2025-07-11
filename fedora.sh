#!/bin/sh
# =============================== dev ==================================
dnf -y install git vim tmux zsh patch g++ cmake webkit2gtk4.1-devel gtk3-devel libappindicator-gtk3-devel librsvg2-devel patchelf @development-tools openssl-devel libxdo-devel libsoup3-devel javascriptcoregtk4.1-devel autojump-zsh java-21-openjdk mysql-server redis bzip2 bzip2-devel readline-devel sqlite-devel libuuid-devel gdbm-devel xz-devel tk-devel openssl-devel

systemctl enable --now mysqld redis

# python env
curl https://pyenv.run | bash
pyenv install 3.13.5

# node
# Download and install fnm:
curl -o- https://fnm.vercel.app/install | bash
# Download and install Node.js:
fnm install 22

# rust & cargo
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# claude && claudia && bun
# Install bun
curl -fsSL https://bun.sh/install | bash
npm install -g @anthropic-ai/claude-code
git clone https://github.com/getAsterisk/claudia.git

# =============================== server ==================================
# docker
dnf -y install docker docker-compose
systemctl enable --now docker

# nginx
dnf -y install nginx
systemctl enable --now nginx
setsebool -P httpd_can_network_connect 1


