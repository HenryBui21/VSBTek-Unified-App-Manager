# Development Setup Script
# Quick setup for developers

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  VSBTek Development Setup" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This will setup your development environment:" -ForegroundColor White
Write-Host "  1. Install Git hooks for auto SHA256 updates" -ForegroundColor Gray
Write-Host "  2. Verify repository structure" -ForegroundColor Gray
Write-Host ""

$response = Read-Host "Continue? (y/n)"
if ($response -ne 'y') {
    Write-Host "Setup cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "[1/2] Installing Git hooks..." -ForegroundColor Yellow

# Check if hook already exists
$hookPath = ".git\hooks\pre-commit"
$psHookPath = ".git\hooks\pre-commit.ps1"

if (Test-Path $hookPath) {
    Write-Host "  Pre-commit hook already exists." -ForegroundColor Yellow
    $overwrite = Read-Host "  Overwrite existing hook? (y/n)"
    if ($overwrite -ne 'y') {
        Write-Host "  Skipping hook installation." -ForegroundColor Cyan
        $hookInstalled = $false
    } else {
        $hookInstalled = $true
    }
} else {
    $hookInstalled = $true
}

if ($hookInstalled) {
    try {
        Write-Host "  Installing pre-commit hook..." -ForegroundColor Yellow

        # Create the shell hook that calls PowerShell script
        $hookContent = @'
#!/bin/sh
# Pre-commit hook - calls PowerShell implementation
# Auto-updates SHA256 hash when install-apps.ps1 changes

powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".git/hooks/pre-commit.ps1"
exit $?
'@

        # Create the PowerShell hook script
        $psHookContent = @'
# PowerShell Pre-commit Hook
# Auto-updates SHA256 hash when install-apps.ps1 changes

# Get list of staged files
$stagedFiles = git diff --cached --name-only

if ($stagedFiles -contains "install-apps.ps1") {
    Write-Host ""
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host "  Auto-updating SHA256 hash..." -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host ""

    try {
        # Read file content and convert to LF line endings (as GitHub serves it)
        $content = Get-Content 'install-apps.ps1' -Raw
        $lfContent = $content -replace "`r`n", "`n"

        # Write to temp file with LF endings
        $tempFile = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($tempFile, $lfContent, [System.Text.Encoding]::UTF8)

        # Calculate hash
        $hash = (Get-FileHash $tempFile -Algorithm SHA256).Hash.ToLower()

        # Cleanup temp file
        Remove-Item $tempFile -Force

        Write-Host "Calculated hash (LF line endings):" -ForegroundColor Yellow
        Write-Host $hash -ForegroundColor Cyan
        Write-Host ""

        # Update .sha256 file
        $hash | Out-File 'install-apps.ps1.sha256' -Encoding ASCII -NoNewline

        # Stage the updated .sha256 file
        git add install-apps.ps1.sha256

        Write-Host "[OK] SHA256 hash updated and staged automatically" -ForegroundColor Green
        Write-Host "  File: install-apps.ps1.sha256" -ForegroundColor Gray
        Write-Host ""

        exit 0
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] Failed to update SHA256 hash" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please update manually:" -ForegroundColor Yellow
        Write-Host "  .\scripts\utils\update-sha256.ps1" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }
}

exit 0
'@

        # Write both hooks
        $hookContent | Out-File $hookPath -Encoding ASCII -Force
        $psHookContent | Out-File $psHookPath -Encoding UTF8 -Force

        Write-Host ""
        Write-Host "  [OK] Pre-commit hook installed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "  What this does:" -ForegroundColor White
        Write-Host "    - Detects when install-apps.ps1 is committed" -ForegroundColor Gray
        Write-Host "    - Calculates SHA256 hash (with LF line endings)" -ForegroundColor Gray
        Write-Host "    - Updates install-apps.ps1.sha256 automatically" -ForegroundColor Gray
        Write-Host "    - Stages the .sha256 file in the same commit" -ForegroundColor Gray
        Write-Host ""
    }
    catch {
        Write-Host ""
        Write-Host "  [ERROR] Failed to install hook" -ForegroundColor Red
        Write-Host "  Reason: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
}

Write-Host ""
Write-Host "[2/2] Verifying repository..." -ForegroundColor Yellow

$requiredFiles = @(
    "install-apps.ps1",
    "install-apps.ps1.sha256",
    "quick-install.ps1",
    "README.md"
)

$allGood = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  [OK] $file" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $file" -ForegroundColor Red
        $allGood = $false
    }
}

Write-Host ""
if ($allGood) {
    Write-Host "==================================" -ForegroundColor Green
    Write-Host "  Setup Complete!" -ForegroundColor Green
    Write-Host "==================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "You're ready to develop!" -ForegroundColor White
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor White
    Write-Host "  1. Make changes to install-apps.ps1" -ForegroundColor Gray
    Write-Host "  2. Git commit will auto-update SHA256 hash" -ForegroundColor Gray
    Write-Host "  3. Push to GitHub" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Documentation: .\docs\AUTOMATION-README.md" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Note: Additional dev tools are available in scripts/ (local only)" -ForegroundColor DarkGray
} else {
    Write-Host "==================================" -ForegroundColor Red
    Write-Host "  Setup Incomplete" -ForegroundColor Red
    Write-Host "==================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Some required files are missing." -ForegroundColor Yellow
    Write-Host "Please check your repository." -ForegroundColor Yellow
}

Write-Host ""
