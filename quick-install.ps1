# VSBTek Chocolatey Quick Installer - Wrapper Script
# This lightweight wrapper enables one-liner execution via: irm URL | iex
# Downloads and executes the main install-apps.ps1 script

$tempPath = "$env:TEMP\vsbtek-install-apps.ps1"
$scriptUrl = "https://raw.githubusercontent.com/HenryBui21/VSBTek-Chocolatey-Installer/main/install-apps.ps1"

Write-Host "VSBTek Quick Installer" -ForegroundColor Cyan
Write-Host "Downloading installer script..." -ForegroundColor Yellow

try {
    # Download the main script
    $content = Invoke-RestMethod -Uri $scriptUrl -ErrorAction Stop

    # Verify it's actually a PowerShell script (not HTML)
    if ($content -match "^\s*<(!DOCTYPE|html|head|body)" -or $content -match "html,\s*body\s*\{") {
        Write-Host "" -ForegroundColor Red
        Write-Host "Error: Downloaded file is HTML, not a PowerShell script!" -ForegroundColor Red
        Write-Host "" -ForegroundColor Yellow
        Write-Host "This usually means:" -ForegroundColor Yellow
        Write-Host "  1. The URL is incorrect or the file doesn't exist on the server" -ForegroundColor Yellow
        Write-Host "  2. The server returned an error page (404, 403, etc.)" -ForegroundColor Yellow
        Write-Host "  3. The web server is not configured to serve .ps1 files" -ForegroundColor Yellow
        Write-Host "" -ForegroundColor White
        Write-Host "Please ensure that install-apps.ps1 is uploaded to:" -ForegroundColor White
        Write-Host "  $scriptUrl" -ForegroundColor Cyan
        Write-Host "" -ForegroundColor White
        Write-Host "Alternative: Download manually and run locally:" -ForegroundColor White
        Write-Host "  git clone https://github.com/HenryBui21/VSBTek-Chocolatey-Installer.git" -ForegroundColor Gray
        Write-Host "  cd VSBTek-Chocolatey-Installer" -ForegroundColor Gray
        Write-Host "  .\install-apps.ps1" -ForegroundColor Gray
        exit 1
    }

    # Save to temp file
    $content | Out-File -FilePath $tempPath -Encoding UTF8 -Force

    Write-Host "Starting installation..." -ForegroundColor Green
    Write-Host ""

    # Execute the main script with interactive mode
    & $tempPath

    # Clean up
    Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host "" -ForegroundColor Red
    Write-Host "Error: Failed to download or execute installer" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "" -ForegroundColor Yellow
    Write-Host "Please check:" -ForegroundColor Yellow
    Write-Host "  1. Internet connection is working" -ForegroundColor Yellow
    Write-Host "  2. URL is accessible: $scriptUrl" -ForegroundColor Yellow
    Write-Host "  3. Firewall/antivirus is not blocking the download" -ForegroundColor Yellow

    # Clean up on error
    if (Test-Path $tempPath) {
        Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
    }

    exit 1
}
