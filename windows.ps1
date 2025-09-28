Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
scoop install git

scoop bucket add extras
scoop bucket add versions
scoop bucket add java
scoop bucket add nonportable

scoop bucket add aki https://github.com/akirco/aki-apps.git
scoop bucket add dorado https://github.com/chawyehsu/dorado.git
scoop bucket add echo https://github.com/echoiron/echo-scoop.git
scoop bucket add lemon https://github.com/hoilc/scoop-lemon.git
scoop bucket add scoopet https://github.com/ivaquero/scoopet.git
scoop bucket add tomato https://github.com/zhoujin7/tomato.git
scoop bucket add scoop-zapps https://github.com/kkzzhizhou/scoop-zapps.git
scoop update 

scoop install qqnt
scoop install wechat
scoop install qqmusic
scoop install feishu
scoop install telegram
scoop install powertoys
scoop install rustdesk
scoop install github
scoop install cursor  
scoop install pwsh
scoop install oh-my-posh
scoop install rustup-msvc
scoop install rust-msvc
scoop install temurin21-jdk
scoop install nodejs-lts
scoop install maven gradle
# scoop install temurin25-jdk
scoop install jetbrains-toolbox
scoop install bandizip nanazip
scoop install redis mariadb another-redis-desktop-manager
scoop install nvidia-display-driver-np


Install-Module -Name PowerShellGet -Force
Install-Module PSReadLine -AllowPrerelease -Force
Install-Module ZLocation -Scope CurrentUser

scoop install office-365-apps-np imazing

powershell -c "irm https://community.chocolatey.org/install.ps1|iex"
# choco install -y gsudu
