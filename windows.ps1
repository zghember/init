#Requires -Version 5.1
<#
Windows 初始化脚本（Windows 11）。

要装的软件写在 .\apps\ 下的纯文本清单里，增删软件只改清单：
    apps/scoop-buckets.txt   scoop bucket，格式 "<name> [<git url>]"，官方 bucket 不用写 url
    apps/scoop.txt           scoop 应用
    apps/winget.txt          winget 包，格式 "<id> [--pin] [其他 winget install 参数]"
                             --pin：装完后 winget pin add，让 topgrade 的 winget upgrade --all 跳过它
    apps/msstore.txt         微软商店应用（通过 winget --source msstore），格式 "<store id> <name>"
    apps/manual.txt          没有包、只能手动装的软件备忘；脚本不会碰它
清单里 `#` 到行尾是注释，空行忽略，临时不想装的软件注释掉即可。

用法（新机器上用自带的 Windows PowerShell 5.1 跑就行）：
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    .\windows.ps1            # 加 -DryRun 只打印将要执行的步骤，不改任何东西
单个软件装失败不会中断脚本，结尾统一汇总失败项。

不在这里管的东西：
    - Windows 11 24H2 起自带 sudo（设置 > 系统 > 开发者选项），所以不再装 gsudo
    - Clash Verge、QQ、微信这类自更新软件，脚本只负责首装，之后由它们自己升级
    - 日常升级统一跑 topgrade（scoop、winget、rustup、npm、pip、Claude Code、JetBrains 插件）
#>
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$appsDir = Join-Path $root 'apps'
$script:failed = New-Object System.Collections.Generic.List[string]
$script:completed = $false

# winget 对"已安装且没有新版本"返回 0x8A15002B，视为成功
$wingetOk = @(0, -1978335189)

function Log([string]$Message) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
}

# 读清单：去掉 # 注释和首尾空白，跳过空行
function Read-List([string]$File) {
    if (-not (Test-Path $File)) {
        Log "Warning: list file not found: $File"
        return
    }
    Get-Content $File -Encoding UTF8 | ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ }
}

# 执行一步并记录失败：退出码不在 OkExitCodes 里、或抛异常，都记进 $failed；-DryRun 时只打印
function Invoke-Tracked {
    param(
        [string]$Label,
        [scriptblock]$Command,
        [int[]]$OkExitCodes = @(0)
    )
    if ($DryRun) {
        Log "[dry-run] $Label"
        return
    }
    Log $Label
    $global:LASTEXITCODE = 0
    $ok = $true
    try {
        & $Command
        if ($OkExitCodes -notcontains $LASTEXITCODE) { $ok = $false }
    } catch {
        Log "  $($_.Exception.Message)"
        $ok = $false
    }
    if (-not $ok) {
        Log "Warning: failed: $Label"
        $script:failed.Add($Label)
    }
}

function Show-Summary {
    Write-Host ''
    Write-Host '============================================================'
    if (-not $script:completed) { Log 'Script exited early due to a fatal error.' }
    if ($script:failed.Count -eq 0) {
        Log 'All tracked steps completed successfully!'
    } else {
        Log "Completed with $($script:failed.Count) failure(s). The following steps failed:"
        Write-Host ''
        foreach ($f in $script:failed) { Write-Host "  $f" }
        Write-Host ''
    }
    Write-Host '============================================================'
}

try {
    Log 'Starting Windows initialization script...'
    if ($DryRun) { Log 'Dry run: nothing will be installed or changed.' }

    Invoke-Tracked 'Set execution policy RemoteSigned (CurrentUser)' {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
    }

    # ---- scoop ----
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Log 'scoop already installed'
    } elseif ($DryRun) {
        Log '[dry-run] Install scoop'
    } else {
        Log 'Installing scoop...'
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { throw 'scoop installation failed' }
    }

    # git 要先于 bucket 装好，scoop 靠它拉 bucket；Claude Code 也要靠它的 git-bash
    Invoke-Tracked 'scoop install git' { scoop install git }
    Invoke-Tracked 'Set CLAUDE_CODE_GIT_BASH_PATH to scoop git-bash' {
        $bash = Join-Path (scoop prefix git) 'bin\bash.exe'
        if (-not (Test-Path $bash)) { throw "bash.exe not found at $bash" }
        [Environment]::SetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', $bash, 'User')
    }

    $buckets = @()
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        $buckets = @(scoop bucket list 6>$null | ForEach-Object { if ($_.Name) { $_.Name } else { "$_" } })
    }
    foreach ($line in Read-List (Join-Path $appsDir 'scoop-buckets.txt')) {
        $parts = $line -split '\s+', 2
        $name = $parts[0]
        $url = if ($parts.Count -gt 1) { $parts[1] } else { $null }
        if ($buckets -contains $name) { Log "Bucket already added: $name"; continue }
        if ($url) { Invoke-Tracked "scoop bucket add $name $url" { scoop bucket add $name $url } }
        else      { Invoke-Tracked "scoop bucket add $name"      { scoop bucket add $name } }
    }
    Invoke-Tracked 'scoop update' { scoop update }

    foreach ($app in Read-List (Join-Path $appsDir 'scoop.txt')) {
        Invoke-Tracked "scoop install $app" { scoop install $app }
    }

    # ---- winget ----
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        foreach ($line in Read-List (Join-Path $appsDir 'winget.txt')) {
            $parts = @($line -split '\s+')
            $id = $parts[0]
            $pin = $parts -contains '--pin'
            $extra = ($parts | Select-Object -Skip 1 | Where-Object { $_ -ne '--pin' }) -join ' '
            Invoke-Tracked "winget install $id" {
                Invoke-Expression "winget install -e --id $id --accept-package-agreements --accept-source-agreements $extra"
            } $wingetOk
            if ($pin) {
                # 已经 pin 过会报错，不算失败
                Invoke-Tracked "winget pin add $id" { winget pin add -e --id $id | Out-Null; $global:LASTEXITCODE = 0 }
            }
        }
        foreach ($line in Read-List (Join-Path $appsDir 'msstore.txt')) {
            $parts = $line -split '\s+', 2
            $id = $parts[0]
            $name = if ($parts.Count -gt 1) { $parts[1] } else { $id }
            Invoke-Tracked "winget install (msstore) $name [$id]" {
                winget install -e --id $id --source msstore --accept-package-agreements --accept-source-agreements
            } $wingetOk
        }
    } else {
        Log 'Warning: winget not found, skipping apps/winget.txt and apps/msstore.txt'
        $script:failed.Add('winget not found: apps/winget.txt and apps/msstore.txt skipped')
    }

    # ---- PowerShell 模块：pwsh 和 Windows PowerShell 的模块目录不同，各装一份 ----
    $moduleSetup = @'
$ProgressPreference = 'SilentlyContinue'
if ($PSVersionTable.PSVersion.Major -lt 6) {
    # Windows PowerShell 自带的 PowerShellGet 1.0 不支持 -AllowPrerelease，先升级它
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    Install-Module PowerShellGet -Force -Scope CurrentUser -AllowClobber
    Import-Module PowerShellGet -MinimumVersion 2.2 -Force
}
Install-Module PSReadLine -AllowPrerelease -Force -Scope CurrentUser
'@
    $moduleSetupEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($moduleSetup))
    foreach ($shell in 'powershell', 'pwsh') {
        if (Get-Command $shell -ErrorAction SilentlyContinue) {
            Invoke-Tracked "Install PSReadLine ($shell)" { & $shell -NoProfile -NonInteractive -EncodedCommand $moduleSetupEncoded }
        }
    }

    # ---- PowerShell profile：pwsh 和 Windows PowerShell 各放一份，内容在仓库的 Microsoft.PowerShell_profile.ps1 ----
    Invoke-Tracked 'Copy PowerShell profile to Documents\PowerShell and Documents\WindowsPowerShell' {
        $docs = [Environment]::GetFolderPath('MyDocuments')
        foreach ($d in "$docs\PowerShell", "$docs\WindowsPowerShell") {
            New-Item -ItemType Directory -Force $d -ErrorAction Stop | Out-Null
            Copy-Item (Join-Path $root 'Microsoft.PowerShell_profile.ps1') (Join-Path $d 'Microsoft.PowerShell_profile.ps1') -Force -ErrorAction Stop
        }
    }

    # ---- Windows Terminal：默认 shell 改成 pwsh，默认字体改成 Nerd Font（否则 oh-my-posh 的图标显示成方块）----
    Invoke-Tracked 'Configure Windows Terminal (default profile + Nerd Font)' {
        $wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        if (Test-Path $wt) {
            $json = ((Get-Content $wt -Raw -ErrorAction Stop) -replace '(?m)^\s*//.*$', '') | ConvertFrom-Json -ErrorAction Stop
        } else {
            New-Item -ItemType Directory -Force (Split-Path $wt) -ErrorAction Stop | Out-Null
            $json = [pscustomobject]@{ '$schema' = 'https://aka.ms/terminal-profiles-schema'; profiles = [pscustomobject]@{ defaults = [pscustomobject]@{} } }
        }
        if (-not $json.profiles) { $json | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{ defaults = [pscustomobject]@{} }) }
        if (-not $json.profiles.defaults) { $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) }
        if ($json.profiles.defaults.font) { $json.profiles.defaults.font | Add-Member -NotePropertyName face -NotePropertyValue 'Maple Mono NF CN' -Force }
        else { $json.profiles.defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{ face = 'Maple Mono NF CN' }) }
        # 默认 shell：{574e775e-...} 是 Terminal 给自动检测到的 PowerShell 7 固定分配的 GUID（source = Windows.Terminal.PowershellCore），
        # scoop 装的 pwsh 也会被检测到，所以不用手写 profile；Terminal 下次启动生成该 profile 后即生效
        $json | Add-Member -NotePropertyName defaultProfile -NotePropertyValue '{574e775e-4f2a-5b96-ac1e-a2962a402336}' -Force
        $json | ConvertTo-Json -Depth 32 | Set-Content $wt -Encoding UTF8 -ErrorAction Stop
    }

    # ---- Claude Code：官方原生安装器，装到 ~\.local\bin，之后靠 claude update 自升级 ----
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Log 'Claude Code already installed'
    } else {
        Invoke-Tracked 'Install Claude Code (https://claude.ai/install.ps1)' {
            & powershell -NoProfile -NonInteractive -Command 'Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression'
        }
    }

    $script:completed = $true
    Log 'Windows initialization script completed!'
} finally {
    Show-Summary
}
