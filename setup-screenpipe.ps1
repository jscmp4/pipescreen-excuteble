param(
    [string]$DataDir = "",
    [switch]$NoStart,
    [switch]$SkipInstall,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor Gray
}

function Write-Warn {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor Yellow
}

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Add-PathIfExists {
    param([string]$Candidate)
    if ((Test-Path $Candidate) -and ($env:Path -notlike "*$Candidate*")) {
        $env:Path = "$Candidate;$env:Path"
        Write-Info "Added to PATH (current session): $Candidate"
    }
}

function Invoke-Action {
    param(
        [string]$Description,
        [ScriptBlock]$Script
    )

    Write-Step $Description
    if ($DryRun) {
        Write-Info "DryRun: skipped"
        return
    }
    & $Script
}

function Install-NodeWithWinget {
    if (-not (Test-Command "winget")) {
        Write-Warn "winget not found, cannot auto-install Node.js."
        return $false
    }

    Invoke-Action -Description "Install Node.js LTS (required for npx)" -Script {
        winget install --id OpenJS.NodeJS.LTS --exact --silent --accept-package-agreements --accept-source-agreements
    }

    Add-PathIfExists "$env:ProgramFiles\nodejs"
    return (Test-Command "npx")
}

function Get-ScreenpipeRunner {
    $dataDirArgs = @()
    $dataDirSuffix = ""
    if ($DataDir -ne "") {
        $dataDirArgs = @("--data-dir", $DataDir)
        $dataDirSuffix = " --data-dir `"$DataDir`""
    }

    if (Test-Command "screenpipe") {
        return [pscustomobject]@{
            Name        = "screenpipe"
            FilePath    = "screenpipe"
            VersionArgs = @("--version")
            StartArgs   = @("record") + $dataDirArgs
            ManualCmd   = "screenpipe record$dataDirSuffix"
        }
    }

    if (Test-Command "npx") {
        return [pscustomobject]@{
            Name        = "npx screenpipe@latest"
            FilePath    = "npx"
            VersionArgs = @("--yes", "screenpipe@latest", "--version")
            StartArgs   = @("--yes", "screenpipe@latest", "record") + $dataDirArgs
            ManualCmd   = "npx --yes screenpipe@latest record$dataDirSuffix"
        }
    }

    return $null
}

function Try-GetVersion {
    param($Runner)
    try {
        $ver = & $Runner.FilePath @($Runner.VersionArgs) 2>$null
        if ($LASTEXITCODE -eq 0 -and $ver) {
            return ($ver | Select-Object -First 1)
        }
    }
    catch {
        return $null
    }
    return $null
}

function Wait-ForHealth {
    param(
        [string]$Url = "http://localhost:3030/health",
        [int]$Retries = 60,
        [int]$SleepSeconds = 3
    )

    for ($i = 1; $i -le $Retries; $i++) {
        try {
            [void](Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 2)
            Write-Info "Health check OK: $Url"
            return $true
        }
        catch {
            Write-Info "Waiting for API... attempt $i/$Retries"
            Start-Sleep -Seconds $SleepSeconds
        }
    }
    return $false
}

Write-Host "Screenpipe local bootstrap (Windows)" -ForegroundColor Green
Write-Info "Mode: local self-hosted CLI"
Write-Info "NoStart: $NoStart"
Write-Info "SkipInstall: $SkipInstall"
Write-Info "DryRun: $DryRun"
if ($DataDir -ne "") {
    Write-Info "DataDir: $DataDir"
}

Add-PathIfExists "$env:ProgramFiles\nodejs"
Add-PathIfExists "$env:USERPROFILE\.screenpipe\bin"
Add-PathIfExists "$env:LOCALAPPDATA\screenpipe\bin"
Add-PathIfExists "$env:USERPROFILE\.cargo\bin"

if (-not $SkipInstall) {
    if (Test-Command "screenpipe") {
        Write-Step "Using existing screenpipe binary"
        Write-Info "Found: screenpipe"
    }
    elseif (Test-Command "npx") {
        Write-Step "Using npx runner"
        Write-Info "Will run screenpipe via: npx --yes screenpipe@latest ..."
    }
    else {
        Write-Step "No screenpipe/npx found"
        $ok = Install-NodeWithWinget
        if (-not $ok -and -not $DryRun) {
            Write-Warn "Node.js installation did not make 'npx' available in this session."
            Write-Warn "Open a new terminal and run:"
            Write-Host "  npx --yes screenpipe@latest record" -ForegroundColor White
            exit 1
        }
    }
}
else {
    Write-Step "Skip install"
    Write-Info "Using existing local installation/runtime."
}

if ($DryRun) {
    Write-Step "DryRun finished"
    Write-Info "Then run for real:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\\setup-screenpipe.ps1" -ForegroundColor White
    exit 0
}

$runner = Get-ScreenpipeRunner
if ($null -eq $runner) {
    Write-Warn "Could not find 'screenpipe' or 'npx'."
    Write-Warn "Install Node.js LTS, then run:"
    Write-Host "  npx --yes screenpipe@latest record" -ForegroundColor White
    exit 1
}

Write-Step "Runner detected"
Write-Info "Runner: $($runner.Name)"
$version = Try-GetVersion -Runner $runner
if ($version) {
    Write-Info "Version: $version"
}
else {
    Write-Info "Version check skipped/failed (can still continue)."
}

if (-not $NoStart) {
    Invoke-Action -Description "Start local recording service" -Script {
        $proc = Start-Process -FilePath $runner.FilePath -ArgumentList $runner.StartArgs -PassThru
        Write-Info "Started PID: $($proc.Id)"
    }

    Write-Step "Wait for local API"
    $healthy = Wait-ForHealth
    if (-not $healthy) {
        Write-Warn "Local API did not become healthy in time."
        Write-Warn "Run in foreground to inspect logs:"
        Write-Host "  $($runner.ManualCmd)" -ForegroundColor White
        exit 1
    }

    Write-Step "Done"
    Write-Host "Local API: http://localhost:3030" -ForegroundColor Green
    Write-Info "Quick test:"
    Write-Host '  Invoke-RestMethod "http://localhost:3030/search?limit=5"' -ForegroundColor White
}
else {
    Write-Step "Done"
    Write-Info "Run manually when ready:"
    Write-Host "  $($runner.ManualCmd)" -ForegroundColor White
}
