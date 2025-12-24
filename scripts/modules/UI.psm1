
# UI Module
# Depends on: Logger, Config, Detection

function Show-CustomSelectionMenu {
    param([string]$Mode = 'local', [string]$RootPath, [string]$GitHubRepo)

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Custom Application Selection" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $allApps = Get-AllAvailableApps -Mode $Mode -RootPath $RootPath -GitHubRepo $GitHubRepo
    if (-not $allApps) { return @() }

    $useGridView = Get-Command Out-GridView -ErrorAction SilentlyContinue

    if ($useGridView) {
        $selectedApps = $allApps | 
            Select-Object Name, Category, Version, Params | 
            Sort-Object Category, Name | 
            Out-GridView -Title "Select Applications (use Ctrl+Click to select multiple)" -OutputMode Multiple
        
        return $selectedApps
    } else {
        # Text-based fallback
        Write-Host "`n  Text-Based Application Selection" -ForegroundColor Yellow
        Write-Host "----------------------------------------`n" -ForegroundColor Yellow

        $groupedApps = $allApps | Group-Object -Property Category | Sort-Object Name
        $index = 1
        $appIndexMap = @{}

        foreach ($group in $groupedApps) {
            Write-Host "`n  $($group.Name):" -ForegroundColor Cyan
            foreach ($app in ($group.Group | Sort-Object Name)) {
                $displayText = "    [$index] $($app.Name)"
                if ($app.Version) { $displayText += " (v$($app.Version))" }
                Write-Host $displayText
                $appIndexMap[$index] = $app
                $index++
            }
        }

        $selection = Read-Host "`nEnter numbers (e.g. 1,3,5-7), 'all', or 'cancel'"
        if ($selection -eq 'cancel' -or [string]::IsNullOrWhiteSpace($selection)) { return @() }
        
        $selectedApps = @()
        if ($selection -eq 'all') {
            $selectedApps = $allApps
        } else {
            $parts = $selection -split ',' | ForEach-Object { $_.Trim() }
            foreach ($part in $parts) {
                if ($part -match '^(\d+)-(\d+)$') {
                    for ($i = [int]$matches[1]; $i -le [int]$matches[2]; $i++) {
                        if ($appIndexMap.ContainsKey($i)) { $selectedApps += $appIndexMap[$i] }
                    }
                } elseif ($part -match '^\d+$') {
                    $num = [int]$part
                    if ($appIndexMap.ContainsKey($num)) { $selectedApps += $appIndexMap[$num] }
                }
            }
        }
        return $selectedApps
    }
}

function Show-InstalledPackages {
    param([array]$Applications)

    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "  Installed Applications Status (Parallel Check)" -ForegroundColor Magenta
    Write-Host "========================================`n" -ForegroundColor Magenta

    # PARALLEL PROCESSING IMPLEMENTATION
    # Use RunspacePool for compatible parallelism in PS 5.1+
    
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, 10) # 10 threads
    $runspacePool.Open()
    $jobs = @()

    $chocoPackages = Get-ChocoPackagesCache
    $wingetList = Get-WingetListCache
    $wingetMap = $script:ChocoToWingetMap

    foreach ($app in $Applications) {
        $appName = if ($app.name) { $app.name } else { $app.Name }
        
        # Pre-calculate simple checks to pass to thread
        $isChoco = $chocoPackages.ContainsKey($appName)
        $chocoVer = if ($isChoco) { $chocoPackages[$appName] } else { $null }
        
        $powershell = [powershell]::Create()
        $powershell.RunspacePool = $runspacePool
        
        # We need to pass the Test-PackageInstalled logic or function into the scriptblock.
        # Since modules are tricky with runspaces, we'll inline a simplified detection logic
        # OR export the detection function content to a string.
        # For simplicity and robustness, we'll stick to Registry checks in the thread since Choco/Winget checks are already done via cache above.

        $scriptBlock = {
            param($name)
            # Simple Registry Check Logic (Simplified for thread)
            $uninstallPaths = @(
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
            
            # Basic search matching logic
            foreach ($path in $uninstallPaths) {
                $matches = Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object { 
                    $_.DisplayName -like "*$name*" -or $_.DisplayName -eq $name
                }
                if ($matches) { return $true }
            }
            return $false
        }

        $powershell.AddScript($scriptBlock).AddArgument($appName) | Out-Null
        
        $job = New-Object PSObject -Property @{
            App = $appName
            Pipe = $powershell
            Result = $powershell.BeginInvoke()
            IsChoco = $isChoco
            ChocoVer = $chocoVer
        }
        $jobs += $job
    }

    # Process results
    foreach ($job in $jobs) {
        $appName = $job.App
        $isChoco = $job.IsChoco
        
        # Wait for thread
        $isReg = $job.Pipe.EndInvoke($job.Result)
        $job.Pipe.Dispose()

        # Winget Check (Fast memory check)
        $wingetId = Resolve-WingetId -Name $appName
        $isWinget = $false
        if ($wingetList) {
            $pattern = "\s" + [regex]::Escape($wingetId) + "\s"
            $isWinget = ($wingetList -match $pattern).Count -gt 0
        }

        if ($isChoco) {
            Write-Host "  [Choco] $appName" -ForegroundColor Green
            Write-Host "    Version: v$($job.ChocoVer)" -ForegroundColor Gray
        } elseif ($isWinget) {
            Write-Host "  [Winget] $appName" -ForegroundColor Cyan
            Write-Host "    Managed by Winget" -ForegroundColor Gray
        } elseif ($isReg) { # Result from parallel thread
            Write-Host "  [Manual] $appName" -ForegroundColor Yellow
            Write-Host "    Installed via Windows (Unmanaged)" -ForegroundColor Gray
        } else {
            Write-Host "  [X] $appName" -ForegroundColor Red
            Write-Host "    Not installed" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    $runspacePool.Close()
    $runspacePool.Dispose()

    Write-Host "`nLegend:" -ForegroundColor Cyan
    Write-Host "  [Choco]  = Managed by Chocolatey" -ForegroundColor Green
    Write-Host "  [Winget] = Managed by Winget" -ForegroundColor Cyan
    Write-Host "  [Manual] = Installed manually (Registry detected)" -ForegroundColor Yellow
    Write-Host "  [X]      = Not installed" -ForegroundColor Red
}

function Show-MainMenu {
    param([string]$RootPath, [string]$GitHubRepo)

    while ($true) {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "  VSBTek Unified App Manager" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan
        Write-Host "  1. Install applications"
        Write-Host "  2. Update applications"
        Write-Host "  3. Uninstall applications"
        Write-Host "  4. List installed applications"
        Write-Host "  5. Upgrade all packages (Hybrid)"
        Write-Host "  6. Manage Package Policies"
        Write-Host "  7. Exit"

        $choice = Read-Host "Enter your choice (1-7)"
        switch ($choice) {
            '1' { return 'Install' }
            '2' { return 'Update' }
            '3' { return 'Uninstall' }
            '4' { return 'List' }
            '5' { return 'Upgrade' }
            '6' { Show-PolicyMenu -RootPath $RootPath -GitHubRepo $GitHubRepo }
            '7' { exit 0 }
        }
    }
}

function Show-PresetMenu {
    param([string]$RootPath)
    $presets = Get-AvailablePresets -Mode 'local' -RootPath $RootPath
    
    while ($true) {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "  Select Application Preset" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        $i = 1
        foreach ($p in $presets) {
            Write-Host "  $i. $($p.Title)"
            $i++
        }
        Write-Host "  $i. Custom Selection"
        Write-Host "  $($i+1). Back to Main Menu"

        $choice = Read-Host "Enter your choice (1-$($i+1))"
        if ($choice -match '^\d+$') {
            $val = [int]$choice
            if ($val -ge 1 -and $val -le $presets.Count) { return $presets[$val-1].ID }
            elseif ($val -eq ($presets.Count + 1)) { return 'custom' }
            elseif ($val -eq ($presets.Count + 2)) { return $null }
        }
    }
}

function Show-PolicyMenu {
    param([string]$RootPath, [string]$GitHubRepo)

    $useGridView = Get-Command Out-GridView -ErrorAction SilentlyContinue

    while ($true) {
        # Assumes that Add-PackagePolicyRule and Remove-PackagePolicyRule exist in the Config module
        $policy = Get-PackagePolicy
        Write-Host "`n========================================" -ForegroundColor Magenta
        Write-Host "  Manage Package Policies" -ForegroundColor Magenta
        Write-Host "========================================`n" -ForegroundColor Magenta

        Write-Host "Current Policies:" -ForegroundColor Yellow

        Write-Host "  Pinned Packages (won't be auto-updated by 'upgrade all'):" -ForegroundColor Gray
        $filteredPinned = $policy.pinned | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($filteredPinned.Count -gt 0) {
            $filteredPinned | ForEach-Object { Write-Host "    - $_" -ForegroundColor White }
        } else {
            Write-Host "    (None)" -ForegroundColor White
        }

        Write-Host "  Prefer Chocolatey For:" -ForegroundColor Gray
        $filteredChoco = $policy.preferChoco | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($filteredChoco.Count -gt 0) {
            $filteredChoco | ForEach-Object { Write-Host "    - $_" -ForegroundColor White }
        } else {
            Write-Host "    (None)" -ForegroundColor White
        }

        Write-Host "  Prefer Winget For:" -ForegroundColor Gray
        $filteredWinget = $policy.preferWinget | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($filteredWinget.Count -gt 0) {
            $filteredWinget | ForEach-Object { Write-Host "    - $_" -ForegroundColor White }
        } else {
            Write-Host "    (None)" -ForegroundColor White
        }
        Write-Host ""
        
        Write-Host "  1. Add 'Pin' rule"
        Write-Host "  2. Add 'Prefer Chocolatey' rule"
        Write-Host "  3. Add 'Prefer Winget' rule"
        Write-Host "  4. Remove a rule for a package"
        Write-Host "  5. Back to Main Menu"

        $choice = Read-Host "Enter choice"
        switch ($choice) {
            '1' {
                $pkgs = @()
                if ($useGridView) {
                    Write-Host "Loading available applications for selection..." -ForegroundColor Gray
                    $allApps = Get-AllAvailableApps -Mode 'local' -RootPath $RootPath -GitHubRepo $GitHubRepo
                    if ($allApps) {
                        $selectedApps = $allApps | Select-Object Name, Category, Version | Sort-Object Category, Name | Out-GridView -Title "Select applications to Pin (use Ctrl+Click to select multiple)" -OutputMode Multiple
                        if ($selectedApps) { $pkgs = $selectedApps.Name }
                    } else { Write-Warning "Could not load application list." }
                } else {
                    $input = Read-Host "Enter package names to Pin, separated by commas (e.g. 'vscode,git')"
                    if (-not [string]::IsNullOrWhiteSpace($input)) {
                        $pkgs = $input.Split(',') | ForEach-Object { $_.Trim() }
                    }
                }

                if ($pkgs.Count -gt 0) {
                    foreach ($pkg in $pkgs) {
                        if ([string]::IsNullOrWhiteSpace($pkg)) { continue }
                        $pkgName = $pkg.ToLower().Trim()
                        Add-PackagePolicyRule -Type 'pinned' -PackageName $pkgName
                        Write-Host "[OK] Pin rule added for '$pkgName'." -ForegroundColor Green

                        Write-Host "  Checking if package is installed to apply pin now..." -ForegroundColor Gray
                        $isChoco = Test-PackageInstalled -PackageName $pkgName -ChocoOnly
                        $isWinget = $false
                        $wingetId = Resolve-WingetId -Name $pkgName
                        $wingetList = Get-WingetListCache
                        if ($wingetId -and $wingetList) {
                            $pattern = '\s' + [regex]::Escape($wingetId) + '\s'
                            if ($wingetList -match $pattern) { $isWinget = $true }
                        }

                        if ($isChoco) { Set-ChocoPin -PackageName $pkgName }
                        elseif ($isWinget) { Set-WingetPin -PackageName $pkgName }
                        else { Write-Host "  '$pkgName' is not currently managed by Choco/Winget. Pin will be applied on next install." -ForegroundColor Gray }
                    }
                }
            }
            '2' {
                $pkgs = @()
                if ($useGridView) {
                    Write-Host "Loading available applications for selection..." -ForegroundColor Gray
                    $allApps = Get-AllAvailableApps -Mode 'local' -RootPath $RootPath -GitHubRepo $GitHubRepo
                    if ($allApps) {
                        $selectedApps = $allApps | Select-Object Name, Category, Version | Sort-Object Category, Name | Out-GridView -Title "Select applications to prefer Chocolatey for (use Ctrl+Click)" -OutputMode Multiple
                        if ($selectedApps) { $pkgs = $selectedApps.Name }
                    } else { Write-Warning "Could not load application list." }
                } else {
                    $input = Read-Host "Enter package names to prefer Chocolatey for, separated by commas"
                    if (-not [string]::IsNullOrWhiteSpace($input)) {
                        $pkgs = $input.Split(',') | ForEach-Object { $_.Trim() }
                    }
                }

                if ($pkgs.Count -gt 0) {
                    foreach ($pkg in $pkgs) {
                        if ([string]::IsNullOrWhiteSpace($pkg)) { continue }
                        Add-PackagePolicyRule -Type 'preferChoco' -PackageName $pkg.ToLower().Trim()
                        Write-Host "[OK] Set preference for '$pkg' to Chocolatey" -ForegroundColor Green
                    }
                }
            }
            '3' {
                $pkgs = @()
                if ($useGridView) {
                    Write-Host "Loading available applications for selection..." -ForegroundColor Gray
                    $allApps = Get-AllAvailableApps -Mode 'local' -RootPath $RootPath -GitHubRepo $GitHubRepo
                    if ($allApps) {
                        $selectedApps = $allApps | Select-Object Name, Category, Version | Sort-Object Category, Name | Out-GridView -Title "Select applications to prefer Winget for (use Ctrl+Click)" -OutputMode Multiple
                        if ($selectedApps) { $pkgs = $selectedApps.Name }
                    } else { Write-Warning "Could not load application list." }
                } else {
                    $input = Read-Host "Enter package names to prefer Winget for, separated by commas"
                    if (-not [string]::IsNullOrWhiteSpace($input)) {
                        $pkgs = $input.Split(',') | ForEach-Object { $_.Trim() }
                    }
                }

                if ($pkgs.Count -gt 0) {
                    foreach ($pkg in $pkgs) {
                        if ([string]::IsNullOrWhiteSpace($pkg)) { continue }
                        Add-PackagePolicyRule -Type 'preferWinget' -PackageName $pkg.ToLower().Trim()
                        Write-Host "[OK] Set preference for '$pkg' to Winget" -ForegroundColor Green
                    }
                }
            }
            '4' {
                $pkgs = @()
                if ($useGridView) {
                    $policy = Get-PackagePolicy
                    $ruledPackages = ($policy.pinned + $policy.preferChoco + $policy.preferWinget) | Select-Object -Unique | Sort-Object
                    if ($ruledPackages.Count -gt 0) {
                        $packageObjects = $ruledPackages | ForEach-Object { [PSCustomObject]@{ PackageName = $_ } }
                        $selectedPkgs = $packageObjects | Out-GridView -Title "Select packages to remove policies from (use Ctrl+Click)" -OutputMode Multiple
                        if ($selectedPkgs) { $pkgs = $selectedPkgs.PackageName }
                    } else {
                        Write-Host "[INFO] No packages have policies to remove." -ForegroundColor Cyan
                    }
                } else {
                    $input = Read-Host "Enter package names to remove from all policies, separated by commas"
                    if (-not [string]::IsNullOrWhiteSpace($input)) {
                        $pkgs = $input.Split(',') | ForEach-Object { $_.Trim() }
                    }
                }

                if ($pkgs.Count -gt 0) {
                    foreach ($pkg in $pkgs) {
                        if ([string]::IsNullOrWhiteSpace($pkg)) { continue }
                        Remove-PackagePolicyRule -PackageName $pkg.ToLower().Trim()
                        Write-Host "[OK] Removed all rules for '$pkg'" -ForegroundColor Green
                    }
                }
            }
            '5' { return }
            default { Write-Warning "Invalid choice." }
        }

        # Pause to show result before looping
        if ($choice -in '1','2','3','4') {
             # Save the in-memory policy changes to the JSON file on disk.
             Save-PackagePolicy -RootPath $RootPath
             Read-Host "Press Enter to continue..." | Out-Null
        }
    }
}


function Show-ContinuePrompt {
    Write-Host "`n  1. Return to Main Menu"
    Write-Host "  2. Exit"
    $choice = Read-Host "Choice"
    if ($choice -eq '2') { return $false }
    return $true
}

Export-ModuleMember -Function Show-CustomSelectionMenu, Show-InstalledPackages, Show-MainMenu, Show-PresetMenu, Show-ContinuePrompt
