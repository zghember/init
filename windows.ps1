Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
scoop install git

scoop bucket add extras
scoop bucket add versions
scoop bucket add java
scoop bucket add nonportable
scoop bucket add nerd-fonts

scoop bucket add aki https://github.com/akirco/aki-apps.git
scoop bucket add dorado https://github.com/chawyehsu/dorado.git
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
scoop install Hack-NF Maple-Mono-NF-CN
scoop install rustup-msvc
scoop install rust-msvc
scoop install temurin21-jdk
scoop install nodejs-lts
scoop install maven gradle
# scoop install temurin25-jdk
scoop install jetbrains-toolbox
scoop install bandizip nanazip
scoop install redis mariadb another-redis-desktop-manager
scoop install twinkle-tray reqable winrar


Install-Module -Name PowerShellGet -Force
Install-Module PSReadLine -AllowPrerelease -Force
Install-Module ZLocation -Scope CurrentUser

# PowerShell profile：pwsh 和 Windows PowerShell 各放一份，内容在仓库的 Microsoft.PowerShell_profile.ps1
$root = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($d in "$docs\PowerShell", "$docs\WindowsPowerShell") {
    New-Item -ItemType Directory -Force $d | Out-Null
    Copy-Item "$root\Microsoft.PowerShell_profile.ps1" "$d\Microsoft.PowerShell_profile.ps1" -Force
}

# Windows Terminal：默认 shell 改成 pwsh，默认字体改成 Nerd Font（否则 oh-my-posh 的图标显示成方块）
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $wt) {
    $json = ((Get-Content $wt -Raw) -replace '(?m)^\s*//.*$', '') | ConvertFrom-Json
} else {
    New-Item -ItemType Directory -Force (Split-Path $wt) | Out-Null
    $json = [pscustomobject]@{ '$schema' = 'https://aka.ms/terminal-profiles-schema'; profiles = [pscustomobject]@{ defaults = [pscustomobject]@{} } }
}
if (-not $json.profiles) { $json | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{ defaults = [pscustomobject]@{} }) }
if (-not $json.profiles.defaults) { $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) }
if ($json.profiles.defaults.font) { $json.profiles.defaults.font | Add-Member -NotePropertyName face -NotePropertyValue 'Maple Mono NF CN' -Force }
else { $json.profiles.defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{ face = 'Maple Mono NF CN' }) }
# 默认 shell：{574e775e-...} 是 Terminal 给自动检测到的 PowerShell 7 固定分配的 GUID（source = Windows.Terminal.PowershellCore），
# scoop 装的 pwsh 也会被检测到，所以不用手写 profile；Terminal 下次启动生成该 profile 后即生效
$json | Add-Member -NotePropertyName defaultProfile -NotePropertyValue '{574e775e-4f2a-5b96-ac1e-a2962a402336}' -Force
$json | ConvertTo-Json -Depth 32 | Set-Content $wt -Encoding UTF8

scoop install office-365-apps-np imazing

scoop install gsudo topgrade

# 不进 scoop、交给 winget 管理的
winget install -e --id Tencent.TencentMeeting --accept-package-agreements --accept-source-agreements
winget install -e --id Baidu.BaiduNetdisk --accept-package-agreements --accept-source-agreements
winget install -e --id NetEase.UURemote --accept-package-agreements --accept-source-agreements
winget install -e --id ByteDance.Lark --accept-package-agreements --accept-source-agreements
