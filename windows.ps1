powershell -c "irm https://community.chocolatey.org/install.ps1|iex"
choco install -y Temurin21
choco install -y nodejs
choco install -y jetbrainstoolbox
choco install -y rustup.install
choco install -y rust
choco install -y redis
choco install -y rustdesk
choco install -y maven gradle
choco install -y mariadb
choco install -y github-desktop
choco install -y git
choco install -y oh-my-posh
choco install -y gsudu
choco install -y bandizip
Install-Module -Name PowerShellGet -Force
Install-Module PSReadLine -AllowPrerelease -Force
Install-Module ZLocation -Scope CurrentUser