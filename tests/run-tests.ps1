$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Work = Join-Path ([IO.Path]::GetTempPath()) ("ai-cli-kickstarter-tests-{0}" -f [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Work | Out-Null

$Pass = 0
$Fail = 0
$CaseNumber = 0

function Invoke-KickstarterCase {
    param(
        [string]$InputText,
        [ValidateSet("ok", "fail", "redirect", "missing", "installed")]
        [string]$Mode = "ok"
    )

    $script:CaseNumber++
    $wrapperPath = Join-Path $Work ("wrapper-{0}.ps1" -f $CaseNumber)
    $commandPath = Join-Path $Work "qwen.cmd"
    Set-Content -LiteralPath $commandPath -Encoding Ascii -Value "@echo qwen-test-version"

    $escapedRoot = $Root.Replace("'", "''")
    $escapedCommandPath = $commandPath.Replace("'", "''")
    $wrapper = @"
`$ErrorActionPreference = "Stop"
`$TestMode = "$Mode"
`$TestCommandPath = '$escapedCommandPath'

function Clear-Host {}
function Start-Sleep {
    param([int]`$Seconds, [int]`$Milliseconds)
}
function Invoke-WebRequest {
    [CmdletBinding()]
    param(
        [string]`$Uri,
        [string]`$Method,
        [int]`$TimeoutSec,
        [int]`$MaximumRedirection,
        [switch]`$UseBasicParsing,
        [string]`$OutFile,
        [switch]`$PassThru
    )
    if (`$Uri -like "*generate_204*") {
        return [pscustomobject]@{ StatusCode = 204 }
    }
    if (`$TestMode -eq "fail") {
        throw "download failed: `$Uri"
    }
    Set-Content -LiteralPath `$OutFile -Encoding UTF8 -Value "Write-Output 'installer-ran'"
    `$finalUrl = if (`$TestMode -eq "redirect") {
        "https://example.invalid/installer.ps1"
    } else {
        `$Uri
    }
    return [pscustomobject]@{
        BaseResponse = [pscustomobject]@{
            ResponseUri = [Uri]`$finalUrl
            RequestMessage = `$null
        }
    }
}
function Get-Command {
    [CmdletBinding()]
    param([string]`$Name)
    if (`$Name -eq "qwen" -and `$TestMode -eq "installed") {
        return [pscustomobject]@{ Source = `$TestCommandPath }
    }
    throw "command not found: `$Name"
}

& '$escapedRoot\kickstarter.ps1'
exit `$LASTEXITCODE
"@
    Set-Content -LiteralPath $wrapperPath -Encoding UTF8 -Value $wrapper

    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = (Join-Path $PSHOME "powershell.exe")
    $startInfo.Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$wrapperPath`""
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $process.StandardInput.Write($InputText)
    $process.StandardInput.Close()

    $timedOut = -not $process.WaitForExit(15000)
    if ($timedOut) {
        $process.Kill()
        $process.WaitForExit()
    }
    $output = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()

    return [pscustomobject]@{
        ExitCode = if ($timedOut) { "timeout" } else { $process.ExitCode }
        Output = $output
    }
}

function Test-OutputMatch {
    param([pscustomobject]$Result, [string]$Text)
    return $Result.Output.Contains($Text)
}

function Add-Check {
    param([string]$Description, [bool]$Condition, [pscustomobject]$Result)
    if ($Condition) {
        $script:Pass++
        Write-Host "PASS: $Description"
    } else {
        $script:Fail++
        Write-Host "FAIL: $Description"
        Write-Host "  ExitCode=$($Result.ExitCode)"
        $Result.Output.Split([Environment]::NewLine) |
            Select-Object -First 30 |
            ForEach-Object { Write-Host "  | $_" }
    }
}

try {
    Write-Host "== closed stdin exits immediately, installs nothing =="
    $result = Invoke-KickstarterCase -InputText ""
    Add-Check "exits with nonzero status" ($result.ExitCode -ne "timeout" -and $result.ExitCode -ne 0) $result
    Add-Check "does not run the installer" (-not (Test-OutputMatch $result "Running the official installer")) $result

    Write-Host "== failed download reaches the ERROR state =="
    $result = Invoke-KickstarterCase -InputText "2`n1`n3`n`n" -Mode fail
    Add-Check "reports installation failure" (Test-OutputMatch $result "Installation failed") $result
    Add-Check "names the download as the cause" (Test-OutputMatch $result "download failed") $result
    Add-Check "does not reach VERIFY" (-not (Test-OutputMatch $result "Verifying")) $result
    Add-Check "exits cleanly" ($result.ExitCode -eq 0) $result

    Write-Host "== unexpected redirect is rejected before execution =="
    $result = Invoke-KickstarterCase -InputText "2`n1`n3`n`n" -Mode redirect
    Add-Check "reports installation failure" (Test-OutputMatch $result "Installation failed") $result
    Add-Check "names the redirect as the cause" (Test-OutputMatch $result "Unexpected installer redirect") $result
    Add-Check "does not execute the installer" (-not (Test-OutputMatch $result "installer-ran")) $result
    Add-Check "exits cleanly" ($result.ExitCode -eq 0) $result

    Write-Host "== installer runs but missing command requires restart =="
    $result = Invoke-KickstarterCase -InputText "2`n1`ny`n2`n`n" -Mode missing
    Add-Check "executes the downloaded installer" (Test-OutputMatch $result "installer-ran") $result
    Add-Check "reaches VERIFY" (Test-OutputMatch $result "Verifying") $result
    Add-Check "reports command not visible" (Test-OutputMatch $result "not visible yet") $result
    Add-Check "does not show the handoff prompt" (-not (Test-OutputMatch $result "Copy the handoff prompt")) $result
    Add-Check "exits cleanly" ($result.ExitCode -eq 0) $result

    Write-Host "== successful install reaches HANDOFF and exits cleanly =="
    $result = Invoke-KickstarterCase -InputText "2`n1`ny`nn`n`n" -Mode installed
    Add-Check "executes the downloaded installer" (Test-OutputMatch $result "installer-ran") $result
    Add-Check "reports installation success" (Test-OutputMatch $result "Installation succeeded") $result
    Add-Check "shows the handoff instructions" (Test-OutputMatch $result "Copy the handoff prompt") $result
    Add-Check "exits cleanly" ($result.ExitCode -eq 0) $result

    Write-Host "== empty confirmation defaults to no =="
    $result = Invoke-KickstarterCase -InputText "2`n1`n`n`n" -Mode missing
    Add-Check "does not run the installer" (-not (Test-OutputMatch $result "Running the official installer")) $result
    Add-Check "exits cleanly" ($result.ExitCode -eq 0) $result

    Write-Host "== Kimi selection uses the current installer URL =="
    $result = Invoke-KickstarterCase -InputText "2`n2`n`n`n" -Mode missing
    Add-Check "uses the current Kimi installer" (Test-OutputMatch $result "https://code.kimi.com/kimi-code/install.ps1") $result
    Add-Check "does not use the deprecated Kimi endpoint" (-not (Test-OutputMatch $result "https://code.kimi.com/install.ps1")) $result
    Add-Check "exits cleanly" ($result.ExitCode -eq 0) $result

    Write-Host ""
    Write-Host "passed: $Pass  failed: $Fail"
    if ($Fail -ne 0) { exit 1 }
} finally {
    if (Test-Path -LiteralPath $Work) {
        Remove-Item -LiteralPath $Work -Recurse -Force
    }
}
