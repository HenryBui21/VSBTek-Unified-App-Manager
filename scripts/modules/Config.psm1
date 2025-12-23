
# Global package policy state
$script:PackagePolicy = @{
    "pinned" = @()
    "preferChoco" = @()
    "preferWinget" = @()
}

function Import-PackagePolicy {
    param([string]$RootPath)
    try {
        $policyFile = "package-policy.json"
        $localPolicyPath = Join-Path $RootPath $policyFile
        if (Test-Path $localPolicyPath) {
            $jsonPolicy = Get-Content $localPolicyPath -Raw | ConvertFrom-Json
            if ($jsonPolicy.pinned) { $script:PackagePolicy.pinned = [array]$jsonPolicy.pinned }
            if ($jsonPolicy.preferChoco) { $script:PackagePolicy.preferChoco = [array]$jsonPolicy.preferChoco }
            if ($jsonPolicy.preferWinget) { $script:PackagePolicy.preferWinget = [array]$jsonPolicy.preferWinget }
        }
    } catch {}
}

function Save-PackagePolicy {
    param([string]$RootPath)
    $policyFile = Join-Path $RootPath "package-policy.json"
    $script:PackagePolicy | ConvertTo-Json -Depth 2 | Out-File $policyFile -Encoding UTF8
}

function Get-PackagePolicy {
    return $script:PackagePolicy
}

function Add-PackagePolicyRule {
    param(
        [string]$PackageName,
        [string]$Type # 'pinned', 'preferChoco', 'preferWinget'
    )
    $PackageName = $PackageName.ToLower()
    
    # Remove existing conflicts
    # The @() wrapper is crucial to ensure the result is always an array,
    # even if Where-Object returns a single scalar item.
    $script:PackagePolicy.preferChoco = @($script:PackagePolicy.preferChoco | Where-Object { $_ -ne $PackageName })
    $script:PackagePolicy.preferWinget = @($script:PackagePolicy.preferWinget | Where-Object { $_ -ne $PackageName })

    switch ($Type) {
        'pinned' {
            if ($script:PackagePolicy.pinned -notcontains $PackageName) { $script:PackagePolicy.pinned += $PackageName }
        }
        'preferChoco' {
            $script:PackagePolicy.preferChoco += $PackageName
        }
        'preferWinget' {
            $script:PackagePolicy.preferWinget += $PackageName
        }
    }
}

function Remove-PackagePolicyRule {
    param([string]$PackageName)
    $PackageName = $PackageName.ToLower()
    $script:PackagePolicy.pinned = @($script:PackagePolicy.pinned | Where-Object { $_ -ne $PackageName })
    $script:PackagePolicy.preferChoco = @($script:PackagePolicy.preferChoco | Where-Object { $_ -ne $PackageName })
    $script:PackagePolicy.preferWinget = @($script:PackagePolicy.preferWinget | Where-Object { $_ -ne $PackageName })
}

# Config State
$script:KnownPresets = @{
    "basic" = @{ File="basic-apps-config.json"; Title="Basic Apps" }
    "dev" = @{ File="dev-tools-config.json"; Title="Dev Tools" }
    "community" = @{ File="community-config.json"; Title="Community" }
    "gaming" = @{ File="gaming-config.json"; Title="Gaming" }
    "remote" = @{ File="remote-config.json"; Title="Remote Tools" }
}

function Get-AvailablePresets {
    param(
        [string]$Mode = 'local',
        [string]$RootPath
    )
    
    $presets = @()
    
    if ($Mode -eq 'local') {
        $configDir = Join-Path $RootPath "config"
        if (Test-Path $configDir) {
            $files = Get-ChildItem -Path $configDir -Filter "*-config.json" -ErrorAction SilentlyContinue
        } else {
            $files = @()
        }
        
        foreach ($file in $files) {
            $knownKey = $null
            foreach ($key in $script:KnownPresets.Keys) {
                if ($script:KnownPresets[$key].File -eq $file.Name) {
                    $knownKey = $key
                    break
                }
            }

            if ($knownKey) {
                $presets += [PSCustomObject]@{
                    ID = $knownKey
                    Title = $script:KnownPresets[$knownKey].Title
                    File = $file.Name
                }
            } else {
                $id = $file.Name -replace '-config.json',''
                $title = $id.Substring(0,1).ToUpper() + $id.Substring(1).ToLower() + " (Custom)"
                $presets += [PSCustomObject]@{
                    ID = $id
                    Title = $title
                    File = $file.Name
                }
            }
        }
    }
    
    if ($presets.Count -eq 0) {
        foreach ($key in $script:KnownPresets.Keys) {
            $presets += [PSCustomObject]@{ ID=$key; Title=$script:KnownPresets[$key].Title; File=$script:KnownPresets[$key].File }
        }
    }
    
    return $presets | Sort-Object Title
}

function Get-ApplicationConfig {
    param([string]$ConfigPath)

    Write-Host "[INFO] Loading configuration from $ConfigPath..." -ForegroundColor Cyan

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "[ERROR] Configuration file not found: $ConfigPath" -ForegroundColor Red
        return $null
    }

    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

        if (-not $config.applications) {
            Write-Host "[ERROR] Invalid configuration: 'applications' property not found" -ForegroundColor Red
            return $null
        }

        Write-Host "[OK] Configuration loaded: $($config.applications.Count) applications found" -ForegroundColor Green
        return $config.applications
    }
    catch {
        Write-Host "[ERROR] Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-WebConfig {
    param([string]$ConfigUrl)

    try {
        Write-Host "[INFO] Downloading configuration from: $ConfigUrl" -ForegroundColor Cyan

        $webClient = New-Object System.Net.WebClient
        $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        $jsonContent = $webClient.DownloadString($ConfigUrl)
        $config = $jsonContent | ConvertFrom-Json

        if (-not $config.applications) {
            Write-Host "[ERROR] Invalid configuration format" -ForegroundColor Red
            return $null
        }

        Write-Host "[OK] Configuration loaded: $($config.applications.Count) applications found" -ForegroundColor Green
        return $config.applications
    }
    catch {
        Write-Host "[ERROR] Failed to download config: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-ConfigApplications {
    param(
        [string]$Preset = $null,
        [string]$ConfigFile = $null,
        [string]$Mode = 'local',
        [string]$RootPath,
        [string]$GitHubRepo
    )

    $applications = $null

    if ($Preset) {
        $configFileName = $null
        if ($script:KnownPresets.ContainsKey($Preset)) {
            $configFileName = $script:KnownPresets[$Preset].File
        } else {
            $configFileName = "$Preset-config.json"
        }

        if ($Mode -eq 'remote') {
            $configUrl = "$GitHubRepo/config/$configFileName"
            $applications = Get-WebConfig -ConfigUrl $configUrl
        } else {
            $configPath = Join-Path $RootPath "config\$configFileName"
            if (-not (Test-Path $configPath)) {
                Write-Host "[WARNING] Local config not found, downloading from GitHub..." -ForegroundColor Yellow
                $configUrl = "$GitHubRepo/config/$configFileName"
                $applications = Get-WebConfig -ConfigUrl $configUrl
            } else {
                $applications = Get-ApplicationConfig -ConfigPath $configPath
            }
        }
    } elseif ($ConfigFile) {
        if ($Mode -eq 'remote') {
            # Fix: Support custom config file in remote mode
            $configUrl = "$GitHubRepo/config/$ConfigFile"
            $applications = Get-WebConfig -ConfigUrl $configUrl
        } else {
            $configPath = $ConfigFile
            if (-not [System.IO.Path]::IsPathRooted($configPath)) {
                $configPath = Join-Path $RootPath "config\$ConfigFile"
                if (-not (Test-Path $configPath)) {
                    # Fallback to root if not found in config dir
                    $configPath = Join-Path $RootPath $ConfigFile
                }
            }
            $applications = Get-ApplicationConfig -ConfigPath $configPath
        }
    }

    return $applications
}

function Get-AllAvailableApps {
    param(
        [string]$Mode = 'local',
        [string]$RootPath,
        [string]$GitHubRepo
    )

    Write-Host "[INFO] Loading all available applications from presets..." -ForegroundColor Cyan

    $allApps = @()
    $presets = Get-AvailablePresets -Mode $Mode -RootPath $RootPath

    foreach ($preset in $presets) {
        $configFileName = $preset.File
        $categoryName = $preset.Title

        try {
            $apps = $null
            if ($Mode -eq 'remote') {
                $configUrl = "$GitHubRepo/config/$configFileName"
                $apps = Get-WebConfig -ConfigUrl $configUrl
            } else {
                $configPath = Join-Path $RootPath "config\$configFileName"
                if (-not (Test-Path $configPath) -and $Mode -eq 'local') {
                    $configUrl = "$GitHubRepo/config/$configFileName"
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
            Write-Host "[WARNING] Failed to load preset '$($preset.Title)': $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    if ($allApps.Count -eq 0) {
        Write-Host "[ERROR] No applications found in any preset" -ForegroundColor Red
        return $null
    }

    Write-Host "[OK] Loaded $($allApps.Count) applications from all presets" -ForegroundColor Green
    return $allApps
}

Export-ModuleMember -Function Import-PackagePolicy, Save-PackagePolicy, Get-PackagePolicy, Add-PackagePolicyRule, Remove-PackagePolicyRule, Get-AvailablePresets, Get-ConfigApplications, Get-AllAvailableApps
