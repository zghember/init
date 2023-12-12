#!/usr/bin/env bash

# Install command-line tools using Homebrew.
xcode-select --install

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

#install brew and brew cask
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# before all, install 1password
brew install --cask 1password

# before casks, install mac app store app
brew install mas
mas install 441258766   #Magnet                    (2.11.0)
mas install 1487937127  #Craft                     (2.5.3)
mas install 1435957248  #Drafts                    (38.0.1)
mas install 1265704574  #Bandizip                  (7.22)
mas install 1469774098  #QSpace                    (3.2.5)
mas install 1176895641  #Spark                     (2.11.29)
mas install 1289197285  #MindNode                  (2023.1.1)
mas install 966085870   #滴答清单                      (4.5.01)

# Install ruby and python env
#brew install rbenv
brew install pyenv

# useful binaries
brew install wget p7zip vim aria2
# command line tools
brew install exa autojump stormssh ack
# devops
brew install tmux mycli

# Install casks
brew install --cask -f wechat wechatwork lark sogouinput thunder rar arc bilibili
# coding
brew install --cask -f iterm2 intellij-idea visual-studio-code sourcetree
# need
brew install --cask -f docker alfred neteasemusic qqmusic imazing pdf-expert
brew install --cask -f bartender timing cleanshot hazeover craft qq
# tools
brew install --cask -f adguard surge typora todesk baidunetdisk cleanmymac-zh
# large file
brew install --cask -f microsoft-office parallels

# fonts
brew tap homebrew/cask-fonts
brew install --cask font-hack-nerd-font
# jdk
brew install temurin temurin17


# Remove outdated versions from the cellar.
brew cleanup

# git clone https://github.com/mbadolato/iTerm2-Color-Schemes ~/.iterm2
