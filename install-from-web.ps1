# VSBTek Chocolatey Installer - Web Installer
# This script downloads config files from GitHub and installs applications via Chocolatey
#
# Usage:
#   Interactive mode: irm https://scripts.vsbtek.com/install | iex
#   Direct install:   irm https://scripts.vsbtek.com/install | iex -Preset basic
#
# Author: VSBTek
# Repository: https://github.com/HenryBui21/VSBTek-Chocolatey-Installer

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('basic', 'dev', 'community', 'gaming')]
    [string]$Preset = $null
)

# ============================================================================
# CONFIGURATION - Update these values for your repository
# ============================================================================

# Your GitHub repository URL (raw content)
# Format: https://raw.githubusercontent.com/USERNAME/REPO-NAME/BRANCH
$GitHubRepo = "https://raw.githubusercontent.com/HenryBui21/VSBTek-Chocolatey-Installer/main"

# URL where this script is hosted
$ScriptUrl = "https://scripts.vsbtek.com/install"

# ============================================================================

# Auto-elevate if not running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow

    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& {irm $ScriptUrl | iex"
    if ($Preset) {
        $arguments += " -Preset $Preset"
    }
    $arguments += "}`""

    Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs
    exit
}

# Script configuration
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Color output functions
function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-WarningMsg {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

# Install Chocolatey if needed
function Install-Chocolatey {
    Write-Info "Checking Chocolatey installation..."

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Success "Chocolatey is already installed"
        choco --version
        return $true
    }

    Write-Info "Installing Chocolatey..."

    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Success "Chocolatey installed successfully"
            return $true
        } else {
            throw "Chocolatey installation failed"
        }
    }
    catch {
        Write-ErrorMsg "Failed to install Chocolatey: $($_.Exception.Message)"
        return $false
    }
}

# Download and parse JSON config from web
function Get-WebConfig {
    param([string]$ConfigUrl)

    try {
        Write-Info "Downloading configuration from: $ConfigUrl"
        $jsonContent = (New-Object System.Net.WebClient).DownloadString($ConfigUrl)
        $config = $jsonContent | ConvertFrom-Json

        if (-not $config.applications) {
            Write-ErrorMsg "Invalid configuration format"
            return $null
        }

        Write-Success "Configuration loaded: $($config.applications.Count) applications found"
        return $config.applications
    }
    catch {
        Write-ErrorMsg "Failed to download config: $($_.Exception.Message)"
        return $null
    }
}

# Install a package
function Install-ChocoPackage {
    param(
        [string]$PackageName,
        [string]$Version = $null,
        [array]$Params = @()
    )

    Write-Info "Installing $PackageName..."

    try {
        $chocoArgs = @('install', $PackageName, '-y', '--no-progress')

        if ($Version) {
            $chocoArgs += "--version=$Version"
        }

        if ($Params.Count -gt 0) {
            $chocoArgs += $Params
        }

        $null = & choco @chocoArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Success "$PackageName installed successfully"
            return $true
        } else {
            Write-WarningMsg "$PackageName may have already been installed"
            return $true
        }
    }
    catch {
        Write-ErrorMsg "Failed to install ${PackageName}: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  VSBTek Chocolatey Web Installer" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

# Determine which preset to use
if (-not $Preset) {
    Write-Host "Available Presets:" -ForegroundColor Cyan
    Write-Host "1. Basic Apps (Browsers, Office tools, Utilities)" -ForegroundColor White
    Write-Host "2. Development Tools (IDEs, Git, Docker, etc.)" -ForegroundColor White
    Write-Host "3. Community Apps (Social, Communication)" -ForegroundColor White
    Write-Host "4. Gaming (Game clients, Discord)" -ForegroundColor White
    Write-Host "5. Exit" -ForegroundColor Yellow
    Write-Host ""

    $choice = Read-Host "Enter your choice (1-5)"

    switch ($choice) {
        "1" { $Preset = "basic" }
        "2" { $Preset = "dev" }
        "3" { $Preset = "community" }
        "4" { $Preset = "gaming" }
        "5" {
            Write-Info "Exiting..."
            exit 0
        }
        default {
            Write-ErrorMsg "Invalid choice. Exiting..."
            exit 1
        }
    }
}

# Map preset to config file
$configMap = @{
    "basic" = "basic-apps-config.json"
    "dev" = "dev-tools-config.json"
    "community" = "community-config.json"
    "gaming" = "gaming-config.json"
}

$configFile = $configMap[$Preset]
$configUrl = "$GitHubRepo/$configFile"

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  Installing: $($Preset.ToUpper()) Preset" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

# Install Chocolatey
if (-not (Install-Chocolatey)) {
    Write-ErrorMsg "Cannot proceed without Chocolatey"
    exit 1
}

# Download configuration
$applications = Get-WebConfig -ConfigUrl $configUrl

if (-not $applications -or $applications.Count -eq 0) {
    Write-ErrorMsg "Failed to load applications"
    exit 1
}

# Display applications
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  Applications to Install" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

foreach ($app in $applications) {
    $appName = if ($app.name) { $app.name } else { $app.Name }
    $appVersion = if ($app.version) { $app.version } else { if ($app.Version) { $app.Version } else { $null } }
    $versionText = if ($appVersion) { "v$appVersion" } else { "latest" }
    Write-Host "  * $appName ($versionText)" -ForegroundColor White
}

Write-Host "========================================`n" -ForegroundColor Magenta

# Confirm installation
$confirm = Read-Host "Do you want to proceed with installation? (Y/N)"
if ($confirm -ne 'Y' -and $confirm -ne 'y') {
    Write-Info "Installation cancelled"
    exit 0
}

# Install applications
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  Starting Installation" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

$successCount = 0
$failCount = 0

foreach ($app in $applications) {
    $appName = if ($app.name) { $app.name } else { $app.Name }
    $appVersion = if ($app.version) { $app.version } else { $app.Version }
    $appParams = if ($app.params) { $app.params } else { if ($app.Params) { $app.Params } else { @() } }

    $installed = Install-ChocoPackage -PackageName $appName -Version $appVersion -Params $appParams

    if ($installed) {
        $successCount++
    } else {
        $failCount++
    }

    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Installation Summary" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Preset: $($Preset.ToUpper())" -ForegroundColor White
Write-Host "Total applications: $($applications.Count)" -ForegroundColor White
Write-Host "Successfully installed: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red
Write-Host "========================================`n" -ForegroundColor Magenta

if ($failCount -eq 0) {
    Write-Success "All applications installed successfully!"
    Write-Info "You may need to restart your terminal or run 'refreshenv' to use the new applications"
} else {
    Write-WarningMsg "Some applications failed to install. Please check the logs above."
}

<#
.SYNOPSIS
    Remote web installer for VSBTek Chocolatey presets

.DESCRIPTION
    This script can be executed remotely to install predefined application sets.
    It downloads configuration from scripts.vsbtek.com and installs applications using Chocolatey.

.PARAMETER Preset
    Optional. Preset to install: basic, dev, community, or gaming
    If not specified, an interactive menu will be shown.

.EXAMPLE
    irm https://scripts.vsbtek.com/install-from-web.ps1 | iex
    # Interactive mode - shows menu to select preset

.EXAMPLE
    irm https://scripts.vsbtek.com/install-from-web.ps1 | iex -Preset basic
    # Install basic apps preset directly

.EXAMPLE
    irm https://scripts.vsbtek.com/install-from-web.ps1 | iex -Preset dev
    # Install development tools preset

.NOTES
    Author: VSBTek
    Website: https://scripts.vsbtek.com
    Requires: Administrator privileges, PowerShell 5.1+, Internet connection
#>
