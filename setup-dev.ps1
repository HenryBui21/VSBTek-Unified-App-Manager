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
if (Test-Path $hookPath) {
    Write-Host "  Pre-commit hook already exists." -ForegroundColor Yellow
    $overwrite = Read-Host "  Overwrite existing hook? (y/n)"
    if ($overwrite -ne 'y') {
        Write-Host "  Skipping hook installation." -ForegroundColor Cyan
    } else {
        & ".\scripts\utils\install-git-hooks.ps1" -Force
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "Failed to install Git hooks. Please check the error above." -ForegroundColor Red
            Write-Host ""
            exit 1
        }
    }
} else {
    & ".\scripts\utils\install-git-hooks.ps1" -Force
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Failed to install Git hooks. Please check the error above." -ForegroundColor Red
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
    Write-Host "Quick commands:" -ForegroundColor White
    Write-Host "  Update hash:  .\scripts\utils\update-sha256.ps1" -ForegroundColor Gray
    Write-Host "  Verify local: .\scripts\tests\verify-hash.ps1" -ForegroundColor Gray
    Write-Host "  Test full:    .\scripts\tests\simulate-quick-install.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Documentation: .\docs\AUTOMATION-README.md" -ForegroundColor Cyan
} else {
    Write-Host "==================================" -ForegroundColor Red
    Write-Host "  Setup Incomplete" -ForegroundColor Red
    Write-Host "==================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Some required files are missing." -ForegroundColor Yellow
    Write-Host "Please check your repository." -ForegroundColor Yellow
}

Write-Host ""
