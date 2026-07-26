# AI CLI Kickstarter — Windows PowerShell
# NOTE: kickstarter.sh mirrors this script; keep states and strings in sync.
$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "需要 PowerShell 5 或更新版本 / PowerShell 5 or newer is required."
    Read-Host "Press Enter to exit" | Out-Null
    exit 1
}
$Version = "0.2.0"
$State = "LANGUAGE"
$Language = ""
$GoogleStatus = "unknown"
$ProviderName = ""
$CommandName = ""
$InstallUrl = ""
$FinalInstallUrl = ""
$InstallerPath = ""
$InstallerSha256 = ""
$LastError = ""

function T([string]$Key) {
    $zh = @{
        title="AI CLI 启动器"; choose_language="请选择语言 / Choose your language";
        probing="正在检测 PowerShell 是否能直接访问 Google……";
        reachable="可以直接访问 Google。"; unreachable="无法直接访问 Google。";
        unknown="无法可靠判断 Google 是否可访问。";
        network_note="该结果只代表当前 PowerShell 对 Google 的连接，不判断地理位置。";
        choose="请选择一个 Kickstarter："; default="直接按 Enter 选择 Qwen Code，或输入 1–3";
        qwen="中国大陆友好；官方独立安装器"; kimi="中国大陆友好；首次启动后输入 /login";
        buddy="腾讯生态；官方原生安装器目前为 Beta";
        checking="正在执行安装前检查……";
        downloading="正在下载安装器以供确认（尚未执行）……";
        ready="准备执行"; source="初始来源"; final_source="最终来源"; checksum="SHA-256";
        confirm="执行这个已下载的安装器？[y/N]";
        installing="正在运行官方安装器……"; verifying="正在验证……"; success="安装成功。";
        not_found="安装器已结束，但当前 PowerShell 尚未找到命令。请重新打开 PowerShell 后再运行。";
        verify_retry="[1] 再次验证  [2] 退出";
        handoff_note="请复制下面的交接 Prompt，并在 AI CLI 启动后粘贴：";
        launch="现在启动？[Y/n]"; failed="安装失败"; retry="[1] 重试  [2] 换一个工具  [3] 退出";
        exit="按 Enter 退出"
    }
    $en = @{
        title="AI CLI Kickstarter"; choose_language="请选择语言 / Choose your language";
        probing="Testing whether PowerShell can reach Google directly...";
        reachable="Google is directly reachable."; unreachable="Google is not directly reachable.";
        unknown="Google reachability could not be determined reliably.";
        network_note="This only tests PowerShell access to Google; it does not infer location.";
        choose="Choose a kickstarter:"; default="Press Enter for Qwen Code, or enter 1–3";
        qwen="Mainland-China friendly; official standalone installer";
        kimi="Mainland-China friendly; enter /login after first launch";
        buddy="Tencent ecosystem; official native installer is currently Beta";
        checking="Running pre-installation checks...";
        downloading="Downloading the installer for review (not executing it yet)...";
        ready="Ready to execute"; source="Initial source"; final_source="Final source"; checksum="SHA-256";
        confirm="Execute this downloaded installer? [y/N]";
        installing="Running the official installer..."; verifying="Verifying..."; success="Installation succeeded.";
        not_found="The installer finished, but the command is not visible yet. Reopen PowerShell and try again.";
        verify_retry="[1] Verify again  [2] Exit";
        handoff_note="Copy the handoff prompt below and paste it after the AI CLI starts:";
        launch="Launch now? [Y/n]"; failed="Installation failed"; retry="[1] Retry  [2] Choose another tool  [3] Exit";
        exit="Press Enter to exit"
    }
    if ($Language -eq "zh") { return $zh[$Key] } else { return $en[$Key] }
}

function Banner {
    Clear-Host
    Write-Host ""
    Write-Host "=== $(T 'title') v$Version ==="
    Write-Host ""
}

function Test-GoogleReachability {
    try {
        $r = Invoke-WebRequest -Uri "https://www.google.com/generate_204" -Method Get -TimeoutSec 7 -MaximumRedirection 2 -UseBasicParsing
        if ($r.StatusCode -eq 204) { $script:GoogleStatus = "reachable" }
        else { $script:GoogleStatus = "unknown" }
    } catch {
        # An HTTP response other than 204 means "unknown"; no response means "unreachable".
        if ($_.Exception -is [System.Net.WebException] -and $_.Exception.Response) { $script:GoogleStatus = "unknown" }
        else { $script:GoogleStatus = "unreachable" }
    }
}

function Test-Affirmative([string]$Answer) {
    return ([string]::IsNullOrWhiteSpace($Answer) -or $Answer -match "^(y|yes|是)$")
}

function Test-ExplicitAffirmative([string]$Answer) {
    return (-not [string]::IsNullOrWhiteSpace($Answer) -and $Answer -match "^(y|yes|是)$")
}

function Read-Answer([string]$Prompt) {
    if ([Console]::IsInputRedirected) {
        if (-not [string]::IsNullOrEmpty($Prompt)) {
            Write-Host -NoNewline "$Prompt "
        }
        $value = [Console]::In.ReadLine()
    } else {
        $value = Read-Host $Prompt
    }
    return [pscustomobject]@{
        IsEof = ($null -eq $value)
        Value = if ($null -eq $value) { "" } else { [string]$value }
    }
}

function Select-Provider([string]$Choice) {
    switch ($Choice) {
        "1" { $script:ProviderName="Qwen Code"; $script:CommandName="qwen"; $script:InstallUrl="https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.ps1" }
        "2" { $script:ProviderName="Kimi Code"; $script:CommandName="kimi"; $script:InstallUrl="https://code.kimi.com/kimi-code/install.ps1" }
        "3" { $script:ProviderName="CodeBuddy CLI"; $script:CommandName="codebuddy"; $script:InstallUrl="https://www.codebuddy.cn/cli/install.ps1" }
    }
}

function Sync-SessionPath {
    # Append, never replace. Installers run in a child process, so re-read the
    # registry and include the providers' documented per-user binary locations.
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$env:Path;$machine;$user;$HOME\.local\bin;$HOME\.kimi-code\bin;$HOME\AppData\Local\codebuddy\bin"
}

function Test-AllowedInstallerUrl([string]$Url) {
    try {
        $uri = [Uri]$Url
    } catch {
        return $false
    }
    if ($uri.Scheme -ne "https") { return $false }

    switch ($ProviderName) {
        "Qwen Code" {
            return ($uri.Host -eq "qwen-code-assets.oss-cn-hangzhou.aliyuncs.com" -and
                $uri.AbsolutePath.StartsWith("/installation/"))
        }
        "Kimi Code" {
            return (($uri.Host -eq "code.kimi.com" -or $uri.Host -eq "cdn.kimi.com") -and
                $uri.AbsolutePath.StartsWith("/kimi-code/"))
        }
        "CodeBuddy CLI" {
            return ($uri.Host -eq "www.codebuddy.cn" -and $uri.AbsolutePath.StartsWith("/cli/"))
        }
        default { return $false }
    }
}

function Clear-DownloadedInstaller {
    if (-not [string]::IsNullOrWhiteSpace($InstallerPath) -and
        (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
        Remove-Item -LiteralPath $InstallerPath -Force
    }
    $script:InstallerPath = ""
}

function Save-Installer {
    Clear-DownloadedInstaller
    $script:LastError = ""
    $script:FinalInstallUrl = ""
    $script:InstallerSha256 = ""
    $script:InstallerPath = Join-Path ([IO.Path]::GetTempPath()) ("ai-cli-kickstarter-{0}.ps1" -f [guid]::NewGuid().ToString("N"))

    try {
        $response = Invoke-WebRequest -Uri $InstallUrl -UseBasicParsing -TimeoutSec 60 `
            -MaximumRedirection 5 -OutFile $InstallerPath -PassThru
        if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf) -or
            (Get-Item -LiteralPath $InstallerPath).Length -eq 0) {
            throw "Empty installer script from $InstallUrl"
        }

        $script:FinalInstallUrl = $InstallUrl
        if ($response.BaseResponse.ResponseUri) {
            $script:FinalInstallUrl = $response.BaseResponse.ResponseUri.AbsoluteUri
        } elseif ($response.BaseResponse.RequestMessage.RequestUri) {
            $script:FinalInstallUrl = $response.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
        }
        if (-not (Test-AllowedInstallerUrl $FinalInstallUrl)) {
            throw "Unexpected installer redirect: $FinalInstallUrl"
        }

        $script:InstallerSha256 = (Get-FileHash -LiteralPath $InstallerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    } catch {
        Clear-DownloadedInstaller
        throw
    }
}

function Show-Handoff {
    if ($Language -eq "zh") {
@'
我是计算机新手。请作为我的个人 AI 电脑助手。

请遵守：
1. 执行命令前，用通俗语言解释目的。
2. 修改配置文件前先备份。
3. 涉及管理员权限、删除、覆盖、付费或隐私时，先询问我。
4. 每完成一步都验证结果。
5. 对每个在线服务都实际检测可访问性，不要仅根据 Google 的结果推断。
6. 只在必要时教我概念和命令，不要一次塞给我太多知识。

首先，请检查当前电脑环境，并告诉我下一步最值得做什么。
'@ | Write-Host
    } else {
@'
I am a complete beginner. Act as my personal AI computer assistant.

Please follow these rules:
1. Explain the purpose in plain language before running commands.
2. Back up configuration files before changing them.
3. Ask first before administrator access, deletion, overwriting, payment, or privacy-sensitive actions.
4. Verify every completed step.
5. Test each online service directly; do not infer all connectivity from the Google result.
6. Teach concepts and commands only when necessary; do not overwhelm me.

First inspect this computer and tell me the single most valuable next step.
'@ | Write-Host
    }
}

while ($true) {
    switch ($State) {
        "LANGUAGE" {
            Banner
            Write-Host (T "choose_language")
            Write-Host "`n  [1] 中文`n  [2] English`n"
            $answer = Read-Answer ">"
            if ($answer.IsEof) { exit 1 }
            $c = $answer.Value
            if ($c -eq "1") { $Language="zh"; $State="PROBE" }
            elseif ($c -eq "2") { $Language="en"; $State="PROBE" }
            else { Start-Sleep -Milliseconds 250 }
        }
        "PROBE" {
            Banner; Write-Host (T "probing"); Test-GoogleReachability
            Write-Host "`n$(T $GoogleStatus)"
            Write-Host (T "network_note")
            Start-Sleep -Seconds 1; $State="SELECT"
        }
        "SELECT" {
            Banner
            Write-Host "$(T $GoogleStatus)`n"
            Write-Host (T "choose")
            Write-Host "`n  [1] Qwen Code — $(T 'qwen')"
            Write-Host "`n  [2] Kimi Code — $(T 'kimi')"
            Write-Host "`n  [3] CodeBuddy CLI — $(T 'buddy')`n"
            $answer = Read-Answer (T "default")
            if ($answer.IsEof) { exit 1 }
            $c = $answer.Value
            if ([string]::IsNullOrWhiteSpace($c)) { $c="1" }
            if ($c -match '^[123]$') { Select-Provider $c; $State="PRECHECK" }
        }
        "PRECHECK" {
            Banner; Write-Host (T "checking")
            $State="DOWNLOAD"
        }
        "DOWNLOAD" {
            Banner; Write-Host (T "downloading")
            try {
                Save-Installer
                $State="CONFIRM"
            } catch {
                $LastError=$_.Exception.Message
                $State="ERROR"
            }
        }
        "CONFIRM" {
            Banner
            Write-Host "$(T 'ready'): $ProviderName"
            Write-Host "$(T 'source'): $InstallUrl"
            Write-Host "$(T 'final_source'): $FinalInstallUrl"
            Write-Host "$(T 'checksum'): $InstallerSha256`n"
            $answer=Read-Answer (T "confirm")
            if ($answer.IsEof) { Clear-DownloadedInstaller; exit 1 }
            if (Test-ExplicitAffirmative $answer.Value) { $State="INSTALL" }
            else { Clear-DownloadedInstaller; $State="DONE" }
        }
        "INSTALL" {
            Banner; Write-Host (T "installing")
            try {
                $powerShellExecutable = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
                & $powerShellExecutable -NoLogo -NoProfile -ExecutionPolicy Bypass -File $InstallerPath
                if ($LASTEXITCODE -ne 0) {
                    throw "$ProviderName installer returned exit code $LASTEXITCODE"
                }
                $State="VERIFY"
            } catch {
                $LastError=$_.Exception.Message; $State="ERROR"
            } finally {
                Clear-DownloadedInstaller
            }
        }
        "VERIFY" {
            Sync-SessionPath; Write-Host "`n$(T 'verifying')"
            try {
                $cmd=Get-Command $CommandName -ErrorAction Stop
                & $cmd.Source --version
                Write-Host (T "success")
                $State="HANDOFF"
            } catch {
                Write-Host (T "not_found")
                $State="RESTART_REQUIRED"
            }
        }
        "RESTART_REQUIRED" {
            Write-Host (T "verify_retry")
            $answer=Read-Answer ">"
            if ($answer.IsEof) { exit 1 }
            $c=$answer.Value
            if ([string]::IsNullOrWhiteSpace($c) -or $c -eq "2") { $State="DONE" }
            elseif ($c -eq "1") { $State="VERIFY" }
        }
        "HANDOFF" {
            Write-Host "`n$(T 'handoff_note')`n"; Show-Handoff
            $answer=Read-Answer "`n$(T 'launch')"
            if ($answer.IsEof) { exit 1 }
            if (Test-Affirmative $answer.Value) {
                Sync-SessionPath
                try { & $CommandName } catch { Write-Host (T "not_found") }
            }
            $State="DONE"
        }
        "ERROR" {
            Write-Host "`n$(T 'failed'): $LastError"
            $answer=Read-Answer (T "retry")
            if ($answer.IsEof) { exit 1 }
            $c=$answer.Value
            if ($c -eq "1") { $State="PRECHECK" }
            elseif ($c -eq "2") { $State="SELECT" }
            elseif ($c -eq "3") { $State="DONE" }
        }
        "DONE" {
            Clear-DownloadedInstaller
            [void](Read-Answer (T "exit"))
            exit
        }
    }
}
