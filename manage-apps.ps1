# Chocolatey Advanced Application Manager
# Supports Install, Update, Uninstall, and List operations
# Author: VSBTek

#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Install', 'Update', 'Uninstall', 'List', 'Upgrade')]
    [string]$Action = $null,

    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = $null,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

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

# Show action selection menu
function Show-ActionMenu {
    Write-ColorOutput "`n========================================" -Color Cyan
    Write-ColorOutput "  Select Action" -Color Cyan
    Write-ColorOutput "========================================" -Color Cyan
    Write-Host ""
    Write-Host "  1. Install applications"
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
            return Show-ActionMenu
        }
    }
}

# Show config file selection menu
function Show-ConfigMenu {
    Write-ColorOutput "`n========================================" -Color Cyan
    Write-ColorOutput "  Select Configuration" -Color Cyan
    Write-ColorOutput "========================================" -Color Cyan
    Write-Host ""
    Write-Host "  1. Basic Apps (18 apps) - Browsers, utilities, tools"
    Write-Host "  2. Dev Tools (15 apps) - IDEs, Git, Docker, etc."
    Write-Host "  3. Community (5 apps) - Teams, Zoom, Slack, etc."
    Write-Host "  4. Gaming (10 apps) - Steam, Discord, OBS, etc."
    Write-Host ""

    $choice = Read-Host "Enter your choice (1-4)"

    switch ($choice) {
        '1' { return 'basic-apps-config.json' }
        '2' { return 'dev-tools-config.json' }
        '3' { return 'community-config.json' }
        '4' { return 'gaming-config.json' }
        default {
            Write-ErrorMsg "Invalid choice. Please try again."
            return Show-ConfigMenu
        }
    }
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
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

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

# Check if package is installed
function Test-PackageInstalled {
    param(
        [string]$PackageName
    )

    try {
        # First check via Chocolatey
        $result = & choco list --local-only --exact $PackageName 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match $PackageName) {
            return $true
        }

        # If not found via choco, check Windows installed programs
        # This helps detect programs installed via other methods
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

# Install a single package
function Install-ChocoPackage {
    param(
        [string]$PackageName,
        [string]$Version = $null,
        [string[]]$Params = @(),
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

# Update a single package
function Update-ChocoPackage {
    param(
        [string]$PackageName,
        [string]$Version = $null
    )

    Write-Info "Updating $PackageName..."

    try {
        # Check if installed
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

# Uninstall a single package
function Uninstall-ChocoPackage {
    param(
        [string]$PackageName,
        [bool]$ForceUninstall = $false
    )

    Write-Info "Uninstalling $PackageName..."

    try {
        # Check if installed
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

# List installed packages from config
function Show-InstalledPackages {
    param(
        [array]$Applications
    )

    Write-ColorOutput "`n========================================" -Color Magenta
    Write-ColorOutput "  Installed Applications Status" -Color Magenta
    Write-ColorOutput "========================================`n" -Color Magenta

    foreach ($app in $Applications) {
        $isInstalled = Test-PackageInstalled -PackageName $app.name

        if ($isInstalled) {
            Write-ColorOutput "  [OK] $($app.name)" -Color Green

            # Get installed version
            try {
                $versionInfo = & choco list --local-only --exact $app.name 2>&1 | Select-String -Pattern "$($app.name)\s+([\d\.]+)"
                if ($versionInfo) {
                    $installedVersion = $versionInfo.Matches.Groups[1].Value
                    Write-ColorOutput "    Installed: v$installedVersion" -Color Gray

                    if ($app.version -and $app.version -ne $installedVersion) {
                        Write-ColorOutput "    Config: v$($app.version)" -Color Yellow
                    }
                }
            }
            catch {
                # Ignore version check errors
            }
        } else {
            Write-ColorOutput "  [X] $($app.name)" -Color Red
            Write-ColorOutput "    Not installed" -Color Gray
        }

        Write-Host ""
    }
}

# Upgrade all packages
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
# Main Execution
# ============================================================================

Write-ColorOutput "`n========================================" -Color Magenta
Write-ColorOutput "  Chocolatey Application Manager" -Color Magenta
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

# Show interactive menu if Action not specified
if (-not $Action) {
    $Action = Show-ActionMenu
}

Write-ColorOutput "`nSelected Action: $Action" -Color Yellow

# For Upgrade All action, we don't need config
if ($Action -eq 'Upgrade') {
    Write-Info "Upgrading all installed Chocolatey packages..."
    Invoke-UpgradeAll
    exit 0
}

# Show config menu if ConfigFile not specified
if (-not $ConfigFile) {
    $ConfigFile = Show-ConfigMenu
}

Write-ColorOutput "Selected Config: $ConfigFile`n" -Color Yellow

# Resolve config file path
$configPath = $ConfigFile
if (-not [System.IO.Path]::IsPathRooted($configPath)) {
    $configPath = Join-Path $PSScriptRoot $ConfigFile
}

# Load configuration
$applications = Get-ApplicationConfig -ConfigPath $configPath

if (-not $applications -or $applications.Count -eq 0) {
    Write-ErrorMsg "No applications found in configuration"
    exit 1
}

# Show confirmation before proceeding
Write-ColorOutput "`nApplications to process: $($applications.Count)" -Color Cyan
Write-Host ""
$confirm = Read-Host "Do you want to proceed? (Y/N)"
if ($confirm -ne 'Y' -and $confirm -ne 'y') {
    Write-Info "Operation cancelled"
    exit 0
}

# Execute action
switch ($Action) {
    'Install' {
        Write-ColorOutput "`n========================================" -Color Magenta
        Write-ColorOutput "  Installing Applications" -Color Magenta
        Write-ColorOutput "========================================`n" -Color Magenta

        $successCount = 0
        $failCount = 0

        foreach ($app in $applications) {
            $params = if ($app.params) { $app.params } else { @() }
            $installed = Install-ChocoPackage -PackageName $app.name -Version $app.version -Params $params -ForceInstall $Force

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
        Write-ColorOutput "Total: $($applications.Count) | Success: $successCount | Failed: $failCount" -Color White
        Write-ColorOutput "========================================`n" -Color Magenta
    }

    'Update' {
        Write-ColorOutput "`n========================================" -Color Magenta
        Write-ColorOutput "  Updating Applications" -Color Magenta
        Write-ColorOutput "========================================`n" -Color Magenta

        $successCount = 0
        $failCount = 0

        foreach ($app in $applications) {
            $updated = Update-ChocoPackage -PackageName $app.name -Version $app.version

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
        Write-ColorOutput "Total: $($applications.Count) | Success: $successCount | Failed: $failCount" -Color White
        Write-ColorOutput "========================================`n" -Color Magenta
    }

    'Uninstall' {
        Write-ColorOutput "`n========================================" -Color Magenta
        Write-ColorOutput "  Uninstalling Applications" -Color Magenta
        Write-ColorOutput "========================================`n" -Color Magenta

        Write-WarningMsg "You are about to uninstall $($applications.Count) applications!"
        $confirm = Read-Host "Type 'YES' to continue"

        if ($confirm -ne 'YES') {
            Write-Info "Uninstall cancelled"
            exit 0
        }

        $successCount = 0
        $failCount = 0

        foreach ($app in $applications) {
            $uninstalled = Uninstall-ChocoPackage -PackageName $app.name -ForceUninstall $Force

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
        Write-ColorOutput "Total: $($applications.Count) | Success: $successCount | Failed: $failCount" -Color White
        Write-ColorOutput "========================================`n" -Color Magenta
    }

    'List' {
        Show-InstalledPackages -Applications $applications
    }
}

Write-Success "Operation completed!"
