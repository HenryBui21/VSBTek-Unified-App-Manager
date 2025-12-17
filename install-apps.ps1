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
    [switch]$UseWinget,

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

# Global cache for Chocolatey packages (improves performance)
$script:ChocoPackagesCache = $null
$script:CacheTimestamp = $null
$script:CacheExpiryMinutes = 5

# Global preset configuration map
$script:PresetConfigMap = @{
    "basic" = "basic-apps-config.json"
    "dev" = "dev-tools-config.json"
    "community" = "community-config.json"
    "gaming" = "gaming-config.json"
}

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
        if ($UseWinget) { $arguments += " -UseWinget" }
        $arguments += " -KeepWindowOpen"
    } else {
        # Running from web (iex & scriptblock)
        $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"iex \`"& { `$(irm $ScriptUrl) }"
        if ($Preset) { $arguments += " -Preset '$Preset'" }
        if ($Mode) { $arguments += " -Mode '$Mode'" }
        if ($Action) { $arguments += " -Action '$Action'" }
        if ($Force) { $arguments += " -Force" }
        if ($UseWinget) { $arguments += " -UseWinget" }
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

        # Create WebClient with timeout
        $webClient = New-Object System.Net.WebClient
        $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

        # Download and execute Chocolatey install script with timeout (60 seconds)
        $installScript = $webClient.DownloadString('https://community.chocolatey.org/install.ps1')
        Invoke-Expression $installScript

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

function Get-RemoteChocoVersion {
    param([string]$Name)
    try {
        $output = choco search $Name --exact --limit-output 2>$null
        if ($output -match "^$([regex]::Escape($Name))\|(.+)$") {
            return $matches[1]
        }
    } catch {}
    return $null
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

        # Create WebClient with timeout
        $webClient = New-Object System.Net.WebClient
        $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

        # Download config with timeout (30 seconds implicit)
        $jsonContent = $webClient.DownloadString($ConfigUrl)
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

# Consolidated helper function to get applications from preset or config file
function Get-ConfigApplications {
    param(
        [string]$Preset = $null,
        [string]$ConfigFile = $null,
        [string]$Mode = 'local'
    )

    $applications = $null

    if ($Preset) {
        # Use preset configuration
        $configFileName = $script:PresetConfigMap[$Preset]

        if ($Mode -eq 'remote') {
            # Download from GitHub
            $configUrl = "$GitHubRepo/$configFileName"
            $applications = Get-WebConfig -ConfigUrl $configUrl
        } else {
            # Load from local file
            $configPath = Join-Path $PSScriptRoot $configFileName

            # If local file doesn't exist, fallback to remote
            if (-not (Test-Path $configPath)) {
                Write-WarningMsg "Local config not found, downloading from GitHub..."
                $configUrl = "$GitHubRepo/$configFileName"
                $applications = Get-WebConfig -ConfigUrl $configUrl
            } else {
                $applications = Get-ApplicationConfig -ConfigPath $configPath
            }
        }
    } elseif ($ConfigFile) {
        # Use custom config file
        $configPath = $ConfigFile
        if (-not [System.IO.Path]::IsPathRooted($configPath)) {
            $configPath = Join-Path $PSScriptRoot $ConfigFile
        }
        $applications = Get-ApplicationConfig -ConfigPath $configPath
    }

    return $applications
}

function Get-AllAvailableApps {
    param([string]$Mode = 'local')

    Write-Info "Loading all available applications from presets..."

    $allApps = @()
    $categories = @{
        'basic' = 'Basic Apps'
        'dev' = 'Dev Tools'
        'community' = 'Community'
        'gaming' = 'Gaming'
    }

    foreach ($presetKey in $categories.Keys) {
        $configFileName = $script:PresetConfigMap[$presetKey]
        $categoryName = $categories[$presetKey]

        try {
            if ($Mode -eq 'remote') {
                $configUrl = "$GitHubRepo/$configFileName"
                $apps = Get-WebConfig -ConfigUrl $configUrl
            } else {
                $configPath = Join-Path $PSScriptRoot $configFileName
                if (-not (Test-Path $configPath)) {
                    Write-WarningMsg "Local config not found: $configFileName, trying remote..."
                    # Fallback to remote if local not found
                    $configUrl = "$GitHubRepo/$configFileName"
                    $apps = Get-WebConfig -ConfigUrl $configUrl
                } else {
                    $apps = Get-ApplicationConfig -ConfigPath $configPath
                }
            }

            if ($apps) {
                foreach ($app in $apps) {
                    $allApps += [PSCustomObject]@{
                        Name = $app.name
                        Category = $categoryName
                        Version = $app.version
                        Params = $app.params
                        DisplayName = "$($app.name) [$categoryName]"
                    }
                }
            }
        }
        catch {
            Write-WarningMsg "Failed to load preset '$presetKey': $($_.Exception.Message)"
        }
    }

    if ($allApps.Count -eq 0) {
        Write-ErrorMsg "No applications found in any preset"
        Write-ErrorMsg "Please check your internet connection or config files"
        return $null
    }

    Write-Success "Loaded $($allApps.Count) applications from all presets"
    return $allApps
}

function Show-CustomSelectionMenu {
    param([string]$Mode = 'local')

    Write-ColorOutput "`n========================================" -Color Cyan
    Write-ColorOutput "  Custom Application Selection" -Color Cyan
    Write-ColorOutput "========================================`n" -Color Cyan

    # Load all available apps
    $allApps = Get-AllAvailableApps -Mode $Mode

    if (-not $allApps -or $allApps.Count -eq 0) {
        Write-ErrorMsg "No applications found in configuration"
        Write-Host ""
        Write-Host "Please ensure:" -ForegroundColor Yellow
        Write-Host "  1. Config files exist in script directory, OR" -ForegroundColor Gray
        Write-Host "  2. You have internet connection for remote mode" -ForegroundColor Gray
        Write-Host ""
        return $null
    }

    # Try Windows Forms CheckedListBox first (best UX - real checkboxes!)
    $supportsWinForms = $true
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    }
    catch {
        $supportsWinForms = $false
    }

    if ($supportsWinForms) {
        Write-Info "Opening checkbox selection window..."
        Write-Host "  - Check/uncheck apps you want to install"
        Write-Host "  - Use 'Select All' / 'Deselect All' buttons"
        Write-Host "  - Click OK when done"
        Write-Host ""

        try {
            $selectedApps = Show-CheckboxSelectionForm -Apps $allApps
            if ($selectedApps) {
                Write-Success "Selected $($selectedApps.Count) applications"
                return $selectedApps
            } else {
                Write-Info "No applications selected or cancelled"
                return $null
            }
        }
        catch {
            Write-WarningMsg "Windows Forms failed: $($_.Exception.Message)"
            Write-Info "Falling back to Out-GridView..."
            $supportsWinForms = $false
        }
    }

    # Fallback 1: Out-GridView
    if (-not $supportsWinForms) {
        $supportsGridView = $true
        try {
            $null = Get-Command Out-GridView -ErrorAction Stop
        }
        catch {
            $supportsGridView = $false
        }

        if ($supportsGridView) {
            Write-Info "Opening selection window (Out-GridView)..."
            Write-Host "  - Use Ctrl+Click to select multiple apps"
            Write-Host "  - Use search box to filter"
            Write-Host "  - Click OK when done"
            Write-Host ""

            try {
                $selected = $allApps | Select-Object DisplayName, Category, Name, Version |
                    Out-GridView -Title "Select Applications to Install (use Ctrl+Click for multiple)" -PassThru

                if ($selected) {
                    $selectedApps = @()
                    foreach ($item in $selected) {
                        $app = $allApps | Where-Object { $_.Name -eq $item.Name }
                        if ($app) {
                            $selectedApps += [PSCustomObject]@{
                                name = $app.Name
                                version = $app.Version
                                params = $app.Params
                            }
                        }
                    }

                    Write-Success "Selected $($selectedApps.Count) applications"
                    return $selectedApps
                } else {
                    Write-Info "No applications selected"
                    return $null
                }
            }
            catch {
                Write-WarningMsg "Out-GridView failed: $($_.Exception.Message)"
                Write-Info "Falling back to text-based selection..."
                $supportsGridView = $false
            }
        }
    }

    # Fallback 2: Text-based selection
    return Show-TextBasedSelection -Apps $allApps
}

function Show-CheckboxSelectionForm {
    param([array]$Apps)

    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Select Applications to Install"
    $form.Size = New-Object System.Drawing.Size(800, 600)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false

    # Create label
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(760, 20)
    $label.Text = "Check the applications you want to install:"
    $form.Controls.Add($label)

    # Create CheckedListBox
    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Location = New-Object System.Drawing.Point(10, 35)
    $checkedListBox.Size = New-Object System.Drawing.Size(760, 450)
    $checkedListBox.CheckOnClick = $true

    # Group apps by category and add to list
    $groupedApps = $Apps | Group-Object -Property Category | Sort-Object Name
    $appLookup = @{}
    $index = 0

    foreach ($group in $groupedApps) {
        # Add category header (disabled, just for visual)
        $headerIndex = $checkedListBox.Items.Add("=== $($group.Name.ToUpper()) ===")
        $checkedListBox.SetItemCheckState($headerIndex, 'Indeterminate')

        # Add apps in this category
        foreach ($app in ($group.Group | Sort-Object Name)) {
            $displayText = "    $($app.Name)"
            if ($app.Version) {
                $displayText += " (v$($app.Version))"
            }
            $itemIndex = $checkedListBox.Items.Add($displayText)
            $appLookup[$itemIndex] = $app
            $index++
        }
    }

    $form.Controls.Add($checkedListBox)

    # Create buttons panel
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Location = New-Object System.Drawing.Point(10, 495)
    $buttonPanel.Size = New-Object System.Drawing.Size(760, 50)

    # Select All button
    $selectAllButton = New-Object System.Windows.Forms.Button
    $selectAllButton.Location = New-Object System.Drawing.Point(0, 10)
    $selectAllButton.Size = New-Object System.Drawing.Size(100, 30)
    $selectAllButton.Text = "Select All"
    $selectAllButton.Add_Click({
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            if ($appLookup.ContainsKey($i)) {
                $checkedListBox.SetItemChecked($i, $true)
            }
        }
    })
    $buttonPanel.Controls.Add($selectAllButton)

    # Deselect All button
    $deselectAllButton = New-Object System.Windows.Forms.Button
    $deselectAllButton.Location = New-Object System.Drawing.Point(110, 10)
    $deselectAllButton.Size = New-Object System.Drawing.Size(100, 30)
    $deselectAllButton.Text = "Deselect All"
    $deselectAllButton.Add_Click({
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            $checkedListBox.SetItemChecked($i, $false)
        }
    })
    $buttonPanel.Controls.Add($deselectAllButton)

    # OK button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(550, 10)
    $okButton.Size = New-Object System.Drawing.Size(100, 30)
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $buttonPanel.Controls.Add($okButton)

    # Cancel button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(660, 10)
    $cancelButton.Size = New-Object System.Drawing.Size(100, 30)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $buttonPanel.Controls.Add($cancelButton)

    $form.Controls.Add($buttonPanel)
    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton

    # Show form and get result
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedApps = @()
        foreach ($i in $checkedListBox.CheckedIndices) {
            if ($appLookup.ContainsKey($i)) {
                $app = $appLookup[$i]
                $selectedApps += [PSCustomObject]@{
                    name = $app.Name
                    version = $app.Version
                    params = $app.Params
                }
            }
        }
        return $selectedApps
    }

    return $null
}

function Show-TextBasedSelection {
    param([array]$Apps)

    Write-ColorOutput "`n========================================" -Color Yellow
    Write-ColorOutput "  Text-Based Application Selection" -Color Yellow
    Write-ColorOutput "========================================`n" -Color Yellow

    # Group by category for better display
    $groupedApps = $Apps | Group-Object -Property Category

    $index = 1
    $appIndexMap = @{}

    foreach ($group in $groupedApps) {
        Write-ColorOutput "`n  $($group.Name):" -Color Cyan
        foreach ($app in $group.Group) {
            Write-Host "    [$index] $($app.Name)"
            $appIndexMap[$index] = $app
            $index++
        }
    }

    Write-Host ""
    Write-Host "Enter numbers to select apps (comma-separated, e.g., '1,3,5-7')" -ForegroundColor White
    Write-Host "Or type 'all' to select all apps, 'cancel' to abort" -ForegroundColor Gray
    Write-Host ""

    $selection = Read-Host "Your selection"

    if ($selection -eq 'cancel') {
        Write-Info "Selection cancelled"
        return $null
    }

    $selectedApps = @()

    if ($selection -eq 'all') {
        # Select all apps
        foreach ($app in $Apps) {
            $selectedApps += [PSCustomObject]@{
                name = $app.Name
                version = $app.Version
                params = $app.Params
            }
        }
    } else {
        # Parse selection
        $parts = $selection -split ',' | ForEach-Object { $_.Trim() }

        foreach ($part in $parts) {
            if ($part -match '^(\d+)-(\d+)$') {
                # Range (e.g., "5-7")
                $start = [int]$matches[1]
                $end = [int]$matches[2]
                for ($i = $start; $i -le $end; $i++) {
                    if ($appIndexMap.ContainsKey($i)) {
                        $app = $appIndexMap[$i]
                        $selectedApps += [PSCustomObject]@{
                            name = $app.Name
                            version = $app.Version
                            params = $app.Params
                        }
                    }
                }
            } elseif ($part -match '^\d+$') {
                # Single number
                $num = [int]$part
                if ($appIndexMap.ContainsKey($num)) {
                    $app = $appIndexMap[$num]
                    $selectedApps += [PSCustomObject]@{
                        name = $app.Name
                        version = $app.Version
                        params = $app.Params
                    }
                }
            }
        }
    }

    if ($selectedApps.Count -gt 0) {
        Write-Success "Selected $($selectedApps.Count) applications:"
        foreach ($app in $selectedApps) {
            Write-Host "  - $($app.name)" -ForegroundColor Gray
        }
        Write-Host ""
        $confirm = Read-Host "Proceed with installation? (y/n)"
        if ($confirm -eq 'y') {
            return $selectedApps
        }
    }

    Write-Info "No applications selected or installation cancelled"
    return $null
}

# ============================================================================
# HELPER FUNCTIONS - PACKAGE DETECTION
# ============================================================================

# Cache function for Chocolatey packages list
function Get-ChocoPackagesCache {
    param([bool]$ForceRefresh = $false)

    if ($ForceRefresh -or -not $script:ChocoPackagesCache -or
        ((Get-Date) - $script:CacheTimestamp).TotalMinutes -gt $script:CacheExpiryMinutes) {

        $result = & choco list --limit-output 2>&1
        $script:ChocoPackagesCache = @{}

        if ($LASTEXITCODE -eq 0 -and $result) {
            foreach ($line in $result) {
                if ($line -match "^([^|]+)\|(.+)$") {
                    $script:ChocoPackagesCache[$matches[1]] = $matches[2]
                }
            }
        }
        $script:CacheTimestamp = Get-Date
    }

    return $script:ChocoPackagesCache
}

# Convert package name to friendly display name
function Get-FriendlyName {
    param([string]$Name)

    $friendlyMap = @{
        'vscode' = 'Visual Studio Code'
        'git' = 'Git'
        'python' = 'Python'
        'nodejs' = 'Node.js'
        'docker' = 'Docker'
        'vlc' = 'VLC media player'
        'firefox' = 'Mozilla Firefox'
        'brave' = 'Brave'
        'chrome' = 'Google Chrome'
        'winrar' = 'WinRAR'
        'unikey' = 'UniKey'
        'ultraviewer' = 'UltraViewer'
        'zoom' = 'Zoom'
        'slack' = 'Slack'
        'discord' = 'Discord'
        'steam' = 'Steam'
        'telegram' = 'Telegram'
        'zalopc' = 'Zalo'
        'curl' = 'curl'
        'wget' = 'Wget'
        'hwinfo' = 'HWiNFO'
    }

    $lower = $Name.ToLower()
    if ($friendlyMap.ContainsKey($lower)) {
        return $friendlyMap[$lower]
    }

    # Capitalize first letter of each word
    $words = $Name -split '-'
    $capitalized = $words | ForEach-Object {
        if ($_.Length -gt 0) {
            $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower()
        } else {
            $_
        }
    }
    return $capitalized -join ' '
}

# Generate search names dynamically from package name
function Get-SearchNames {
    param([string]$PackageName)

    $names = @()
    $lower = $PackageName.ToLower()

    # Static mappings for known special cases
    $staticMap = @{
        'googlechrome' = @('Google Chrome')
        'microsoft-edge' = @('Microsoft Edge')
        'notepadplusplus' = @('Notepad++')
        'notepadplusplus.install' = @('Notepad++')
        'foxitreader' = @('Foxit Reader', 'Foxit PDF Reader')
        '7zip' = @('7-Zip')
        '7zip.install' = @('7-Zip')
        'powertoys' = @('PowerToys', 'Microsoft PowerToys')
        'treesizefree' = @('TreeSize Free')
        'patch-my-pc' = @('PatchMyPC', 'Patch My PC')
        'winaero-tweaker' = @('Winaero Tweaker')
        'revo-uninstaller' = @('Revo Uninstaller')
        'obs-studio' = @('OBS Studio')
        'geforce-experience' = @('NVIDIA GeForce Experience')
        'msiafterburner' = @('MSI Afterburner')
        'crystaldiskinfo' = @('CrystalDiskInfo')
        'cpu-z' = @('CPU-Z')
        'epicgameslauncher' = @('Epic Games Launcher')
        'github-desktop' = @('GitHub Desktop')
        'microsoft-windows-terminal' = @('Windows Terminal', 'Microsoft Windows Terminal')
        'wsl2' = @('Windows Subsystem for Linux')
    }

    # Check static map first
    if ($staticMap.ContainsKey($lower)) {
        return $staticMap[$lower]
    }

    # Dynamic generation for common patterns
    $baseName = $PackageName -replace '\.install$', '' -replace '\.portable$', ''

    # Pattern 1: dotnet packages
    if ($baseName -match '^dotnet') {
        $names += "Microsoft .NET*"
        $names += ".NET*"
        if ($baseName -match '(\d+\.\d+)') {
            $version = $matches[1]
            $names += "*$version*"
        }
    }
    # Pattern 2: microsoft- prefix
    elseif ($baseName -match '^microsoft-(.+)') {
        $appName = $matches[1] -replace '-', ' '
        $names += "Microsoft $appName"
        $names += "$appName"
    }
    # Pattern 3: -lts, -core suffixes (nodejs-lts, powershell-core)
    elseif ($baseName -match '^(.+?)-(lts|core)$') {
        $appName = $matches[1]
        $names += Get-FriendlyName $appName
    }
    # Pattern 4: Simple names (git, vscode, python, etc.)
    else {
        $names += Get-FriendlyName $baseName
    }

    # Always add original package name as fallback
    if ($names.Count -eq 0) {
        $names += $PackageName
    }

    return $names
}

function Test-PackageInstalled {
    param(
        [string]$PackageName,
        [switch]$ChocoOnly
    )

    try {
        # Check via Chocolatey first using cache
        $chocoPackages = Get-ChocoPackagesCache

        if ($chocoPackages.ContainsKey($PackageName)) {
            return $true
        }

        # If ChocoOnly flag is set, only check Chocolatey
        if ($ChocoOnly) {
            return $false
        }

        # Check Windows installed programs registry
        $uninstallPaths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        # REMOVED nested functions - now using module-level Get-SearchNames
        $searchNames = Get-SearchNames -PackageName $PackageName

        foreach ($path in $uninstallPaths) {
            $installed = Get-ItemProperty $path -ErrorAction SilentlyContinue |
                Where-Object {
                    $displayName = $_.DisplayName
                    if ($displayName) {
                        foreach ($name in $searchNames) {
                            $matched = $false

                            # Improved matching logic to avoid false positives
                            if ($name -match '\*') {
                                # Pattern contains wildcard, use -like
                                $matched = $displayName -like $name
                            } elseif ($displayName -eq $name) {
                                # Exact match
                                $matched = $true
                            } elseif ($displayName -like "$name *") {
                                # Starts with name followed by space
                                $matched = $true
                            } elseif ($displayName -like "* $name") {
                                # Ends with name preceded by space
                                $matched = $true
                            } elseif ($displayName -like "* $name *") {
                                # Contains name with spaces on both sides
                                $matched = $true
                            }

                            if ($matched) {
                                # Additional verification: Check if install location exists
                                # This helps avoid ghost registry entries
                                $installLocation = $_.InstallLocation
                                $uninstallString = $_.UninstallString

                                # If we have install location, verify it exists
                                if ($installLocation -and $installLocation -ne '') {
                                    if (Test-Path $installLocation) {
                                        return $true
                                    }
                                    # Location doesn't exist - likely a ghost entry
                                    continue
                                }

                                # If we have uninstall string, check if the executable exists
                                if ($uninstallString -and $uninstallString -ne '') {
                                    # Extract path from uninstall string (remove quotes and arguments)
                                    $exePath = $uninstallString -replace '"', '' -replace ' /.*$', '' -replace ' -.*$', ''
                                    if (Test-Path $exePath) {
                                        return $true
                                    }
                                    # Uninstaller doesn't exist - likely a ghost entry
                                    continue
                                }

                                # No location info available - trust the registry entry
                                # (Some apps don't populate these fields)
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

function Compare-Versions {
    param($v1, $v2)
    # Returns 1 if v1 > v2, -1 if v1 < v2, 0 if equal
    try {
        # Normalize versions (remove 'v' prefix if present)
        $ver1 = [System.Version]($v1 -replace '^v', '')
        $ver2 = [System.Version]($v2 -replace '^v', '')
        return $ver1.CompareTo($ver2)
    } catch {
        # Fallback to string comparison if parsing fails
        return [string]::Compare($v1, $v2, $true)
    }
}

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

        # Chocolatey exit codes:
        # 0 = success
        # 1 = general error
        # 3010 = success, reboot required
        # Other non-zero = various errors
        if ($LASTEXITCODE -eq 0) {
            Write-Success "$PackageName installed successfully"
            return $true
        } elseif ($LASTEXITCODE -eq 3010) {
            Write-Success "$PackageName installed successfully (reboot required)"
            return $true
        } elseif ($LASTEXITCODE -eq 1641) {
            Write-Success "$PackageName installed successfully (reboot initiated)"
            return $true
        } else {
            Write-ErrorMsg "$PackageName installation failed (exit code: $LASTEXITCODE)"
            return $false
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
        [string]$Version = $null,
        [switch]$AllowReinstall
    )

    Write-Info "Updating $PackageName..."

    try {
        # Check if installed via Chocolatey
        $isChocoInstalled = Test-PackageInstalled -PackageName $PackageName -ChocoOnly

        if (-not $isChocoInstalled) {
            # Check if installed via other methods (Windows Registry)
            $installedViaOtherMethods = Test-PackageInstalled -PackageName $PackageName

            if ($installedViaOtherMethods) {
                Write-WarningMsg "$PackageName is installed via Windows (not Chocolatey)"

                if ($AllowReinstall) {
                    Write-Info "  Attempting to install via Chocolatey (will coexist or upgrade)..."
                    $result = Install-ChocoPackage -PackageName $PackageName -Version $Version -ForceInstall $false
                    if ($result) {
                        Write-Success "$PackageName now managed by Chocolatey"
                        return $true
                    } else {
                        Write-ErrorMsg "Failed to takeover package management"
                        return $false
                    }
                } else {
                    Write-Host "  Use Update mode with -Force flag to reinstall via Chocolatey" -ForegroundColor Gray
                    Write-Host "  Or uninstall manually first and run Install mode" -ForegroundColor Gray
                    return $false
                }
            } else {
                Write-WarningMsg "$PackageName is not installed"
                Write-Info "  Installing package instead..."
                return Install-ChocoPackage -PackageName $PackageName -Version $Version -ForceInstall $false
            }
        }

        # Package is managed by Chocolatey - proceed with normal upgrade
        $chocoArgs = @('upgrade', $PackageName, '-y', '--no-progress')

        if ($Version) {
            $chocoArgs += "--version=$Version"
            Write-Info "  Target version: $Version"
        }

        $null = & choco @chocoArgs 2>&1

        # Chocolatey exit codes:
        # 0 = success (package updated)
        # 2 = no update available (already latest)
        # 3010 = success, reboot required
        # Other non-zero = errors
        if ($LASTEXITCODE -eq 0) {
            Write-Success "$PackageName updated successfully"
            return $true
        } elseif ($LASTEXITCODE -eq 2) {
            Write-Info "$PackageName is already at the latest version"
            return $true
        } elseif ($LASTEXITCODE -eq 3010) {
            Write-Success "$PackageName updated successfully (reboot required)"
            return $true
        } elseif ($LASTEXITCODE -eq 1641) {
            Write-Success "$PackageName updated successfully (reboot initiated)"
            return $true
        } else {
            Write-ErrorMsg "$PackageName update failed (exit code: $LASTEXITCODE)"
            return $false
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

    # Get all Chocolatey packages using cache for better performance
    $chocoPackages = Get-ChocoPackagesCache

    foreach ($app in $Applications) {
        $appName = if ($app.name) { $app.name } else { $app.Name }
        $isInstalled = Test-PackageInstalled -PackageName $appName
        $isChocoInstalled = $chocoPackages.ContainsKey($appName)

        if ($isInstalled) {
            $statusText = if ($isChocoInstalled) { "[OK]" } else { "[OK*]" }
            Write-ColorOutput "  $statusText $appName" -Color Green

            if ($isChocoInstalled) {
                $installedVersion = $chocoPackages[$appName]
                Write-ColorOutput "    Chocolatey: v$installedVersion" -Color Gray

                $appVersion = if ($app.version) { $app.version } else { $app.Version }
                if ($appVersion -and $appVersion -ne $installedVersion) {
                    Write-ColorOutput "    Config: v$appVersion" -Color Yellow
                }
            } else {
                Write-ColorOutput "    Installed via Windows (not Chocolatey)" -Color Gray
            }
        } else {
            Write-ColorOutput "  [X] $appName" -Color Red
            Write-ColorOutput "    Not installed" -Color Gray
        }

        Write-Host ""
    }

    Write-ColorOutput "`nLegend:" -Color Cyan
    Write-ColorOutput "  [OK]  = Installed via Chocolatey" -Color Gray
    Write-ColorOutput "  [OK*] = Installed via Windows (cannot update via Chocolatey)" -Color Gray
    Write-ColorOutput "  [X]   = Not installed" -Color Gray
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
# HELPER FUNCTIONS - WINGET
# ============================================================================

function Get-RemoteWingetVersion {
    param([string]$Name)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $null }
    
    # winget show returns unstructured text, we need to parse "Version: x.y.z"
    # We use --accept-source-agreements to avoid prompts
    $output = winget show $Name --accept-source-agreements 2>&1
    foreach ($line in $output) {
        if ($line -match "Version:\s+(.+)") {
            return $matches[1].Trim()
        }
    }
    return $null
}

function Install-WingetPackage {
    param(
        [string]$PackageName,
        [string]$Version = $null,
        [array]$Params = @(),
        [bool]$ForceInstall = $false
    )

    Write-Info "Installing $PackageName via Winget..."

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "Winget command not found. Please ensure App Installer is installed."
        return $false
    }

    try {
        # Construct arguments
        # We use --accept-package-agreements and --accept-source-agreements for automation
        $wingetArgs = @('install', $PackageName, '--accept-package-agreements', '--accept-source-agreements')

        if ($Version) {
            $wingetArgs += '--version'
            $wingetArgs += $Version
        }

        if ($ForceInstall) {
            $wingetArgs += '--force'
        }

        # Handle parameters (Winget uses --override for installer args)
        if ($Params.Count -gt 0) {
            $overrideArgs = $Params -join ' '
            $wingetArgs += '--override'
            $wingetArgs += "$overrideArgs"
        }

        # Execute Winget
        $process = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-Success "$PackageName installed successfully via Winget"
            return $true
        } else {
            Write-ErrorMsg "$PackageName installation failed (Exit code: $($process.ExitCode))"
            return $false
        }
    }
    catch {
        Write-ErrorMsg "Failed to install $PackageName via Winget: $($_.Exception.Message)"
        return $false
    }
}

function Update-WingetPackage {
    param(
        [string]$PackageName,
        [string]$Version = $null
    )

    Write-Info "Updating $PackageName via Winget..."

    $wingetArgs = @('upgrade', $PackageName, '--accept-package-agreements', '--accept-source-agreements')
    if ($Version) {
        $wingetArgs += '--version'
        $wingetArgs += $Version
    }

    $process = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
    return ($process.ExitCode -eq 0)
}

function Uninstall-WingetPackage {
    param(
        [string]$PackageName
    )

    Write-Info "Uninstalling $PackageName via Winget..."

    $wingetArgs = @('uninstall', $PackageName)
    $process = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Success "$PackageName uninstalled successfully"
        return $true
    }
    return $false
}

# ============================================================================
# MENU FUNCTIONS
# ============================================================================

function Show-ContinuePrompt {
    Write-Host ""
    Write-ColorOutput "========================================" -Color Cyan
    Write-Host "  1. Return to Main Menu"
    Write-Host "  2. Exit"
    Write-Host ""

    $choice = Read-Host "Enter your choice (1-2)"

    switch ($choice) {
        '1' { return $true }
        '2' {
            Write-Info "Exiting..."
            return $false
        }
        default {
            Write-ErrorMsg "Invalid choice. Returning to menu..."
            return $true
        }
    }
}

function Show-MainMenu {
    while ($true) {
        Write-ColorOutput "`n========================================" -Color Cyan
        Write-ColorOutput "  VSBTek Chocolatey Manager" -Color Cyan
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
                # Continue loop for retry
            }
        }
    }
}

function Show-PresetMenu {
    while ($true) {
        Write-ColorOutput "`n========================================" -Color Cyan
        Write-ColorOutput "  Select Application Preset" -Color Cyan
        Write-ColorOutput "========================================" -Color Cyan
        Write-Host ""
        Write-Host "  1. Basic Apps (18 apps) - Browsers, utilities, tools"
        Write-Host "  2. Dev Tools (13 apps) - IDEs, Git, Docker, etc."
        Write-Host "  3. Community (4 apps) - Teams, Zoom, Telegram, Zalo"
        Write-Host "  4. Gaming (9 apps) - Steam, Discord, OBS, etc."
        Write-Host "  5. Custom Selection - Pick individual apps from all categories"
        Write-Host "  6. Cancel"
        Write-Host ""

        $choice = Read-Host "Enter your choice (1-6)"

        switch ($choice) {
            '1' { return 'basic' }
            '2' { return 'dev' }
            '3' { return 'community' }
            '4' { return 'gaming' }
            '5' { return 'custom' }
            '6' {
                Write-Info "Cancelled"
                exit 0
            }
            default {
                Write-ErrorMsg "Invalid choice. Please try again."
                # Continue loop for retry
            }
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
    $totalCount = $Applications.Count
    $currentIndex = 0

    foreach ($app in $Applications) {
        $currentIndex++
        $appName = if ($app.name) { $app.name } else { $app.Name }
        $appVersion = if ($app.version) { $app.version } else { $app.Version }
        $appParams = if ($app.params) { $app.params } else { if ($app.Params) { $app.Params } else { @() } }

        Write-ColorOutput "`n[$currentIndex/$totalCount] Processing: $appName" -Color Cyan

        $primarySource = 'Choco'

        if ($UseWinget) {
            Write-Info "Checking available versions..."
            $wVer = Get-RemoteWingetVersion -Name $appName
            $cVer = Get-RemoteChocoVersion -Name $appName

            if ($wVer -and $cVer) {
                Write-Info "  Winget: $wVer | Chocolatey: $cVer"
                if ((Compare-Versions $wVer $cVer) -ge 0) { $primarySource = 'Winget' }
            } elseif ($wVer) {
                Write-Info "  Found on Winget ($wVer)"
                $primarySource = 'Winget'
            } elseif ($cVer) {
                Write-Info "  Found on Chocolatey ($cVer)"
                $primarySource = 'Choco'
            } else {
                $primarySource = 'Winget' # Default preference if check fails
            }
        }

        $installed = $false

        if ($primarySource -eq 'Winget') {
            $installed = Install-WingetPackage -PackageName $appName -Version $appVersion -Params $appParams -ForceInstall $Force
            if (-not $installed) {
                Write-WarningMsg "Winget installation failed. Attempting fallback to Chocolatey..."
                $installed = Install-ChocoPackage -PackageName $appName -Version $appVersion -Params $appParams -ForceInstall $Force
            }
        } else {
            $installed = Install-ChocoPackage -PackageName $appName -Version $appVersion -Params $appParams -ForceInstall $Force
            if (-not $installed -and $UseWinget) {
                Write-WarningMsg "Chocolatey installation failed. Attempting fallback to Winget..."
                $installed = Install-WingetPackage -PackageName $appName -Version $appVersion -Params $appParams -ForceInstall $Force
            }
        }

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
    param(
        [array]$Applications,
        [bool]$AllowReinstall = $false
    )

    Write-ColorOutput "`n========================================" -Color Magenta
    Write-ColorOutput "  Updating Applications" -Color Magenta
    Write-ColorOutput "========================================`n" -Color Magenta

    if ($AllowReinstall) {
        Write-Info "Reinstall mode enabled: Will takeover non-Chocolatey installations"
        Write-Host ""
    }

    $successCount = 0
    $failCount = 0
    $totalCount = $Applications.Count
    $currentIndex = 0

    foreach ($app in $Applications) {
        $currentIndex++
        $appName = if ($app.name) { $app.name } else { $app.Name }
        $appVersion = if ($app.version) { $app.version } else { $app.Version }

        Write-ColorOutput "`n[$currentIndex/$totalCount] Processing: $appName" -Color Cyan

        if ($UseWinget) {
            $updated = Update-WingetPackage -PackageName $appName -Version $appVersion
        } else {
            $updated = Update-ChocoPackage -PackageName $appName -Version $appVersion -AllowReinstall:$AllowReinstall
        }

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
    $totalCount = $Applications.Count
    $currentIndex = 0

    foreach ($app in $Applications) {
        $currentIndex++
        $appName = if ($app.name) { $app.name } else { $app.Name }

        Write-ColorOutput "`n[$currentIndex/$totalCount] Processing: $appName" -Color Cyan

        if ($UseWinget) {
            $uninstalled = Uninstall-WingetPackage -PackageName $appName
        } else {
            $uninstalled = Uninstall-ChocoPackage -PackageName $appName -ForceUninstall $Force
        }

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
# MAIN WORKFLOW FUNCTION
# ============================================================================

function Invoke-MainWorkflow {
    param(
        [string]$InitialAction = $null,
        [string]$InitialPreset = $null,
        [string]$InitialConfigFile = $null,
        [string]$ExecutionMode = 'local',
        [bool]$ForceFlag = $false
    )

    # Determine action
    $selectedAction = $InitialAction
    if (-not $selectedAction) {
        $selectedAction = Show-MainMenu
    }

    Write-ColorOutput "`nSelected Action: $selectedAction" -Color Yellow

    # Handle Upgrade All (doesn't need config)
    if ($selectedAction -eq 'Upgrade') {
        Write-Info "Upgrading all installed Chocolatey packages..."
        Invoke-UpgradeAll
        return $true  # Continue to menu
    }

    # Determine preset/config using consolidated helper function
    $applications = $null

    if ($InitialPreset -or $InitialConfigFile) {
        # Use preset or config file directly
        if ($InitialPreset -eq 'custom') {
            $applications = Show-CustomSelectionMenu -Mode $ExecutionMode
        } else {
            $applications = Get-ConfigApplications -Preset $InitialPreset -ConfigFile $InitialConfigFile -Mode $ExecutionMode
        }
    } else {
        # Show preset menu and get applications
        $selectedPreset = Show-PresetMenu
        if ($selectedPreset -eq 'custom') {
            $applications = Show-CustomSelectionMenu -Mode $ExecutionMode
        } else {
            $applications = Get-ConfigApplications -Preset $selectedPreset -Mode $ExecutionMode
        }
    }

    # Validate applications loaded
    if (-not $applications -or $applications.Count -eq 0) {
        Write-ErrorMsg "No applications found in configuration"
        return $true  # Continue to menu
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
        return $true  # Continue to menu
    }

    # Execute selected action
    switch ($selectedAction) {
        'Install' {
            Invoke-InstallMode -Applications $applications
        }
        'Update' {
            Invoke-UpdateMode -Applications $applications -AllowReinstall $ForceFlag
        }
        'Uninstall' {
            Invoke-UninstallMode -Applications $applications
        }
        'List' {
            Show-InstalledPackages -Applications $applications
        }
    }

    Write-Success "Operation completed!"
    return $true  # Continue to menu
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
    Write-ErrorMsg "Chocolatey installation failed"
    Write-Host ""
    Write-ColorOutput "Possible solutions:" -Color Yellow
    Write-Host "  1. Check your internet connection"
    Write-Host "  2. Disable firewall/antivirus temporarily"
    Write-Host "  3. Run as Administrator"
    Write-Host "  4. Install manually from https://chocolatey.org/install"
    Write-Host ""

    $retry = Read-Host "Do you want to retry? (Y/N)"
    if ($retry -eq 'Y' -or $retry -eq 'y') {
        if (Install-Chocolatey) {
            Write-Success "Chocolatey installed successfully on retry"
        } else {
            Write-ErrorMsg "Cannot proceed without Chocolatey. Exiting..."
            Read-Host "Press Enter to exit"
            exit 1
        }
    } else {
        Write-Info "Script cancelled by user"
        Read-Host "Press Enter to exit"
        exit 0
    }
}

# Main execution loop
$continueRunning = $true

# If command-line parameters are provided, run once and show prompt
if ($Action -or $Preset -or $ConfigFile) {
    # Run with provided parameters
    Invoke-MainWorkflow -InitialAction $Action -InitialPreset $Preset -InitialConfigFile $ConfigFile -ExecutionMode $Mode -ForceFlag $Force

    # Show continue prompt
    if ($KeepWindowOpen) {
        $continueRunning = Show-ContinuePrompt
    } else {
        $continueRunning = $false
    }
}

# Interactive loop
while ($continueRunning) {
    # Run workflow (will show menu)
    $result = Invoke-MainWorkflow -ExecutionMode $Mode -ForceFlag $Force

    if ($result) {
        # Show continue prompt
        $continueRunning = Show-ContinuePrompt
    } else {
        $continueRunning = $false
    }
}

Write-Info "Thank you for using VSBTek Chocolatey Manager!"

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
