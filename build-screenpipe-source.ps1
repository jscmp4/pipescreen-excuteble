param(
    [string]$RepoDir = (Join-Path $PSScriptRoot "screenpipe-src"),
    [switch]$InstallDeps,
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

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-WithWinget {
    param(
        [string]$PackageId,
        [string]$FriendlyName,
        [string]$ExtraArgs = ""
    )

    if (-not (Test-Command "winget")) {
        Write-Warn "winget not found. Please install manually: $FriendlyName"
        return
    }

    $isInstalled = $false
    try {
        $list = winget list --id $PackageId --exact --accept-source-agreements 2>$null
        if ($list -match $PackageId) {
            $isInstalled = $true
        }
    }
    catch {
        $isInstalled = $false
    }

    if ($isInstalled) {
        Write-Info "$FriendlyName already installed."
        return
    }

    Invoke-Action -Description "Install $FriendlyName ($PackageId)" -Script {
        $baseArgs = @(
            "install",
            "--id", $PackageId,
            "--exact",
            "--silent",
            "--accept-package-agreements",
            "--accept-source-agreements"
        )
        if ($ExtraArgs) {
            $baseArgs += @("--override", $ExtraArgs)
        }
        winget @baseArgs
    }
}

Write-Host "Screenpipe source build (Windows)" -ForegroundColor Green
Write-Info "RepoDir: $RepoDir"
Write-Info "InstallDeps: $InstallDeps"
Write-Info "DryRun: $DryRun"

if ($InstallDeps) {
    Write-Step "Install build dependencies (winget)"
    Install-WithWinget -PackageId "Git.Git" -FriendlyName "Git"
    Install-WithWinget -PackageId "Rustlang.Rustup" -FriendlyName "Rustup / Rust"
    Install-WithWinget -PackageId "Oven-sh.Bun" -FriendlyName "Bun"
    Install-WithWinget -PackageId "CMake.CMake" -FriendlyName "CMake"
    Install-WithWinget -PackageId "LLVM.LLVM" -FriendlyName "LLVM/Clang"
    Install-WithWinget -PackageId "Microsoft.VisualStudio.2022.BuildTools" -FriendlyName "VS 2022 Build Tools (C++)" -ExtraArgs "--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
}

if ($DryRun) {
    Write-Step "DryRun finished"
    Write-Info "Then run for real:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\\build-screenpipe-source.ps1 -InstallDeps" -ForegroundColor White
    exit 0
}

if (-not (Test-Command "git")) {
    Write-Warn "git not found. Install Git first."
    exit 1
}

if (-not (Test-Path $RepoDir)) {
    Invoke-Action -Description "Clone screenpipe repository" -Script {
        git clone https://github.com/screenpipe/screenpipe $RepoDir
    }
}
else {
    Invoke-Action -Description "Update repository (git pull --ff-only)" -Script {
        git -C $RepoDir pull --ff-only
    }
}

if (-not (Test-Command "cargo")) {
    Write-Warn "cargo not found. Please install Rust toolchain first."
    exit 1
}

if (-not (Test-Command "bun")) {
    Write-Warn "bun not found. Please install Bun first."
    exit 1
}

Invoke-Action -Description "Build Rust binaries (release)" -Script {
    Push-Location $RepoDir
    try {
        cargo build --release
    }
    finally {
        Pop-Location
    }
}

$tauriDir = Join-Path $RepoDir "apps\screenpipe-app-tauri"
if (-not (Test-Path $tauriDir)) {
    Write-Warn "Tauri app directory not found: $tauriDir"
    exit 1
}

Invoke-Action -Description "Install Tauri app dependencies (bun install)" -Script {
    Push-Location $tauriDir
    try {
        bun install
    }
    finally {
        Pop-Location
    }
}

Invoke-Action -Description "Build desktop package (bun tauri build)" -Script {
    Push-Location $tauriDir
    try {
        bun tauri build
    }
    finally {
        Pop-Location
    }
}

$cliExe = Join-Path $RepoDir "target\release\screenpipe.exe"
$bundleDir = Join-Path $tauriDir "src-tauri\target\release\bundle"

Write-Step "Build complete"
if (Test-Path $cliExe) {
    Write-Info "CLI binary: $cliExe"
}
else {
    Write-Warn "CLI binary path not found yet: $cliExe"
}
if (Test-Path $bundleDir) {
    Write-Info "Desktop bundle dir: $bundleDir"
}
else {
    Write-Warn "Bundle path not found yet: $bundleDir"
}
