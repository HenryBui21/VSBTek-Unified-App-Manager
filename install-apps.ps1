# Chocolatey Applications Installer Script (Smart Mode)
# This script can be executed remotely using: irm <url> | iex
# Or with JSON config: .\install-apps.ps1 -ConfigFile "apps-config.json"
# Author: VSBTek
# Description: Automates installation of applications via Chocolatey package manager

#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = $null
)

# Script configuration
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✓ $Message" -Color Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-ColorOutput "✗ $Message" -Color Red
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "→ $Message" -Color Cyan
}

function Write-WarningMsg {
    param([string]$Message)
    Write-ColorOutput "⚠ $Message" -Color Yellow
}

# Check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Install Chocolatey if not already installed
function Install-Chocolatey {
    Write-Info "Checking Chocolatey installation..."

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Success "Chocolatey is already installed"
        choco --version
        return $true
    }

    Write-Info "Chocolatey not found. Installing..."

    try {
        # Set security protocol to TLS 1.2
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

        # Download and install Chocolatey
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Success "Chocolatey installed successfully"
            choco --version
            return $true
        } else {
            throw "Chocolatey installation completed but command not found"
        }
    }
    catch {
        Write-ErrorMsg "Failed to install Chocolatey: $($_.Exception.Message)"
        return $false
    }
}

# Load configuration from JSON file
function Get-ApplicationConfig {
    param(
        [string]$ConfigPath
    )

    Write-Info "Loading configuration from $ConfigPath..."

    if (-not (Test-Path $ConfigPath)) {
        Write-ErrorMsg "Configuration file not found: $ConfigPath"
        return $null
    }

    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

        if (-not $config.applications) {
            Write-ErrorMsg "Invalid configuration: 'applications' property not found"
            return $null
        }

        Write-Success "Configuration loaded: $($config.applications.Count) applications found"
        return $config.applications
    }
    catch {
        Write-ErrorMsg "Failed to load configuration: $($_.Exception.Message)"
        return $null
    }
}

# Install a single package
function Install-ChocoPackage {
    param(
        [string]$PackageName,
        [string]$Version = $null,
        [string[]]$Params = @()
    )

    Write-Info "Installing $PackageName..."

    try {
        $chocoArgs = @('install', $PackageName, '-y', '--no-progress')

        if ($Version) {
            $chocoArgs += "--version=$Version"
            Write-Info "  Version: $Version"
        }

        if ($Params.Count -gt 0) {
            $chocoArgs += $Params
            Write-Info "  Parameters: $($Params -join ' ')"
        }

        $null = & choco @chocoArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Success "$PackageName installed successfully"
            return $true
        } else {
            Write-WarningMsg "$PackageName may have already been installed or encountered a non-critical issue"
            return $true
        }
    }
    catch {
        Write-ErrorMsg "Failed to install ${PackageName}: $($_.Exception.Message)"
        return $false
    }
}

# Main installation function
function Install-Applications {
    param(
        [Parameter(Mandatory=$false)]
        [array]$Applications = @()
    )

    # Determine mode and load applications
    $mode = "Hardcoded"

    if ($Applications.Count -eq 0) {
        # Default application list (for remote execution or no config)
        $Applications = @(
            @{ name = 'googlechrome'; version = $null; params = @() },
            @{ name = 'firefox'; version = $null; params = @() },
            @{ name = 'vscode'; version = $null; params = @() },
            @{ name = '7zip'; version = $null; params = @() },
            @{ name = 'git'; version = $null; params = @('--params', '/GitAndUnixToolsOnPath') },
            @{ name = 'notepadplusplus'; version = $null; params = @() }
        )
    } else {
        $mode = "JSON Config"
    }

    Write-ColorOutput "`n========================================" -Color Magenta
    Write-ColorOutput "  Chocolatey Application Installer" -Color Magenta
    Write-ColorOutput "  Mode: $mode" -Color Magenta
    Write-ColorOutput "========================================`n" -Color Magenta

    # Check administrator privileges
    if (-not (Test-Administrator)) {
        Write-ErrorMsg "This script requires Administrator privileges"
        Write-Info "Please run PowerShell as Administrator and try again"
        exit 1
    }

    Write-Success "Running with Administrator privileges"

    # Install Chocolatey
    if (-not (Install-Chocolatey)) {
        Write-ErrorMsg "Cannot proceed without Chocolatey"
        exit 1
    }

    # Display application list
    Write-ColorOutput "`n========================================" -Color Magenta
    Write-ColorOutput "  Applications to Install" -Color Magenta
    Write-ColorOutput "========================================" -Color Magenta

    foreach ($app in $Applications) {
        $appName = if ($app.name) { $app.name } else { $app.Name }
        $appVersion = if ($app.version) { $app.version } else { if ($app.Version) { $app.Version } else { $null } }
        $versionText = if ($appVersion) { "v$appVersion" } else { "latest" }
        Write-ColorOutput "  • $appName ($versionText)" -Color White
    }

    Write-ColorOutput "========================================`n" -Color Magenta

    # Install applications
    Write-ColorOutput "========================================" -Color Magenta
    Write-ColorOutput "  Starting Installation" -Color Magenta
    Write-ColorOutput "========================================`n" -Color Magenta

    $successCount = 0
    $failCount = 0

    foreach ($app in $Applications) {
        # Support both lowercase (JSON) and uppercase (hashtable) property names
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
    Write-ColorOutput "========================================" -Color Magenta
    Write-ColorOutput "  Installation Summary" -Color Magenta
    Write-ColorOutput "========================================" -Color Magenta
    if ($mode -eq "JSON Config") {
        Write-ColorOutput "Configuration: $ConfigFile" -Color White
    }
    Write-ColorOutput "Total applications: $($Applications.Count)" -Color White
    Write-ColorOutput "Successfully installed: $successCount" -Color Green
    Write-ColorOutput "Failed: $failCount" -Color Red
    Write-ColorOutput "========================================`n" -Color Magenta

    if ($failCount -eq 0) {
        Write-Success "All applications installed successfully!"
        Write-Info "You may need to restart your terminal or run 'refreshenv' to use the new applications"
    } else {
        Write-WarningMsg "Some applications failed to install. Please check the logs above."
    }
}

# Main execution logic
function Main {
    if ($ConfigFile) {
        # Config mode: Load from JSON
        $configPath = $ConfigFile
        if (-not [System.IO.Path]::IsPathRooted($configPath)) {
            $configPath = Join-Path $PSScriptRoot $ConfigFile
        }

        $applications = Get-ApplicationConfig -ConfigPath $configPath

        if (-not $applications -or $applications.Count -eq 0) {
            Write-ErrorMsg "No applications to install"
            exit 1
        }

        Install-Applications -Applications $applications
    } else {
        # Hardcoded mode: Use default list
        Install-Applications
    }
}

# Execute main function
Main

<#
.SYNOPSIS
    Installs applications using Chocolatey package manager

.DESCRIPTION
    This script automates the installation of applications via Chocolatey.
    It can work in two modes:
    1. Hardcoded mode (default) - Uses built-in application list
    2. JSON Config mode - Loads applications from a JSON file

.PARAMETER ConfigFile
    Optional. Path to JSON configuration file containing application list.
    If not specified, uses built-in default application list.

.EXAMPLE
    .\install-apps.ps1
    # Installs default applications (Chrome, Firefox, VSCode, 7-Zip, Git, Notepad++)

.EXAMPLE
    .\install-apps.ps1 -ConfigFile "basic-apps-config.json"
    # Installs applications from basic-apps-config.json

.EXAMPLE
    .\install-apps.ps1 -ConfigFile "dev-tools-config.json"
    # Installs developer tools

.EXAMPLE
    irm https://your-url/install-apps.ps1 | iex
    # Remote execution with default applications

.NOTES
    Author: VSBTek
    Requires: Administrator privileges, PowerShell 5.1+, Internet connection
#>
