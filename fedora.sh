#!/bin/sh
systemctl enable --now sshd
dnf -y install git tmux zsh clash exa patch g++ cmake

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
dnf -y install java-17-openjdk

