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
mas install 1289197285 #MindNode (6.0.3)
mas install 966085870 #滴答清单 (3.1.00)
mas install 1176895641 #Spark (2.3.6)
mas install 836500024 #微信 (2.3.25)
mas install 441258766 #Magnet (2.4.5)
mas install 1469774098 #QSpace (1.6.2)

# Install ruby and python env
#brew install rbenv
brew install pyenv

# useful binaries
brew install wget p7zip unrar vim aria2
# command line tools
brew install exa autojump stormssh ack
# devops
brew install tmux mycli
# cloud tools
# brew install awscli helm
# develop
# brew install jadx apktool

# Install casks
# brew cask install sogouinput thunder youdao mplayerx teamviewer
# coding
brew install --cask -f iterm2 intellij-idea visual-studio-code setapp sourcetree edrawmax
# need
brew install --cask -f docker alfred neteasemusic imazing pdf-expert microsoft-edge rar
# tools
brew install --cask -f adguard surge devonthink typora xmind-zen teamviewer
# large file
brew install --cask -f microsoft-office parallels

# fonts
brew tap homebrew/cask-fonts
brew install --cask font-hack-nerd-font
# jdk
brew tap adoptopenjdk/openjdk
brew install --cask adoptopenjdk adoptopenjdk8
brew install gradle


# Remove outdated versions from the cellar.
brew cleanup

# git clone https://github.com/mbadolato/iTerm2-Color-Schemes ~/.iterm2
