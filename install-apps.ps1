# VSBTek Unified App Manager - Modularized
# Combines installation, management, and remote execution capabilities
# Refactored for performance and maintainability

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = $null,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Install', 'Update', 'Uninstall', 'List', 'Upgrade')]
    [string]$Action = $null,

    [Parameter(Mandatory=$false)]
    [ValidateSet('basic', 'dev', 'community', 'gaming', 'remote')]
    [string]$Preset = $null,

    [Parameter(Mandatory=$false)]
    [ValidateSet('local', 'remote')]
    [string]$Mode = 'local',

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$UseWinget,

    [Parameter(Mandatory=$false)]
    [switch]$KeepWindowOpen,

    [Parameter(Mandatory=$false)]
    [switch]$ForceUpdate
)

# Configuration
$GitHubRepo = "https://raw.githubusercontent.com/HenryBui21/VSBTek-Unified-App-Manager/main"
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ============================================================================
# BOOTSTRAP & MODULE LOADING
# ============================================================================

# Determine Root Path to handle 'iex' (remote execution) or local execution
if ($PSScriptRoot) {
    $AppRoot = $PSScriptRoot
} else {
    $AppRoot = Join-Path $env:TEMP "VSBTek-Unified-App-Manager"
    if (-not (Test-Path $AppRoot)) {
        New-Item -ItemType Directory -Force -Path $AppRoot | Out-Null
    }
}

$ModulesPath = Join-Path $AppRoot "scripts\modules"
$ConfigPath  = Join-Path $AppRoot "config"

# Ensure directories exist
if (-not (Test-Path $ModulesPath)) { New-Item -ItemType Directory -Force -Path $ModulesPath | Out-Null }
if (-not (Test-Path $ConfigPath))  { New-Item -ItemType Directory -Force -Path $ConfigPath | Out-Null }

$ModulesList = @("Logger.psm1", "Core.psm1", "Config.psm1", "Detection.psm1", "PackageManager.psm1", "UI.psm1")

# Check if we need to download modules (Self-healing / Remote execution)
$missingModules = $false
foreach ($mod in $ModulesList) {
    if (-not (Test-Path (Join-Path $ModulesPath $mod))) {
        $missingModules = $true
        break
    }
}

if ($missingModules -or $Mode -eq 'remote' -or $ForceUpdate) {
    Write-Host "Initializing VSBTek App Manager..." -ForegroundColor Cyan
    Write-Host "Downloading required modules to: $AppRoot" -ForegroundColor Gray
    
    try {
        $WebClient = New-Object System.Net.WebClient
        $WebClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        
        # Download Modules
        foreach ($mod in $ModulesList) {
            $modLocalPath = Join-Path $ModulesPath $mod
            $url = "$GitHubRepo/scripts/modules/$mod"
            # The outer 'if' condition has already determined we need to download.
            $WebClient.DownloadFile($url, $modLocalPath)
        }
    } catch {
        Write-Error "Failed to download required components. Please check your internet connection."
        Write-Error "Source: $GitHubRepo"
        Write-Error $_.Exception.Message
        exit 1
    }
}

# Import Modules
foreach ($mod in $ModulesList) {
    try {
        # Get module name from filename (e.g., Logger.psm1 -> Logger)
        $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($mod)
        # Forcefully remove any cached version of the module from the current session
        Remove-Module $moduleName -ErrorAction SilentlyContinue
        # Import the fresh version
        Import-Module (Join-Path $ModulesPath $mod) -Force -ErrorAction Stop
    } catch {
        Write-Warning "Failed to import module: $mod"
        throw $_
    }
}

# Initialize Global State
# We pass AppRoot so modules know where to look for configs
Initialize-Detection -RootPath $AppRoot -GitHubRepo $GitHubRepo
Import-PackagePolicy -RootPath $AppRoot

# ============================================================================
# AUTO-ELEVATION
# ============================================================================

if (-not (Test-Administrator)) {
    Write-WarningMsg "Requesting Administrator privileges..."
    
    if ($PSScriptRoot) {
        # Local file execution
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($ConfigFile) { $arguments += " -ConfigFile `"$ConfigFile`"" }
        if ($Action) { $arguments += " -Action `"$Action`"" }
        if ($Preset) { $arguments += " -Preset `"$Preset`"" }
        if ($Mode) { $arguments += " -Mode `"$Mode`"" }
        if ($Force) { $arguments += " -Force" }
        if ($UseWinget) { $arguments += " -UseWinget" }
        if ($ForceUpdate) { $arguments += " -ForceUpdate" }
        $arguments += " -KeepWindowOpen"
        
        Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs
        exit
    } else {
        # Remote/IEX mode elevation
        # We need to download the script to disk to elevate it properly
        $LocalScriptPath = Join-Path $AppRoot "install-apps.ps1"
        try {
            (New-Object System.Net.WebClient).DownloadFile("$GitHubRepo/install-apps.ps1", $LocalScriptPath)
            
            $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$LocalScriptPath`""
            # Default to remote mode behavior
            $arguments += " -Mode remote"
            if ($UseWinget) { $arguments += " -UseWinget" }
            if ($ForceUpdate) { $arguments += " -ForceUpdate" }
            $arguments += " -KeepWindowOpen"
            
            Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs
            exit
        } catch {
            Write-WarningMsg "Could not auto-elevate in remote mode. Please run PowerShell as Administrator and try again."
            exit 1
        }
    }
}

# ============================================================================
# MAIN WORKFLOW
# ============================================================================

function Invoke-MainWorkflow {
    param(
        [string]$InitialAction = $null,
        [string]$InitialPreset = $null,
        [string]$InitialConfigFile = $null,
        [string]$ExecutionMode = 'local',
        [bool]$ForceFlag = $false
    )

    $selectedAction = $InitialAction
    if (-not $selectedAction) {
        $selectedAction = Show-MainMenu -RootPath $AppRoot -GitHubRepo $GitHubRepo
    }

    Write-Host ""
    Write-ColorOutput "Selected Action: $selectedAction" -Color Yellow

    if ($selectedAction -eq 'Upgrade') {
        Invoke-UpgradeAll
        return $true
    }

    $applications = $null
    if ($InitialPreset -or $InitialConfigFile) {
        if ($InitialPreset -eq 'custom') {
            $applications = Show-CustomSelectionMenu -Mode $ExecutionMode -RootPath $AppRoot -GitHubRepo $GitHubRepo
        } else {
            $applications = Get-ConfigApplications -Preset $InitialPreset -ConfigFile $InitialConfigFile -Mode $ExecutionMode -RootPath $AppRoot -GitHubRepo $GitHubRepo
        }
    } else {
        $selectedPreset = Show-PresetMenu -RootPath $AppRoot
        if ($selectedPreset -eq 'custom') {
            $applications = Show-CustomSelectionMenu -Mode $ExecutionMode -RootPath $AppRoot -GitHubRepo $GitHubRepo
        } else {
            $applications = Get-ConfigApplications -Preset $selectedPreset -Mode $ExecutionMode -RootPath $AppRoot -GitHubRepo $GitHubRepo
        }
    }

    if (-not $applications -or $applications.Count -eq 0) {
        Write-ErrorMsg "No applications found/selected"
        return $true
    }

    # Execute Action
    switch ($selectedAction) {
        'Install' {
            # Optimization: Pre-check status?
            # For now, we stick to sequential install to ensure Winget/Choco stability
            foreach ($app in $applications) {
                $appName = if ($app.name) { $app.name } else { $app.Name }
                $appVer = if ($app.version) { $app.version } else { $app.Version }
                $appParams = if ($app.params) { $app.params } else { $app.Params }
                
                $source = Get-PreferredSource -AppName $appName -UseWinget $UseWinget
                
                $success = $false
                if ($source -eq 'Winget') {
                    $success = Install-WingetPackage -PackageName $appName -Version $appVer -Params $appParams -ForceInstall $ForceFlag
                    if (-not $success) { $success = Install-ChocoPackage -PackageName $appName -Version $appVer -Params $appParams -ForceInstall $ForceFlag }
                } else {
                    $success = Install-ChocoPackage -PackageName $appName -Version $appVer -Params $appParams -ForceInstall $ForceFlag
                    if (-not $success -and $UseWinget) { $success = Install-WingetPackage -PackageName $appName -Version $appVer -Params $appParams -ForceInstall $ForceFlag }
                }
                
                # Handle Pinning
                $policy = Get-PackagePolicy
                if ($policy.pinned -contains $appName.ToLower()) {
                    if ($source -eq 'Winget') { Set-WingetPin -PackageName $appName } else { Set-ChocoPin -PackageName $appName }
                }
            }
        }
        'Update' {
            foreach ($app in $applications) {
                $appName = if ($app.name) { $app.name } else { $app.Name }
                $appVer = if ($app.version) { $app.version } else { $app.Version }
                Update-ChocoPackage -PackageName $appName -Version $appVer
            }
        }
        'Uninstall' {
            foreach ($app in $applications) {
                $appName = if ($app.name) { $app.name } else { $app.Name }
                Uninstall-ChocoPackage -PackageName $appName
            }
        }
        'List' {
            # This function uses Parallel Processing internally
            Show-InstalledPackages -Applications $applications
        }
    }

    return $true
}

# ============================================================================
# ENTRY POINT
# ============================================================================

Write-ColorOutput "VSBTek Unified App Manager (Modularized)" -Color Magenta

if (-not (Install-Chocolatey)) { exit 1 }
Update-SessionEnvironment

# Proactively check for Winget support and attempt installation if the OS is compatible.
$isWingetSupported = $false
$osVersion = [Environment]::OSVersion.Version
if ($osVersion.Major -ge 10 -and $osVersion.Build -ge 17763) { # Winget requires build 17763+
    $isWingetSupported = $true
}

# If the OS supports it, or the user explicitly requested it, try to install/enable.
if ($isWingetSupported -or $UseWinget) {
    if (Install-Winget) {
        $UseWinget = $true
        Write-Host "[OK] Winget is available and enabled for this session." -ForegroundColor Green
    } else {
        # If installation failed, ensure the flag is false for the rest of the session.
        $UseWinget = $false
        Write-WarningMsg "Winget is not available. Winget-related features will be disabled."
    }
}

$continueRunning = $true
if ($Action -or $Preset -or $ConfigFile) {
    Invoke-MainWorkflow -InitialAction $Action -InitialPreset $Preset -InitialConfigFile $ConfigFile -ExecutionMode $Mode -ForceFlag $Force 
    if ($KeepWindowOpen) { $continueRunning = Show-ContinuePrompt } else { $continueRunning = $false }
}

while ($continueRunning) {
    $result = Invoke-MainWorkflow -ExecutionMode $Mode -ForceFlag $Force
    if ($result) { $continueRunning = Show-ContinuePrompt } else { $continueRunning = $false }
}