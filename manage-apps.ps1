# Chocolatey Advanced Application Manager
# Supports Install, Update, Uninstall, and List operations
# Author: VSBTek

#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Install', 'Update', 'Uninstall', 'List', 'Upgrade')]
    [string]$Action = 'Install',

    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "apps-config.json",

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
        $result = & choco list --local-only --exact $PackageName 2>&1
        return $LASTEXITCODE -eq 0 -and $result -match $PackageName
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
            Write-ColorOutput "  ✓ $($app.name)" -Color Green

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
            Write-ColorOutput "  ✗ $($app.name)" -Color Red
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

# Main execution
function Main {
    Write-ColorOutput "`n========================================" -Color Magenta
    Write-ColorOutput "  Chocolatey Application Manager" -Color Magenta
    Write-ColorOutput "  Action: $Action" -Color Magenta
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

    # For Upgrade All action, we don't need config
    if ($Action -eq 'Upgrade') {
        Write-Info "Upgrading all installed Chocolatey packages..."
        Invoke-UpgradeAll
        return
    }

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
                return
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
}

# Execute main function
Main
