
# Package Manager Module
# Depends on: Logger, Detection, Core (for Environment), Config (for Policy)

function Compare-Versions {
    param($v1, $v2)
    try {
        $ver1 = [System.Version]($v1 -replace '^v', '')
        $ver2 = [System.Version]($v2 -replace '^v', '')
        return $ver1.CompareTo($ver2)
    } catch {
        return [string]::Compare($v1, $v2, $true)
    }
}

function Install-Chocolatey {
    Write-Host "[INFO] Checking Chocolatey installation..." -ForegroundColor Cyan

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "[OK] Chocolatey is already installed" -ForegroundColor Green
        choco --version
        return $true
    }

    Write-Host "[INFO] Chocolatey not found. Installing..." -ForegroundColor Cyan

    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        $webClient = New-Object System.Net.WebClient
        $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        $installScript = $webClient.DownloadString('https://community.chocolatey.org/install.ps1')
        Invoke-Expression $installScript

        # Assuming Update-SessionEnvironment is available in global scope or via module
        Update-SessionEnvironment

        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Host "[OK] Chocolatey installed successfully" -ForegroundColor Green
            choco --version
            return $true
        } else {
            throw "Chocolatey installation completed but command not found"
        }
    }
    catch {
        Write-Host "[ERROR] Failed to install Chocolatey: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Install-ChocoPackage {
    param(
        [string]$PackageName,
        [string]$Version = $null,
        [array]$Params = @(),
        [bool]$ForceInstall = $false
    )

    Write-Host "[INFO] Installing $PackageName..." -ForegroundColor Cyan

    try {
        $chocoArgs = @('install', $PackageName, '-y', '--no-progress')

        if ($Version) {
            $chocoArgs += "--version=$Version"
            Write-Host "  Version: $Version" -ForegroundColor Cyan
        }

        if ($ForceInstall) {
            $chocoArgs += '--force'
        }

        if ($Params.Count -gt 0) {
            $chocoArgs += $Params
            Write-Host "  Parameters: $($Params -join ' ')" -ForegroundColor Cyan
        }

        $null = & choco @chocoArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] $PackageName installed successfully" -ForegroundColor Green
            return $true
        } elseif ($LASTEXITCODE -eq 3010) {
            Write-Host "[OK] $PackageName installed successfully (reboot required)" -ForegroundColor Green
            return $true
        } elseif ($LASTEXITCODE -eq 1641) {
            Write-Host "[OK] $PackageName installed successfully (reboot initiated)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[ERROR] $PackageName installation failed (exit code: $LASTEXITCODE)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "[ERROR] Failed to install ${PackageName}: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Update-ChocoPackage {
    param(
        [string]$PackageName,
        [string]$Version = $null,
        [switch]$AllowReinstall,
        [bool]$InstallIfMissing = $true
    )

    Write-Host "[INFO] Updating $PackageName..." -ForegroundColor Cyan

    try {
        $isChocoInstalled = Test-PackageInstalled -PackageName $PackageName -ChocoOnly

        if (-not $isChocoInstalled) {
            $installedViaOtherMethods = Test-PackageInstalled -PackageName $PackageName

            if ($installedViaOtherMethods) {
                Write-Host "[WARNING] $PackageName is installed via Windows (not Chocolatey)" -ForegroundColor Yellow

                if ($AllowReinstall) {
                    Write-Host "[INFO]   Attempting to install via Chocolatey (will coexist or upgrade)..." -ForegroundColor Cyan
                    $result = Install-ChocoPackage -PackageName $PackageName -Version $Version -ForceInstall $false
                    if ($result) {
                        Write-Host "[OK] $PackageName now managed by Chocolatey" -ForegroundColor Green
                        return $true
                    } else {
                        Write-Host "[ERROR] Failed to takeover package management" -ForegroundColor Red
                        return $false
                    }
                } else {
                    Write-Host "  Use Update mode with -Force flag to reinstall via Chocolatey" -ForegroundColor Gray
                    return $false
                }
            } else {
                if ($InstallIfMissing) {
                    Write-Host "[WARNING] $PackageName is not installed" -ForegroundColor Yellow
                    Write-Host "[INFO]   Installing package instead..." -ForegroundColor Cyan
                    return Install-ChocoPackage -PackageName $PackageName -Version $Version -ForceInstall $false
                } else {
                    Write-Host "[WARNING] $PackageName is not installed. Skipping." -ForegroundColor Yellow
                    return $false
                }
            }
        }

        $chocoArgs = @('upgrade', $PackageName, '-y', '--no-progress')
        if ($Version) { $chocoArgs += "--version=$Version" }

        $null = & choco @chocoArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] $PackageName updated successfully" -ForegroundColor Green
            return $true
        } elseif ($LASTEXITCODE -eq 2) {
            Write-Host "[INFO] $PackageName is already at the latest version" -ForegroundColor Cyan
            return $true
        } elseif ($LASTEXITCODE -eq 3010) {
            Write-Host "[OK] $PackageName updated successfully (reboot required)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[ERROR] $PackageName update failed" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "[ERROR] Failed to update ${PackageName}: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Uninstall-ChocoPackage {
    param(
        [string]$PackageName,
        [bool]$ForceUninstall = $false
    )
    Write-Host "[INFO] Uninstalling $PackageName..." -ForegroundColor Cyan
    try {
        if (-not (Test-PackageInstalled -PackageName $PackageName)) {
            Write-Host "[WARNING] $PackageName is not installed, skipping" -ForegroundColor Yellow
            return $false
        }
        $chocoArgs = @('uninstall', $PackageName, '-y', '--no-progress')
        if ($ForceUninstall) { $chocoArgs += '--force' }
        $null = & choco @chocoArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] $PackageName uninstalled successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[WARNING] $PackageName uninstallation encountered issues" -ForegroundColor Yellow
            return $false
        }
    } catch { return $false }
}

function Set-ChocoPin {
    param([string]$PackageName)
    try {
        Write-Host "  Attempting to pin '$PackageName' with Chocolatey..." -ForegroundColor Gray
        $output = & choco pin add -n $PackageName -y 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] '$PackageName' pinned successfully via Chocolatey." -ForegroundColor Green
            return $true
        } else {
            Write-WarningMsg "Failed to pin '$PackageName' with Chocolatey (Exit code: $LASTEXITCODE)."
            $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
            return $false
        }
    } catch {
        Write-ErrorMsg "An error occurred while trying to pin '$PackageName' with Chocolatey: $($_.Exception.Message)"
        return $false
    }
}

function Install-Winget {
    # This function checks for Winget. If not found, it attempts to install it.
    # Returns $true if Winget is available after execution, $false otherwise.

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        # It's already here, no action needed.
        return $true
    }

    # Check OS compatibility
    $osVersion = [Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10 -or ($osVersion.Major -eq 10 -and $osVersion.Build -lt 17763)) {
        Write-WarningMsg "Winget requires Windows 10 (build 17763) or newer. Your build: $($osVersion.Build)."
        return $false
    }

    Write-Host "[INFO] Winget not found. Attempting to install from GitHub..." -ForegroundColor Cyan
    $tempDir = Join-Path $env:TEMP "winget-install-temp"
    if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }
    
    try {
        # Use GitHub API to find the latest release asset
        $releaseApiUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        Write-Host "  Querying latest release from GitHub..." -ForegroundColor Gray
        $releaseInfo = Invoke-RestMethod -Uri $releaseApiUrl -UseBasicParsing -TimeoutSec 15
        
        $bundleAsset = $releaseInfo.assets | Where-Object { $_.name -like '*.msixbundle' }
        $dependencyAsset = $releaseInfo.assets | Where-Object { $_.name -like '*VCLibs*.appx' }

        if (-not $bundleAsset) {
            throw "Could not find .msixbundle in the latest Winget release assets."
        }

        # Download and install dependency if it exists
        if ($dependencyAsset) {
            $dependencyPath = Join-Path $tempDir $dependencyAsset.name
            Write-Host "  Downloading dependency: $($dependencyAsset.name)" -ForegroundColor Gray
            Invoke-WebRequest -Uri $dependencyAsset.browser_download_url -OutFile $dependencyPath -UseBasicParsing -TimeoutSec 120
            
            Write-Host "  Installing dependency..." -ForegroundColor Gray
            Add-AppxPackage -Path $dependencyPath | Out-Null
        }

        # Download and install main package
        $bundlePath = Join-Path $tempDir $bundleAsset.name
        Write-Host "  Downloading main package: $($bundleAsset.name)" -ForegroundColor Gray
        Invoke-WebRequest -Uri $bundleAsset.browser_download_url -OutFile $bundlePath -UseBasicParsing -TimeoutSec 120

        Write-Host "  Installing main package..." -ForegroundColor Gray
        Add-AppxPackage -Path $bundlePath | Out-Null

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "[OK] Winget installed successfully." -ForegroundColor Green
            return $true
        }
        throw "Winget installation seemed to succeed, but the 'winget' command is not available."
    } catch {
        Write-ErrorMsg "Failed to automatically install Winget: $($_.Exception.Message)"
        Write-WarningMsg "This can happen if a required dependency is missing or if there's a conflict with an existing 'App Installer' version."
        Write-WarningMsg "Please try installing/updating 'App Installer' from the Microsoft Store first, then run this script again."
        return $false
    } finally {
        # Clean up downloaded files
        if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Install-WingetPackage {
    param(
        [string]$PackageName,
        [string]$Version = $null,
        [array]$Params = @(),
        [bool]$ForceInstall = $false
    )
    Write-Host "[INFO] Installing $PackageName via Winget..." -ForegroundColor Cyan
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }

    $target = Resolve-WingetId -Name $PackageName
    try {
        $wingetArgs = @('install', '--id', $target, '--exact', '--accept-package-agreements', '--accept-source-agreements')
        if ($Version) { $wingetArgs += '--version'; $wingetArgs += $Version }
        if ($ForceInstall) { $wingetArgs += '--force' }
        if ($Params.Count -gt 0) { $wingetArgs += '--override'; $wingetArgs += ($Params -join ' ') }

        $process = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0) {
            Write-Host "[OK] $PackageName installed successfully via Winget" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[ERROR] Winget install failed (Code: $($process.ExitCode))" -ForegroundColor Red
            return $false
        }
    } catch { return $false }
}

function Update-WingetPackage {
    param([string]$PackageName, [string]$Version = $null)
    $target = Resolve-WingetId -Name $PackageName
    $wingetArgs = @('upgrade', '--id', $target, '--exact', '--accept-package-agreements', '--accept-source-agreements')
    if ($Version) { $wingetArgs += '--version'; $wingetArgs += $Version }
    $process = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
    return ($process.ExitCode -eq 0)
}

function Uninstall-WingetPackage {
    param([string]$PackageName)
    $target = Resolve-WingetId -Name $PackageName
    $wingetArgs = @('uninstall', '--id', $target, '--exact')
    $process = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
    return ($process.ExitCode -eq 0)
}

function Set-WingetPin {
    param([string]$PackageName)
    $target = Resolve-WingetId -Name $PackageName
    if (-not $target) {
        Write-WarningMsg "Could not resolve Winget ID for '$PackageName'. Cannot pin."
        return $false
    }
    try {
        Write-Host "  Attempting to pin '$PackageName' (ID: $target) with Winget..." -ForegroundColor Gray
        $process = Start-Process -FilePath "winget" -ArgumentList "pin", "add", "--id", $target, "--blocking" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0) {
            Write-Host "[OK] '$PackageName' pinned successfully via Winget." -ForegroundColor Green
            return $true
        } else {
            Write-WarningMsg "Failed to pin '$PackageName' with Winget (Exit code: $($process.ExitCode))."
            Write-WarningMsg "  Run 'winget pin add --id $target' manually in a terminal to see the full error."
            return $false
        }
    } catch {
        Write-ErrorMsg "An error occurred while trying to pin '$PackageName' with Winget: $($_.Exception.Message)"
        return $false
    }
}

function Get-PreferredSource {
    param([string]$AppName, [bool]$UseWinget, [string]$ExplicitSource = $null)
    
    $policy = Get-PackagePolicy
    if ($policy.preferChoco -contains $AppName.ToLower()) { return 'Choco' }
    if ($policy.preferWinget -contains $AppName.ToLower()) { return 'Winget' }

    if ($ExplicitSource) {
        if ($ExplicitSource -match 'winget') { return 'Winget' }
        return 'Choco'
    }

    if (-not $UseWinget) { return 'Choco' }
    
    Write-Host "[INFO] Checking available versions..." -ForegroundColor Cyan
    $wVer = Get-RemoteWingetVersion -Name $AppName
    $cVer = Get-RemoteChocoVersion -Name $AppName

    if ($wVer -and $cVer) {
        if ((Compare-Versions $wVer $cVer) -ge 0) { return 'Winget' } else { return 'Choco' }
    } elseif ($wVer) { return 'Winget' } elseif ($cVer) { return 'Choco' }
    
    return 'Winget'
}

function Invoke-UpgradeAll {
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "  System-Wide Upgrade (Hybrid)" -ForegroundColor Magenta
    Write-Host "========================================`n" -ForegroundColor Magenta

    # Load package policy to respect pinned packages
    $policy = Get-PackagePolicy
    $pinnedPackages = $policy.pinned

    Write-Host "[INFO] Phase 1/2: Upgrading Chocolatey packages..." -ForegroundColor Cyan
    $chocoArgs = @('upgrade', 'all', '-y', '--no-progress')
    if ($pinnedPackages.Count -gt 0) {
        $chocoPinned = $pinnedPackages -join ','
        $chocoArgs += "--except=$($chocoPinned)"
        Write-Host "  Excluding pinned packages: $chocoPinned" -ForegroundColor Gray
    }
    try {
        $null = & choco @chocoArgs 2>&1
    } catch {}

    Write-Host "`n[INFO] Phase 2/2: Upgrading Winget packages..." -ForegroundColor Cyan
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $wingetArgs = @('upgrade', '--all', '--include-unknown', '--accept-package-agreements', '--accept-source-agreements')

        if ($pinnedPackages.Count -gt 0) {
            $excludedIds = @()
            foreach ($pkgName in $pinnedPackages) {
                # Resolve choco name to winget ID. Assumes Resolve-WingetId is available.
                $wingetId = Resolve-WingetId -Name $pkgName
                if ($wingetId) {
                    $wingetArgs += @('--exclude', $wingetId)
                    $excludedIds += $wingetId
                }
            }
            if ($excludedIds.Count -gt 0) {
                Write-Host "  Excluding pinned packages (Winget IDs): $($excludedIds -join ', ')" -ForegroundColor Gray
            }
        }

        Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -NoNewWindow
    }
}

Export-ModuleMember -Function Compare-Versions, Install-Chocolatey, Install-ChocoPackage, Update-ChocoPackage, Uninstall-ChocoPackage, Set-ChocoPin, Install-Winget, Install-WingetPackage, Update-WingetPackage, Uninstall-WingetPackage, Set-WingetPin, Get-PreferredSource, Invoke-UpgradeAll
