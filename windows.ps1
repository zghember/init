Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

scoop bucket add aki https://github.com/akirco/aki-apps.git
scoop bucket add dorado https://github.com/chawyehsu/dorado.git
scoop bucket add echo https://github.com/echoiron/echo-scoop.git
scoop bucket add lemon https://github.com/hoilc/scoop-lemon.git
scoop bucket add scoopet https://github.com/ivaquero/scoopet.git
scoop bucket add tomato https://github.com/zhoujin7/tomato.git
scoop bucket add scoop-zapps https://github.com/kkzzhizhou/scoop-zapps.git
scoop update 

scoop install powertoys
scoop install pwsh oh-my-posh git rustup-msvc rust-msvc
scoop install temurin21-jdk git nodejs-lts maven gradle
# scoop install temurin25-jdk
scoop install jetbrains-toolbox
scoop install bandizip nanazip
scoop install redis mariadb
scoop install 


powershell -c "irm https://community.chocolatey.org/install.ps1|iex"
choco install -y rustdesk
choco install -y github-desktop
# choco install -y gsudu
Install-Module -Name PowerShellGet -Force
Install-Module PSReadLine -AllowPrerelease -Force
Install-Module ZLocation -Scope CurrentUser