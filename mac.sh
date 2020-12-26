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

# Install other useful binaries.
#brew install ack
#brew install exiv2
brew install wget autojump p7zip unrar stormssh vim aria2


# Install ruby and python env
brew install rbenv
brew install pyenv

# devops
brew install awscli helm tmux mycli

# Install casks
# brew cask install sogouinput thunder youdao mplayerx teamviewer
# coding
brew install --cask -f iterm2 intellij-idea visual-studio-code setapp sourcetree
# need
brew install --cask -f docker alfred neteasemusic imazing pdf-expert microsoft-edge
# tools
brew install --cask -f adguard surge devonthink typora xmind-zen teamviewer
# large file
brew install --cask -f microsoft-office parallels

# fonts
brew tap homebrew/cask-fonts
brew cask install font-hack-nerd-font
# jdk
brew tap adoptopenjdk/openjdk
brew cask install adoptopenjdk adoptopenjdk8
brew install gradle


# Remove outdated versions from the cellar.
brew cleanup

# zsh
git clone https://github.com/robbyrussell/oh-my-zsh ~/.oh-my-zsh
# zsh theme
git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k
# zsh plugin
git clone "https://github.com/zsh-users/zsh-syntax-highlighting" "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
git clone "https://github.com/zsh-users/zsh-autosuggestions" "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

# colorls
rbenv install 3.0.0
eval "$(rbenv init -)"
rbenv global 3.0.0
gem install colorls

# git clone https://github.com/mbadolato/iTerm2-Color-Schemes ~/.iterm2
