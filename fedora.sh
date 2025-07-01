#!/bin/sh
dnf -y install git tmux zsh exa patch g++ cmake webkit2gtk4.1-devel gtk3-devel libappindicator-gtk3-devel librsvg2-devel patchelf @development-tools openssl-devel libxdo-devel libsoup3-devel javascriptcoregtk4.1-devel

# docker
dnf -y install docker docker-compose
systemctl enable --now docker

# nginx
dnf -y install nginx
systemctl enable --now nginx
setsebool -P httpd_can_network_connect 1

# python env
curl https://pyenv.run | bash
dnf -y install bzip2 bzip2-devel readline-devel sqlite-devel libuuid-devel gdbm-devel xz-devel tk-devel openssl-devel
pyenv install 3.8.10

# jdk
dnf -y install java-21-openjdk

