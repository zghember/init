#!/usr/bin/env bash

xcode-select --install

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

#install brew and brew cask
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew update && brew upgrade


# before casks, install mac app store app
brew install mas
mas install 1487937127  #Craft                     (2.5.3)
mas install 1435957248  #Drafts                    (38.0.1)
mas install 1265704574  #Bandizip                  (7.22)

# install compiler
brew install pyenv rust node

# useful binaries
brew install -f wget vim aria2 p7zip
# command line tools
brew install -f autojump stormssh ack tmux

# Install casks
# must install
brew install --cask -f wechat lark arc qqmusic bilibili onedrive
brew install --cask -f rar adguard todesk typora surge flomo notion clash-verge-rev
# coding
brew install --cask -f iterm2 jetbrains-toolbox cursor sourcetree
# need
brew install --cask -f wechatwork qq docker alfred iina neteasemusic
# tools
brew install --cask -f timing thunder cleanshot pdf-expert imazing
# large file
brew install --cask -f parallels

# jdk
brew install temurin17

# Remove outdated versions from the cellar.
brew cleanup

