# VSBTek Chocolatey Quick Installer - Wrapper Script
# This lightweight wrapper enables one-liner execution via: irm URL | iex
# Downloads and executes the main install-apps.ps1 script

$tempPath = "$env:TEMP\vsbtek-install-apps.ps1"
$scriptUrl = "https://raw.githubusercontent.com/HenryBui21/VSBTek-Chocolatey-Installer/main/install-apps.ps1"
$sha256Url = "https://raw.githubusercontent.com/HenryBui21/VSBTek-Chocolatey-Installer/main/install-apps.ps1.sha256"

Write-Host "VSBTek Quick Installer" -ForegroundColor Cyan
Write-Host "Downloading installer script..." -ForegroundColor Yellow

try {
    # Download the main script with cache-busting
    $cacheBuster = [DateTime]::UtcNow.Ticks
    $urlWithCache = "$scriptUrl?cb=$cacheBuster"
    $content = Invoke-RestMethod -Uri $urlWithCache -Headers @{"Cache-Control"="no-cache"} -TimeoutSec 30 -ErrorAction Stop

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

    # Download and verify SHA256 checksum
    Write-Host "Verifying file integrity..." -ForegroundColor Yellow
    try {
        $sha256UrlWithCache = $sha256Url + "?cb=$cacheBuster"
        $expectedHash = (Invoke-RestMethod -Uri $sha256UrlWithCache -Headers @{"Cache-Control"="no-cache"} -TimeoutSec 10 -ErrorAction Stop).Trim().ToLower()
        $actualHash = (Get-FileHash -Path $tempPath -Algorithm SHA256).Hash.ToLower()

        if ($actualHash -ne $expectedHash) {
            Write-Host "" -ForegroundColor Red
            Write-Host "SECURITY WARNING: SHA256 checksum mismatch!" -ForegroundColor Red
            Write-Host "Expected: $expectedHash" -ForegroundColor Yellow
            Write-Host "Actual:   $actualHash" -ForegroundColor Yellow
            Write-Host "" -ForegroundColor Red
            Write-Host "The downloaded file may have been tampered with or is corrupted." -ForegroundColor Red
            Write-Host "Installation aborted for security reasons." -ForegroundColor Red

            # Clean up and exit
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
            exit 1
        }

        Write-Host "File integrity verified successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "" -ForegroundColor Yellow
        Write-Host "Warning: Could not verify SHA256 checksum" -ForegroundColor Yellow
        Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "" -ForegroundColor Yellow
        Write-Host "Do you want to continue without verification? (Not recommended)" -ForegroundColor Yellow
        $response = Read-Host "Type 'yes' to continue at your own risk"

        if ($response -ne 'yes') {
            Write-Host "Installation cancelled by user." -ForegroundColor Red
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
            exit 1
        }

        Write-Host "Proceeding without verification..." -ForegroundColor Yellow
    }

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
