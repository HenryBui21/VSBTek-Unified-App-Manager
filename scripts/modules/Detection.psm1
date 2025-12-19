
# Detection Module

# Cache variables
$script:ChocoPackagesCache = $null
$script:CacheTimestamp = $null
$script:CacheExpiryMinutes = 5
$script:WingetListCache = $null
$script:ChocoToWingetMap = @{}

function Initialize-Detection {
    param([string]$RootPath, [string]$GitHubRepo)
    
    # Load Winget Map
    try {
        $mapFile = "winget-map.json"
        $localMapPath = Join-Path $RootPath "config\$mapFile"
        
        if (Test-Path $localMapPath) {
            $jsonMap = Get-Content $localMapPath -Raw | ConvertFrom-Json
        } else {
            $webClient = New-Object System.Net.WebClient
            $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
            $jsonContent = $webClient.DownloadString("$GitHubRepo/$mapFile")
            $jsonMap = $jsonContent | ConvertFrom-Json
        }

        foreach ($prop in $jsonMap.PSObject.Properties) {
            $script:ChocoToWingetMap[$prop.Name] = $prop.Value
        }
    } catch {}
}

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

function Get-WingetListCache {
    param([bool]$ForceRefresh = $false)

    if ($ForceRefresh -or -not $script:WingetListCache) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            $script:WingetListCache = winget list --accept-source-agreements 2>&1
        }
    }
    return $script:WingetListCache
}

function Resolve-WingetId {
    param([string]$Name)
    $lowerName = $Name.ToLower()
    if ($script:ChocoToWingetMap.ContainsKey($lowerName)) {
        return $script:ChocoToWingetMap[$lowerName]
    }
    return $Name
}

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

function Get-SearchNames {
    param([string]$PackageName)

    $names = @()
    $lower = $PackageName.ToLower()

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

    if ($staticMap.ContainsKey($lower)) {
        return $staticMap[$lower]
    }

    $baseName = $PackageName -replace '\.install$', '' -replace '\.portable$', ''

    if ($baseName -match '^dotnet') {
        $names += "Microsoft .NET*"
        $names += ".NET*"
        if ($baseName -match '(\d+\.\d+)') {
            $version = $matches[1]
            $names += "*$version*"
        }
    }
    elseif ($baseName -match '^microsoft-(.+)') {
        $appName = $matches[1] -replace '-', ' '
        $names += "Microsoft $appName"
        $names += "$appName"
    }
    elseif ($baseName -match '^(.+?)-(lts|core)$') {
        $appName = $matches[1]
        $names += Get-FriendlyName $appName
    }
    else {
        $names += Get-FriendlyName $baseName
    }

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
        $chocoPackages = Get-ChocoPackagesCache

        if ($chocoPackages.ContainsKey($PackageName)) {
            return $true
        }

        if ($ChocoOnly) {
            return $false
        }

        $uninstallPaths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        $searchNames = Get-SearchNames -PackageName $PackageName

        foreach ($path in $uninstallPaths) {
            $installed = Get-ItemProperty $path -ErrorAction SilentlyContinue |
                Where-Object {
                    $displayName = $_.DisplayName
                    if ($displayName) {
                        foreach ($name in $searchNames) {
                            $matched = $false
                            if ($name -match '\*') {
                                $matched = $displayName -like $name
                            } elseif ($displayName -eq $name) {
                                $matched = $true
                            } elseif ($displayName -like "$name *") {
                                $matched = $true
                            } elseif ($displayName -like "* $name") {
                                $matched = $true
                            } elseif ($displayName -like "* $name *") {
                                $matched = $true
                            }

                            if ($matched) {
                                $installLocation = $_.InstallLocation
                                $uninstallString = $_.UninstallString

                                if ($installLocation -and $installLocation -ne '') {
                                    if (Test-Path $installLocation) { return $true }
                                    continue
                                }
                                if ($uninstallString -and $uninstallString -ne '') {
                                    $exePath = $uninstallString -replace '"', '' -replace ' /.*$', '' -replace ' -.*$', ''
                                    if (Test-Path $exePath) { return $true }
                                    continue
                                }
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

function Get-RemoteWingetVersion {
    param([string]$Name)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $null }
    
    $target = Resolve-WingetId -Name $Name
    $output = winget show --id $target --exact --accept-source-agreements 2>&1
    foreach ($line in $output) {
        if ($line -match "^(Version|Phiên bản|Ver\.|Versie|Versão)[\w\s]*:\s+([0-9]+\.[0-9\.]+.*)$") {
            return $matches[2].Trim()
        } elseif ($line -match "^Version:\s+(.+)$") {
            return $matches[1].Trim()
        }
    }
    return $null
}

Export-ModuleMember -Function Initialize-Detection, Get-ChocoPackagesCache, Get-WingetListCache, Resolve-WingetId, Get-FriendlyName, Get-SearchNames, Test-PackageInstalled, Get-RemoteChocoVersion, Get-RemoteWingetVersion
