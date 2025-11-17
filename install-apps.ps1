# VSBTek Chocolatey Manager - Unified Script
# Combines installation, management, and remote execution capabilities
# Author: VSBTek
# Repository: https://github.com/HenryBui21/VSBTek-Chocolatey-Installer
#
# Usage:
#   Local interactive:     .\install-apps.ps1
#   Local with preset:     .\install-apps.ps1 -Preset basic
#   Local with config:     .\install-apps.ps1 -ConfigFile "basic-apps-config.json"
#   Management mode:       .\install-apps.ps1 -Action Update -Preset dev
#   Remote (download):     irm URL -OutFile install-apps.ps1; .\install-apps.ps1
#   Remote (one-liner):    irm URL -OutFile "$env:TEMP\install-apps.ps1"; & "$env:TEMP\install-apps.ps1"

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = $null,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Install', 'Update', 'Uninstall', 'List', 'Upgrade')]
    [string]$Action = $null,

    [Parameter(Mandatory=$false)]
    [ValidateSet('basic', 'dev', 'community', 'gaming')]
    [string]$Preset = $null,

    [Parameter(Mandatory=$false)]
    [ValidateSet('local', 'remote')]
    [string]$Mode = 'local',

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$KeepWindowOpen
)

# ============================================================================
# CONFIGURATION
# ============================================================================

# GitHub repository URL for remote mode
$GitHubRepo = "https://raw.githubusercontent.com/HenryBui21/VSBTek-Chocolatey-Installer/main"
$ScriptUrl = "https://scripts.vsbtek.com/install-apps.ps1"

# Script configuration
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ============================================================================
# AUTO-ELEVATION
# ============================================================================

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow

    # Determine if running from file or from web
    $runningFromFile = $null -ne $MyInvocation.MyCommand.Path -and $MyInvocation.MyCommand.Path -ne ''

    if ($runningFromFile) {
        # Running from a file
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($ConfigFile) { $arguments += " -ConfigFile `"$ConfigFile`"" }
        if ($Action) { $arguments += " -Action `"$Action`"" }
        if ($Preset) { $arguments += " -Preset `"$Preset`"" }
        if ($Mode) { $arguments += " -Mode `"$Mode`"" }
        if ($Force) { $arguments += " -Force" }
        $arguments += " -KeepWindowOpen"
    } else {
        # Running from web (iex & scriptblock)
        $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"iex \`"& { `$(irm $ScriptUrl) }"
        if ($Preset) { $arguments += " -Preset '$Preset'" }
        if ($Mode) { $arguments += " -Mode '$Mode'" }
        if ($Action) { $arguments += " -Action '$Action'" }
        if ($Force) { $arguments += " -Force" }
        $arguments += " -KeepWindowOpen\`"`""
    }

    Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs
    exit
}

# ============================================================================
# HELPER FUNCTIONS - OUTPUT
# ============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "[OK] $Message" -Color Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" -Color Red
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "[INFO] $Message" -Color Cyan
}

function Write-WarningMsg {
    param([string]$Message)
    Write-ColorOutput "[WARNING] $Message" -Color Yellow
}

# ============================================================================
# HELPER FUNCTIONS - ENVIRONMENT
# ============================================================================

function Update-SessionEnvironment {
    Write-Info "Refreshing environment variables..."

    $locations = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
                 'HKCU:\Environment'

    $locations | ForEach-Object {
        $k = Get-Item $_
        $k.GetValueNames() | ForEach-Object {
            $name = $_
            $value = $k.GetValue($name)
            if ($name -eq 'Path') {
                $env:Path = $value
            } else {
                Set-Item -Path "Env:\$name" -Value $value
            }
        }
    }

    # Append chocolatey to path if not already there
    $chocoPath = "$env:ALLUSERSPROFILE\chocolatey\bin"
    if ($env:Path -notlike "*$chocoPath*") {
        $env:Path = "$env:Path;$chocoPath"
    }
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================================
# HELPER FUNCTIONS - CHOCOLATEY
# ============================================================================

function Install-Chocolatey {
    Write-Info "Checking Chocolatey installation..."

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Success "Chocolatey is already installed"
        choco --version
        return $true
    }

    Write-Info "Chocolatey not found. Installing..."

    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

        Update-SessionEnvironment

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

# ============================================================================
# HELPER FUNCTIONS - CONFIGURATION
# ============================================================================

function Get-ApplicationConfig {
    param([string]$ConfigPath)

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

# ============================================================================
# HELPER FUNCTIONS - PACKAGE DETECTION
# ============================================================================

function Test-PackageInstalled {
    param([string]$PackageName)

    try {
        # First check via Chocolatey
        $result = & choco list --local-only --exact $PackageName 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match $PackageName) {
            return $true
        }

        # Check Windows installed programs registry
        $uninstallPaths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        # Map package names to common display names
        $nameMap = @{
            'googlechrome' = @('Google Chrome', 'Chrome')
            'microsoft-edge' = @('Microsoft Edge', 'Edge')
            'firefox' = @('Mozilla Firefox', 'Firefox')
            'brave' = @('Brave', 'Brave Browser')
            'notepadplusplus' = @('Notepad++')
            'foxitreader' = @('Foxit Reader', 'Foxit PDF Reader')
            'ultraviewer' = @('UltraViewer')
            'treesizefree' = @('TreeSize Free')
            '7zip' = @('7-Zip')
            'winrar' = @('WinRAR')
            'vlc' = @('VLC media player', 'VLC')
            'powertoys' = @('PowerToys', 'Microsoft PowerToys')
            'unikey' = @('UniKey')
            'revo-uninstaller' = @('Revo Uninstaller')
            'winaero-tweaker' = @('Winaero Tweaker')
            'vscode' = @('Microsoft Visual Studio Code', 'Visual Studio Code')
            'git' = @('Git', 'Git version')
            'python' = @('Python')
            'nodejs-lts' = @('Node.js')
            'docker-desktop' = @('Docker Desktop')
        }

        $searchNames = if ($nameMap.ContainsKey($PackageName.ToLower())) {
            $nameMap[$PackageName.ToLower()]
        } else {
            @($PackageName)
        }

        foreach ($path in $uninstallPaths) {
            $installed = Get-ItemProperty $path -ErrorAction SilentlyContinue |
                Where-Object {
                    $displayName = $_.DisplayName
                    if ($displayName) {
                        foreach ($name in $searchNames) {
                            if ($displayName -like "*$name*") {
                                return $true
                            }
                        }
                    }
                    $false
                }

            if ($installed) {
                return $true
            }
        }

        return $false
    }
    catch {
        return $false
    }
}

# ============================================================================
# HELPER FUNCTIONS - PACKAGE OPERATIONS
# ============================================================================

function Install-ChocoPackage {
    param(
        [string]$PackageName,
        [string]$Version = $null,
        [array]$Params = @(),
        [bool]$ForceInstall = $false
    )

    Write-Info "Installing $PackageName..."

    try {
        $chocoArgs = @('install', $PackageName, '-y', '--no-progress')

        if ($Version) {
            $chocoArgs += "--version=$Version"
            Write-Info "  Version: $Version"
        }

        if ($ForceInstall) {
            $chocoArgs += '--force'
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

function Update-ChocoPackage {
    param(
        [string]$PackageName,
        [string]$Version = $null
    )

    Write-Info "Updating $PackageName..."

    try {
        if (-not (Test-PackageInstalled -PackageName $PackageName)) {
            Write-WarningMsg "$PackageName is not installed, skipping update"
            return $false
        }

        $chocoArgs = @('upgrade', $PackageName, '-y', '--no-progress')

        if ($Version) {
            $chocoArgs += "--version=$Version"
            Write-Info "  Target version: $Version"
        }

        $null = & choco @chocoArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Success "$PackageName updated successfully"
            return $true
        } else {
            Write-WarningMsg "$PackageName may already be at the latest version"
            return $true
        }
    }
    catch {
        Write-ErrorMsg "Failed to update ${PackageName}: $($_.Exception.Message)"
        return $false
    }
}

function Uninstall-ChocoPackage {
    param(
        [string]$PackageName,
        [bool]$ForceUninstall = $false
    )

    Write-Info "Uninstalling $PackageName..."

    try {
        if (-not (Test-PackageInstalled -PackageName $PackageName)) {
            Write-WarningMsg "$PackageName is not installed, skipping uninstall"
            return $false
        }

        $chocoArgs = @('uninstall', $PackageName, '-y', '--no-progress')

        if ($ForceUninstall) {
            $chocoArgs += '--force'
        }

        $null = & choco @chocoArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Success "$PackageName uninstalled successfully"
            return $true
        } else {
            Write-WarningMsg "$PackageName uninstallation encountered issues"
            return $false
        }
    }
    catch {
        Write-ErrorMsg "Failed to uninstall ${PackageName}: $($_.Exception.Message)"
        return $false
    }
}

function Show-InstalledPackages {
    param([array]$Applications)

    Write-ColorOutput "`n========================================" -Color Magenta
    Write-ColorOutput "  Installed Applications Status" -Color Magenta
    Write-ColorOutput "========================================`n" -Color Magenta

    foreach ($app in $Applications) {
        $appName = if ($app.name) { $app.name } else { $app.Name }
        $isInstalled = Test-PackageInstalled -PackageName $appName

        if ($isInstalled) {
            Write-ColorOutput "  [OK] $appName" -Color Green

            try {
                $versionInfo = & choco list --local-only --exact $appName 2>&1 | Select-String -Pattern "$appName\s+([\d\.]+)"
                if ($versionInfo) {
                    $installedVersion = $versionInfo.Matches.Groups[1].Value
                    Write-ColorOutput "    Installed: v$installedVersion" -Color Gray

                    $appVersion = if ($app.version) { $app.version } else { $app.Version }
                    if ($appVersion -and $appVersion -ne $installedVersion) {
                        Write-ColorOutput "    Config: v$appVersion" -Color Yellow
                    }
                }
            }
            catch {
                # Ignore version check errors
            }
        } else {
            Write-ColorOutput "  [X] $appName" -Color Red
            Write-ColorOutput "    Not installed" -Color Gray
        }

        Write-Host ""
    }
}

function Invoke-UpgradeAll {
    Write-Info "Upgrading all installed Chocolatey packages..."

    try {
        $null = & choco upgrade all -y --no-progress 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Success "All packages upgraded successfully"
            return $true
        } else {
            Write-WarningMsg "Some packages may have encountered issues during upgrade"
            return $false
        }
    }
    catch {
        Write-ErrorMsg "Failed to upgrade packages: $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
# MENU FUNCTIONS
# ============================================================================

function Show-MainMenu {
    Write-ColorOutput "`n========================================" -Color Cyan
    Write-ColorOutput "  VSBTek Chocolatey Manager" -Color Cyan
    Write-ColorOutput "========================================" -Color Cyan
    Write-Host ""
    Write-Host "  1. Install applications (from preset)"
    Write-Host "  2. Update applications"
    Write-Host "  3. Uninstall applications"
    Write-Host "  4. List installed applications"
    Write-Host "  5. Upgrade all Chocolatey packages"
    Write-Host "  6. Exit"
    Write-Host ""

    $choice = Read-Host "Enter your choice (1-6)"

    switch ($choice) {
        '1' { return 'Install' }
        '2' { return 'Update' }
        '3' { return 'Uninstall' }
        '4' { return 'List' }
        '5' { return 'Upgrade' }
        '6' {
            Write-Info "Exiting..."
            exit 0
        }
        default {
            Write-ErrorMsg "Invalid choice. Please try again."
            return Show-MainMenu
        }
    }
}

function Show-PresetMenu {
    Write-ColorOutput "`n========================================" -Color Cyan
    Write-ColorOutput "  Select Application Preset" -Color Cyan
    Write-ColorOutput "========================================" -Color Cyan
    Write-Host ""
    Write-Host "  1. Basic Apps (18 apps) - Browsers, utilities, tools"
    Write-Host "  2. Dev Tools (15 apps) - IDEs, Git, Docker, etc."
    Write-Host "  3. Community (5 apps) - Teams, Zoom, Slack, etc."
    Write-Host "  4. Gaming (10 apps) - Steam, Discord, OBS, etc."
    Write-Host "  5. Cancel"
    Write-Host ""

    $choice = Read-Host "Enter your choice (1-5)"

    switch ($choice) {
        '1' { return 'basic' }
        '2' { return 'dev' }
        '3' { return 'community' }
        '4' { return 'gaming' }
        '5' {
            Write-Info "Cancelled"
            exit 0
        }
        default {
            Write-ErrorMsg "Invalid choice. Please try again."
            return Show-PresetMenu
        }
    }
}

# ============================================================================
# MAIN EXECUTION LOGIC
# ============================================================================

function Invoke-InstallMode {
    param([array]$Applications)

    Write-ColorOutput "`n========================================" -Color Magenta
    Write-ColorOutput "  Installing Applications" -Color Magenta
    Write-ColorOutput "========================================`n" -Color Magenta

    $successCount = 0
    $failCount = 0

    foreach ($app in $Applications) {
        $appName = if ($app.name) { $app.name } else { $app.Name }
        $appVersion = if ($app.version) { $app.version } else { $app.Version }
        $appParams = if ($app.params) { $app.params } else { if ($app.Params) { $app.Params } else { @() } }

        $installed = Install-ChocoPackage -PackageName $appName -Version $appVersion -Params $appParams -ForceInstall $Force

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
    Write-ColorOutput "Total: $($Applications.Count) | Success: $successCount | Failed: $failCount" -Color White
    Write-ColorOutput "========================================`n" -Color Magenta

    if ($failCount -eq 0) {
        Write-Success "All applications installed successfully!"
        Write-Info "You may need to restart your terminal or run 'refreshenv' to use the new applications"
    } else {
        Write-WarningMsg "Some applications failed to install. Please check the logs above."
    }
}

function Invoke-UpdateMode {
    param([array]$Applications)

    Write-ColorOutput "`n========================================" -Color Magenta
    Write-ColorOutput "  Updating Applications" -Color Magenta
    Write-ColorOutput "========================================`n" -Color Magenta

    $successCount = 0
    $failCount = 0

    foreach ($app in $Applications) {
        $appName = if ($app.name) { $app.name } else { $app.Name }
        $appVersion = if ($app.version) { $app.version } else { $app.Version }

        $updated = Update-ChocoPackage -PackageName $appName -Version $appVersion

        if ($updated) {
            $successCount++
        } else {
            $failCount++
        }

        Write-Host ""
    }

    # Summary
    Write-ColorOutput "========================================" -Color Magenta
    Write-ColorOutput "  Update Summary" -Color Magenta
    Write-ColorOutput "========================================" -Color Magenta
    Write-ColorOutput "Total: $($Applications.Count) | Success: $successCount | Failed: $failCount" -Color White
    Write-ColorOutput "========================================`n" -Color Magenta
}

function Invoke-UninstallMode {
    param([array]$Applications)

    Write-ColorOutput "`n========================================" -Color Magenta
    Write-ColorOutput "  Uninstalling Applications" -Color Magenta
    Write-ColorOutput "========================================`n" -Color Magenta

    Write-WarningMsg "You are about to uninstall $($Applications.Count) applications!"
    $confirm = Read-Host "Type 'YES' to continue"

    if ($confirm -ne 'YES') {
        Write-Info "Uninstall cancelled"
        exit 0
    }

    $successCount = 0
    $failCount = 0

    foreach ($app in $Applications) {
        $appName = if ($app.name) { $app.name } else { $app.Name }
        $uninstalled = Uninstall-ChocoPackage -PackageName $appName -ForceUninstall $Force

        if ($uninstalled) {
            $successCount++
        } else {
            $failCount++
        }

        Write-Host ""
    }

    # Summary
    Write-ColorOutput "========================================" -Color Magenta
    Write-ColorOutput "  Uninstall Summary" -Color Magenta
    Write-ColorOutput "========================================" -Color Magenta
    Write-ColorOutput "Total: $($Applications.Count) | Success: $successCount | Failed: $failCount" -Color White
    Write-ColorOutput "========================================`n" -Color Magenta
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

Write-ColorOutput "`n========================================" -Color Magenta
Write-ColorOutput "  VSBTek Chocolatey Manager" -Color Magenta
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

# Determine action
if (-not $Action) {
    $Action = Show-MainMenu
}

Write-ColorOutput "`nSelected Action: $Action" -Color Yellow

# Handle Upgrade All (doesn't need config)
if ($Action -eq 'Upgrade') {
    Write-Info "Upgrading all installed Chocolatey packages..."
    Invoke-UpgradeAll

    if ($KeepWindowOpen) {
        Write-Host ""
        Read-Host "Press Enter to close this window"
    }
    exit 0
}

# Determine preset/config
$applications = $null

if ($Preset) {
    # Preset specified - use it
    $configMap = @{
        "basic" = "basic-apps-config.json"
        "dev" = "dev-tools-config.json"
        "community" = "community-config.json"
        "gaming" = "gaming-config.json"
    }

    $configFile = $configMap[$Preset]

    if ($Mode -eq 'remote') {
        # Download from GitHub
        $configUrl = "$GitHubRepo/$configFile"
        $applications = Get-WebConfig -ConfigUrl $configUrl
    } else {
        # Load from local file
        $configPath = Join-Path $PSScriptRoot $configFile
        $applications = Get-ApplicationConfig -ConfigPath $configPath
    }
} elseif ($ConfigFile) {
    # Config file specified
    $configPath = $ConfigFile
    if (-not [System.IO.Path]::IsPathRooted($configPath)) {
        $configPath = Join-Path $PSScriptRoot $ConfigFile
    }
    $applications = Get-ApplicationConfig -ConfigPath $configPath
} else {
    # Show preset menu
    $selectedPreset = Show-PresetMenu

    $configMap = @{
        "basic" = "basic-apps-config.json"
        "dev" = "dev-tools-config.json"
        "community" = "community-config.json"
        "gaming" = "gaming-config.json"
    }

    $configFile = $configMap[$selectedPreset]

    if ($Mode -eq 'remote') {
        $configUrl = "$GitHubRepo/$configFile"
        $applications = Get-WebConfig -ConfigUrl $configUrl
    } else {
        $configPath = Join-Path $PSScriptRoot $configFile
        $applications = Get-ApplicationConfig -ConfigPath $configPath
    }
}

# Validate applications loaded
if (-not $applications -or $applications.Count -eq 0) {
    Write-ErrorMsg "No applications found in configuration"
    exit 1
}

# Display applications to process
Write-ColorOutput "`n========================================" -Color Magenta
Write-ColorOutput "  Applications to Process: $($applications.Count)" -Color Magenta
Write-ColorOutput "========================================" -Color Magenta

foreach ($app in $applications) {
    $appName = if ($app.name) { $app.name } else { $app.Name }
    $appVersion = if ($app.version) { $app.version } else { if ($app.Version) { $app.Version } else { $null } }
    $versionText = if ($appVersion) { "v$appVersion" } else { "latest" }
    Write-ColorOutput "  * $appName ($versionText)" -Color White
}

Write-ColorOutput "========================================`n" -Color Magenta

# Confirm before proceeding
$confirm = Read-Host "Do you want to proceed? (Y/N)"
if ($confirm -ne 'Y' -and $confirm -ne 'y') {
    Write-Info "Operation cancelled"
    exit 0
}

# Execute selected action
switch ($Action) {
    'Install' {
        Invoke-InstallMode -Applications $applications
    }
    'Update' {
        Invoke-UpdateMode -Applications $applications
    }
    'Uninstall' {
        Invoke-UninstallMode -Applications $applications
    }
    'List' {
        Show-InstalledPackages -Applications $applications
    }
}

Write-Success "Operation completed!"

# Keep window open if requested
if ($KeepWindowOpen) {
    Write-Host ""
    Read-Host "Press Enter to close this window"
}

<#
.SYNOPSIS
    Unified Chocolatey package manager for installation and management

.DESCRIPTION
    This script combines local installation, remote installation, and package management
    capabilities into a single unified tool. It supports interactive menus and command-line
    parameters for automation.

.PARAMETER ConfigFile
    Path to JSON configuration file containing application list

.PARAMETER Action
    Management action: Install, Update, Uninstall, List, or Upgrade

.PARAMETER Preset
    Predefined application preset: basic, dev, community, or gaming

.PARAMETER Mode
    Execution mode: local (use local configs) or remote (download from GitHub)

.PARAMETER Force
    Force installation or uninstallation

.PARAMETER KeepWindowOpen
    Keep PowerShell window open after completion (useful for elevated sessions)

.EXAMPLE
    .\install-apps.ps1
    Interactive mode with menus

.EXAMPLE
    .\install-apps.ps1 -Preset basic
    Install basic apps preset

.EXAMPLE
    .\install-apps.ps1 -Action Update -ConfigFile "dev-tools-config.json"
    Update applications from dev tools config

.EXAMPLE
    .\install-apps.ps1 -Action List -Preset gaming
    List installation status of gaming apps

.EXAMPLE
    .\install-apps.ps1 -Action Upgrade
    Upgrade all Chocolatey packages

.EXAMPLE
    irm https://scripts.vsbtek.com/install-apps.ps1 -OutFile install-apps.ps1
    .\install-apps.ps1
    Download and run with interactive menu

.EXAMPLE
    irm https://scripts.vsbtek.com/install-apps.ps1 -OutFile "$env:TEMP\install-apps.ps1"; & "$env:TEMP\install-apps.ps1"
    One-liner: download to temp and run immediately

.NOTES
    Author: VSBTek
    Repository: https://github.com/HenryBui21/VSBTek-Chocolatey-Installer
    Requires: Administrator privileges, PowerShell 5.1+, Internet connection
#>
