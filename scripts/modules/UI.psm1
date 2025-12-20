
# UI Module
# Depends on: Logger, Config, Detection

function Show-CheckboxSelectionForm {
    param([array]$Apps)

    # Simple stub if WinForms not available or headless
    if ($Host.UI.RawUI.BufferSize) { 
        # Checking if we can actually show UI
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    } catch { return $null }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Select Applications to Install"
    $form.Size = New-Object System.Drawing.Size(800, 600)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(760, 20)
    $label.Text = "Check the applications you want to install:"
    $form.Controls.Add($label)

    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Location = New-Object System.Drawing.Point(10, 35)
    $checkedListBox.Size = New-Object System.Drawing.Size(760, 450)
    $checkedListBox.CheckOnClick = $true

    $groupedApps = $Apps | Group-Object -Property Category | Sort-Object Name
    $appLookup = @{}
    $index = 0

    foreach ($group in $groupedApps) {
        $headerIndex = $checkedListBox.Items.Add("=== $($group.Name.ToUpper()) ===")
        $checkedListBox.SetItemCheckState($headerIndex, 'Indeterminate')

        foreach ($app in ($group.Group | Sort-Object Name)) {
            $displayText = "    $($app.Name)"
            if ($app.Version) { $displayText += " (v$($app.Version))" }
            $itemIndex = $checkedListBox.Items.Add($displayText)
            $appLookup[$itemIndex] = $app
            $index++
        }
    }
    $form.Controls.Add($checkedListBox)

    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Location = New-Object System.Drawing.Point(10, 495)
    $buttonPanel.Size = New-Object System.Drawing.Size(760, 50)

    $selectAllButton = New-Object System.Windows.Forms.Button
    $selectAllButton.Location = New-Object System.Drawing.Point(0, 10)
    $selectAllButton.Text = "Select All"
    $selectAllButton.Add_Click({
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            if ($appLookup.ContainsKey($i)) { $checkedListBox.SetItemChecked($i, $true) }
        }
    })
    $buttonPanel.Controls.Add($selectAllButton)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(550, 10)
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $buttonPanel.Controls.Add($okButton)

    $form.Controls.Add($buttonPanel)
    $form.AcceptButton = $okButton
    
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedApps = @()
        foreach ($i in $checkedListBox.CheckedIndices) {
            if ($appLookup.ContainsKey($i)) {
                $app = $appLookup[$i]
                $selectedApps += [PSCustomObject]@{ name = $app.Name; version = $app.Version; params = $app.Params }
            }
        }
        return $selectedApps
    }
    return $null
}



function Show-TextBasedSelection {
    param([array]$Apps)
    
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "  Text-Based Application Selection" -ForegroundColor Yellow
    Write-Host "========================================`n" -ForegroundColor Yellow

    $groupedApps = $Apps | Group-Object -Property Category
    $index = 1
    $appIndexMap = @{}

    foreach ($group in $groupedApps) {
        Write-Host "`n  $($group.Name):" -ForegroundColor Cyan
        foreach ($app in $group.Group) {
            Write-Host "    [$index] $($app.Name)"
            $appIndexMap[$index] = $app
            $index++
        }
    }

    $selection = Read-Host "Enter numbers (e.g. 1,3,5-7) or 'all'"
    if ($selection -eq 'cancel') { return $null }
    
    $selectedApps = @()
    if ($selection -eq 'all') {
        foreach ($app in $Apps) { $selectedApps += [PSCustomObject]@{ name=$app.Name; version=$app.Version; params=$app.Params } }
    } else {
        $parts = $selection -split ',' | ForEach-Object { $_.Trim() }
        foreach ($part in $parts) {
            if ($part -match '^(\d+)-(\d+)$') {
                for ($i = [int]$matches[1]; $i -le [int]$matches[2]; $i++) {
                    if ($appIndexMap.ContainsKey($i)) { $selectedApps += [PSCustomObject]@{ name=$appIndexMap[$i].Name; version=$appIndexMap[$i].Version; params=$appIndexMap[$i].Params } }
                }
            } elseif ($part -match '^\d+$') {
                $num = [int]$part
                if ($appIndexMap.ContainsKey($num)) { $selectedApps += [PSCustomObject]@{ name=$appIndexMap[$num].Name; version=$appIndexMap[$num].Version; params=$appIndexMap[$num].Params } }
            }
        }
    }
    return $selectedApps
}

function Show-CustomSelectionMenu {
    param([string]$Mode = 'local', [string]$RootPath, [string]$GitHubRepo)

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Custom Application Selection" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $allApps = Get-AllAvailableApps -Mode $Mode -RootPath $RootPath -GitHubRepo $GitHubRepo
    if (-not $allApps) { return $null }

    # Smart Detection Logic
    $canShowGui = $false
    
    # Check 1: Is the environment interactive?
    if ([Environment]::UserInteractive) {
        # Check 2: Can we load Windows Forms?
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $canShowGui = $true
        } catch {
            Write-Warning "GUI libraries not available. Falling back to text mode."
        }
    }

    if ($canShowGui) {
        # Try to show the GUI
        try {
            $selectedApps = Show-CheckboxSelectionForm -Apps $allApps
            
            # Logic: If Show-CheckboxSelectionForm returns $null, it means the user 
            # clicked Cancel or closed the window. We RESPECT that choice and do NOT fallback.
            return $selectedApps
        } catch {
            # Only fallback if the GUI function actually crashed
            Write-Warning "GUI encountered an error. Falling back to text mode."
        }
    }

    # Fallback to Text ONLY if GUI is unavailable or crashed
    return Show-TextBasedSelection -Apps $allApps
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
            '6' { Show-PolicyMenu }
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
        Write-Host "  $($i+1). Cancel"

        $choice = Read-Host "Enter your choice (1-$($i+1))"
        if ($choice -match '^\d+$') {
            $val = [int]$choice
            if ($val -ge 1 -and $val -le $presets.Count) { return $presets[$val-1].ID }
            elseif ($val -eq ($presets.Count + 1)) { return 'custom' }
            elseif ($val -eq ($presets.Count + 2)) { exit 0 }
        }
    }
}

function Show-PolicyMenu {
    while ($true) {
        # Assumes that Add-PackagePolicyRule and Remove-PackagePolicyRule exist in the Config module
        $policy = Get-PackagePolicy
        Write-Host "`n========================================" -ForegroundColor Magenta
        Write-Host "  Manage Package Policies" -ForegroundColor Magenta
        Write-Host "========================================`n" -ForegroundColor Magenta

        Write-Host "Current Policies:" -ForegroundColor Yellow
        Write-Host "  Pinned Packages (won't be auto-updated by 'upgrade all'):" -ForegroundColor Gray
        Write-Host "    $($policy.pinned -join ', ')" -ForegroundColor White
        Write-Host "  Prefer Chocolatey For:" -ForegroundColor Gray
        Write-Host "    $($policy.preferChoco -join ', ')" -ForegroundColor White
        Write-Host "  Prefer Winget For:" -ForegroundColor Gray
        Write-Host "    $($policy.preferWinget -join ', ')" -ForegroundColor White
        Write-Host ""
        
        Write-Host "  1. Add 'Pin' rule"
        Write-Host "  2. Add 'Prefer Chocolatey' rule"
        Write-Host "  3. Add 'Prefer Winget' rule"
        Write-Host "  4. Remove a rule for a package"
        Write-Host "  5. Back to Main Menu"

        $choice = Read-Host "Enter choice"
        switch ($choice) {
            '1' {
                $pkg = Read-Host "Enter package name to Pin (e.g. 'vscode')"
                if (-not [string]::IsNullOrWhiteSpace($pkg)) {
                    Add-PackagePolicyRule -Type 'pinned' -PackageName $pkg.ToLower().Trim()
                    Write-Host "[OK] Added pin for '$pkg'" -ForegroundColor Green
                }
            }
            '2' {
                $pkg = Read-Host "Enter package name to prefer Chocolatey for (e.g. '7zip')"
                if (-not [string]::IsNullOrWhiteSpace($pkg)) {
                    Add-PackagePolicyRule -Type 'preferChoco' -PackageName $pkg.ToLower().Trim()
                    Write-Host "[OK] Set preference for '$pkg' to Chocolatey" -ForegroundColor Green
                }
            }
            '3' {
                $pkg = Read-Host "Enter package name to prefer Winget for (e.g. 'powertoys')"
                if (-not [string]::IsNullOrWhiteSpace($pkg)) {
                    Add-PackagePolicyRule -Type 'preferWinget' -PackageName $pkg.ToLower().Trim()
                    Write-Host "[OK] Set preference for '$pkg' to Winget" -ForegroundColor Green
                }
            }
            '4' {
                $pkg = Read-Host "Enter package name to remove from all policies"
                if (-not [string]::IsNullOrWhiteSpace($pkg)) {
                    Remove-PackagePolicyRule -PackageName $pkg.ToLower().Trim()
                    Write-Host "[OK] Removed all rules for '$pkg'" -ForegroundColor Green
                }
            }
            '5' { return }
            default { Write-Warning "Invalid choice." }
        }
        # Pause to show result before looping
        if ($choice -in '1','2','3','4') {
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
